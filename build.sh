#!/usr/bin/env bash
###############################################################################
# ZAIos master build script
#
# Usage:
#   ./build.sh --arch=x86_64 --target=all
#   ./build.sh --arch=arm64  --target=kernel
#   ./build.sh --arch=arm    --target=rootfs
#   ./build.sh --arch=x86_64 --target=shell
#   ./build.sh --arch=x86_64 --target=iso
#   ./build.sh --list-targets
#
# This script orchestrates the full ZAIos build pipeline:
#   1. Download & verify upstream source tarballs (Linux, Qt6, etc.)
#   2. Cross-compile (or native-compile) the Linux kernel for the target arch
#   3. Build the custom init (zaios-init) and ZAIos services
#   4. Build the Qt6/QML shell
#   5. Assemble the rootfs (squashfs)
#   6. Build the initramfs
#   7. Assemble the bootable ISO (xorriso + GRUB + ISOLINUX)
#
# Output: build/zaios-<arch>-<version>.iso
###############################################################################
set -Eeuo pipefail

# ─── Globals ────────────────────────────────────────────────────────────────
ZAIOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZAIOS_VERSION="${ZAIOS_VERSION:-1.0}"
ZAIOS_CODENAME="Aurora"

# Source-of-truth versions — pinned for reproducibility
LINUX_VERSION="6.10.5"
QT_VERSION="6.7.2"
GLIBC_VERSION="2.40"
BUSYBOX_VERSION="1.36.1"
LIBRESPOT_VERSION="dev"
MIRACLECAST_VERSION="master"
MPV_VERSION="0.39.0"
YT_DLP_VERSION="2024.08.06"
WPA_SUPPLICANT_VERSION="2.10"
BLUEZ_VERSION="5.79"
PIPEWIRE_VERSION="1.2.5"
CAGE_VERSION="0.2.0"
CALAMARES_VERSION="3.3.13"
CHROMIUM_VERSION="128.0.6613.84"

# Color codes
C_RED='\033[0;31m'; C_GRN='\033[0;32m'; C_YEL='\033[1;33m'
C_BLU='\033[0;34m'; C_MAG='\033[0;35m'; C_CYN='\033[0;36m'
C_WHT='\033[1;37m'; C_RST='\033[0m'

log()  { printf "${C_BLU}[*]${C_RST} %s\n" "$*"; }
ok()   { printf "${C_GRN}[✓]${C_RST} %s\n" "$*"; }
warn() { printf "${C_YEL}[!]${C_RST} %s\n" "$*" >&2; }
err()  { printf "${C_RED}[✗]${C_RST} %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }
section() { printf "\n${C_MAG}════════════════════════════════════════════${C_RST}\n${C_MAG}  %s${C_RST}\n${C_MAG}════════════════════════════════════════════${C_RST}\n" "$*"; }

# ─── Default args ───────────────────────────────────────────────────────────
ARCH=""
TARGET=""
JOBS="$(nproc)"
DOWNLOAD_ONLY=0
CLEAN=0
SKIP_DOWNLOADS=0

# ─── Arg parsing ────────────────────────────────────────────────────────────
list_targets() {
    cat <<EOF
ZAIos build targets:
  kernel       Build Linux kernel (zaios_defconfig) + modules
  init         Build zaios-init (PID 1) and ZAIos services
  shell        Build Qt6 + ZAIos Shell (QML desktop)
  rootfs       Assemble rootfs squashfs (with all binaries)
  initramfs    Build initramfs (xz-compressed cpio)
  iso          Assemble bootable ISO (xorriso + GRUB + ISOLINUX)
  calamares    Build Calamares installer (bundled inside ISO)
  all          Build everything in correct order
  download     Only download & verify upstream source tarballs
  clean        Remove build/ directory
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch=*)       ARCH="${1#*=}"; shift ;;
        --arch)         ARCH="$2"; shift 2 ;;
        --target=*)     TARGET="${1#*=}"; shift ;;
        --target)       TARGET="$2"; shift 2 ;;
        --jobs=*)       JOBS="${1#*=}"; shift ;;
        --jobs|-j)      JOBS="$2"; shift 2 ;;
        --download-only) DOWNLOAD_ONLY=1; shift ;;
        --skip-downloads) SKIP_DOWNLOADS=1; shift ;;
        --clean)        CLEAN=1; shift ;;
        --list-targets) list_targets; exit 0 ;;
        --help|-h)
            cat <<EOF
ZAIos build script
Usage: $0 --arch=<arch> --target=<target> [options]

Architectures:
  x86_64   Intel/AMD mini-PCs, NUCs, generic PCs
  arm64    Raspberry Pi 4/5, Odroid, Snapdragon TV sticks (AArch64)
  arm      Raspberry Pi 2/3 (ARMv7 32-bit)

Targets: see --list-targets

Options:
  -j, --jobs N          Parallel make jobs (default: nproc)
  --download-only       Only fetch & verify upstream sources, then exit
  --skip-downloads      Assume sources already present in cache/
  --clean               Remove build/ directory and exit
  --list-targets        Show all available targets and exit
  -h, --help            Show this help

Environment:
  ZAIOS_VERSION         Override version string (default: 1.0)
EOF
            exit 0 ;;
        *) die "Unknown argument: $1 (try --help)" ;;
    esac
done

[[ -z "$ARCH"   ]] && { ARCH="x86_64"; warn "No --arch given, defaulting to $ARCH"; }
[[ -z "$TARGET" ]] && die "No --target given. Try --list-targets."

case "$ARCH" in
    x86_64|arm64|arm) ;;
    *) die "Invalid arch '$ARCH' (use: x86_64, arm64, arm)" ;;
esac

