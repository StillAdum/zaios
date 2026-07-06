/*
 * zaios-init.h — shared header for ZAIos init system.
 */
#ifndef ZAIOS_INIT_H
#define ZAIOS_INIT_H

#include <stdio.h>
#include <stdarg.h>
#include <unistd.h>
#include <sys/types.h>
#include <time.h>

#define ZAIOS_MAX_ARGS 16
#define MAX_SERVICES   16

/* syslog-like priorities */
enum {
    LOG_EMERG=0, LOG_ALERT, LOG_CRIT, LOG_ERR,
    LOG_WARNING, LOG_NOTICE, LOG_INFO, LOG_DEBUG
};

struct zaios_service {
    char     name[64];
    char     exec_path[256];
    char    *args[ZAIOS_MAX_ARGS];
    pid_t    pid;
    int      restart_on_death;
    int      critical;
    uid_t    uid;
    gid_t    gid;
    int      restart_attempts;
    time_t   last_start;
};

void zaios_log(int prio, const char *fmt, ...);
#define ZAIOS_LOG(prio, ...) zaios_log((prio), __VA_ARGS__)

#endif
