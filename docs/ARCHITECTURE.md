# ZAIos — Architecture

This document describes the internal architecture of ZAIos: how the
components fit together, how data flows between them, and the design
principles behind each layer.

---

## 1. Layer overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER-FACING LAYER                            │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ ZAIos Shell (Qt6/QML)                                         │ │
│  │  • Setup Wizard     • Spotify      • Browser (QtWebEngine)     │ │
│  │  • Home grid        • YouTube      • Cast UI                   │ │
│  │  • Settings         • Network      • Bluetooth                 │ │
│  │  • Power menu       • Toasts       • Volume overlay            │ │
│  └────────────────────────────┬───────────────────────────────────┘ │
│                               │ QML → C++ context properties         │
│  ┌────────────────────────────┴───────────────────────────────────┐ │
│  │ C++ Manager Classes                                            │ │
│  │  InputBridge  NetworkManager  BluetoothManager  CastManager     │ │
│  │  SpotifyManager  YouTubeManager  BrowserManager                 │ │
│  │  SettingsManager  SystemService  PowerManager  Notifications    │ │
│  └────────────────────────────┬───────────────────────────────────┘ │
└───────────────────────────────┼─────────────────────────────────────┘
                                │ Unix sockets + DBus
┌───────────────────────────────┴─────────────────────────────────────┐
│                         SERVICE LAYER                                │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────────┐ │
│  │ zaios-input    │  │ zaios-network  │  │ zaios-spotify          │ │
│  │ (evdev router) │  │ (wpa_supplicant│  │ (Spotube + librespot)  │ │
│  │                │  │  wrapper)      │  │                        │ │
│  └────────────────┘  └────────────────┘  └────────────────────────┘ │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────────┐ │
│  │ zaios-cast     │  │ dbus-daemon    │  │ bluetoothd (BlueZ)     │ │
│  │ (MiracleCast)  │  │                │  │                        │ │
│  └────────────────┘  └────────────────┘  └────────────────────────┘ │
│  ┌────────────────┐  ┌────────────────┐                            │
│  │ pipewire       │  │ wireplumber    │                            │
│  └────────────────┘  └────────────────┘                            │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ forked + supervised
┌───────────────────────────────┴─────────────────────────────────────┐
│                          INIT LAYER                                  │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ zaios-init (PID 1, C, static-linked)                           │ │
│  │  • Mounts /proc /sys /dev /run /tmp                            │ │
│  │  • Loads modules from /etc/modules-load.d/                     │ │
│  │  • Starts udev (coldplug)                                      │ │
│  │  • Brings up loopback                                          │ │
│  │  • Registers + supervises services                             │ │
│  │  • Starts Cage (Wayland kiosk compositor)                      │ │
│  │  • Reaps zombies                                                │ │
│  │  • Handles SIGTERM → clean shutdown                            │ │
│  └────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ runs as child of
┌───────────────────────────────┴─────────────────────────────────────┐
│                         KERNEL LAYER                                 │
│  Linux kernel (zaios_defconfig)                                     │
│   • DRM/KMS (Intel, AMD, NVIDIA-open, VC4, V3D, Lima, Panfrost)     │
│   • WiFi (all mainline chipsets: iwl, ath, rtl, mt, brcm, ...)      │
│   • Bluetooth (btusb, hci_uart, all codec drivers)                  │
│   • Input (evdev, HID, RC core with all decoders)                   │
│   • Sound (HDA, USB, I2S, BCM2835, SoC codecs)                      │
│   • Wayland (DRM lease, atomic, GBM)                                │
│   • OverlayFS + SquashFS (live ISO)                                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Boot flow (detailed)

1. **Firmware** (UEFI or BIOS) loads the boot sector from the ISO.
2. **GRUB** (EFI) or **ISOLINUX** (BIOS) shows the boot menu.
3. User selects "ZAIos Live" (or installer auto-boots after 30s).
4. GRUB loads `vmlinuz` + `initramfs.img` into RAM and jumps to the kernel.
5. **Linux kernel** initializes: brings up CPU, MMU, IRQs, mounts devtmpfs.
6. Kernel runs `/init` from the initramfs.
7. **initramfs `/init`** (a shell script):
   - Mounts /proc /sys /dev
   - Probes all storage devices for `zaios/rootfs.squashfs`
   - Loop-mounts the squashfs onto `/newroot`
   - Moves /dev /proc /sys into /newroot
   - `switch_root /newroot /sbin/zaios-init`
