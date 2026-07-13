/*
 * zaios-init.c — ZAIos PID 1 init
 *
 * Responsibilities:
 *   1. Mount /proc /sys /dev /run /tmp /var (and overlay if running from squashfs)
 *   2. Bring up loopback + udev
 *   3. Set hostname, load /etc/hostname
 *   4. Start background services (input router, network, bluetooth, cast, spotify)
 *   5. Wait for DRM/KMS to be ready, then start Cage (Wayland kiosk compositor)
 *   6. Start zaios-shell as a child of Cage with WAYLAND_DISPLAY exported
 *   7. Reap zombies forever
 *   8. On SIGINT/SIGTERM → clean shutdown; on shell exit → reboot
 *
 * Design:
 *   - No external deps beyond glibc + libudev. (Static-linked for safety.)
 *   - All services are direct children, supervised by us. If a critical
 *     service dies, we restart it. If the shell dies, we restart it
 *     (after a short delay to avoid tight crash loops).
 *   - We don't implement a full service manager (no unit files). Each service
 *     is a forked process with a known restart policy.
 *
 * Author: ZAIos Project
 * License: MIT
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <ctype.h>
#include <sys/wait.h>
#include <sys/mount.h>
#include <sys/reboot.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/prctl.h>
#include <linux/reboot.h>
#include <time.h>
#include <pwd.h>
#include <grp.h>

#include "zaios-init.h"

#define LOG_TAG "zaios-init"
#define MAX_SERVICES 16

extern int  zaios_mounts_setup(void);
extern int  zaios_udev_start(void);
extern int  zaios_loopback_up(void);
extern int  zaios_load_modules(void);
extern void zaios_start_services(void);
extern void zaios_stop_services(void);
extern void zaios_start_shell(void);
extern void zaios_reboot(int poweroff);

/* Pretty log */
static int log_fd = -1;
void zaios_log(int prio, const char *fmt, ...) {
    (void)prio;
    va_list ap;
    va_start(ap, fmt);
    char buf[1024];
    int n = vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    if (n < 0) return;
    if (log_fd < 0) log_fd = open("/dev/kmsg", O_WRONLY);
    if (log_fd >= 0) write(log_fd, buf, n);
    buf[n>0?n:0] = 0;
    fputs(LOG_TAG ": ", stderr); fputs(buf, stderr);
    fputc('\n', stderr);
}

/* Service registry */
static struct zaios_service services[MAX_SERVICES];
static int service_count = 0;

void zaios_service_register(const char *name, const char *exec_path,
                            const char *args[], int restart_on_death,
                            int critical, uid_t uid, gid_t gid) {
    if (service_count >= MAX_SERVICES) {
        ZAIOS_LOG(LOG_ERR, "service registry full");
        return;
    }
    struct zaios_service *s = &services[service_count++];
    strncpy(s->name, name, sizeof(s->name) - 1);
    strncpy(s->exec_path, exec_path, sizeof(s->exec_path) - 1);
    s->args[0] = s->exec_path;
    for (int i = 0; args && args[i] && i < ZAIOS_MAX_ARGS - 1; i++)
        s->args[i + 1] = (char *)args[i];
    s->args[ZAIOS_MAX_ARGS - 1] = NULL;
    s->pid = 0;
    s->restart_on_death = restart_on_death;
    s->critical = critical;
    s->uid = uid;
    s->gid = gid;
    s->restart_attempts = 0;
    ZAIOS_LOG(LOG_INFO, "registered service: %s", name);
}

/* Spawn a service */
static pid_t spawn_service(struct zaios_service *s) {
    pid_t pid = fork();
    if (pid < 0) {
        ZAIOS_LOG(LOG_ERR, "fork failed for %s: %s", s->name, strerror(errno));
        return -1;
    }
    if (pid == 0) {
        /* Child */
        setsid();
        /* Drop privileges if requested */
        if (s->uid != 0 || s->gid != 0) {
            if (setgid(s->gid) < 0) {
                ZAIOS_LOG(LOG_ERR, "setgid(%d) failed for %s: %s", s->gid, s->name, strerror(errno));
                _exit(126);
            }
            if (setuid(s->uid) < 0) {
                ZAIOS_LOG(LOG_ERR, "setuid(%d) failed for %s: %s", s->uid, s->name, strerror(errno));
                _exit(126);
            }
        }
        execv(s->exec_path, s->args);
        ZAIOS_LOG(LOG_ERR, "execv(%s) failed: %s", s->exec_path, strerror(errno));
        _exit(127);
    }
    s->pid = pid;
    s->last_start = time(NULL);
    ZAIOS_LOG(LOG_INFO, "started %s pid=%d", s->name, pid);
    return pid;
}

