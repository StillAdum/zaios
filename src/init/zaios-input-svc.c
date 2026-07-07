/*
 * zaios-input-svc.c — ZAIos input event router.
 *
 * Reads raw evdev events from /dev/input/event*, decodes them into:
 *   - keys (for D-pad remotes, keyboards)
 *   - relative motion (for air mice)
 *   - absolute motion (for touchscreens)
 *
 * Then forwards them to the Qt shell via a Unix socket at
 *   /run/zaios/input.sock
 *
 * The Qt shell subscribes to this socket and feeds events into its
 * QInputEvent pipeline (so the QML UI's focus chain + cursor both work).
 *
 * Why a separate process?
 *   - evdev requires root (or udev rules). One privileged process can read
 *     all devices and forward to the unprivileged Qt shell.
 *   - Decouples input hotplug from the GUI.
 *   - Survives GUI crashes; the GUI reconnects on restart.
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <dirent.h>
#include <poll.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <linux/input.h>
#include <linux/input-event-codes.h>

#define INPUT_DEV_DIR "/dev/input"
#define SOCK_PATH     "/run/zaios/input.sock"
#define MAX_DEVICES   32

/* Forward declaration - defined at end of file */
static int mkdir_p(const char *path, mode_t mode);

static int running = 1;
static void on_sigterm(int s) { (void)s; running = 0; }

struct input_dev {
    int fd;
    char path[256];
    char name[128];
    int has_keys;
    int has_rel;
    int has_abs;
};

static struct input_dev devs[MAX_DEVICES];
static int dev_count = 0;
static int *client_fds = NULL;
static int client_count = 0;
static int client_cap = 0;

static int open_input_devices(void) {
    DIR *d = opendir(INPUT_DEV_DIR);
    if (!d) {
        perror("opendir " INPUT_DEV_DIR);
        return -1;
    }
    struct dirent *de;
    while ((de = readdir(d)) != NULL && dev_count < MAX_DEVICES) {
        if (strncmp(de->d_name, "event", 5) != 0) continue;

        char path[256];
        snprintf(path, sizeof(path), "%s/%s", INPUT_DEV_DIR, de->d_name);
        int fd = open(path, O_RDONLY | O_NONBLOCK);
        if (fd < 0) continue;

        /* Try to grab the device (exclusive) — optional */
        /* ioctl(fd, EVIOCGRAB, 1); */

        char name[128] = {0};
        ioctl(fd, EVIOCGNAME(sizeof(name)), name);

        /* Read device capabilities */
        unsigned long evbits[4] = {0};
        ioctl(fd, EVIOCGBIT(EV_SYN, sizeof(evbits)), evbits);

        struct input_dev *dev = &devs[dev_count];
        dev->fd = fd;
        strncpy(dev->path, path, sizeof(dev->path) - 1);
        strncpy(dev->name, name, sizeof(dev->name) - 1);
        dev->has_keys = (evbits[0] & (1 << EV_KEY)) != 0;
        dev->has_rel  = (evbits[0] & (1 << EV_REL)) != 0;
        dev->has_abs  = (evbits[0] & (1 << EV_ABS)) != 0;

        fprintf(stderr, "[zaios-input] opened %s (%s) keys=%d rel=%d abs=%d\n",
                path, name, dev->has_keys, dev->has_rel, dev->has_abs);
        dev_count++;
    }
    closedir(d);
    return dev_count;
}

/* Set up the listening socket */
static int setup_socket(void) {
    mkdir_p("/run/zaios", 0755);
    unlink(SOCK_PATH);

    int s = socket(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK, 0);
    if (s < 0) { perror("socket"); return -1; }
    struct sockaddr_un addr = {0};
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCK_PATH, sizeof(addr.sun_path) - 1);
    if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind"); close(s); return -1;
    }
    if (listen(s, 8) < 0) {
        perror("listen"); close(s); return -1;
    }
    chmod(SOCK_PATH, 0666);
    return s;
}

/* Broadcast an event JSON line to all clients (drop clients that have closed) */
static void broadcast_event(const char *json) {
    for (int i = 0; i < client_count; ) {
        int n = write(client_fds[i], json, strlen(json));
        if (n < 0 && (errno == EPIPE || errno == ECONNRESET)) {
            close(client_fds[i]);
            client_fds[i] = client_fds[--client_count];
            continue;
        }
        i++;
    }
}

