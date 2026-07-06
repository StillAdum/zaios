# ZAIos — Build Guide

This document explains how to compile ZAIos from source and produce a
bootable ISO.

> **Time required**: 4–8 hours for a clean x86_64 build (depending on hardware).
> More for ARM64/ARM32 because of Qt6 + Chromium cross-compilation.

---

## 1. Host prerequisites

You need a Linux host (Debian/Ubuntu, Arch, Fedora) with at least 30 GB
free disk and 4+ GB RAM.

### Debian/Ubuntu

```bash
sudo apt install -y \
    build-essential gcc g++ make cmake ninja-build \
    bc bison flex libelf-dev libssl-dev \
    python3 python3-pip \
    pkg-config wget curl git \
    xorriso grub-common grub-pc-bin isolinux syslinux-utils \
    mtools dosfstools \
    qt6-base-dev qt6-base-dev-tools qt6-declarative-dev qt6-declarative-dev-tools \
    qt6-wayland-dev qt6-multimedia-dev qt6-webengine-dev \
    qt6-shadertools-dev qt6-svg-dev qt6-serialport-dev \
    qt6-bluez-dev qt6-positioning-dev \
    libglib2.0-dev libgstreamer1.0-dev \
    libpipewire-0.3-dev libwireplumber-0.4-dev \
    libbluetooth-dev \
    libevdev-dev libinput-dev libudev-dev \
    libwayland-dev wayland-protocols \
    libdrm-dev libgbm-dev libgl-dev libgles-dev libegl-dev \
    squashfs-tools \
    network-manager \
    bluez bluez-tools \
    wpasupplicant \
    pipewire wireplumber \
    mpv \
    chromium
```

### Cross-compile toolchains (for ARM targets)

```bash
# ARM64
sudo apt install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu

# ARM32
sudo apt install -y gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf
```

### Arch Linux

```bash
sudo pacman -S --needed \
    base-devel cmake ninja bc bison flex \
    libelf openssl python pkgconf wget curl git \
    xorriso grub isolinux syslinux mtools dosfstools \
    qt6-base qt6-declarative qt6-wayland qt6-multimedia \
    qt6-webengine qt6-shadertools qt6-svg \
    bluez bluez-libs pipewire wireplumber \
    libevdev libinput wayland wayland-protocols \
    libdrm mesa squashfs-tools networkmanager mpv chromium \
    aarch64-linux-gnu-gcc arm-linux-gnueabihf-gcc
```

### Fedora

```bash
sudo dnf install -y \
    @development-tools gcc g++ cmake ninja-build \
    bc bison flex elfutils-libelf-devel openssl-devel \
    python3 wget curl git \
    xorriso grub2-tools grub2-efi-x64-modules syslinux \
    mtools dosfstools \
    qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtwayland-devel \
    qt6-qtmultimedia-devel qt6-qtwebengine-devel \
    qt6-qtshadertools-devel qt6-qtsvg-devel \
    bluez-libs-devel pipewire-devel wireplumber-devel \
    libevdev-devel libinput-devel systemd-devel \
    wayland-devel wayland-protocols-devel \
    libdrm-devel mesa-libgbm-devel mesa-libGL-devel \
    squashfs-tools NetworkManager mpv chromium \
    gcc-aarch64-linux-gnu gcc-arm-linux-gnu
```

---

## 2. Quick build (x86_64)

```bash
git clone <your-zaios-repo> zaios
cd zaios
./build.sh --arch=x86_64 --target=all
```

The ISO will be at `build/out/zaios-x86_64-1.0.iso`.

---

## 3. Targeted builds

You can build individual components:

```bash
# Just download & verify upstream sources
./build.sh --target=download

# Just the Linux kernel
./build.sh --arch=x86_64 --target=kernel

# Just the rootfs squashfs (depends on kernel)
./build.sh --arch=x86_64 --target=rootfs

# Just the initramfs
./build.sh --arch=x86_64 --target=initramfs

# Just the Qt6 + ZAIos Shell
./build.sh --arch=x86_64 --target=shell

# Just assemble the ISO (needs rootfs + initramfs already built)
./build.sh --arch=x86_64 --target=iso
```

---

## 4. Multi-arch builds

### ARM64 (Raspberry Pi 4/5, Odroid, Snapdragon TV sticks)

```bash
# Install the cross toolchain first (see §1)
./build.sh --arch=arm64 --target=all
```

Output: `build/out/zaios-arm64-1.0.iso`

Flash to a USB stick and boot on the ARM64 device. Most Pi 4/5 boards
will boot from this ISO directly via U-Boot + GRUB EFI.

### ARM32 (Raspberry Pi 2/3)

```bash
./build.sh --arch=arm --target=all
```

Output: `build/out/zaios-arm-1.0.iso`

---

## 5. Firmware blobs

Some hardware requires proprietary firmware that we cannot ship:
- Broadcom Wi-Fi (BCM43430 on Pi 3/Zero W, BCM43455 on Pi 3B+/4)
- Realtek Wi-Fi (RTL8821CU, RTL8812BU)
- NVIDIA GPU firmware ( nouveau works open-source but is slower )

Clone the linux-firmware repo and place it in `cache/firmware/`:

```bash
git clone https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git \
    cache/firmware
```