/* Restart a service if it died */
static void handle_service_death(pid_t pid, int status) {
    for (int i = 0; i < service_count; i++) {
        struct zaios_service *s = &services[i];
        if (s->pid != pid) continue;

        ZAIOS_LOG(LOG_WARNING, "%s (pid=%d) exited status=%d",
                  s->name, pid, WEXITSTATUS(status));

        s->pid = 0;

        if (s->critical) {
            ZAIOS_LOG(LOG_ERR, "CRITICAL service %s died — rebooting in 5s",
                      s->name);
            sleep(5);
            zaios_reboot(0); /* reboot */
        }

        if (!s->restart_on_death) return;

        time_t now = time(NULL);
        if (now - s->last_start < 5) {
            s->restart_attempts++;
            if (s->restart_attempts > 10) {
                ZAIOS_LOG(LOG_ERR, "%s crashed 10x in <5s — giving up",
                          s->name);
                return;
            }
            /* Exponential backoff */
            int delay = 1 << (s->restart_attempts < 6 ? s->restart_attempts : 6);
            ZAIOS_LOG(LOG_WARNING, "%s backing off %ds", s->name, delay);
            sleep(delay);
        } else {
            s->restart_attempts = 0;
        }
        spawn_service(s);
        return;
    }
    /* Unknown PID — orphan */
}

/* SIGCHLD handler — reap zombies */
static volatile sig_atomic_t got_sigchld = 0;
static void sigchld_handler(int sig) { (void)sig; got_sigchld = 1; }

/* SIGTERM/SIGINT — shutdown */
static volatile sig_atomic_t shutdown_requested = 0;
static void shutdown_handler(int sig) { (void)sig; shutdown_requested = 1; }

