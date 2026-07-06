# ZAIos Makefile — thin wrapper around build.sh for convenience.
# Real work is in build.sh; this is here for `make iso` muscle memory.

ZAIOS_VERSION ?= 1.0
ARCH          ?= x86_64
JOBS          ?= $(shell nproc)

.PHONY: all kernel init shell rootfs initramfs iso calamares download clean help \
        arch-x86_64 arch-arm64 arch-arm

help:
	@echo "ZAIos build targets:"
	@echo "  make all          ARCH=x86_64|arm64|arm  (default: $(ARCH))"
	@echo "  make kernel       Build Linux kernel"
	@echo "  make init         Build zaios-init (PID 1) + services"
	@echo "  make shell        Build Qt6 + ZAIos Shell"
	@echo "  make rootfs       Assemble rootfs squashfs"
	@echo "  make initramfs    Build initramfs"
	@echo "  make calamares    Stage Calamares installer"
	@echo "  make iso          Assemble bootable ISO"
	@echo "  make download     Only download & verify upstream sources"
	@echo "  make clean        Remove build/ directory"
	@echo ""
	@echo "Architecture shortcuts:"
	@echo "  make arch-x86_64  Set ARCH=x86_64 and build all"
	@echo "  make arch-arm64   Set ARCH=arm64 and build all"
	@echo "  make arch-arm     Set ARCH=arm and build all"

all:
	./build.sh --arch=$(ARCH) --target=all --jobs=$(JOBS)

kernel:
	./build.sh --arch=$(ARCH) --target=kernel --jobs=$(JOBS)

init:
	./build.sh --arch=$(ARCH) --target=init --jobs=$(JOBS)

shell:
	./build.sh --arch=$(ARCH) --target=shell --jobs=$(JOBS)

rootfs:
	./build.sh --arch=$(ARCH) --target=rootfs --jobs=$(JOBS)

initramfs:
	./build.sh --arch=$(ARCH) --target=initramfs --jobs=$(JOBS)

calamares:
	./build.sh --arch=$(ARCH) --target=calamares --jobs=$(JOBS)

iso:
	./build.sh --arch=$(ARCH) --target=iso --jobs=$(JOBS)

download:
	./build.sh --target=download

clean:
	./build.sh --clean

arch-x86_64:
	./build.sh --arch=x86_64 --target=all --jobs=$(JOBS)

arch-arm64:
	./build.sh --arch=arm64 --target=all --jobs=$(JOBS)

arch-arm:
	./build.sh --arch=arm --target=all --jobs=$(JOBS)