8. **zaios-init** (PID 1):
   - Mounts remaining filesystems (/run, /tmp, /dev/pts, /dev/shm, cgroup2)
   - If running from squashfs, sets up overlayfs over /etc /var /home /root
     so writes work despite / being read-only
   - Loads modules from `/etc/modules-load.d/`
   - Starts udev (coldplugs all devices)
   - Brings up loopback interface
   - Sets hostname from /etc/hostname
   - Registers services in the registry
   - Spawns all services with 100ms spacing (DBus first)
   - Waits for /dev/dri/card0 to appear (DRM/KMS ready)
   - Spawns Cage (Wayland compositor) as a child, with zaios-shell as its client
   - Enters the waitpid() loop, reaps zombies, restarts crashed services
9. **Cage** initializes the Wayland display:
   - Opens /dev/dri/card0
   - Initializes GBM + EGL
   - Creates a single full-screen surface
   - Launches `/usr/bin/zaios-shell` as its child
10. **zaios-shell** (Qt6/QML):
    - Reads Settings; if `setupComplete=false`, shows SetupWizard
    - Otherwise shows Home grid
    - Connects to all service sockets in the background
    - Renders the UI at 60fps via Qt Quick scenegraph

---

## 3. Service registry & supervision

`zaios-init` maintains a simple service registry:

```c
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
```

Each service has a restart policy:
- **critical=1**: if it dies, reboot the system (DBus, Pipewire, Input)
- **restart_on_death=1, critical=0**: restart with exponential backoff
  (1s, 2s, 4s, ..., up to 64s, capped at 10 attempts in <5s)
- **restart_on_death=0**: leave dead (e.g. setup helpers)

The init loop is just `waitpid(-1, ...)`. When a child dies, we look up
its name in the registry and apply the policy.

---

## 4. Input event flow

The input pipeline supports **three simultaneous modes**:

### D-pad remote (5-way)
```
/dev/input/event0 ─┐
/dev/input/event1 ─┼─► zaios-input service ──► /run/zaios/input.sock
/dev/input/event2 ─┘                                    │
                                                       │ JSON lines
                                                       ▼
                                              InputBridge (C++)
                                                       │ Qt signals
                                                       ▼
                                              navEvent("up"/"down"/...)
                                                       │
                                                       ▼
                                              QML Item.activeFocus chain
                                              (Qt's focus system handles
                                               which item gets the event)
```

### Air mouse (gyro pointer)
```
/dev/input/event3 (REL_X, REL_Y) ─► zaios-input ─► relx/rely events
                                                       │
                                                       ▼
                                              InputBridge.moveCursor()
                                                       │
                                                       ▼
                                              customCursor Image (QML)
                                              (spring-animated position)
```

### Keyboard (full QWERTY)
```
/dev/input/event4 (KEY_A, KEY_B, ...) ─► zaios-input ─► key events
                                                       │
                                                       ▼
                                              InputBridge.keyEvent()
                                                       │
                                                       ▼
                                              ActiveFocus TextField / item
                                              (Qt's normal key dispatch)
```

All three modes work simultaneously. The QML UI detects which mode is
"active" by which event types are coming in (cursor movement = pointer
mode; otherwise D-pad mode).

---

## 5. Audio pipeline

```
┌──────────────────────────────────────────────────────────────┐
│  App (Spotify / YouTube / Browser)                           │
│    │                                                          │
│    │ subprocess                                               │
│    ▼                                                          │
│  mpv (libmpv)                                                │
│    │                                                          │
│    │ PipeWire backend                                         │
│    ▼                                                          │
│  pipewire-pulse  ──►  pipewire daemon  ──►  ALSA            │
│                                                  │            │
│                                                  ▼            │
│                                          HDMI codec / USB DAC │
└──────────────────────────────────────────────────────────────┘
```

- **Pipewire** is the central audio server.
- **Wireplumber** is the session manager (auto-routes to HDMI by default).
- **mpv** connects to Pipewire via its PulseAudio backend (which Pipewire
  implements).
- Volume is controlled via `pactl` (Pipewire-Pulse compatibility).

---

## 6. Spotify playback strategies

ZAIos supports **two** Spotify playback paths:

### Strategy A: Spotube-style (default, no premium required)
```
User searches "Queen Bohemian"
       │
       ▼
SpotifyManager.sendCommand("search")  ──►  zaios-spotify service
                                                │
                                                ▼
                                       curl https://api.spotify.com/v1/search
                                                │
                                                ▼
                                       Parse JSON: get track ID + title + artist
                                                │
                                                ▼
                                       (User picks a track)
                                                │
                                       User clicks "play"
                                                │
                                                ▼
                                       Search YouTube: "$artist $title audio"
                                                │
                                                ▼
                                       yt-dlp -g -f bestaudio <youtube_url>
                                                │
                                                ▼
                                       Pass URL to mpv (audio-only mode)
                                                │
                                                ▼
                                       mpv plays audio via Pipewire
```

