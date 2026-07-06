# ZAIos — Installation Guide

How to install ZAIos onto a TV box / mini-PC / Raspberry Pi.

---

## 1. Requirements

### Minimum
- 64-bit x86 PC or ARM device (Pi 4 or newer recommended)
- 2 GB RAM
- 16 GB storage (USB stick, SD card, eMMC, SSD)
- HDMI output
- USB port (for the install media)
- A TV or monitor with HDMI input

### Recommended
- 4 GB+ RAM
- 64 GB+ SSD
- Wi-Fi + Bluetooth built-in (or USB dongles)
- Hardware-accelerated GPU (Intel / AMD / Mali / Adreno)
- Wired Ethernet for initial setup (faster than WiFi)

---

## 2. Create install media

### From the ISO

```bash
# Find your USB stick
lsblk

# Flash (replace /dev/sdX with your device!)
sudo dd if=zaios-x86_64-1.0.iso of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

Or use a GUI tool: Balena Etcher, Popsicle, Rosa Image Writer.

### For Raspberry Pi

Pi 4/5 boot from SD card. Flash the ISO to a high-quality SD card
(SanDisk Extreme, Samsung EVO Plus, ≥32 GB):

```bash
sudo dd if=zaios-arm64-1.0.iso of=/dev/mmcblk0 bs=4M status=progress conv=fsync
sync
```

---

## 3. Boot the live ISO

1. Insert the USB stick (or SD card) into the target device.
2. Power on. Press F12 / F8 / F2 / Esc (depends on manufacturer) to open
   the boot menu.
3. Select the USB device.
4. ZAIos boots into the live environment. After ~10 seconds the
   Setup Wizard appears.

If the device doesn't boot:
- **x86 BIOS**: make sure USB booting is enabled in BIOS settings.
- **x86 UEFI**: disable Secure Boot (ZAIos is signed with a self-signed cert).
- **Pi 4/5**: the Pi firmware expects a specific partition layout; if you
  flashed the ISO via `dd`, it should work. If not, you may need to set
  `BOOT_ORDER` in the Pi EEPROM to try USB/SD first.

---

## 4. First-time setup

The Setup Wizard walks you through:
1. **Welcome** — "Get Started"
2. **Language** — pick your language (defaults to English)
3. **Wi-Fi** — connect to your network (skip if wired Ethernet is connected)
4. **Bluetooth** — pair a remote, headphones, or game controller (optional)
5. **Spotify account** — optional; sign in for Premium-quality playback,
   or skip and use Spotube (free, YouTube-backed)
6. **Device name** — what shows up on the network (default: `zaios`)
7. **Timezone** — for the clock
8. **Complete** — ZAIos Home screen appears

---

## 5. Install to disk (permanent)

The live session runs entirely in RAM. To install ZAIos permanently:

### Method A: From the live session (recommended)
1. Open the home screen.
2. Go to **Settings → All Apps → Terminal** (or press `Ctrl+Alt+F2` for
   a TTY).
3. Run `sudo calamares` (or just `calamares` — the live session's `zaios`
   user has sudo).
4. The Calamares GUI installer launches.
5. Follow the wizard:
   - **Welcome** — confirm language
   - **Location** — pick timezone
   - **Keyboard** — pick layout
   - **Partitioning** — choose:
     - **Erase disk** (recommended) — wipes the target disk
     - **Manual** — for advanced users
   - **Users** — pick a username (default `zaios`, no password)
6. Click **Install**. Wait ~10 minutes.
7. Reboot. Remove the USB stick when prompted.
8. ZAIos boots from the internal disk.

### Method B: From another OS (advanced)
If the target device already runs another OS, you can install ZAIos
alongside it (dual-boot) using Calamares' manual partitioner. Reserve at
least 16 GB for ZAIos.

---

## 6. Post-install configuration

After the first boot from disk:

### Update apps
ZAIos doesn't have a package manager by default. To install new apps:
1. Download the source tarball.
2. Build it on another machine.
3. Copy the binaries to `/usr/bin/` on the ZAIos device (via USB or scp
   over SSH).

For package management, you can install `pacman` (Arch-style) or `apt`
(Debian-style) — but this is advanced. Most users won't need it.

### Enable SSH (optional, useful for development)
```bash
# On ZAIos (after install):
sudo apt install openssh-server   # if apt is available
sudo systemctl enable ssh         # if systemd is installed
# OR install dropbear (lighter):
sudo apt install dropbear
```

By default ZAIos does not include SSH — install it manually if you need
remote shell access.

### Cast from your phone
1. Open **Cast** app on ZAIos.
2. Click **Start Receiver**.
3. On Android: open any cast-enabled app, select "ZAIos" from the cast menu.
4. On Windows: open Project → Connect to wireless display → select "ZAIos".

---

## 7. Troubleshooting

### Won't boot from USB
- Try a different USB port (prefer USB 2.0 over USB 3.0 for compatibility).
- Re-flash the USB stick (sometimes the dd was incomplete).
- Disable Secure Boot / Fast Boot in BIOS.
- Try a different USB stick (some cheap ones don't boot reliably).

### Black screen after GRUB
- The kernel might not support your GPU. Try `nomodeset` kernel param
  (edit GRUB entry, append `nomodeset`).
- Connect to a TTY (`Ctrl+Alt+F2`) and check `dmesg | grep -i drm`.

### No Wi-Fi networks visible
- Your Wi-Fi adapter might need firmware blobs. Run `dmesg | grep firmware`
  to see what's missing.
- Manually copy firmware files to `/lib/firmware/` and reboot.

### No sound
- Check that Pipewire is running: `pgrep pipewire`.
- Check available sinks: `pactl list short sinks`.
- Try `pactl set-default-sink <sink-name>`.

### Bluetooth won't pair
- Check that bluetoothd is running: `pgrep bluetoothd`.
- Check `rfkill list bluetooth` — make sure it's not soft-blocked.
- Try `bluetoothctl` → `power on` → `scan on` → `pair <mac>`.

### Cursor invisible / D-pad not working
- Press a key on the remote — the InputBridge should pick it up.
- If nothing happens, check `dmesg | grep -i input` to see if evdev
  registered your remote.
- Try plugging the remote's USB dongle into a different port.

---

## 8. Uninstalling ZAIos

To remove ZAIos and reinstall another OS:
1. Boot from a Linux live USB (Ubuntu, Arch, etc.).
2. Use `gparted` or `fdisk` to delete the ZAIos partitions.
3. Reformat the disk and install the new OS.

ZAIos doesn't install a custom bootloader that's hard to remove — it
uses standard GRUB, which any other Linux installer will overwrite.

---

## 9. Dual-booting ZAIos with Windows

Yes, this is possible (x86_64 only):

1. In Windows, shrink your C: drive by 32+ GB.
2. Boot the ZAIos USB.
3. In Calamares, choose **Manual partitioning**.
4. Create a new partition in the unallocated space:
   - 512 MB, FAT32, mount `/boot`, flags `[boot, esp]`
   - The rest, ext4, mount `/`
5. Install GRUB to the new ESP (not the Windows ESP).
6. ZAIos will detect Windows and add it to the GRUB menu automatically.

For UEFI systems, you may need to set ZAIos's GRUB as the default boot
entry in your firmware's boot order.

---

## 10. Recovery mode

If ZAIos won't boot after an update:
1. Boot from the ZAIos install USB.
2. In the GRUB menu, press `e` to edit the default entry.
3. Append `init=/bin/sh` to the linux line.
4. Press `Ctrl+X` to boot.
5. You'll get a root shell on the installed system.
6. Fix whatever's broken:
   ```sh
   mount -o remount,rw /
   # edit /etc/zaios/zaios.conf or /etc/default/grub
   sync
   reboot
   ```

---

## 11. Updating ZAIos

Currently there's no auto-updater. To update:
1. Re-run the build on your build machine with newer source.
2. Generate a new ISO.
3. Reinstall (or use rsync to update just the changed files).

A future `zaios-update` tool is planned (see `docs/ROADMAP.md`).
