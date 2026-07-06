/*
 * zaios-mounts.c — filesystem setup for ZAIos init.
 *
 * Mounts:  /proc /sys /dev (devtmpfs) /run (tmpfs) /tmp (tmpfs)
 *          /dev/pts /dev/shm
 * Also handles overlayfs for / if running from squashfs (live ISO).
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <ctype.h>
#include <dirent.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/reboot.h>
#include <linux/reboot.h>
#include "zaios-init.h"

struct mount_entry {
    const char *source;
    const char *target;
    const char *fstype;
    unsigned long flags;
    const char *opts;
};

static struct mount_entry base_mounts[] = {
    {"proc",     "/proc",     "proc",     0,                       NULL},
    {"sysfs",    "/sys",      "sysfs",    0,                       NULL},
    {"devtmpfs", "/dev",      "devtmpfs", 0,                       "mode=0755,size=4M"},
    {"tmpfs",    "/run",      "tmpfs",    0,                       "mode=0755,size=128M"},
    {"tmpfs",    "/tmp",      "tmpfs",    0,                       "mode=1777,size=256M"},
    {"devpts",   "/dev/pts",  "devpts",   0,                       "mode=0620,gid=5,ptmxmode=0666"},
    {"tmpfs",    "/dev/shm",  "tmpfs",    0,                       "mode=1777,size=64M"},
    {"cgroup2",  "/sys/fs/cgroup", "cgroup2", 0,                   NULL},
    {"configfs", "/sys/kernel/config", "configfs", 0,              NULL},
    {"debugfs",  "/sys/kernel/debug",  "debugfs", 0,               NULL},
    {"tracefs",  "/sys/kernel/tracing","tracefs", 0,               NULL},
    {0}
};

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

int zaios_mounts_setup(void) {
    ZAIOS_LOG(LOG_INFO, "mounting base filesystems");

    for (int i = 0; base_mounts[i].target; i++) {
        struct mount_entry *m = &base_mounts[i];
        mkdir_p(m->target, 0755);
        if (mount(m->source, m->target, m->fstype, m->flags, m->opts) < 0) {
            if (errno != EBUSY) {
                ZAIOS_LOG(LOG_WARNING, "mount %s -> %s: %s",
                          m->source, m->target, strerror(errno));
            }
        } else {
            ZAIOS_LOG(LOG_INFO, "mounted %s on %s", m->fstype, m->target);
        }
    }

    /* Symlink /proc/self/fd → /dev/fd if missing */
    if (access("/dev/fd", F_OK) != 0)
        symlink("/proc/self/fd", "/dev/fd");
    if (access("/dev/stdin", F_OK) != 0) {
        symlink("/proc/self/fd/0", "/dev/stdin");
        symlink("/proc/self/fd/1", "/dev/stdout");
        symlink("/proc/self/fd/2", "/dev/stderr");
    }

    /* If running from squashfs, / is read-only. Set up overlay so writes work. */
    if (access("/etc/zaios/boot-dev", F_OK) == 0) {
        /* We're on the live ISO */
        mkdir_p("/run/overlay", 0755);
        mkdir_p("/run/work",    0755);

        /* Move squashfs to /run/squashfs and overlay on top of / */
        /* For simplicity we use overlayfs over /usr /etc /var */
        const char *overlays[] = {"/etc", "/var", "/home", "/root", NULL};
        for (int i = 0; overlays[i]; i++) {
            char upper[256], work[256];
            snprintf(upper, sizeof(upper), "/run/overlay%s", overlays[i]);
            snprintf(work,  sizeof(work),  "/run/work%s",    overlays[i]);
            mkdir_p(upper, 0755);
            mkdir_p(work,  0755);
            char opts[512];
            snprintf(opts, sizeof(opts),
                     "lowerdir=%s,upperdir=%s,workdir=%s",
                     overlays[i], upper, work);
            /* Remount: bind overlay on top of lower */
            if (mount("overlay", overlays[i], "overlay", 0, opts) < 0) {
                ZAIOS_LOG(LOG_WARNING, "overlay %s: %s",
                          overlays[i], strerror(errno));
            }
        }
        ZAIOS_LOG(LOG_INFO, "live ISO overlay filesystems ready");
    }

    /* /var/log — make sure it exists */
    mkdir_p("/var/log",   0755);
    mkdir_p("/var/run",   0755);
    mkdir_p("/var/lock",  0755);
    mkdir_p("/var/cache", 0755);
    symlink("/run", "/var/run");

    return 0;
}

int zaios_loopback_up(void) {
    /* Bring up lo via netlink-style ioctl; fallback to system() if that fails */
    ZAIOS_LOG(LOG_INFO, "bringing up loopback interface");
    int ret = system("ip link set lo up 2>/dev/null");
    if (ret != 0) {
        ret = system("ifconfig lo 127.0.0.1 up 2>/dev/null");
    }
    return ret;
}

int zaios_load_modules(void) {
    ZAIOS_LOG(LOG_INFO, "loading kernel modules from /etc/modules-load.d");
    DIR *d = opendir("/etc/modules-load.d");
    if (!d) return 0; /* optional */
    struct dirent *de;
    while ((de = readdir(d)) != NULL) {
        if (de->d_name[0] == '.') continue;
        char path[256];
        snprintf(path, sizeof(path), "/etc/modules-load.d/%s", de->d_name);
        FILE *f = fopen(path, "r");
        if (!f) continue;
        char line[256];
        while (fgets(line, sizeof(line), f)) {
            /* strip comments and whitespace */
            char *p = strchr(line, '#'); if (p) *p = 0;
            p = line; while (*p && isspace((unsigned char)*p)) p++;
            char *end = p + strlen(p);
            while (end > p && isspace((unsigned char)end[-1])) *--end = 0;
            if (!*p) continue;
            char cmd[512];
            snprintf(cmd, sizeof(cmd), "modprobe %s 2>/dev/null", p);
            system(cmd);
        }
        fclose(f);
    }
    closedir(d);
    return 0;
}

int zaios_udev_start(void) {
    ZAIOS_LOG(LOG_INFO, "starting udev");
    pid_t pid = fork();
    if (pid < 0) return -1;
    if (pid == 0) {
        /* Trigger coldplug */
        execlp("udevd", "udevd", "--daemon", NULL);
        /* If udevd not present, try systemd-udevd */
        execlp("systemd-udevd", "systemd-udevd", "--daemon", NULL);
        _exit(127);
    }
    /* Wait briefly for udev to start */
    sleep(1);
    /* Trigger coldplug events */
    system("udevadm trigger --action=add 2>/dev/null");
    system("udevadm settle --timeout=10 2>/dev/null");
    return 0;
}

void zaios_stop_services(void) {
    ZAIOS_LOG(LOG_INFO, "stopping services");
    /* Send SIGTERM to all services in reverse order */
    /* Implementation: just kill all our children */
    kill(0, SIGTERM);
    sleep(2);
    kill(0, SIGKILL);
}

void zaios_reboot(int poweroff) {
    ZAIOS_LOG(LOG_INFO, "%s", poweroff ? "powering off" : "rebooting");
    sync();
    if (poweroff) {
        reboot(LINUX_REBOOT_CMD_POWER_OFF);
    } else {
        reboot(LINUX_REBOOT_CMD_RESTART);
    }
    /* Should not return */
    while (1) pause();
}
