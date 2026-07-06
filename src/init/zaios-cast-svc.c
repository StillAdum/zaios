/*
 * zaios-cast-svc.c — ZAIos Cast (Miracast / Wi-Fi Display) sink service.
 *
 * Wraps miraclecast (https://github.com/albfan/miraclecast) to provide a
 * simple JSON-over-socket API for the Qt shell:
 *
 *   Request:
 *     {"cmd":"start"}              - start the sink
 *     {"cmd":"stop"}               - stop the sink
 *     {"cmd":"status"}             - get sink state
 *     {"cmd":"list_peers"}         - list paired/pending peers
 *     {"cmd":"accept","peer":"X"}  - accept a connection from peer X
 *     {"cmd":"reject","peer":"X"}  - reject a connection from peer X
 *
 *   Response:
 *     {"ok":true,"state":"listening","peers":[...]}
 *
 * Under the hood we run:
 *   miracle-wifid  (Wi-Fi Direct manager)
 *   miracle-sinkctl (Wi-Fi Display sink)
 *
 * When a peer connects, miracle-sinkctl launches a gstreamer pipeline that
 * receives H.264 video + AAC audio over RTP and plays it via the local
 * audio/video output.
 *
 * Why Miracast instead of Google Cast?
 *   Google Cast is proprietary. Miracast (Wi-Fi Display) is an open IEEE
 *   standard supported by Windows 10+/Android 4.2+/macOS (via third-party).
 *   It does NOT receive casts from iOS or Chrome (those use Castv2), but it
 *   is the closest open alternative. The Qt shell can also bundle a
 *   browser-based "cast sender" page that handles the Castv2 protocol
 *   (see src/shell/qml/pages/Cast.qml).
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <poll.h>
#include <ctype.h>

#define SOCK_PATH "/run/zaios/cast.sock"
#define MAX_CLIENTS 8

static int running = 1;
static pid_t wifid_pid = 0;
static pid_t sinkctl_pid = 0;
static int cast_state = 0; /* 0=stopped, 1=starting, 2=listening, 3=connected */

static void on_sigterm(int s) { (void)s; running = 0; }

static int mkdir_p(const char *path, mode_t mode) {
    char tmp[256];
    snprintf(tmp, sizeof(tmp), "%s", path);
    size_t len = strlen(tmp);
    if (len == 0) return 0;
    if (tmp[len-1] == '/') tmp[len-1] = 0;
    for (char *p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = 0;
            if (mkdir(tmp, mode) < 0 && errno != EEXIST) return -1;
            *p = '/';
        }
    }
    if (mkdir(tmp, mode) < 0 && errno != EEXIST) return -1;
    return 0;
}

static void cast_start(void) {
    if (cast_state != 0) return;
    cast_state = 1;

    /* Find a Wi-Fi interface that supports P2P (wlan0 → p2p-wlan0-0) */
    system("iw phy phy0 interface add p2p-wlan0-0 type p2p 2>/dev/null");
    system("ip link set p2p-wlan0-0 up 2>/dev/null");

    /* Start miracle-wifid */
    wifid_pid = fork();
    if (wifid_pid == 0) {
        execlp("miracle-wifid", "miracle-wifid",
               "--interface", "p2p-wlan0-0",
               "--log-level", "info",
               NULL);
        _exit(127);
    }
    sleep(1);

    /* Start miracle-sinkctl (Wi-Fi Display sink) */
    sinkctl_pid = fork();
    if (sinkctl_pid == 0) {
        execlp("miracle-sinkctl", "miracle-sinkctl",
               "--external-player", "/usr/lib/zaios/zaios-cast-player.sh",
               NULL);
        _exit(127);
    }
    cast_state = 2;
}

static void cast_stop(void) {
    if (sinkctl_pid > 0) { kill(sinkctl_pid, SIGTERM); waitpid(sinkctl_pid, NULL, 0); sinkctl_pid = 0; }
    if (wifid_pid  > 0) { kill(wifid_pid,  SIGTERM); waitpid(wifid_pid,  NULL, 0); wifid_pid = 0; }
    cast_state = 0;
}

