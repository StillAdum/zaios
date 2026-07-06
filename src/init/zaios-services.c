/*
 * zaios-services.c — service registration helpers for ZAIos init.
 *
 * This file is intentionally thin: it provides wrappers around the service
 * registry defined in zaios-init.c. It is kept separate so that the main
 * init logic stays small.
 */
#define _GNU_SOURCE
#include <string.h>
#include <unistd.h>
#include "zaios-init.h"

/* All actual service registration happens in zaios-init.c main().
 * This file exists for future expansion: e.g. parsing /etc/zaios/services.d/
 * unit files into the registry at startup. */

/* Parse a simple INI-style unit file and register the service */
int zaios_service_load_from_file(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    char line[512];
    char name[64] = {0};
    char exec[256] = {0};
    char args_str[256] = {0};
    int restart = 1;
    int critical = 0;

    while (fgets(line, sizeof(line), f)) {
        char *p = strchr(line, '#'); if (p) *p = 0;
        p = line; while (*p && (*p==' '||*p=='\t')) p++;
        char *eq = strchr(p, '=');
        if (!eq) continue;
        *eq++ = 0;
        while (*eq && (*eq==' '||*eq=='\t')) eq++;
        char *end = eq + strlen(eq);
        while (end > eq && (end[-1]=='\n' || end[-1]==' ')) *--end = 0;

        if (!strcmp(p, "Name"))        strncpy(name, eq, sizeof(name)-1);
        else if (!strcmp(p, "Exec"))   strncpy(exec, eq, sizeof(exec)-1);
        else if (!strcmp(p, "Args"))   strncpy(args_str, eq, sizeof(args_str)-1);
        else if (!strcmp(p, "Restart"))restart = !strcmp(eq, "yes");
        else if (!strcmp(p, "Critical"))critical = !strcmp(eq, "yes");
    }
    fclose(f);
    if (!name[0] || !exec[0]) return -1;

    /* Simple tokenizer for args */
    char *args[ZAIOS_MAX_ARGS] = {0};
    int n = 0;
    if (args_str[0]) {
        char *save = NULL;
        char *tok = strtok_r(args_str, " \t", &save);
        while (tok && n < ZAIOS_MAX_ARGS - 2) {
            args[n++] = tok;
            tok = strtok_r(NULL, " \t", &save);
        }
    }
    extern void zaios_service_register(const char *, const char *,
                                       const char *[], int, int, uid_t, gid_t);
    zaios_service_register(name, exec, (const char **)args, restart, critical, 0, 0);
    return 0;
}
