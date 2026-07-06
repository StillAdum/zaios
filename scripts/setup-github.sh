#!/usr/bin/env bash
###############################################################################
# ZAIos — GitHub repo setup script
###############################################################################
set -euo pipefail

REPO_NAME="${REPO_NAME:-zaios}"
REPO_DESC="ZAIos — a custom TV operating system with Spotify, YouTube, Miracast, and more"

if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI not installed. Install from: https://cli.github.com/"
    echo "On Ubuntu: sudo apt install gh && gh auth login"
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "Not authenticated with GitHub. Run: gh auth login"
    exit 1
fi

cd "$(dirname "$0")/.."

if [[ ! -f build.sh ]]; then
    echo "Error: build.sh not found. Run this from the ZAIos source root."
    exit 1
fi

echo "==> Initializing git repo"
git init -b main 2>/dev/null || git init

echo "==> Adding all files"
git add .

echo "==> Creating initial commit"
if ! git rev-parse HEAD >/dev/null 2>&1; then
    git config user.email "$(gh api user --jq '.email // "you@example.com"')"
    git config user.name  "$(gh api user --jq '.login')"
    git commit -m "Initial commit: ZAIos source

- Custom Linux-based TV OS (from-scratch, LFS-style)
- Qt6/QML glassmorphism shell with D-pad + air mouse + keyboard support
- Spotify (no premium required, Spotube-style + librespot fallback)
- YouTube (yt-dlp + mpv backend)
- Miracast (Wi-Fi Display) receiver
- Bluetooth (BlueZ), Wi-Fi (wpa_supplicant), Pipewire audio
- First-time setup wizard
- Calamares GUI installer for disk install
- Multi-arch: x86_64, ARM64 (Pi 4/5), ARM32 (Pi 2/3)
- GitHub Actions workflow for automated ISO builds"
fi

echo "==> Creating public GitHub repo: $REPO_NAME"
gh repo create "$REPO_NAME" \
    --public \
    --description "$REPO_DESC" \
    --source=. \
    --push \
    --remote=origin

echo ""
echo "==> Repository created: $(gh repo view --json url --jq .url)"
echo ""
echo "==> To trigger a build:"
echo "    Go to: $(gh repo view --json url --jq .url)/actions"
echo "    Click 'Build ZAIos ISO' -> 'Run workflow'"
echo ""
echo "==> Or trigger from CLI:"
echo "    gh workflow run build.yml -f arch=x86_64 -f skip_chromium=true"
echo ""
echo "==> Watch the build:"
echo "    gh run watch"
echo ""
echo "==> Download the ISO when done:"
echo "    gh run list --workflow=build.yml --limit 1"
echo "    gh run download <run-id> -n zaios-x86_64-1.0-iso"