static char *handle_request(const char *req) {
    char buf[1024];
    strncpy(buf, req, sizeof(buf) - 1);
    buf[sizeof(buf)-1] = 0;

    char cmd[32] = {0};
    char *p = strstr(buf, "\"cmd\"");
    if (!p) return strdup("{\"ok\":false,\"error\":\"no cmd\"}\n");
    p = strchr(p + 5, ':'); if (!p) return strdup("{\"ok\":false,\"error\":\"bad cmd\"}\n");
    p++;
    while (*p && (*p==' '||*p=='\t'||*p=='"')) p++;
    int i = 0;
    while (*p && *p != '"' && i < (int)sizeof(cmd)-1) cmd[i++] = *p++;
    cmd[i] = 0;

    const char *state_str = cast_state == 0 ? "stopped" :
                            cast_state == 1 ? "starting" :
                            cast_state == 2 ? "listening" : "connected";

    if (!strcmp(cmd, "start")) {
        cast_start();
        char *r = malloc(256);
        snprintf(r, 256, "{\"ok\":true,\"state\":\"%s\"}\n", state_str);
        return r;
    }
    if (!strcmp(cmd, "stop")) {
        cast_stop();
        return strdup("{\"ok\":true,\"state\":\"stopped\"}\n");
    }
    if (!strcmp(cmd, "status")) {
        char *r = malloc(256);
        snprintf(r, 256, "{\"ok\":true,\"state\":\"%s\"}\n", state_str);
        return r;
    }
    if (!strcmp(cmd, "list_peers")) {
        /* miracle-sinkctl peer list comes from its DBus interface — we run
         * a helper script that queries it. */
        FILE *fp = popen("miracle-sinkctl list-peers 2>/dev/null", "r");
        char *resp = malloc(2048);
        strcpy(resp, "{\"ok\":true,\"peers\":[");
        size_t len = strlen(resp);
        if (fp) {
            char line[256];
            int first = 1;
            while (fgets(line, sizeof(line), fp)) {
                char peer[64] = {0}, name[128] = {0};
                if (sscanf(line, "%63s %127[^\n]", peer, name) >= 1) {
                    if (!first) strcat(resp + len, ",");
                    len = strlen(resp);
                    snprintf(resp + len, 2048 - len,
                             "{\"peer\":\"%s\",\"name\":\"%s\"}",
                             peer, name);
                    first = 0;
                }
            }
            pclose(fp);
        }
        strcat(resp, "]}\n");
        return resp;
    }
    if (!strcmp(cmd, "accept") || !strcmp(cmd, "reject")) {
        /* Extract peer */
        char peer[64] = {0};
        char *q = strstr(buf, "\"peer\"");
        if (q) {
            q = strchr(q + 6, ':'); if (q) q++;
            while (*q && (*q==' '||*q=='\t'||*q=='"')) q++;
            i = 0; while (*q && *q != '"' && i < (int)sizeof(peer)-1) peer[i++] = *q++;
        }
        char cmdbuf[256];
        snprintf(cmdbuf, sizeof(cmdbuf),
                 "miracle-sinkctl %s %s 2>/dev/null",
                 cmd, peer);
        system(cmdbuf);
        return strdup("{\"ok\":true}\n");
    }
    return strdup("{\"ok\":false,\"error\":\"unknown cmd\"}\n");
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    signal(SIGTERM, on_sigterm);
    signal(SIGINT,  on_sigterm);

    mkdir_p("/run/zaios", 0755);
    unlink(SOCK_PATH);

    int s = socket(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK, 0);
    if (s < 0) { perror("socket"); return 1; }
    struct sockaddr_un addr = {0};
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCK_PATH, sizeof(addr.sun_path) - 1);
    if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) < 0) { perror("bind"); return 1; }
    if (listen(s, 8) < 0) { perror("listen"); return 1; }
    chmod(SOCK_PATH, 0666);

    int clients[MAX_CLIENTS] = {0};
    int ncli = 0;

    fprintf(stderr, "[zaios-cast] listening on %s\n", SOCK_PATH);

    while (running) {
        struct pollfd pfds[MAX_CLIENTS + 1];
        pfds[0].fd = s; pfds[0].events = POLLIN;
        for (int i = 0; i < ncli; i++) {
            pfds[i + 1].fd = clients[i];
            pfds[i + 1].events = POLLIN;
        }
        int ret = poll(pfds, ncli + 1, 1000);
        if (ret <= 0) {
            if (ret < 0 && errno != EINTR) perror("poll");
            continue;
        }
        if (pfds[0].revents & POLLIN) {
            int c = accept4(s, NULL, NULL, SOCK_NONBLOCK);
            if (c >= 0 && ncli < MAX_CLIENTS) clients[ncli++] = c;
            else if (c >= 0) close(c);
        }
        for (int i = 0; i < ncli; ) {
            if (!(pfds[i + 1].revents & POLLIN)) { i++; continue; }
            char req[2048] = {0};
            ssize_t r = read(clients[i], req, sizeof(req) - 1);
            if (r <= 0) { close(clients[i]); clients[i] = clients[--ncli]; continue; }
            while (r > 0 && (req[r-1]=='\n'||req[r-1]=='\r')) req[--r] = 0;
            char *resp = handle_request(req);
            if (resp) { write(clients[i], resp, strlen(resp)); free(resp); }
            i++;
        }
    }
    cast_stop();
    unlink(SOCK_PATH);
    return 0;
}
