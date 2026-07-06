# ZAIos — A Custom TV Operating System

ZAIos is a from-scratch Linux-based operating system designed for TVs and TV-boxes.
It boots directly into a Qt6/QML glassmorphism shell, supports D-pad remotes, air
mice, and keyboards, ships Spotify (no premium required), YouTube, Google Cast
(Miracast), a Chromium browser, Bluetooth, and WiFi — all packaged as a multi-arch
bootable ISO installable to disk via Calamares.

> Built with Linux kernel + custom init + Qt6 + Wayland (Cage kiosk) + MiracleCast
> + librespot + yt-dlp + mpv + Chromium. Not a fork of any existing distribution.

---

## 1. What this repository contains

```
zaios/
├── build.sh                  # Master orchestrator — builds everything end-to-end
├── Makefile                  # Convenience targets
├── iso/                      # ISO builder (xorriso + GRUB EFI + ISOLINUX BIOS)
├── rootfs/                   # Skeleton root filesystem (etc/, usr/share/)
├── src/
│   ├── kernel/               # Linux kernel .config fragments per arch
│   ├── init/                 # zaios-init — a custom PID 1 written in C
│   ├── shell/                # ZAIos Shell — Qt6/QML TV UI (the actual desktop)
│   └── services/             # Background services (input router, cast, spotify)
├── calamares/                # Calamares installer config (GUI disk installer)
├── packages/                 # Source tarballs list + build order
├── docs/                     # BUILD.md, ARCHITECTURE.md, INSTALL.md
└── scripts/                  # Helper scripts (cross-compile, sign, etc.)
```

This repo does NOT ship precompiled binaries. You compile on your machine.
Build instructions are in `docs/BUILD.md`.

---

## 2. System architecture (high level)

```
┌─────────────────────────────────────────────────────────────┐
│                      ZAIos Boot Flow                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  U-PI / EDK2 / BIOS                                        │
│       │                                                     │
│       ▼                                                     │
│  GRUB (EFI) / ISOLINUX (BIOS)  ◄── from ISO                 │
│       │   loads: /boot/vmlinuz + /boot/initramfs.img        │
│       ▼                                                     │
│  Linux Kernel (zaios_defconfig)                            │
│       │                                                     │
│       ▼                                                     │
│  /sbin/zaios-init  (PID 1, custom C init)                  │
│       │                                                     │
│       ├─► mount /proc /sys /dev /run /tmp                  │
│       ├─► bring up loopback + udev                         │
│       ├─► start zaios-input    (evdev router → DBus)        │
│       ├─► start NetworkManager (WiFi via wpa_supplicant)    │
│       ├─► start Bluetooth      (BlueZ)                      │
│       ├─► start Cage           (Wayland kiosk compositor)   │
│       └─► start zaios-shell    (Qt6/QML TV desktop)         │
│                                                             │
│  zaios-shell:                                               │
│   ├─ First-boot → SetupWizard (lang, wifi, bluetooth, acc) │
│   ├─ Home grid (Spotify, YouTube, Browser, Cast, Settings) │
│   ├─ Spotify page (Spotube-style + librespot fallback)     │
│   ├─ YouTube page (yt-dlp + mpv backend)                   │
│   ├─ Browser page (Chromium embedded via QtWebEngine)      │
│   ├─ Cast page (MiracleCast Wi-Fi Display sink)            │
│   └─ Settings (network, bluetooth, display, about)         │
└─────────────────────────────────────────────────────────────┘
```

Full architecture in `docs/ARCHITECTURE.md`.

---

## 3. Feature checklist

| Feature                      | Implementation                                       |
|------------------------------|------------------------------------------------------|
| Bootable ISO                 | xorriso + GRUB EFI + ISOLINUX BIOS, multi-arch       |
| Install to disk              | Calamares GUI installer                              |
| Spotify (no premium)         | Spotube-style: search Spotify catalog, stream YouTube audio. librespot bundled as fallback for premium users. |
| YouTube                      | yt-dlp + mpv backend, ad-block via sponsorblock      |
| Google Cast                  | MiracleCast (Wi-Fi Display sink) — open Miracast     |
| Browser                      | Chromium via QtWebEngine (kiosk mode)                |
| TV remote (D-pad)            | evdev → key events → Qt focus chain                  |
| Air mouse (gyro)             | evdev → pointer events → Qt cursor                   |
| Keyboard                     | standard evdev → Qt key events                       |
| Bluetooth                    | BlueZ + QtBluetooth (A2DP, HID, BLE)                 |
| WiFi                         | wpa_supplicant + iwd (backend selectable)            |
| First-time setup             | QML SetupWizard (language → wifi → bt → account)     |
| Animations & VFX             | Qt Quick animations, ShaderEffect, glass blur        |
| Architectures                | x86_64, ARM64, ARM32 (Pi 2/3/4/5)                    |

---

## 4. Quick start (full build)

Prerequisites (host): any modern Linux with `gcc`, `make`, `cmake`, `ninja`,
`qt6-base-dev`, `xorriso`, `grub-common`, `isolinux`, `mtools`, `dosfstools`,
`bc`, `bison`, `flex`, `libelf-dev`, `libssl-dev`, `python3`, `wpa_supplicant`,
`bluez`, `liburing-dev`. About 30 GB free disk and 4+ hours for a clean build.

```bash
git clone <this-repo> zaios && cd zaios
./build.sh --arch=x86_64 --target=all
# Output: build/zaios-x86_64-1.0.iso
```

Targeted builds:

```bash
./build.sh --arch=x86_64  --target=kernel      # only Linux kernel
./build.sh --arch=x86_64  --target=rootfs      # only rootfs squashfs
./build.sh --arch=x86_64  --target=shell       # only Qt shell (deploy to rootfs)
./build.sh --arch=x86_64  --target=iso         # only assemble ISO
./build.sh --arch=arm64   --target=all         # ARM64 (Raspberry Pi 4/5)
./build.sh --arch=arm     --target=all         # ARM32 (Raspberry Pi 2/3)
./build.sh --list-targets
```

Full instructions: `docs/BUILD.md`.

---

## 5. Licensing

- ZAIos-specific source (init, shell, services, build scripts, configs): **MIT**
- Linux kernel: GPL-2.0
- Qt6: LGPL-3.0 / commercial
- librespot, MiracleCast, yt-dlp, mpv, Chromium, BlueZ, wpa_supplicant: their own licenses

See `LICENSE` and `THIRD_PARTY.md`.

---

## 6. Status

ZAIos is a complete source blueprint. The code in this repository compiles on a
suitable Linux host and produces a bootable ISO. Some hardware-specific drivers
(NVIDIA proprietary, Broadcom Wi-Fi on Pi) require user-supplied firmware blobs
during the build; see `docs/BUILD.md` § "Firmware blobs".
