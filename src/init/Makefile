# =============================================================================
# ZAIos init — Makefile
# Builds zaios-init, a minimal PID 1 in C with no external deps (just glibc).
# Cross-compilable via CC=, CXX=, STRIP= on the make command line.
# =============================================================================

CC      ?= gcc
CXX     ?= g++
STRIP   ?= strip
CFLAGS  ?= -O2 -Wall -Wextra -Wno-unused-parameter -std=c11
LDFLAGS ?= -static
OUT     ?= .

INIT_SOURCES = \
    zaios-init.c       \
    zaios-mounts.c     \
    zaios-services.c   \
    zaios-input.c      \
    zaios-cast.c       \
    zaios-spotify.c    \
    zaios-network.c

SERVICES = \
    zaios-input        \
    zaios-cast         \
    zaios-spotify      \
    zaios-network

.PHONY: all clean install

all: $(OUT)/zaios-init $(addprefix $(OUT)/,$(SERVICES))

$(OUT)/zaios-init: $(INIT_SOURCES)
	@mkdir -p $(OUT)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(INIT_SOURCES) -ludev -lrt
	$(STRIP) $@ 2>/dev/null || true

# Service binaries (separate executables launched by zaios-init)
$(OUT)/zaios-input: zaios-input-svc.c
	@mkdir -p $(OUT)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< -ludev -levdev -lrt
	$(STRIP) $@ 2>/dev/null || true

$(OUT)/zaios-cast: zaios-cast-svc.c
	@mkdir -p $(OUT)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< -lrt
	$(STRIP) $@ 2>/dev/null || true

$(OUT)/zaios-spotify: zaios-spotify-svc.c
	@mkdir -p $(OUT)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< -lrt
	$(STRIP) $@ 2>/dev/null || true

$(OUT)/zaios-network: zaios-network-svc.c
	@mkdir -p $(OUT)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< -lrt
	$(STRIP) $@ 2>/dev/null || true

install: all
	install -Dm755 $(OUT)/zaios-init $(DESTDIR)/sbin/zaios-init
	for svc in $(SERVICES); do \
	    install -Dm755 $(OUT)/$$svc $(DESTDIR)/usr/lib/zaios/$$svc; \
	done

clean:
	rm -f $(OUT)/zaios-init $(addprefix $(OUT)/,$(SERVICES))