This works for **free**, no Spotify account needed. Audio quality depends
on the YouTube upload (usually 128kbps AAC).

### Strategy B: Librespot (Spotify Premium native)
```
User signs in with Spotify credentials
       │
       ▼
SpotifyManager.loginLibrespot(user, pass)  ─►  zaios-spotify service
                                                     │
                                                     ▼
                                            Spawn librespot
                                            with backend=pipe
                                                     │
                                                     ▼
                                            librespot streams Spotify
                                            protocol natively (Vorbis 320kbps)
                                                     │
                                                     ▼
                                            Pipe to mpv → Pipewire → audio out
```

The shell UI shows which backend is active. Default is Spotube-style.

---

## 7. Miracast (Wi-Fi Display) receiver

```
Sender device (Windows / Android / macOS)
       │
       │ Wi-Fi Direct
       ▼
p2p-wlan0-0  ◄── created by `iw phy phy0 interface add p2p-wlan0-0 type p2p`
       │
       ▼
miracle-wifid  ──►  miracle-sinkctl
       │                  │
       │                  │ When a peer connects:
       │                  ▼
       │              Spawn gstreamer pipeline:
       │              gst-launch-1.0 rtpbin name=rtpbin \
       │                  udpsrc port=1234 ! rtpmp2tdepay ! tsdemux ! \
       │                  queue ! h264dec ! videoconvert ! waylandsink
       │
       ▼
Qt shell is notified via DBus ──► CastManager ──► shows "Connected" UI
```

### Why Miracast and not Google Cast?

Google Cast (Castv2) is proprietary:
- The receiver requires a Google-issued certificate.
- The receiver software is closed-source.
- Only certified devices can use the official Google Cast trademark.

Miracast is an open IEEE 802.11 standard:
- Anyone can implement it.
- Works with Windows 10+, Android 4.2+, macOS (via third-party apps).
- Built on standard Wi-Fi Direct + H.264 over RTP.

The trade-off: **iOS devices and Chrome browser cannot cast to Miracast**.
For those, ZAIos relies on the built-in Browser page, which can use the
web-based cast sender protocol.

---

## 8. Live ISO → installed system

```
┌─────────────────────┐                ┌──────────────────────────┐
│ Live ISO            │                │ Installed system          │
│                     │                │                           │
│ /live/vmlinuz       │                │ /boot/vmlinuz             │
│ /live/initramfs.img │                │ /boot/initramfs.img       │
│ /zaios/rootfs.sqfs  │  Calamares     │ /boot/grub/grub.cfg       │
│                     │ ──────────►    │ /etc/...                  │
│ initramfs mounts    │  unpackfs      │ /usr/...                  │
│ squashfs read-only  │  + copy        │ /var/...                  │
│                     │                │                           │
│ /etc overlayfs      │                │ ext4 (writable)           │
│ /var overlayfs      │                │                           │
│ /home overlayfs     │                │                           │
└─────────────────────┘                └──────────────────────────┘
```

The squashfs is read-only. The live session uses overlayfs to make
`/etc`, `/var`, `/home`, `/root` writable so the user can save WiFi
networks and pair Bluetooth devices during first-time setup.

Calamares copies the squashfs contents to the target disk as a regular
ext4 filesystem, then runs `zaios-finalize` to:
- Mark the system as "installed" (`/etc/zaios/installed`)
- Update `zaios.conf` to `boot.mode=disk`
- Preserve WiFi/Bluetooth pairings from the live session
- Install GRUB to the target disk
- Generate a new initramfs on the target

---

## 9. Why a custom init (not systemd)?

ZAIos uses a custom PID 1 written in C, not systemd. Reasons:

1. **Simplicity**: ~600 lines of C code vs systemd's 1M+ lines.
2. **Boot speed**: ~1.5 seconds from kernel to shell, vs 4–8s for systemd.
3. **Auditability**: anyone can read the init in an afternoon.
4. **No unit files**: services are hardcoded in C — easy to understand.
5. **Static-linked**: doesn't depend on glibc being available before /usr
   is mounted.

Trade-offs:
- No service dependencies (services must handle their own ordering).
- No socket activation.
- No cgroups management per-service (we use a single cgroup for the shell).
- No `journalctl` (logs go to /dev/kmsg).

These trade-offs are acceptable for a TV OS that runs a fixed set of
services.

---

## 10. Why Qt6/QML (not Electron)?