The build script will stage these into the rootfs automatically.

### Raspberry Pi-specific firmware

For Pi, you also need:
- `start4.elf` and `fixup4.dat` (Pi 4 bootloader firmware)
- `bcm2711-rpi-4-b.dtb` etc. (device tree blobs; usually built by kernel)

Place these in `cache/firmware/bcm2711/` and the build script picks them
up. Alternatively, install `raspi-firmware` from your distro.

---

## 6. Running in QEMU (for testing without a TV)

```bash
qemu-system-x86_64 \
    -m 4G \
    -enable-kvm \
    -smp 4 \
    -cdrom build/out/zaios-x86_64-1.0.iso \
    -boot d \
    -vga virtio \
    -display gtk
```

For ARM64 testing in QEMU:

```bash
qemu-system-aarch64 \
    -m 2G \
    -cpu cortex-a72 \
    -machine virt \
    -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
    -cdrom build/out/zaios-arm64-1.0.iso \
    -display gtk
```

---

## 7. Flashing to USB

```bash
# Find your USB device
lsblk

# Flash (BE CAREFUL — this overwrites the disk!)
sudo dd if=build/out/zaios-x86_64-1.0.iso \
    of=/dev/sdX \
    bs=4M \
    status=progress \
    conv=fsync
sync
```

Or use `etcher`, `popsicle`, `rosa-imagewriter` for a GUI.

---

## 8. Installing to disk

1. Boot the live ISO on the target device.
2. The first-time setup wizard runs.
3. From the home screen, go to **Settings → Restart** OR run
   `calamares` from a terminal (`Ctrl+Alt+F2`).
4. Calamares launches the GUI installer.
5. Pick the target disk, partition layout, user name.
6. Wait ~10 minutes.
7. Reboot — ZAIos is now installed to disk.

---

## 9. Build outputs reference

```
build/
├── linux-build-<arch>/         # Kernel build tree
├── modules-<arch>/             # Kernel modules (staged)
├── init-<arch>/                # zaios-init + services binaries
├── qt-<arch>/                  # Qt6 install prefix
├── shell-<arch>/               # ZAIos Shell build dir
├── rootfs-<arch>/              # Assembled rootfs directory
├── rootfs-<arch>.squashfs      # Squashfs image (goes into ISO)
├── initramfs-<arch>/           # Initramfs staging dir
├── initramfs-<arch>.img        # Compressed initramfs
├── iso-<arch>/                 # ISO staging directory
└── out/
    └── zaios-<arch>-1.0.iso    # Final bootable ISO
```

---

## 10. Common build failures

### "Qt6 configure failed: could not find python"

Qt6 needs Python 3.9+ for the build system. Install `python3` and make
sure `python3 -m venv` works (`python3-venv` package on Debian).

### "XWayland not found" during Qt6 build

The Qt6 build script needs `xwayland` for some tests. Install it:
- Debian: `apt install xwayland`
- Arch: `pacman -S xorg-server-xwayland`

### "out of memory" during Qt6 build

Qt6 is huge. Try:
```bash
./build.sh --arch=x86_64 --target=shell --jobs 2
```
(Reduce parallelism to lower peak RAM usage.)

### "grub-mkimage: error: cannot find module 'efi_gop'"

You're missing the GRUB EFI modules package:
- Debian: `apt install grub-efi-amd64-bin`
- Arch: `pacman -S grub`
- Fedora: `dnf install grub2-efi-x64-modules`

### "isolinux.bin not found"

Install `isolinux` / `syslinux-common`:
- Debian: `apt install isolinux syslinux-common`
- Arch: `pacman -S syslinux`

### Kernel build: "BFD: error: unresolvable R_AARCH64_ADR_PREL_PG_HI21"

This is a known issue with some binutils versions. Try adding
`CONFIG_ARM64_ERRATUM_843419=n` to your kernel config, or upgrade
binutils to 2.38+.

### Cross-compile: `aarch64-linux-gnu-gcc: command not found`

Install the cross toolchain:
```bash
sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
```

---

## 11. Building only what changed

The build script skips already-built stages. To force a rebuild:

```bash
# Remove kernel build — next run will rebuild kernel
rm -rf build/linux-build-x86_64

# Remove rootfs — next run will repack
rm build/rootfs-x86_64.squashfs

# Remove Qt6 install — next run will rebuild Qt (LONG!)
rm -rf build/qt-x86_64

# Force rebuild of just the shell
rm -rf build/shell-x86_64

# Force rebuild of just the ISO (fast)
rm -rf build/iso-x86_64
./build.sh --arch=x86_64 --target=iso
```

---

## 12. Building on the target device itself

If you're building ZAIos on the actual TV box (e.g. a Raspberry Pi 4 with
8 GB RAM), use native compilation:

```bash
./build.sh --arch=arm64 --target=all --jobs 4
```

This is slower than cross-compiling but simpler — no toolchain setup
needed. Expect 8–12 hours on a Pi 4.

---

## 13. Reproducibility

All upstream source tarballs are pinned to specific versions in
`build.sh`. To verify, after a `--target=download`:

```bash
cd cache/dl
sha256sum *.tar.*
# Compare with checksums in build.sh
```

If a download fails (server down, etc.), you can manually place the
tarball in `cache/dl/` with the correct filename.