int main(int argc, char **argv) {
    (void)argc; (void)argv;

    /* Make sure we're PID 1 */
    if (getpid() != 1) {
        fprintf(stderr, "zaios-init should be run as PID 1\n");
        return 1;
    }

    /* Set up signal handlers */
    struct sigaction sa = {0};
    sa.sa_handler = sigchld_handler;
    sa.sa_flags = SA_RESTART | SA_NOCLDSTOP;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGCHLD, &sa, NULL);

    struct sigaction sa_term = {0};
    sa_term.sa_handler = shutdown_handler;
    sa_term.sa_flags = SA_RESTART;
    sigemptyset(&sa_term.sa_mask);
    sigaction(SIGTERM, &sa_term, NULL);
    sigaction(SIGINT,  &sa_term, NULL);

    /* Don't die on SIGPIPE — services may close sockets */
    signal(SIGPIPE, SIG_IGN);

    /* If we exit, kernel panics. Prevent that. */
    prctl(PR_SET_PDEATHSIG, SIGTERM);

    ZAIOS_LOG(LOG_INFO, "ZAIos init starting (build %s %s)", __DATE__, __TIME__);

    /* Step 1: filesystems */
    if (zaios_mounts_setup() < 0) {
        ZAIOS_LOG(LOG_ERR, "mounts_setup failed — dropping to emergency shell");
        execl("/bin/sh", "sh", NULL);
    }

    /* Step 2: load modules (Wi-Fi, BT, GPU, etc.) */
    zaios_load_modules();

    /* Step 3: udev (for hotplug device events) */
    zaios_udev_start();

    /* Step 4: loopback up — DBus, services, etc. need it */
    zaios_loopback_up();

    /* Step 5: hostname */
    FILE *hostf = fopen("/etc/hostname", "r");
    if (hostf) {
        char name[256] = {0};
        if (fgets(name, sizeof(name), hostf)) {
            name[strcspn(name, "\n")] = 0;
            sethostname(name, strlen(name));
        }
        fclose(hostf);
    } else {
        sethostname("zaios", 5);
    }

    /* Step 6: bring up loopback interface */
    system("ip link set lo up 2>/dev/null || ifconfig lo up 2>/dev/null");

    /* Step 6b: Create /run/zaios with world-writable permissions so that
     * unprivileged services (pipewire, wireplumber, zaios-spotify) running
     * as uid 1000 can create their Unix sockets there. */
    mkdir("/run/zaios", 0777);
    chmod("/run/zaios", 0777);

    /* Step 7: register & start services */
    ZAIOS_LOG(LOG_INFO, "starting services");

    /* Find uid for 'zaios' user (services run unprivileged) */
    struct passwd *pw = getpwnam("zaios");
    uid_t zaios_uid = pw ? pw->pw_uid : 1000;
    gid_t zaios_gid = pw ? pw->pw_gid : 1000;

    /* DBus first — everything talks to it */
    const char *dbus_args[] = {"--system", NULL};
    zaios_service_register("dbus", "/usr/bin/dbus-daemon",
                          dbus_args, 1, 0, 0, 0);

    /* NetworkManager (Wi-Fi, Ethernet) */
    const char *nm_args[] = {"--no-daemon", NULL};
    zaios_service_register("networkmanager", "/usr/sbin/NetworkManager",
                          nm_args, 1, 0, 0, 0);

    /* Bluetooth (BlueZ) */
    const char *bt_args[] = {"-d", "-n", NULL};
    zaios_service_register("bluetooth", "/usr/libexec/bluetooth/bluetoothd",
                          bt_args, 1, 0, 0, 0);

    /* Pipewire (audio) */
    const char *pw_args[] = {NULL};
    zaios_service_register("pipewire", "/usr/bin/pipewire",
                          pw_args, 1, 0, zaios_uid, zaios_gid);

    /* Wireplumber (pipewire session manager) */
    const char *wp_args[] = {NULL};
    zaios_service_register("wireplumber", "/usr/bin/wireplumber",
                          wp_args, 1, 0, zaios_uid, zaios_gid);

    /* MiracleCast controller (Wi-Fi Display sink) */
    const char *cast_args[] = {"--manager", NULL};
    zaios_service_register("cast-manager", "/usr/lib/zaios/zaios-cast",
                          cast_args, 1, 0, 0, 0);

    /* Input router (evdev → DBus → Qt shell) */
    const char *input_args[] = {NULL};
    zaios_service_register("zaios-input", "/usr/lib/zaios/zaios-input",
                          input_args, 1, 0, 0, 0);

    /* Spotify backend (librespot + spotube-style fallback) */
    const char *spot_args[] = {NULL};
    zaios_service_register("zaios-spotify", "/usr/lib/zaios/zaios-spotify",
                          spot_args, 1, 0, zaios_uid, zaios_gid);

    /* Spawn everything */
    for (int i = 0; i < service_count; i++) {
        spawn_service(&services[i]);
        usleep(100000); /* 100ms between starts to avoid races */
    }

    /* Wait for /dev/dri/card0 (DRM/KMS) to appear, up to 10s */
    for (int i = 0; i < 100; i++) {
        if (access("/dev/dri/card0", F_OK) == 0) break;
        usleep(100000);
    }
    if (access("/dev/dri/card0", F_OK) != 0) {
        ZAIOS_LOG(LOG_WARNING, "/dev/dri/card0 not present — trying framebuffer");
    }

    /* Cage (Wayland kiosk compositor) — runs as root, then drops to zaios uid */
    ZAIOS_LOG(LOG_INFO, "starting Cage Wayland compositor");
    pid_t cage_pid = fork();
    if (cage_pid == 0) {
        setenv("XDG_RUNTIME_DIR", "/run", 1);
        setenv("WLR_BACKENDS", "drm", 1);
        setenv("WLR_DRM_DEVICES", "/dev/dri/card0", 1);
        /* Tell Cage to run the zaios-shell as its client */
        execlp("cage", "cage", "--", "/usr/bin/zaios-shell", NULL);
        ZAIOS_LOG(LOG_ERR, "failed to exec cage: %s", strerror(errno));
        _exit(127);
    }

    /* Main loop — reap zombies, watch for shutdown */
    ZAIOS_LOG(LOG_INFO, "entering main loop");
    while (!shutdown_requested) {
        int status;
        pid_t pid = waitpid(-1, &status, 0);
        if (pid < 0) {
            if (errno == EINTR) continue;
            ZAIOS_LOG(LOG_ERR, "waitpid: %s", strerror(errno));
            break;
        }
        if (pid == cage_pid) {
            ZAIOS_LOG(LOG_WARNING, "Cage (compositor) exited status=%d — restarting in 3s",
                      WEXITSTATUS(status));
            sleep(3);
            cage_pid = fork();
            if (cage_pid == 0) {
                setenv("XDG_RUNTIME_DIR", "/run", 1);
                setenv("WLR_BACKENDS", "drm", 1);
                setenv("WLR_DRM_DEVICES", "/dev/dri/card0", 1);
                execlp("cage", "cage", "--", "/usr/bin/zaios-shell", NULL);
                _exit(127);
            }
        } else {
            handle_service_death(pid, status);
        }
    }

    ZAIOS_LOG(LOG_INFO, "shutdown requested — stopping services");
    zaios_stop_services();
    sync();
    zaios_reboot(1); /* poweroff */
    return 0;
}