| Aspect            | Qt6/QML                          | Electron                       |
|-------------------|----------------------------------|--------------------------------|
| Memory            | ~50 MB                           | ~150–300 MB                    |
| Boot time         | <1s                              | 3–5s                           |
| Animations        | Native GPU (scene graph)         | CSS transitions / JS           |
| Bundle size       | ~30 MB shared libs               | ~150 MB (Chromium + Node)      |
| Native APIs       | Direct C++ bindings              | IPC to Node.js                 |
| Wayland           | First-class (Qt Wayland)         | Hacky via Chromium flags       |
| Hardware decode   | Built-in (QtMultimedia)          | Requires Widevine/CDM dance    |
| Bluetooth         | QtBluetooth (native)             | Requires noble (Node lib)      |
| Distribution      | Single binary + QML resources    | asar + Chromium runtime        |

For a TV OS where memory and boot time matter, Qt6/QML is the right call.

---

## 11. File locations on the running system

```
/sbin/zaios-init                     PID 1 (custom init)
/init                                symlink → /sbin/zaios-init

/usr/bin/zaios-shell                 Qt6/QML desktop
/usr/bin/cage                        Wayland kiosk compositor
/usr/bin/mpv                         media player (used by Spotify + YouTube)
/usr/bin/yt-dlp                      YouTube URL resolver
/usr/bin/calamares                   GUI installer
/usr/bin/wpa_supplicant              Wi-Fi
/usr/libexec/bluetooth/bluetoothd    BlueZ
/usr/bin/pipewire                    audio server
/usr/bin/wireplumber                 Pipewire session manager
/usr/bin/dbus-daemon                 system bus

/usr/lib/zaios/
    zaios-input                      input event router service
    zaios-network                    Wi-Fi management service
    zaios-cast                       Miracast sink service
    zaios-spotify                    Spotify backend service

/usr/share/zaios/
    qml/                             QML UI files (deployed from src/shell/qml/)
    icons/                           App icons
    fonts/                           Inter font family

/etc/zaios/
    zaios.conf                       boot config
    installed                        marker file (only on installed system)
    boot-dev                         written by initramfs (boot device)

/var/lib/zaios/
    settings.ini                     runtime settings (SettingsManager)
    mpv.sock                         mpv IPC socket (Spotify backend)
    mpv-youtube.sock                 mpv IPC socket (YouTube backend)

/run/zaios/
    input.sock                       InputBridge ← zaios-input
    network.sock                     NetworkManager ← zaios-network
    cast.sock                        CastManager ← zaios-cast
    spotify.sock                     SpotifyManager ← zaios-spotify
```

---

## 12. Extending ZAIos

### Adding a new app
1. Create `src/shell/qml/pages/MyApp.qml`.
2. Add it to `CMakeLists.txt` QML_FILES.
3. Add a case to `goTo()` in `qml/main.qml`.
4. Add a tile to `qml/pages/Home.qml`.

### Adding a new background service
1. Write a new C service in `src/init/` (use `zaios-input-svc.c` as a template).
2. Add a build rule to `src/init/Makefile`.
3. Register it in `zaios-init.c`'s `main()`.
4. Write a C++ manager class in `src/shell/src/` that connects to its socket.
5. Expose it as a context property in `src/shell/src/main.cpp`.

### Adding a new kernel driver
1. Edit the appropriate `src/kernel/configs/zaios_<arch>.config` (or `zaios_common.config`).
2. Set `CONFIG_<DRIVER>=y` (built-in) or `=m` (module).
3. Re-run `./build.sh --target=kernel`.

---

## 13. Performance budget

| Component            | Target       | Actual (estimated)        |
|----------------------|--------------|---------------------------|
| Kernel → shell start | <3 s         | ~2.5 s on Intel NUC       |
| Shell frame rate     | 60 fps       | 60 fps (most animations)  |
| RAM at idle          | <300 MB      | ~220 MB (Qt + Cage + services) |
| ISO size (x86_64)    | <2 GB        | ~1.4 GB                   |
| Install to disk      | <10 min      | ~7 min (SSD)              |
| First-boot setup     | <2 min       | ~1.5 min (if WiFi is fast)|

---

## 14. Security model

ZAIos is a **single-user TV OS** with relaxed security:

- Root account has no password (TV OS — physical access assumed).
- The `zaios` user (uid 1000) runs the shell and most services.
- DBus policy allows `zaios` to talk to all system services.
- Bluetooth, NetworkManager, and audio are accessible without polkit prompts.
- AppArmor is enabled with the default profile (no custom profiles).
- No firewall by default (TV OSes live behind home routers).
- SSH server is **not** installed by default.

For a hardened deployment (e.g. hotel TVs, kiosks), see `docs/HARDENING.md`
(future work).