/* Translate evdev key code → Qt-friendly key name (subset) */
static const char *key_name(int code) {
    switch (code) {
        case KEY_UP:     return "Up";
        case KEY_DOWN:   return "Down";
        case KEY_LEFT:   return "Left";
        case KEY_RIGHT:  return "Right";
        case KEY_OK:
        case KEY_ENTER:  return "Ok";
        case KEY_BACK:   return "Back";
        case KEY_HOME:   return "Home";
        case KEY_MENU:   return "Menu";
        case KEY_PLAY:   return "Play";
        case KEY_PAUSE:  return "Pause";
        case KEY_STOP:   return "Stop";
        case KEY_NEXT:   return "Next";
        case KEY_PREVIOUS: return "Previous";
        case KEY_REWIND: return "Rewind";
        case KEY_FASTFORWARD: return "FastForward";
        case KEY_VOLUMEUP:   return "VolumeUp";
        case KEY_VOLUMEDOWN: return "VolumeDown";
        case KEY_MUTE:       return "Mute";
        case KEY_POWER:      return "Power";
        case KEY_SEARCH:     return "Search";
        case KEY_RED:        return "Red";
        case KEY_GREEN:      return "Green";
        case KEY_YELLOW:     return "Yellow";
        case KEY_BLUE:       return "Blue";
        case KEY_0: return "0"; case KEY_1: return "1"; case KEY_2: return "2";
        case KEY_3: return "3"; case KEY_4: return "4"; case KEY_5: return "5";
        case KEY_6: return "6"; case KEY_7: return "7"; case KEY_8: return "8";
        case KEY_9: return "9";
        default: {
            static char buf[16];
            snprintf(buf, sizeof(buf), "Key%d", code);
            return buf;
        }
    }
}

static void handle_event(struct input_dev *dev, struct input_event *ev) {
    char json[256];
    if (ev->type == EV_KEY && dev->has_keys) {
        const char *state = (ev->value == 0) ? "released"
                          : (ev->value == 1) ? "pressed" : "repeat";
        snprintf(json, sizeof(json),
                 "{\"type\":\"key\",\"key\":\"%s\",\"state\":\"%s\",\"dev\":\"%s\"}\n",
                 key_name(ev->code), state, dev->name);
        broadcast_event(json);
    } else if (ev->type == EV_REL && dev->has_rel) {
        if (ev->code == REL_X) {
            snprintf(json, sizeof(json),
                     "{\"type\":\"relx\",\"value\":%d,\"dev\":\"%s\"}\n",
                     ev->value, dev->name);
            broadcast_event(json);
        } else if (ev->code == REL_Y) {
            snprintf(json, sizeof(json),
                     "{\"type\":\"rely\",\"value\":%d,\"dev\":\"%s\"}\n",
                     ev->value, dev->name);
            broadcast_event(json);
        } else if (ev->code == REL_WHEEL) {
            snprintf(json, sizeof(json),
                     "{\"type\":\"wheel\",\"value\":%d,\"dev\":\"%s\"}\n",
                     ev->value, dev->name);
            broadcast_event(json);
        }
    } else if (ev->type == EV_ABS && dev->has_abs) {
        if (ev->code == ABS_X || ev->code == ABS_Y) {
            snprintf(json, sizeof(json),
                     "{\"type\":\"abs\",\"axis\":%d,\"value\":%d,\"dev\":\"%s\"}\n",
                     ev->code, ev->value, dev->name);
            broadcast_event(json);
        }
    }
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    signal(SIGTERM, on_sigterm);
    signal(SIGINT,  on_sigterm);

    if (open_input_devices() <= 0) {
        fprintf(stderr, "[zaios-input] no input devices found\n");
        return 1;
    }

    int listen_fd = setup_socket();
    if (listen_fd < 0) return 1;

    fprintf(stderr, "[zaios-input] listening on %s\n", SOCK_PATH);

    /* Main poll loop */
    struct pollfd pfds[MAX_DEVICES + 8];
    while (running) {
        int n = 0;
        /* Add listen socket */
        pfds[n].fd = listen_fd;
        pfds[n].events = POLLIN;
        n++;
        /* Add input devices */
        for (int i = 0; i < dev_count; i++) {
            pfds[n].fd = devs[i].fd;
            pfds[n].events = POLLIN;
            n++;
        }
        /* Add clients (for write-ready detection — not used here) */

        int ret = poll(pfds, n, 1000);
        if (ret < 0) {
            if (errno == EINTR) continue;
            perror("poll");
            break;
        }
        if (ret == 0) continue;

        /* Accept new clients */
        if (pfds[0].revents & POLLIN) {
            int c = accept4(listen_fd, NULL, NULL, SOCK_NONBLOCK);
            if (c >= 0) {
                if (client_count == client_cap) {
                    client_cap = client_cap ? client_cap * 2 : 8;
                    client_fds = realloc(client_fds, client_cap * sizeof(int));
                }
                client_fds[client_count++] = c;
                fprintf(stderr, "[zaios-input] client connected (total=%d)\n",
                        client_count);
            }
        }

        /* Read input events */
        for (int i = 0; i < dev_count; i++) {
            if (pfds[1 + i].revents & POLLIN) {
                struct input_event ev[16];
                ssize_t r = read(devs[i].fd, ev, sizeof(ev));
                if (r > 0) {
                    int count = r / sizeof(struct input_event);
                    for (int j = 0; j < count; j++) {
                        handle_event(&devs[i], &ev[j]);
                    }
                }
            }
        }
    }

    fprintf(stderr, "[zaios-input] shutting down\n");
    unlink(SOCK_PATH);
    return 0;
}

/* Helper: mkdir -p */
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
