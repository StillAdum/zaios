/*
 * zaios-network-svc.c — ZAIos network management service.
 *
 * Provides a Unix-socket API at /run/zaios/network.sock for the Qt shell
 * to:
 *   - list WiFi networks (scan)
 *   - connect to a WiFi network
 *   - disconnect
 *   - get connection state
 *   - get IP address
 *
 * Internally it shells out to wpa_supplicant (via wpa_cli) and ip(8).
 * This avoids the complexity of shipping NetworkManager for the very small
 * set of operations ZAIos needs.
 *
 * Why not use NetworkManager directly?
 *   - The init system already starts NetworkManager, but the shell's UI
 *     talks to wpa_supplicant for simplicity. Both can coexist: NM manages
 *     Ethernet + saved Wi-Fi networks; this service exposes wpa_cli for
 *     the shell to do scan/connect on demand.
 *
 * Protocol: simple JSON line-based request/response.
 *   Request:  {"cmd":"scan"}
 *             {"cmd":"list"}
 *             {"cmd":"connect","ssid":"MyNet","psk":"secret"}
 *             {"cmd":"disconnect"}
 *             {"cmd":"status"}
 *   Response: {"ok":true,"networks":[...]}
 *             {"ok":false,"error":"..."}
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

#define SOCK_PATH "/run/zaios/network.sock"
#define MAX_CLIENTS 16

static int running = 1;
static void on_sigterm(int s) { (void)s; running = 0; }

/* Run a shell command, return its stdout (caller frees) */
static char *run_cmd(const char *cmd) {
    FILE *p = popen(cmd, "r");
    if (!p) return NULL;
    size_t cap = 4096, len = 0;
    char *buf = malloc(cap);
    if (!buf) { pclose(p); return NULL; }
    size_t r;
    while ((r = fread(buf + len, 1, cap - len - 1, p)) > 0) {
        len += r;
        if (len + 1 >= cap) {
            cap *= 2;
            char *nb = realloc(buf, cap);
            if (!nb) { pclose(p); free(buf); return NULL; }
            buf = nb;
        }
    }
    buf[len] = 0;
    pclose(p);
    return buf;
}

/* Escape a string for JSON */
static void json_escape(const char *in, char *out, size_t outsz) {
    size_t o = 0;
    for (size_t i = 0; in[i] && o < outsz - 2; i++) {
        if (in[i] == '"' || in[i] == '\\') {
            if (o + 2 < outsz) out[o++] = '\\';
            if (o + 1 < outsz) out[o++] = in[i];
        } else if ((unsigned char)in[i] < 0x20) {
            if (o + 6 < outsz) {
                o += snprintf(out + o, outsz - o, "\\u%04x", (unsigned char)in[i]);
            }
        } else {
            out[o++] = in[i];
        }
    }
    out[o] = 0;
}

