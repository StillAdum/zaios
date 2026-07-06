#!/usr/bin/env bash
###############################################################################
# ZAIos master build script
###############################################################################
set -Eeuo pipefail

ZAIOS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZAIOS_VERSION="${ZAIOS_VERSION:-1.0}"
ZAIOS_CODENAME="Aurora"

LINUX_VERSION="6.10.5"
QT_VERSION="6.7.2"
GLIBC_VERSION="2.40"
BUSYBOX_VERSION="1.36.1"
MPV_VERSION="0.39.0"
YT_DLP_VERSION="2024.08.06"
WPA_SUPPLICANT_VERSION="2.10"
BLUEZ_VERSION="5.79"
PIPEWIRE_VERSION="1.2.5"
CAGE_VERSION="0.2.0"
CALAMARES_VERSION="3.3.13"
CHROMIUM_VERSION="128.0.6613.84"

C_RED='\033[0;31m'; C_GRN='\033[0;32m'; C_YEL='\033[1;33m'
C_BLU='\033[0;34m'; C_MAG='\033[0;35m'; C_RST='\033[0m'

log()  { printf "${C_BLU}[*]${C_RST} %s\n" "$*"; }
ok()   { printf "${C_GRN}[OK]${C_RST} %s\n" "$*"; }
warn() { printf "${C_YEL}[!]${C_RST} %s\n" "$*" >&2; }
err()  { printf "${C_RED}[ERR]${C_RST} %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }
section() { printf "\n${C_MAG}========================================${C_RST}\n${C_MAG}  %s${C_RST}\n${C_MAG}========================================${C_RST}\n" "$*"; }

ARCH=""
TARGET=""
JOBS="$(nproc)"
DOWNLOAD_ONLY=0
CLEAN=0
SKIP_DOWNLOADS=0

list_targets() {
    cat <<EOF
ZAIos build targets:
  kernel, init, shell, rootfs, initramfs, iso, calamares, all, download, clean
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
        --help|-h)      grep '^#' "$0" | head -20; exit 0 ;;
        *) die "Unknown argument: $1 (try --help)" ;;
    esac
done

[[ -z "$ARCH"   ]] && { ARCH="x86_64"; warn "No --arch given, defaulting to $ARCH"; }
[[ -z "$TARGET" ]] && die "No --target given. Try --list-targets."

case "$ARCH" in
    x86_64|arm64|arm) ;;
    *) die "Invalid arch '$ARCH' (use: x86_64, arm64, arm)" ;;
esac

BUILD_DIR="$ZAIOS_ROOT/build"
CACHE_DIR="$ZAIOS_ROOT/cache"
DL_DIR="$CACHE_DIR/dl"
SRC_DIR="$CACHE_DIR/src"
ROOTFS_DIR="$BUILD_DIR/rootfs-$ARCH"
ISO_DIR="$BUILD_DIR/iso-$ARCH"
OUT_DIR="$BUILD_DIR/out"

mkdir -p "$DL_DIR" "$SRC_DIR" "$BUILD_DIR" "$OUT_DIR"

kernel_arch() {
    case "$ARCH" in
        x86_64) echo "x86_64" ;;
        arm64)  echo "arm64"  ;;
        arm)    echo "arm"    ;;
    esac
}

cross_tuple() {
    case "$ARCH" in
        x86_64) echo ""                   ;;
        arm64)  echo "aarch64-linux-gnu-" ;;
        arm)    echo "arm-linux-gnueabihf-" ;;
    esac
}