# ─── Directory layout ───────────────────────────────────────────────────────
BUILD_DIR="$ZAIOS_ROOT/build"
CACHE_DIR="$ZAIOS_ROOT/cache"
DL_DIR="$CACHE_DIR/dl"
SRC_DIR="$CACHE_DIR/src"
ROOTFS_DIR="$BUILD_DIR/rootfs-$ARCH"
ISO_DIR="$BUILD_DIR/iso-$ARCH"
OUT_DIR="$BUILD_DIR/out"

mkdir -p "$DL_DIR" "$SRC_DIR" "$BUILD_DIR" "$OUT_DIR"

# Normalize arch for kernel
kernel_arch() {
    case "$ARCH" in
        x86_64) echo "x86_64" ;;
        arm64)  echo "arm64"  ;;
        arm)    echo "arm"    ;;
    esac
}

# Cross-compile tuple
cross_tuple() {
    case "$ARCH" in
        x86_64) echo ""                   ;; # native
        arm64)  echo "aarch64-linux-gnu-" ;;
        arm)    echo "arm-linux-gnueabihf-" ;;
    esac
}

# ─── Step 0: host deps check ────────────────────────────────────────────────
check_host_deps() {
    section "Checking host dependencies"
    local deps=(
        gcc g++ make cmake ninja bc bison flex
        xorriso grub-mkimage isolinux mtools
        libelf-dev libssl-dev python3
        pkg-config wget curl
    )
    if [[ "$ARCH" != "x86_64" ]]; then
        deps+=("$(cross_tuple)gcc" "$(cross_tuple)g++")
    fi
    local missing=()
    for d in "${deps[@]}"; do
        if ! command -v "$d" >/dev/null 2>&1; then
            # try dpkg-query for things like libelf-dev
            if dpkg -s "$d" >/dev/null 2>&1; then continue; fi
            missing+=("$d")
        fi
    done
    if (( ${#missing[@]} > 0 )); then
        warn "Missing host packages: ${missing[*]}"
        warn "On Debian/Ubuntu: sudo apt install -y ${missing[*]}"
        warn "On Arch: sudo pacman -S --needed ${missing[*]/libelf-dev/libelf} ${missing[*]/libssl-dev/openssl}"
        die "Install missing host deps first."
    fi
    ok "Host deps OK ($(nproc) cores, $(free -h | awk '/^Mem:/{print $2}') RAM)"
}

# ─── Step 1: download sources ──────────────────────────────────────────────
download_sources() {
    section "Downloading upstream sources"

    # All URLs verified 2026-07-05. Note: mpv uses .tar.xz, Chromium uses
    # GitHub tag tarball (Google's CDN often rate-limits).
    declare -A SRC_URLS=(
        ["linux-$LINUX_VERSION.tar.xz"]="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$LINUX_VERSION.tar.xz"
        ["qt-everywhere-src-$QT_VERSION.tar.xz"]="https://download.qt.io/archive/qt/$(echo $QT_VERSION | cut -d. -f1-2)/$QT_VERSION/single/qt-everywhere-src-$QT_VERSION.tar.xz"
        ["glibc-$GLIBC_VERSION.tar.xz"]="https://ftp.gnu.org/gnu/glibc/glibc-$GLIBC_VERSION.tar.xz"
        ["busybox-$BUSYBOX_VERSION.tar.bz2"]="https://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2"
        ["mpv-$MPV_VERSION.tar.gz"]="https://github.com/mpv-player/mpv/archive/refs/tags/v$MPV_VERSION.tar.gz"
        ["yt-dlp-$YT_DLP_VERSION.tar.gz"]="https://github.com/yt-dlp/yt-dlp/archive/refs/tags/$YT_DLP_VERSION.tar.gz"
        ["wpa_supplicant-$WPA_SUPPLICANT_VERSION.tar.gz"]="https://w1.fi/releases/wpa_supplicant-$WPA_SUPPLICANT_VERSION.tar.gz"
        ["bluez-$BLUEZ_VERSION.tar.xz"]="https://www.kernel.org/pub/linux/bluetooth/bluez-$BLUEZ_VERSION.tar.xz"
        ["pipewire-$PIPEWIRE_VERSION.tar.gz"]="https://gitlab.freedesktop.org/pipewire/pipewire/-/archive/$PIPEWIRE_VERSION/pipewire-$PIPEWIRE_VERSION.tar.gz"
        ["cage-v$CAGE_VERSION.tar.gz"]="https://github.com/cage-kiosk/cage/archive/refs/tags/v$CAGE_VERSION.tar.gz"
        ["calamares-$CALAMARES_VERSION.tar.gz"]="https://github.com/calamares/calamares/releases/download/v$CALAMARES_VERSION/calamares-$CALAMARES_VERSION.tar.gz"
        ["miraclecast.tar.gz"]="https://github.com/albfan/miraclecast/archive/refs/heads/master.tar.gz"
        ["librespot.tar.gz"]="https://github.com/librespot-org/librespot/archive/refs/heads/dev.tar.gz"
        ["chromium-$CHROMIUM_VERSION.tar.gz"]="https://github.com/chromium/chromium/archive/refs/tags/$CHROMIUM_VERSION.tar.gz"
    )

    local failed=()
    for name in "${!SRC_URLS[@]}"; do
        local url="${SRC_URLS[$name]}"
        local dest="$DL_DIR/$name"
        if [[ -f "$dest" ]] && (( SKIP_DOWNLOADS )); then
            continue
        fi
        if [[ -f "$dest" ]]; then
            ok "Cached: $name"
            continue
        fi
        log "Downloading $name"
        # Retry up to 3 times for flaky networks
        local tries=0
        while (( tries < 3 )); do
            if wget -q --show-progress --tries=2 --timeout=60 -O "$dest" "$url"; then
                break
            fi
            tries=$((tries + 1))
            warn "Download attempt $tries failed for $name — retrying..."
            rm -f "$dest"
            sleep 3
        done
        if [[ ! -f "$dest" ]] || [[ ! -s "$dest" ]]; then
            err "Failed to download $url"
            err "Try manually: wget -O cache/dl/$name '$url'"
            failed+=("$name")
        fi
    done

    if (( ${#failed[@]} > 0 )); then
        err "These downloads failed: ${failed[*]}"
        err "Manual fix: see the 'SRC_URLS' array in build.sh and download each manually to cache/dl/"
        die "Cannot proceed without all sources."
    fi

    ok "All sources downloaded to $DL_DIR"
}

# ─── Step 2: extract sources ───────────────────────────────────────────────
extract_sources() {
    section "Extracting sources"
    for f in "$DL_DIR"/*; do
        local name="$(basename "$f")"
        local dest
        case "$name" in
            *.tar.xz)  dest="$SRC_DIR/$(basename "$name" .tar.xz)" ;;
            *.tar.bz2) dest="$SRC_DIR/$(basename "$name" .tar.bz2)" ;;
            *.tar.gz)  dest="$SRC_DIR/$(basename "$name" .tar.gz)" ;;
            *.tgz)     dest="$SRC_DIR/$(basename "$name" .tgz)" ;;
            *) continue ;;
        esac
        if [[ -d "$dest" ]]; then
            continue
        fi
        log "Extracting $name"
        case "$name" in
            *.tar.xz)  tar -xf "$f" -C "$SRC_DIR" ;;
            *.tar.bz2) tar -xjf "$f" -C "$SRC_DIR" ;;
            *.tar.gz|*.tgz) tar -xzf "$f" -C "$SRC_DIR" ;;
        esac
    done
    ok "Sources extracted to $SRC_DIR"
}

# ─── Step 3: build kernel ──────────────────────────────────────────────────
build_kernel() {
    section "Building Linux kernel $LINUX_VERSION for $ARCH"

    local ksrc="$SRC_DIR/linux-$LINUX_VERSION"
    local kbuild="$BUILD_DIR/linux-build-$ARCH"
    local kcfg="$ZAIOS_ROOT/src/kernel/configs/zaios_$ARCH.config"

    [[ ! -d "$ksrc" ]] && die "Kernel source missing at $ksrc"
    [[ ! -f "$kcfg" ]] && die "Kernel config missing at $kcfg"

    mkdir -p "$kbuild"

    # Concatenate common + arch-specific config
    local common_cfg="$ZAIOS_ROOT/src/kernel/configs/zaios_common.config"
    cat "$common_cfg" "$kcfg" > "$kbuild/.config"

    local cross="$(cross_tuple)"
    local arch="$(kernel_arch)"

    # Configure
    log "Configuring kernel (arch=$arch, cross=$cross)"
    ( cd "$ksrc" && \
        make O="$kbuild" ARCH="$arch" \
        ${cross:+CROSS_COMPILE=$cross} \
        olddefconfig )

    # Build
    log "Building kernel + modules (${JOBS} jobs)"
    ( cd "$ksrc" && \
        make O="$kbuild" ARCH="$arch" \
        ${cross:+CROSS_COMPILE=$cross} \
        -j"$JOBS" bzImage modules ) || die "Kernel build failed"

    # Install modules into a temp staging dir
    local moddir="$BUILD_DIR/modules-$ARCH"
    rm -rf "$moddir"; mkdir -p "$moddir"
    ( cd "$ksrc" && \
        make O="$kbuild" ARCH="$arch" \
        ${cross:+CROSS_COMPILE=$cross} \
        INSTALL_MOD_PATH="$moddir" modules_install )

    ok "Kernel built:"
    ok "  Image:   $kbuild/arch/$arch/boot/bzImage"
    ok "  Modules: $moddir/lib/modules/"

    # Stage into rootfs
    if [[ -d "$ROOTFS_DIR" ]]; then
        log "Staging kernel + modules into rootfs"
        local kimg_dest="$ROOTFS_DIR/boot/vmlinuz-$ZAIOS_VERSION-$ARCH"
        local kdtb_dest="$ROOTFS_DIR/boot/dtb-$ARCH"
        mkdir -p "$ROOTFS_DIR/boot" "$ROOTFS_DIR/lib/modules"
        cp "$kbuild/arch/$arch/boot/bzImage" "$kimg_dest"
        # ARM: copy device-tree blobs
        if [[ "$ARCH" != "x86_64" && -d "$kbuild/arch/$arch/boot/dts" ]]; then
            mkdir -p "$kdtb_dest"
            cp -r "$kbuild/arch/$arch/boot/dts/"*.dtb "$kdtb_dest/" 2>/dev/null || true
        fi
        cp -a "$moddir/lib/modules/"* "$ROOTFS_DIR/lib/modules/"
        # Symlink stable
        ln -sf "vmlinuz-$ZAIOS_VERSION-$ARCH" "$ROOTFS_DIR/boot/vmlinuz"
        ok "Kernel staged to rootfs/boot/"
    fi
}

# ─── Step 4: build init + services ─────────────────────────────────────────
build_init() {
    section "Building zaios-init (PID 1) + services"

    local cross="$(cross_tuple)"
    local init_src="$ZAIOS_ROOT/src/init"
    local out="$BUILD_DIR/init-$ARCH"
    mkdir -p "$out"

        # Compile directly with gcc — bypasses the Makefile (avoids tab/space issues in web editor)
    local cc="${cross:-gcc}gcc"
    local strip_bin="${cross:-strip}strip"
    log "Compiling zaios-init"
    $cc -O2 -Wall -Wextra -Wno-unused-parameter -std=c11 -static \
        -o "$out/zaios-init" \
        "$init_src/zaios-init.c" "$init_src/zaios-mounts.c" "$init_src/zaios-services.c" \
        -ludev -lrt || die "zaios-init compile failed"
    $strip_bin "$out/zaios-init" 2>/dev/null || true

    log "Compiling zaios-input"
    $cc -O2 -Wall -Wextra -Wno-unused-parameter -std=c11 -static \
        -o "$out/zaios-input" "$init_src/zaios-input-svc.c" -ludev -lrt || die "zaios-input compile failed"
    $strip_bin "$out/zaios-input" 2>/dev/null || true

    log "Compiling zaios-cast"
    $cc -O2 -Wall -Wextra -Wno-unused-parameter -std=c11 -static \
        -o "$out/zaios-cast" "$init_src/zaios-cast-svc.c" -lrt || die "zaios-cast compile failed"
    $strip_bin "$out/zaios-cast" 2>/dev/null || true

    log "Compiling zaios-spotify"
    $cc -O2 -Wall -Wextra -Wno-unused-parameter -std=c11 -static \
        -o "$out/zaios-spotify" "$init_src/zaios-spotify-svc.c" -lrt || die "zaios-spotify compile failed"
    $strip_bin "$out/zaios-spotify" 2>/dev/null || true

    log "Compiling zaios-network"
    $cc -O2 -Wall -Wextra -Wno-unused-parameter -std=c11 -static \
        -o "$out/zaios-network" "$init_src/zaios-network-svc.c" -lrt || die "zaios-network compile failed"
    $strip_bin "$out/zaios-network" 2>/dev/null || true

    ok "init + services built to $out"

    # Stage into rootfs
    if [[ -d "$ROOTFS_DIR" ]]; then
        log "Staging init + services into rootfs"
        mkdir -p "$ROOTFS_DIR/sbin" "$ROOTFS_DIR/usr/lib/zaios"
        cp "$out/zaios-init" "$ROOTFS_DIR/sbin/zaios-init"
        ln -sf /sbin/zaios-init "$ROOTFS_DIR/init"
        for bin in zaios-input zaios-cast zaios-spotify zaios-network; do
            [[ -f "$out/$bin" ]] && cp "$out/$bin" "$ROOTFS_DIR/usr/lib/zaios/$bin"
        done
        ok "init + services staged"
    fi
}

# ─── Step 5: build Qt6 + ZAIos Shell ───────────────────────────────────────
build_shell() {
    section "Building ZAIos Shell (Qt6/QML)"

    local cross="$(cross_tuple)"
    local qt_prefix="$BUILD_DIR/qt-$ARCH"
    local shell_src="$ZAIOS_ROOT/src/shell"
    local shell_build="$BUILD_DIR/shell-$ARCH"

    # If Qt6 not yet built for this arch, build it
    if [[ ! -f "$qt_prefix/lib/libQt6Core.so" ]] && [[ ! -f "$qt_prefix/lib/libQt6Core.a" ]]; then
        log "Building Qt6 base (this takes ~2 hours on 4 cores)"
        local qtsrc="$SRC_DIR/qt-everywhere-src-$QT_VERSION"
        local qtbuild="$BUILD_DIR/qt-build-$ARCH"
        mkdir -p "$qtbuild"
        ( cd "$qtsrc" && ./configure \
            -prefix "$qt_prefix" \
            -release \
            -opensource -confirm-license \
            ${cross:+-device-option CROSS_COMPILE=$cross} \
            -nomake examples -nomake tests \
            -skip qtwebengine -skip qtactiveqt \
            -system-zlib -system-libjpeg -system-libpng \
            -dbus -gui -widgets \
            -no-feature-sqlmodel \
            -optimized-qmake \
            -no-warnings-are-errors \
            2>&1 | tail -50 ) || die "Qt6 configure failed"
        ( cd "$qtsrc" && cmake --build . -j"$JOBS" 2>&1 | tail -50 ) || die "Qt6 build failed"
        ( cd "$qtsrc" && cmake --install . 2>&1 | tail -20 ) || die "Qt6 install failed"
        ok "Qt6 installed to $qt_prefix"
    else
        ok "Qt6 already built at $qt_prefix"
    fi

    # Build QtWebEngine (Chromium) — separate step because it's huge
    if [[ ! -d "$qt_prefix/lib/QtWebEngineCore.framework" ]] && \
       [[ ! -f "$qt_prefix/lib/libQt6WebEngineCore.so" ]]; then
        warn "QtWebEngine not built — building it now (this takes 4+ hours)"
        local qtsrc="$SRC_DIR/qt-everywhere-src-$QT_VERSION"
        ( cd "$qtsrc" && \
            ./configure -prefix "$qt_prefix" \
            -release -opensource -confirm-license \
            -skip qtactiveqt \
            -nomake examples -nomake tests \
            ${cross:+-device-option CROSS_COMPILE=$cross} \
            -no-warnings-are-errors \
            -module qtwebengine \
            2>&1 | tail -20 ) || die "QtWebEngine configure failed"
        ( cd "$qtsrc" && cmake --build . --target qtwebengine -j"$JOBS" 2>&1 | tail -30 ) \
            || die "QtWebEngine build failed"
        ( cd "$qtsrc" && cmake --install . 2>&1 | tail -10 ) || die "QtWebEngine install failed"
        ok "QtWebEngine installed"
    fi

    # Build ZAIos Shell itself
    log "Configuring ZAIos Shell"
    mkdir -p "$shell_build"
    ( cd "$shell_build" && cmake "$shell_src" \
        -DCMAKE_PREFIX_PATH="$qt_prefix" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        ${cross:+-DCMAKE_CXX_COMPILER=${cross}g++} \
        ${cross:+-DCMAKE_C_COMPILER=${cross}gcc} \
        -G Ninja ) || die "Shell configure failed"

    log "Compiling ZAIos Shell"
    ( cd "$shell_build" && ninja -j"$JOBS" ) || die "Shell build failed"

    ok "ZAIos Shell built: $shell_build/zaios-shell"

    # Stage into rootfs
    if [[ -d "$ROOTFS_DIR" ]]; then
        log "Staging ZAIos Shell into rootfs"
        mkdir -p "$ROOTFS_DIR/usr/bin" "$ROOTFS_DIR/usr/lib/zaios"
        cp "$shell_build/zaios-shell" "$ROOTFS_DIR/usr/bin/zaios-shell"
        # Qt plugins + QML — copy runtime deps
        mkdir -p "$ROOTFS_DIR/usr/lib/qt6" "$ROOTFS_DIR/usr/share/zaios/qml"
        cp -a "$qt_prefix/qml"/* "$ROOTFS_DIR/usr/share/zaios/qml/" 2>/dev/null || true
        cp -a "$qt_prefix/plugins"/* "$ROOTFS_DIR/usr/lib/qt6/" 2>/dev/null || true
        cp -a "$shell_src/qml"/* "$ROOTFS_DIR/usr/share/zaios/qml/" 2>/dev/null || true
        # Qt libs (shared)
        for lib in libQt6Core libQt6Gui libQt6Quick libQt6Qml libQt6Network libQt6DBus \
                   libQt6Multimedia libQt6WebEngineCore libQt6WebEngineQuick \
                   libQt6Bluetooth libQt6WaylandClient; do
            for f in "$qt_prefix/lib/$lib".so*; do
                [[ -f "$f" ]] && cp -a "$f" "$ROOTFS_DIR/usr/lib/" 2>/dev/null || true
            done
        done
        ok "Shell + Qt runtime staged"
    fi
}

# ─── Step 6: assemble rootfs ───────────────────────────────────────────────
build_rootfs() {
    section "Assembling rootfs for $ARCH"

    # Start from a fresh rootfs skeleton ( BusyBox + glibc )
    rm -rf "$ROOTFS_DIR"
    mkdir -p "$ROOTFS_DIR"/{boot,bin,sbin,etc,proc,sys,dev,run,tmp,var,usr/{bin,sbin,lib,share},lib,root,home,opt,mnt}

    # Copy skeleton from repo
    cp -a "$ZAIOS_ROOT/rootfs/." "$ROOTFS_DIR/"

    # Install BusyBox (provides coreutils, util-linux, etc.)
    local bb_src="$SRC_DIR/busybox-$BUSYBOX_VERSION"
    if [[ ! -f "$bb_src/busybox" ]]; then
        log "Building BusyBox"
        ( cd "$bb_src" && make defconfig && make -j"$JOBS" )
    fi
    cp "$bb_src/busybox" "$ROOTFS_DIR/bin/busybox"
    chmod +x "$ROOTFS_DIR/bin/busybox"
    # Symlink all applets
    for applet in $("$bb_src/busybox" --list); do
        ln -sf /bin/busybox "$ROOTFS_DIR/bin/$applet" 2>/dev/null || true
    done

    # glibc
    local glibc_src="$SRC_DIR/glibc-$GLIBC_VERSION"
    if [[ ! -f "$BUILD_DIR/glibc-$ARCH/usr/lib/libc.so.6" ]]; then
        log "Building glibc $GLIBC_VERSION"
        local gbuild="$BUILD_DIR/glibc-build-$ARCH"
        mkdir -p "$gbuild"
        local cross="$(cross_tuple)"
        # For native builds (cross is empty), omit --host entirely.
        # For cross builds, use the proper triplet (e.g. aarch64-linux-gnu).
        local host_flag=""
        local cc_flag=""
        if [[ -n "$cross" ]]; then
            host_flag="--host=${cross%-linux-gnu-}linux-gnu"
            cc_flag="CC=${cross}gcc"
        fi
        ( cd "$gbuild" && "$glibc_src/configure" \
            --prefix=/usr \
            $host_flag \
            $cc_flag \
            --enable-kernel=5.15 \
            --disable-werror && \
            make -j"$JOBS" && \
            make DESTDIR="$BUILD_DIR/glibc-$ARCH" install ) || die "glibc build failed"
    fi
    cp -a "$BUILD_DIR/glibc-$ARCH/usr/lib/"*so* "$ROOTFS_DIR/usr/lib/" 2>/dev/null || true
    cp -a "$BUILD_DIR/glibc-$ARCH/usr/lib/ld-linux"* "$ROOTFS_DIR/lib/" 2>/dev/null || true

    # Now run other build steps that stage into rootfs
    build_init
    build_shell

    # Stage yt-dlp (Python script)
    local ytdlp_src="$SRC_DIR/yt-dlp-$YT_DLP_VERSION"
    if [[ -d "$ytdlp_src" ]]; then
        mkdir -p "$ROOTFS_DIR/usr/bin"
        cp "$ytdlp_src/yt-dlp" "$ROOTFS_DIR/usr/bin/yt-dlp" 2>/dev/null || \
        cp "$ytdlp_src/yt-dlp/yt-dlp" "$ROOTFS_DIR/usr/bin/yt-dlp" 2>/dev/null || true
        chmod +x "$ROOTFS_DIR/usr/bin/yt-dlp"
    fi

    # Stage Calamares config (the binary itself must be built separately)
    if [[ -d "$ZAIOS_ROOT/calamares" ]]; then
        mkdir -p "$ROOTFS_DIR/etc/calamares"
        cp -a "$ZAIOS_ROOT/calamares/." "$ROOTFS_DIR/etc/calamares/"
    fi

    # Stage firmware blobs (linux-firmware)
    if [[ -d "$CACHE_DIR/firmware" ]]; then
        mkdir -p "$ROOTFS_DIR/lib/firmware"
        cp -a "$CACHE_DIR/firmware/." "$ROOTFS_DIR/lib/firmware/"
        ok "Firmware blobs staged"
    else
        warn "No firmware blobs at $CACHE_DIR/firmware — some Wi-Fi/GPU may not work"
        warn "Clone https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git there"
    fi

    # Write /etc/os-release
    cat > "$ROOTFS_DIR/etc/os-release" <<EOF
NAME="ZAIos"
VERSION="$ZAIOS_VERSION ($ZAIOS_CODENAME)"
ID=zaios
ID_LIKE=zaios
VERSION_ID="$ZAIOS_VERSION"
PRETTY_NAME="ZAIos $ZAIOS_VERSION ($ZAIOS_CODENAME)"
ANSI_COLOR="0;36"
HOME_URL="https://github.com/zaios/zaios"
SUPPORT_URL="https://github.com/zaios/zaios/issues"
BUG_REPORT_URL="https://github.com/zaios/zaios/issues"
EOF

    # /etc/hostname
    echo "zaios" > "$ROOTFS_DIR/etc/hostname"

    # /etc/fstab (filled by Calamares at install time)
    cat > "$ROOTFS_DIR/etc/fstab" <<'EOF'
# Generated by ZAIos — filled by Calamares at install time
# <device>  <mount>  <type>  <options>  <dump>  <pass>
EOF

    # Permissions
    chmod 4755 "$ROOTFS_DIR/bin/busybox" 2>/dev/null || true
    mkdir -p "$ROOTFS_DIR/var/tmp" && chmod 1777 "$ROOTFS_DIR/tmp" "$ROOTFS_DIR/var/tmp"

    # Pack squashfs
    local sqfs="$BUILD_DIR/rootfs-$ARCH.squashfs"
    log "Packing squashfs: $sqfs"
    rm -f "$sqfs"
    mksquashfs "$ROOTFS_DIR" "$sqfs" -comp zstd -Xcompression-level 19 -noappend \
        -progress || die "mksquashfs failed"

    ok "Rootfs squashfs: $sqfs ($(du -h "$sqfs" | cut -f1))"
}

# ─── Step 7: build initramfs ───────────────────────────────────────────────
build_initramfs() {
    section "Building initramfs for $ARCH"

    local irfs="$BUILD_DIR/initramfs-$ARCH"
    rm -rf "$irfs"; mkdir -p "$irfs"/{bin,sbin,proc,sys,dev,run,newroot,usr/{bin,sbin}}

    # BusyBox (static)
    local bb_src="$SRC_DIR/busybox-$BUSYBOX_VERSION"
    if [[ ! -f "$bb_src/busybox" ]]; then
        log "Building static BusyBox for initramfs"
        ( cd "$bb_src" && make defconfig && \
          sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config && \
          make -j"$JOBS" )
    fi
    cp "$bb_src/busybox" "$irfs/bin/busybox"
    chmod +x "$irfs/bin/busybox"
    for applet in $("$bb_src/busybox" --list); do
        ln -sf /bin/busybox "$irfs/bin/$applet" 2>/dev/null || true
    done

    # Init script (finds squashfs on the boot media, mounts, switch_root)
    cat > "$irfs/init" <<'INITSCRIPT'
#!/bin/sh
# ZAIos initramfs init — finds the squashfs on boot media and switch_roots.
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

mount -t proc     none /proc
mount -t sysfs    none /sys
mount -t devtmpfs none /dev  2>/dev/null || mdev -s

echo "[zaios-initramfs] Searching for ZAIos boot media..."

# We look for a partition with a /zaios/ marker file, or a CD-ROM with
# /zaios/rootfs.squashfs.
BOOT_DEV=""
for dev in /dev/disk/by-uuid/* /dev/sr* /dev/sd* /dev/mmcblk*p* /dev/nvme*p*; do
    [ -b "$dev" ] || continue
    mkdir -p /mnt/probe
    if mount -o ro "$dev" /mnt/probe 2>/dev/null; then
        if [ -f /mnt/probe/zaios/rootfs.squashfs ] || \
           [ -f /mnt/probe/boot/vmlinuz ]; then
            BOOT_DEV="$dev"
            echo "[zaios-initramfs] Found ZAIos media at $dev"
            break
        fi
        umount /mnt/probe 2>/dev/null
    fi
done

if [ -z "$BOOT_DEV" ]; then
    echo "[zaios-initramfs] FATAL: No ZAIos boot media found. Dropping to shell."
    exec /bin/sh
fi

# Mount the squashfs
mount -t squashfs -o ro /mnt/probe/zaios/rootfs.squashfs /newroot

# Move /dev /proc /sys into newroot
mount --move /dev  /newroot/dev  2>/dev/null
mount --move /proc /newroot/proc 2>/dev/null
mount --move /sys  /newroot/sys  2>/dev/null

# Pass boot device to real init
echo "BOOT_DEV=$BOOT_DEV" > /newroot/etc/zaios/boot-dev

# Cleanup probe (it's now under /newroot/mnt/probe; will be unmounted by init)
exec switch_root /newroot /sbin/zaios-init
INITSCRIPT
    chmod +x "$irfs/init"

    # Pack as xz-compressed cpio
    local out="$BUILD_DIR/initramfs-$ARCH.img"
    log "Packing initramfs: $out"
    ( cd "$irfs" && find . | cpio -H newc -o | xz -9 --check=crc32 ) > "$out" \
        || die "initramfs pack failed"
    ok "Initramfs: $out ($(du -h "$out" | cut -f1))"
}

# ─── Step 8: build Calamares ───────────────────────────────────────────────
build_calamares() {
    section "Building Calamares installer"
    warn "Calamares build is delegated to the host's package manager for brevity."
    warn "On Debian/Ubuntu: sudo apt install calamares"
    warn "On Arch: sudo pacman -S calamares"
    warn "The ZAIos Calamares config is in /etc/calamares/ and is shipped in the ISO rootfs."
    # Stage the binary if installed on host
    if command -v calamares >/dev/null 2>&1 && [[ "$ARCH" == "x86_64" ]]; then
        mkdir -p "$ROOTFS_DIR/usr/bin"
        cp "$(command -v calamares)" "$ROOTFS_DIR/usr/bin/calamares"
        ok "Staged host Calamares binary into rootfs"
    fi
}

# ─── Step 9: assemble ISO ──────────────────────────────────────────────────
build_iso() {
    section "Assembling bootable ISO for $ARCH"

    local sqfs="$BUILD_DIR/rootfs-$ARCH.squashfs"
    local kimg="$ROOTFS_DIR/boot/vmlinuz-$ZAIOS_VERSION-$ARCH"
    local irfs="$BUILD_DIR/initramfs-$ARCH.img"
    local iso_out="$OUT_DIR/zaios-$ARCH-$ZAIOS_VERSION.iso"

    [[ ! -f "$sqfs" ]] && die "rootfs squashfs missing: $sqfs"
    [[ ! -f "$kimg" ]] && die "kernel image missing: $kimg"
    [[ ! -f "$irfs" ]] && die "initramfs missing: $irfs"

    rm -rf "$ISO_DIR"; mkdir -p "$ISO_DIR"/{zaios,boot/{grub,isolinux,efi/boot},live}

    # Stage payloads
    cp "$kimg" "$ISO_DIR/live/vmlinuz"
    cp "$irfs" "$ISO_DIR/live/initramfs.img"
    cp "$sqfs" "$ISO_DIR/zaios/rootfs.squashfs"

    # ARM: copy device-tree blobs alongside
    if [[ "$ARCH" != "x86_64" ]]; then
        local dtb_dir="$ROOTFS_DIR/boot/dtb-$ARCH"
        [[ -d "$dtb_dir" ]] && cp -r "$dtb_dir" "$ISO_DIR/live/dtb"
    fi

    # Marker file for initramfs probe
    touch "$ISO_DIR/zaios/.boot-marker"

    # ISOLINUX config (BIOS boot)
    cat > "$ISO_DIR/boot/isolinux/isolinux.cfg" <<EOF
SERIAL 0 115200
UI vesamenu.c32
PROMPT 0
TIMEOUT 30
DEFAULT zaios

MENU TITLE ZAIos $ZAIOS_VERSION ($ZAIOS_CODENAME) — $ARCH

LABEL zaios
    MENU LABEL ^ZAIos Live (default)
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initramfs.img boot=live zaios.media=cdrom zaios.arch=$ARCH quiet loglevel=3

LABEL zaios-verbose
    MENU LABEL ZAIos Live (verbose boot)
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initramfs.img boot=live zaios.media=cdrom zaios.arch=$ARCH loglevel=7

LABEL zaios-install
    MENU LABEL ^Install ZAIos to disk (Calamares)
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initramfs.img boot=live zaios.media=cdrom zaios.arch=$ARCH zaios.installer=1 quiet
EOF

    # ISOLINUX binaries (from host's isolinux package)
    for f in isolinux.bin ldlinux.c32 libcom32.c32 libutil.c32 vesamenu.c32 menu.c32; do
        local src="/usr/lib/ISOLINUX/$f"
        [[ -f "/usr/lib/syslinux/modules/bios/$f" ]] && src="/usr/lib/syslinux/modules/bios/$f"
        [[ -f "$src" ]] && cp "$src" "$ISO_DIR/boot/isolinux/$f"
    done

    # GRUB config (EFI boot, both x86_64-efi and arm64-efi)
    cat > "$ISO_DIR/boot/grub/grub.cfg" <<'GRUBCFG'
set default=0
set timeout=10
set gfxmode=auto
set gfxpayload=keep
insmod all_video
insmod gfxterm
insmod png
insmod progress
insmod gzio

loadfont /boot/grub/fonts/unicode.pf2
terminal_output gfxterm

menu_color_normal=white/black
menu_color_highlight=cyan/black

menuentry "ZAIos Live (default)" {
    linux  /live/vmlinuz boot=live zaios.media=cdrom quiet loglevel=3
    initrd /live/initramfs.img
}

menuentry "ZAIos Live (verbose)" {
    linux  /live/vmlinuz boot=live zaios.media=cdrom loglevel=7
    initrd /live/initramfs.img
}

menuentry "Install ZAIos to disk (Calamares)" {
    linux  /live/vmlinuz boot=live zaios.media=cdrom zaios.installer=1 quiet
    initrd /live/initramfs.img
}
GRUBCFG

    # Build EFI boot images (GRUB)
    case "$ARCH" in
        x86_64)
            # Build bootx64.efi
            log "Building GRUB EFI image for x86_64"
            grub-mkimage -O x86_64-efi \
                -p /boot/grub \
                -o "$ISO_DIR/boot/efi/boot/bootx64.efi" \
                ext2 fat iso9660 part_gpt part_msdos \
                normal boot linux configfile loopback chain \
                efifwsetup efi_gop efi_uga ls search search_label \
                search_fs_uuid search_fs_file gfxterm gfxterm_background \
                gfxterm_menu test all_video loadenv exfat ntfs udf \
                font echo cat help part_apple hfsplus \
                || die "grub-mkimage x86_64-efi failed"

            # Also build a BIOS boot image
            log "Building GRUB BIOS image"
            grub-mkimage -O i386-pc-eltorito \
                -p /boot/grub \
                -o "$ISO_DIR/boot/grub/core.img" \
                biosdisk iso9660 ext2 fat ls search \
                normal configfile part_msdos part_gpt \
                boot linux chain echo cat help \
                || die "grub-mkimage i386-pc failed"

            # Stage BIOS modules
            mkdir -p "$ISO_DIR/boot/grub/i386-pc"
            cp /usr/lib/grub/i386-pc/*.mod "$ISO_DIR/boot/grub/i386-pc/" 2>/dev/null || true
            cp /usr/lib/grub/i386-pc/eltorito.img "$ISO_DIR/boot/isolinux/" 2>/dev/null || true
            ;;
        arm64)
            log "Building GRUB EFI image for ARM64"
            grub-mkimage -O arm64-efi \
                -p /boot/grub \
                -o "$ISO_DIR/boot/efi/boot/bootaa64.efi" \
                ext2 fat iso9660 part_gpt part_msdos \
                normal boot linux configfile loopback chain \
                efifwsetup efi_gop ls search search_label \
                search_fs_uuid search_fs_file gfxterm gfxterm_background \
                gfxterm_menu test all_video loadenv exfat ntfs udf \
                font echo cat help \
                || die "grub-mkimage arm64-efi failed"
            ;;
    esac

    # Stage GRUB modules + fonts for runtime
    local grubdir="/usr/lib/grub"
    case "$ARCH" in
        x86_64) mkdir -p "$ISO_DIR/boot/grub/x86_64-efi"
                cp -a "$grubdir/x86_64-efi/"*.mod "$ISO_DIR/boot/grub/x86_64-efi/" 2>/dev/null || true ;;
        arm64)  mkdir -p "$ISO_DIR/boot/grub/arm64-efi"
                cp -a "$grubdir/arm64-efi/"*.mod "$ISO_DIR/boot/grub/arm64-efi/" 2>/dev/null || true ;;
    esac
    mkdir -p "$ISO_DIR/boot/grub/fonts"
    cp "$grubdir/unicode.pf2" "$ISO_DIR/boot/grub/fonts/unicode.pf2" 2>/dev/null || true

    # Splash background (placeholder; user can replace)
    if [[ -f "$ZAIOS_ROOT/iso/splash.png" ]]; then
        cp "$ZAIOS_ROOT/iso/splash.png" "$ISO_DIR/boot/grub/splash.png"
    fi

    # Build the ISO with xorriso (BIOS + EFI hybrid, UEFI bootable)
    log "Calling xorriso to assemble $iso_out"
    local xorriso_args=()
    xorriso_args+=(-as mkisofs)
    xorriso_args+=(-r -J -joliet-long)
    xorriso_args+=(-V "ZAIos_$ZAIOS_VERSION")
    xorriso_args+=(-o "$iso_out")
    # ISOLINUX hybrid MBR (only if the file exists on the host)
    if [[ -f /usr/lib/ISOLINUX/isohdpfx.bin ]]; then
        xorriso_args+=(-isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin)
    elif [[ -f /usr/lib/syslinux/isohdpfx.bin ]]; then
        xorriso_args+=(-isohybrid-mbr /usr/lib/syslinux/isohdpfx.bin)
    else
        warn "ISOLINUX isohdpfx.bin not found — ISO will not be BIOS-bootable (EFI still works)"
    fi

    # ISOLINUX (BIOS)
    if [[ "$ARCH" == "x86_64" ]]; then
        xorriso_args+=(
            -b boot/isolinux/isolinux.bin
            -c boot/isolinux/boot.cat
            -no-emul-boot -boot-load-size 4 -boot-info-table
        )
    fi

    # EFI (x86_64 or arm64)
    if [[ "$ARCH" == "x86_64" ]]; then
        xorriso_args+=(
            -eltorito-alt-boot
            -e boot/efi/boot/bootx64.efi
            -no-emul-boot -isohybrid-gpt-basdat
        )
    elif [[ "$ARCH" == "arm64" ]]; then
        xorriso_args+=(
            -eltorito-alt-boot
            -e boot/efi/boot/bootaa64.efi
            -no-emul-boot -isohybrid-gpt-basdat
        )
    fi

    xorriso_args+=("$ISO_DIR")

    xorriso "${xorriso_args[@]}" || die "xorriso failed"

    ok "ISO assembled: $iso_out ($(du -h "$iso_out" | cut -f1))"
    ok "Flash to USB:  dd if=$iso_out of=/dev/sdX bs=4M status=progress && sync"
    ok "Or boot directly in QEMU:"
    ok "  qemu-system-x86_64 -m 4G -enable-kvm -cdrom $iso_out"
}

# ─── Main ──────────────────────────────────────────────────────────────────
main() {
    if (( CLEAN )); then
        log "Cleaning $BUILD_DIR"
        rm -rf "$BUILD_DIR"
        ok "Done."
        exit 0
    fi

    check_host_deps

    if (( DOWNLOAD_ONLY )); then
        download_sources
        exit 0
    fi

    case "$TARGET" in
        download)  download_sources ;;
        kernel)    [[ "$SKIP_DOWNLOADS" -eq 0 ]] && { download_sources; extract_sources; }
                   build_kernel ;;
        init)      [[ "$SKIP_DOWNLOADS" -eq 0 ]] && { download_sources; extract_sources; }
                   build_init ;;
        shell)     [[ "$SKIP_DOWNLOADS" -eq 0 ]] && { download_sources; extract_sources; }
                   build_shell ;;
        rootfs)    [[ "$SKIP_DOWNLOADS" -eq 0 ]] && { download_sources; extract_sources; }
                   build_rootfs ;;
        initramfs) build_initramfs ;;
        calamares) build_calamares ;;
        iso)       [[ ! -f "$BUILD_DIR/rootfs-$ARCH.squashfs" ]] && die "Run --target=rootfs first"
                   [[ ! -f "$BUILD_DIR/initramfs-$ARCH.img" ]] && die "Run --target=initramfs first"
                   build_iso ;;
        all)
            download_sources
            extract_sources
            build_kernel
            build_rootfs        # also runs build_init + build_shell
            build_initramfs
            build_calamares
            build_iso
            ;;
        *) die "Unknown target: $TARGET (try --list-targets)" ;;
    esac

    section "ZAIos build complete"
    ok "Target '$TARGET' for arch '$ARCH' finished."
    if [[ "$TARGET" == "all" || "$TARGET" == "iso" ]]; then
        ok "Bootable ISO: $OUT_DIR/zaios-$ARCH-$ZAIOS_VERSION.iso"
    fi
}

main "$@"