/* Handle a single JSON request and return JSON response (caller frees) */
static char *handle_request(const char *req) {
    /* Very simple JSON parser — only handles our known commands */
    char buf[1024];
    strncpy(buf, req, sizeof(buf) - 1);
    buf[sizeof(buf)-1] = 0;

    /* Extract "cmd" field */
    char cmd[32] = {0};
    char *p = strstr(buf, "\"cmd\"");
    if (!p) return strdup("{\"ok\":false,\"error\":\"no cmd\"}\n");
    p = strchr(p + 5, ':');
    if (!p) return strdup("{\"ok\":false,\"error\":\"bad cmd\"}\n");
    p++;
    while (*p && (*p==' '||*p=='\t'||*p=='"')) p++;
    int i = 0;
    while (*p && *p != '"' && i < (int)sizeof(cmd)-1) cmd[i++] = *p++;
    cmd[i] = 0;

    if (!strcmp(cmd, "scan")) {
        system("wpa_cli -i wlan0 scan >/dev/null 2>&1");
        sleep(3);
        return strdup("{\"ok\":true}\n");
    }

    if (!strcmp(cmd, "list")) {
        char *out = run_cmd("wpa_cli -i wlan0 scan_results 2>/dev/null");
        if (!out) return strdup("{\"ok\":false,\"error\":\"scan_results failed\"}\n");

        /* Parse wpa_cli output:
         * bssid / frequency / signal level / flags / ssid
         * Skip header line */
        char *lines = NULL;
        char *save = NULL;
        char *tok = strtok_r(out, "\n", &save);
        int first = 1;
        size_t cap = 4096, len = 0;
        char *resp = malloc(cap);
        len += snprintf(resp + len, cap - len, "{\"ok\":true,\"networks\":[");
        while (tok) {
            if (first) { first = 0; tok = strtok_r(NULL, "\n", &save); continue; }
            char bssid[32] = {0}, flags[64] = {0}, ssid[128] = {0};
            int freq = 0, sig = 0;
            sscanf(tok, "%31s %d %d %63s %127[^\n]",
                   bssid, &freq, &sig, flags, ssid);
            /* trim trailing whitespace from ssid */
            char *end = ssid + strlen(ssid);
            while (end > ssid && isspace((unsigned char)end[-1])) *--end = 0;
            char essid[256], eflags[128];
            json_escape(ssid,   essid,  sizeof(essid));
            json_escape(flags,  eflags, sizeof(eflags));
            char entry[512];
            int n = snprintf(entry, sizeof(entry),
                "%s{\"ssid\":\"%s\",\"bssid\":\"%s\",\"signal\":%d,\"freq\":%d,\"flags\":\"%s\"}",
                (len > 30 ? "," : ""), essid, bssid, sig, freq, eflags);
            if (len + n + 4 >= cap) {
                cap *= 2;
                resp = realloc(resp, cap);
            }
            strcat(resp + len, entry);
            len += n;
            tok = strtok_r(NULL, "\n", &save);
        }
        len = strlen(resp);
        if (len + 4 >= cap) { cap += 4; resp = realloc(resp, cap); }
        strcat(resp + len, "]}\n");
        free(out);
        return resp;
    }

    if (!strcmp(cmd, "connect")) {
        char ssid[128] = {0}, psk[128] = {0};
        /* Extract ssid */
        char *q = strstr(buf, "\"ssid\"");
        if (q) {
            q = strchr(q + 6, ':'); if (q) q++;
            while (*q && (*q==' '||*q=='\t'||*q=='"')) q++;
            i = 0; while (*q && *q != '"' && i < (int)sizeof(ssid)-1) ssid[i++] = *q++;
        }
        q = strstr(buf, "\"psk\"");
        if (q) {
            q = strchr(q + 5, ':'); if (q) q++;
            while (*q && (*q==' '||*q=='\t'||*q=='"')) q++;
            i = 0; while (*q && *q != '"' && i < (int)sizeof(psk)-1) psk[i++] = *q++;
        }

        /* Add network via wpa_cli */
        char cmdbuf[512];
        snprintf(cmdbuf, sizeof(cmdbuf),
                 "wpa_cli -i wlan0 add_network 2>/dev/null");
        char *nid_str = run_cmd(cmdbuf);
        if (!nid_str) return strdup("{\"ok\":false,\"error\":\"add_network failed\"}\n");
        int nid = atoi(nid_str);
        free(nid_str);

        snprintf(cmdbuf, sizeof(cmdbuf),
                 "wpa_cli -i wlan0 set_network %d ssid '\"%s\"' >/dev/null 2>&1", nid, ssid);
        system(cmdbuf);
        if (psk[0]) {
            snprintf(cmdbuf, sizeof(cmdbuf),
                     "wpa_cli -i wlan0 set_network %d psk '\"%s\"' >/dev/null 2>&1", nid, psk);
        } else {
            snprintf(cmdbuf, sizeof(cmdbuf),
                     "wpa_cli -i wlan0 set_network %d key_mgmt NONE >/dev/null 2>&1", nid);
        }
        system(cmdbuf);
        snprintf(cmdbuf, sizeof(cmdbuf),
                 "wpa_cli -i wlan0 enable_network %d >/dev/null 2>&1", nid);
        system(cmdbuf);
        system("wpa_cli -i wlan0 save_config >/dev/null 2>&1");
        return strdup("{\"ok\":true}\n");
    }

    if (!strcmp(cmd, "disconnect")) {
        system("wpa_cli -i wlan0 disconnect >/dev/null 2>&1");
        return strdup("{\"ok\":true}\n");
    }

    if (!strcmp(cmd, "status")) {
        char *out = run_cmd("wpa_cli -i wlan0 status 2>/dev/null");
        if (!out) return strdup("{\"ok\":false,\"error\":\"status failed\"}\n");
        char *save = NULL;
        char *tok = strtok_r(out, "\n", &save);
        char wpa_state[32] = {0}, ssid[128] = {0}, ip[64] = {0};
        while (tok) {
            if (!strncmp(tok, "wpa_state=", 10)) strncpy(wpa_state, tok + 10, sizeof(wpa_state)-1);
            else if (!strncmp(tok, "ssid=", 5)) strncpy(ssid, tok + 5, sizeof(ssid)-1);
            else if (!strncmp(tok, "ip_address=", 11)) strncpy(ip, tok + 11, sizeof(ip)-1);
            tok = strtok_r(NULL, "\n", &save);
        }
        free(out);
        char essid[256], eip[128];
        json_escape(ssid, essid, sizeof(essid));
        json_escape(ip,   eip,   sizeof(eip));
        char *resp = malloc(512);
        snprintf(resp, 512,
                 "{\"ok\":true,\"state\":\"%s\",\"ssid\":\"%s\",\"ip\":\"%s\"}\n",
                 wpa_state, essid, eip);
        return resp;
    }

    return strdup("{\"ok\":false,\"error\":\"unknown cmd\"}\n");
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    signal(SIGTERM, on_sigterm);
    signal(SIGINT,  on_sigterm);

    mkdir("/run/zaios", 0755);
    unlink(SOCK_PATH);

    int s = socket(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK, 0);
    if (s < 0) { perror("socket"); return 1; }
    struct sockaddr_un addr = {0};
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCK_PATH, sizeof(addr.sun_path) - 1);
    if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind"); return 1;
    }
    if (listen(s, 8) < 0) { perror("listen"); return 1; }
    chmod(SOCK_PATH, 0666);

    int clients[MAX_CLIENTS] = {0};
    int ncli = 0;

    fprintf(stderr, "[zaios-network] listening on %s\n", SOCK_PATH);

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

        /* Accept new */
        if (pfds[0].revents & POLLIN) {
            int c = accept4(s, NULL, NULL, SOCK_NONBLOCK);
            if (c >= 0 && ncli < MAX_CLIENTS) {
                clients[ncli++] = c;
            } else if (c >= 0) {
                close(c);
            }
        }

        /* Read from clients */
        for (int i = 0; i < ncli; ) {
            if (!(pfds[i + 1].revents & POLLIN)) { i++; continue; }
            char req[2048] = {0};
            ssize_t r = read(clients[i], req, sizeof(req) - 1);
            if (r <= 0) {
                close(clients[i]);
                clients[i] = clients[--ncli];
                continue;
            }
            /* Strip trailing newline */
            while (r > 0 && (req[r-1] == '\n' || req[r-1] == '\r')) req[--r] = 0;
            char *resp = handle_request(req);
            if (resp) {
                write(clients[i], resp, strlen(resp));
                free(resp);
            }
            i++;
        }
    }

    unlink(SOCK_PATH);
    return 0;
}