check_host_deps() {
    section "Checking host dependencies"
    local deps=(gcc g++ make cmake ninja bc bison flex xorriso grub-mkimage mtools python3 pkg-config wget curl)
    if [[ "$ARCH" != "x86_64" ]]; then
        deps+=("$(cross_tuple)gcc" "$(cross_tuple)g++")
    fi
    local missing=()
    for d in "${deps[@]}"; do
        if ! command -v "$d" >/dev/null 2>&1; then
            if dpkg -s "$d" >/dev/null 2>&1; then continue; fi
            missing+=("$d")
        fi
    done
    if (( ${#missing[@]} > 0 )); then
        warn "Missing host packages: ${missing[*]}"
        die "Install missing host deps first."
    fi
    ok "Host deps OK ($(nproc) cores, $(free -h | awk '/^Mem:/{print $2}') RAM)"
}

download_sources() {
    section "Downloading upstream sources"
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
        ["chromium.tar.xz"]="https://commondatastorage.googleapis.com/chromium-browser-official/chromium-$CHROMIUM_VERSION.tar.xz"
    )

    local failed=()
    for name in "${!SRC_URLS[@]}"; do
        local url="${SRC_URLS[$name]}"
        local dest="$DL_DIR/$name"
        if [[ -f "$dest" ]] && [[ -s "$dest" ]]; then
            ok "Cached: $name ($(du -h "$dest" | cut -f1))"
            continue
        fi
        if [[ -f "$dest" ]] && [[ ! -s "$dest" ]]; then
            warn "$name is 0 bytes - re-downloading"
            rm -f "$dest"
        fi
        log "Downloading $name"
        local tries=0
        while (( tries < 3 )); do
            if wget -q --show-progress --tries=2 --timeout=60 -O "$dest" "$url"; then
                break
            fi
            tries=$((tries + 1))
            warn "Download attempt $tries failed for $name - retrying..."
            rm -f "$dest"
            sleep 3
        done
        if [[ ! -f "$dest" ]] || [[ ! -s "$dest" ]]; then
            err "Failed: $url"
            failed+=("$name")
        fi
    done

    if (( ${#failed[@]} > 0 )); then
        err "These downloads failed: ${failed[*]}"
        die "Cannot proceed without all sources."
    fi
    ok "All sources downloaded to $DL_DIR"
}

extract_sources() {
    section "Extracting sources"
    for f in "$DL_DIR"/*; do
        local name="$(basename "$f")"
        local dest
        case "$name" in
            *.tar.xz)  dest="$SRC_DIR/$(basename "$name" .tar.xz)" ;;
            *.tar.bz2) dest="$SRC_DIR/$(basename "$name" .tar.bz2)" ;;
            *.tar.gz)  dest="$SRC_DIR/$(basename "$name" .tar.gz)" ;;
            *) continue ;;
        esac
        if [[ -d "$dest" ]]; then continue; fi
        log "Extracting $name"
        case "$name" in
            *.tar.xz)  tar -xf "$f" -C "$SRC_DIR" ;;
            *.tar.bz2) tar -xjf "$f" -C "$SRC_DIR" ;;
            *.tar.gz)  tar -xzf "$f" -C "$SRC_DIR" ;;
        esac
    done
    ok "Sources extracted to $SRC_DIR"
}

build_kernel() {
    section "Building Linux kernel $LINUX_VERSION for $ARCH"
    local ksrc="$SRC_DIR/linux-$LINUX_VERSION"
    local kbuild="$BUILD_DIR/linux-build-$ARCH"
    local kcfg="$ZAIOS_ROOT/src/kernel/configs/zaios_$ARCH.config"
    local common_cfg="$ZAIOS_ROOT/src/kernel/configs/zaios_common.config"

    [[ ! -d "$ksrc" ]] && die "Kernel source missing at $ksrc"
    [[ ! -f "$kcfg" ]] && die "Kernel config missing at $kcfg"

    mkdir -p "$kbuild"
    cat "$common_cfg" "$kcfg" > "$kbuild/.config"

    local cross="$(cross_tuple)"
    local arch="$(kernel_arch)"

    log "Configuring kernel (arch=$arch, cross=${cross:-native})"
    ( cd "$ksrc" && make O="$kbuild" ARCH="$arch" ${cross:+CROSS_COMPILE=$cross} olddefconfig )

    log "Building kernel + modules (${JOBS} jobs)"
    ( cd "$ksrc" && make O="$kbuild" ARCH="$arch" ${cross:+CROSS_COMPILE=$cross} -j"$JOBS" bzImage modules ) || die "Kernel build failed"

    local moddir="$BUILD_DIR/modules-$ARCH"
    rm -rf "$moddir"; mkdir -p "$moddir"
    ( cd "$ksrc" && make O="$kbuild" ARCH="$arch" ${cross:+CROSS_COMPILE=$cross} INSTALL_MOD_PATH="$moddir" modules_install )

    ok "Kernel built: $kbuild/arch/$arch/boot/bzImage"

    if [[ -d "$ROOTFS_DIR" ]]; then
        log "Staging kernel + modules into rootfs"
        local kimg_dest="$ROOTFS_DIR/boot/vmlinuz-$ZAIOS_VERSION-$ARCH"
        mkdir -p "$ROOTFS_DIR/boot" "$ROOTFS_DIR/lib/modules"
        cp "$kbuild/arch/$arch/boot/bzImage" "$kimg_dest"
        cp -a "$moddir/lib/modules/"* "$ROOTFS_DIR/lib/modules/"
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

    # Compile directly with gcc - no -static, no -ludev (both cause link errors)
    local cc="${cross}gcc"
    local strip_bin="${cross}strip"

    log "Compiling zaios-init"
    $cc -O2 -Wall -Wextra -Wno-unused-parameter -Wno-unused-result -std=c11 \
        -o "$out/zaios-init" \
        "$init_src/zaios-init.c" "$init_src/zaios-mounts.c" "$init_src/zaios-services.c" \
        -lrt || die "zaios-init compile failed"
    $strip_bin "$out/zaios-init" 2>/dev/null || true

    log "Compiling zaios-input"
    $cc -O2 -Wall -Wextra -Wno-unused-parameter -Wno-unused-result -std=c11 \
        -o "$out/zaios-input" \
        "$init_src/zaios-input-svc.c" \
        -lrt || die "zaios-input compile failed"
    $strip_bin "$out/zaios-input" 2>/dev/null || true

    log "Compiling zaios-cast"
    $cc -O2 -Wall -Wextra -Wno-unused-parameter -Wno-unused-result -std=c11 \
        -o "$out/zaios-cast" \
        "$init_src/zaios-cast-svc.c" \
        -lrt || die "zaios-cast compile failed"
    $strip_bin "$out/zaios-cast" 2>/dev/null || true

    log "Compiling zaios-spotify"
    $cc -O2 -Wall -Wextra -Wno-unused-parameter -Wno-unused-result -std=c11 \
        -o "$out/zaios-spotify" \
        "$init_src/zaios-spotify-svc.c" \
        -lrt || die "zaios-spotify compile failed"
    $strip_bin "$out/zaios-spotify" 2>/dev/null || true

    log "Compiling zaios-network"
    $cc -O2 -Wall -Wextra -Wno-unused-parameter -Wno-unused-result -std=c11 \
        -o "$out/zaios-network" \
        "$init_src/zaios-network-svc.c" \
        -lrt || die "zaios-network compile failed"
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

build_shell() {
    section "Building ZAIos Shell (Qt6/QML)"
    local cross="$(cross_tuple)"
    local qt_prefix="$BUILD_DIR/qt-$ARCH"
    local shell_src="$ZAIOS_ROOT/src/shell"
    local shell_build="$BUILD_DIR/shell-$ARCH"

    if [[ ! -f "$qt_prefix/lib/libQt6Core.so" ]]; then
        log "Building Qt6 base (this takes ~2 hours)"
        local qtsrc="$SRC_DIR/qt-everywhere-src-$QT_VERSION"
        ( cd "$qtsrc" && ./configure -prefix "$qt_prefix" -release -opensource -confirm-license ${cross:+-device-option CROSS_COMPILE=$cross} -nomake examples -nomake tests -skip qtwebengine -skip qtactiveqt -system-zlib -system-libjpeg -system-libpng -dbus -gui -widgets -no-feature-sqlmodel -optimized-qmake -no-warnings-are-errors 2>&1 | tail -50 ) || die "Qt6 configure failed"
        ( cd "$qtsrc" && cmake --build . -j"$JOBS" 2>&1 | tail -50 ) || die "Qt6 build failed"
        ( cd "$qtsrc" && cmake --install . 2>&1 | tail -20 ) || die "Qt6 install failed"
        ok "Qt6 installed to $qt_prefix"
    else
        ok "Qt6 already built at $qt_prefix"
    fi

    log "Configuring ZAIos Shell"
    mkdir -p "$shell_build"
    ( cd "$shell_build" && cmake "$shell_src" -DCMAKE_PREFIX_PATH="$qt_prefix" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr ${cross:+-DCMAKE_CXX_COMPILER=${cross}g++} ${cross:+-DCMAKE_C_COMPILER=${cross}gcc} -G Ninja ) || die "Shell configure failed"

    log "Compiling ZAIos Shell"
    ( cd "$shell_build" && ninja -j"$JOBS" ) || die "Shell build failed"

    ok "ZAIos Shell built: $shell_build/zaios-shell"

    if [[ -d "$ROOTFS_DIR" ]]; then
        log "Staging ZAIos Shell into rootfs"
        mkdir -p "$ROOTFS_DIR/usr/bin" "$ROOTFS_DIR/usr/lib/zaios"
        cp "$shell_build/zaios-shell" "$ROOTFS_DIR/usr/bin/zaios-shell"
        mkdir -p "$ROOTFS_DIR/usr/lib/qt6" "$ROOTFS_DIR/usr/share/zaios/qml"
        cp -a "$qt_prefix/qml"/* "$ROOTFS_DIR/usr/share/zaios/qml/" 2>/dev/null || true
        cp -a "$qt_prefix/plugins"/* "$ROOTFS_DIR/usr/lib/qt6/" 2>/dev/null || true
        cp -a "$shell_src/qml"/* "$ROOTFS_DIR/usr/share/zaios/qml/" 2>/dev/null || true
        for lib in libQt6Core libQt6Gui libQt6Quick libQt6Qml libQt6Network libQt6DBus libQt6Multimedia libQt6Bluetooth libQt6WaylandClient; do
            for f in "$qt_prefix/lib/$lib".so*; do
                [[ -f "$f" ]] && cp -a "$f" "$ROOTFS_DIR/usr/lib/" 2>/dev/null || true
            done
        done
        ok "Shell + Qt runtime staged"
    fi
}

build_rootfs() {
    section "Assembling rootfs for $ARCH"

    rm -rf "$ROOTFS_DIR"
    mkdir -p "$ROOTFS_DIR"/{boot,bin,sbin,etc,proc,sys,dev,run,tmp,var,usr/{bin,sbin,lib,share},lib,root,home,opt,mnt}

    cp -a "$ZAIOS_ROOT/rootfs/." "$ROOTFS_DIR/"

    local bb_src="$SRC_DIR/busybox-$BUSYBOX_VERSION"
    if [[ ! -f "$bb_src/busybox" ]]; then
        log "Building BusyBox"
        ( cd "$bb_src" && make defconfig && make -j"$JOBS" )
    fi
    cp "$bb_src/busybox" "$ROOTFS_DIR/bin/busybox"
    chmod +x "$ROOTFS_DIR/bin/busybox"
    for applet in $("$bb_src/busybox" --list); do
        ln -sf /bin/busybox "$ROOTFS_DIR/bin/$applet" 2>/dev/null || true
    done

    local glibc_src="$SRC_DIR/glibc-$GLIBC_VERSION"
    if [[ ! -f "$BUILD_DIR/glibc-$ARCH/usr/lib/libc.so.6" ]]; then
        log "Building glibc $GLIBC_VERSION"
        local gbuild="$BUILD_DIR/glibc-build-$ARCH"
        mkdir -p "$gbuild"
        local cross="$(cross_tuple)"
        local host_flag=""
        local cc_flag=""
        if [[ -n "$cross" ]]; then
            host_flag="--host=${cross%-linux-gnu-}linux-gnu"
            cc_flag="CC=${cross}gcc"
        fi
        ( cd "$gbuild" && "$glibc_src/configure" --prefix=/usr $host_flag $cc_flag --enable-kernel=5.15 --disable-werror && make -j"$JOBS" && make DESTDIR="$BUILD_DIR/glibc-$ARCH" install ) || die "glibc build failed"
    fi
    cp -a "$BUILD_DIR/glibc-$ARCH/usr/lib/"*so* "$ROOTFS_DIR/usr/lib/" 2>/dev/null || true
    cp -a "$BUILD_DIR/glibc-$ARCH/usr/lib/ld-linux"* "$ROOTFS_DIR/lib/" 2>/dev/null || true

    build_init
    build_shell

    local ytdlp_src="$SRC_DIR/yt-dlp-$YT_DLP_VERSION"
    if [[ -d "$ytdlp_src" ]]; then
        mkdir -p "$ROOTFS_DIR/usr/bin"
        cp "$ytdlp_src/yt-dlp" "$ROOTFS_DIR/usr/bin/yt-dlp" 2>/dev/null || \
        cp "$ytdlp_src/yt-dlp/yt-dlp" "$ROOTFS_DIR/usr/bin/yt-dlp" 2>/dev/null || true
        chmod +x "$ROOTFS_DIR/usr/bin/yt-dlp"
    fi

    if [[ -d "$ZAIOS_ROOT/calamares" ]]; then
        mkdir -p "$ROOTFS_DIR/etc/calamares"
        cp -a "$ZAIOS_ROOT/calamares/." "$ROOTFS_DIR/etc/calamares/"
    fi

    if [[ -d "$CACHE_DIR/firmware" ]]; then
        mkdir -p "$ROOTFS_DIR/lib/firmware"
        cp -a "$CACHE_DIR/firmware/." "$ROOTFS_DIR/lib/firmware/"
        ok "Firmware blobs staged"
    else
        warn "No firmware blobs at $CACHE_DIR/firmware"
    fi

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
EOF

    echo "zaios" > "$ROOTFS_DIR/etc/hostname"

    chmod 4755 "$ROOTFS_DIR/bin/busybox" 2>/dev/null || true
    mkdir -p "$ROOTFS_DIR/var/tmp" && chmod 1777 "$ROOTFS_DIR/tmp" "$ROOTFS_DIR/var/tmp"

    local sqfs="$BUILD_DIR/rootfs-$ARCH.squashfs"
    log "Packing squashfs: $sqfs"
    rm -f "$sqfs"
    mksquashfs "$ROOTFS_DIR" "$sqfs" -comp zstd -Xcompression-level 19 -noappend -progress || die "mksquashfs failed"
    ok "Rootfs squashfs: $sqfs ($(du -h "$sqfs" | cut -f1))"
}

build_initramfs() {
    section "Building initramfs for $ARCH"
    local irfs="$BUILD_DIR/initramfs-$ARCH"
    rm -rf "$irfs"; mkdir -p "$irfs"/{bin,sbin,proc,sys,dev,run,newroot,usr/{bin,sbin}}

    local bb_src="$SRC_DIR/busybox-$BUSYBOX_VERSION"
    if [[ ! -f "$bb_src/busybox" ]]; then
        log "Building static BusyBox for initramfs"
        ( cd "$bb_src" && make defconfig && sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config && make -j"$JOBS" )
    fi
    cp "$bb_src/busybox" "$irfs/bin/busybox"
    chmod +x "$irfs/bin/busybox"
    for applet in $("$bb_src/busybox" --list); do
        ln -sf /bin/busybox "$irfs/bin/$applet" 2>/dev/null || true
    done

    cat > "$irfs/init" <<'INITSCRIPT'
#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || mdev -s

echo "[zaios-initramfs] Searching for ZAIos boot media..."
BOOT_DEV=""
for dev in /dev/disk/by-uuid/* /dev/sr* /dev/sd* /dev/mmcblk*p* /dev/nvme*p*; do
    [ -b "$dev" ] || continue
    mkdir -p /mnt/probe
    if mount -o ro "$dev" /mnt/probe 2>/dev/null; then
        if [ -f /mnt/probe/zaios/rootfs.squashfs ] || [ -f /mnt/probe/boot/vmlinuz ]; then
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

mount -t squashfs -o ro /mnt/probe/zaios/rootfs.squashfs /newroot
mount --move /dev  /newroot/dev  2>/dev/null
mount --move /proc /newroot/proc 2>/dev/null
mount --move /sys  /newroot/sys  2>/dev/null
echo "BOOT_DEV=$BOOT_DEV" > /newroot/etc/zaios/boot-dev
exec switch_root /newroot /sbin/zaios-init
INITSCRIPT
    chmod +x "$irfs/init"

    local out="$BUILD_DIR/initramfs-$ARCH.img"
    log "Packing initramfs: $out"
    ( cd "$irfs" && find . | cpio -H newc -o | xz -9 --check=crc32 ) > "$out" || die "initramfs pack failed"
    ok "Initramfs: $out ($(du -h "$out" | cut -f1))"
}

build_calamares() {
    section "Building Calamares installer"
    if command -v calamares >/dev/null 2>&1 && [[ "$ARCH" == "x86_64" ]]; then
        mkdir -p "$ROOTFS_DIR/usr/bin"
        cp "$(command -v calamares)" "$ROOTFS_DIR/usr/bin/calamares"
        ok "Staged host Calamares binary into rootfs"
    else
        warn "Calamares binary not found on host - install with: apt install calamares"
    fi
}

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

    cp "$kimg" "$ISO_DIR/live/vmlinuz"
    cp "$irfs" "$ISO_DIR/live/initramfs.img"
    cp "$sqfs" "$ISO_DIR/zaios/rootfs.squashfs"
    touch "$ISO_DIR/zaios/.boot-marker"

    cat > "$ISO_DIR/boot/isolinux/isolinux.cfg" <<EOF
SERIAL 0 115200
UI vesamenu.c32
PROMPT 0
TIMEOUT 30
DEFAULT zaios

MENU TITLE ZAIos $ZAIOS_VERSION ($ZAIOS_CODENAME) - $ARCH

LABEL zaios
    MENU LABEL ^ZAIos Live (default)
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initramfs.img boot=live zaios.media=cdrom zaios.arch=$ARCH quiet loglevel=3

LABEL zaios-install
    MENU LABEL ^Install ZAIos to disk (Calamares)
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initramfs.img boot=live zaios.media=cdrom zaios.arch=$ARCH zaios.installer=1 quiet
EOF

    for f in isolinux.bin ldlinux.c32 libcom32.c32 libutil.c32 vesamenu.c32 menu.c32; do
        local src="/usr/lib/ISOLINUX/$f"
        [[ -f "/usr/lib/syslinux/modules/bios/$f" ]] && src="/usr/lib/syslinux/modules/bios/$f"
        [[ -f "$src" ]] && cp "$src" "$ISO_DIR/boot/isolinux/$f"
    done

    cat > "$ISO_DIR/boot/grub/grub.cfg" <<'GRUBCFG'
set default=0
set timeout=10
set gfxmode=auto
set gfxpayload=keep
insmod all_video
insmod gfxterm
insmod png
insmod gzio
loadfont /boot/grub/fonts/unicode.pf2
terminal_output gfxterm
menu_color_normal=white/black
menu_color_highlight=cyan/black

menuentry "ZAIos Live (default)" {
    linux  /live/vmlinuz boot=live zaios.media=cdrom quiet loglevel=3
    initrd /live/initramfs.img
}

menuentry "Install ZAIos to disk (Calamares)" {
    linux  /live/vmlinuz boot=live zaios.media=cdrom zaios.installer=1 quiet
    initrd /live/initramfs.img
}
GRUBCFG

    case "$ARCH" in
        x86_64)
            log "Building GRUB EFI image for x86_64"
            grub-mkimage -O x86_64-efi -p /boot/grub -o "$ISO_DIR/boot/efi/boot/bootx64.efi" ext2 fat iso9660 part_gpt part_msdos normal boot linux configfile loopback chain efifwsetup efi_gop efi_uga ls search search_label search_fs_uuid search_fs_file gfxterm gfxterm_background gfxterm_menu test all_video loadenv exfat ntfs udf font echo cat help part_apple hfsplus || die "grub-mkimage x86_64-efi failed"
            log "Building GRUB BIOS image"
            grub-mkimage -O i386-pc-eltorito -p /boot/grub -o "$ISO_DIR/boot/grub/core.img" biosdisk iso9660 ext2 fat ls search normal configfile part_msdos part_gpt boot linux chain echo cat help || die "grub-mkimage i386-pc failed"
            mkdir -p "$ISO_DIR/boot/grub/i386-pc"
            cp /usr/lib/grub/i386-pc/*.mod "$ISO_DIR/boot/grub/i386-pc/" 2>/dev/null || true
            ;;
        arm64)
            log "Building GRUB EFI image for ARM64"
            grub-mkimage -O arm64-efi -p /boot/grub -o "$ISO_DIR/boot/efi/boot/bootaa64.efi" ext2 fat iso9660 part_gpt part_msdos normal boot linux configfile loopback chain efifwsetup efi_gop ls search search_label search_fs_uuid search_fs_file gfxterm gfxterm_background gfxterm_menu
