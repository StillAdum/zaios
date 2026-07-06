# Building ZAIos with GitHub Actions

This guide walks you through setting up GitHub Actions to build ZAIos
automatically. The workflow file is at `.github/workflows/build.yml`.

---

## TL;DR — Quick Start

1. Create a **public** GitHub repo (private repos have limited free minutes)
2. Push your ZAIos source to it:
   ```bash
   cd zaios
   git init
   git add .
   git commit -m "ZAIos initial source"
   git branch -M main
   git remote add origin https://github.com/<your-username>/zaios.git
   git push -u origin main
   ```
3. Go to **https://github.com/<your-username>/zaios/actions**
4. Click **"Build ZAIos ISO"** → **"Run workflow"**
5. Pick arch (`x86_64` recommended for first build)
6. Click **"Run workflow"** green button
7. Wait ~3 hours
8. Click the run → scroll down to **"Artifacts"** → download the ISO

---

## What the workflow does

The workflow is split into 21 steps:

| Step | Purpose | Time |
|------|---------|------|
| 1. Checkout | Pulls your source | ~10 sec |
| 2. Free disk space | Removes pre-installed bloat (~5 GB) | ~30 sec |
| 3. Install deps | apt installs ~2 GB of build tools | ~3 min |
| 4. Verify tools | Sanity check | ~5 sec |
| 5. Cache source tarballs | Reuses `cache/dl/` across runs | ~5 sec |
| 6. Cache extracted sources | Reuses `cache/src/` | ~5 sec |
| 7. Cache Qt6 install | **Big time saver** — skips 2-hour Qt6 build | ~5 sec |
| 8. Skip Chromium | Optional — saves 4 hours | instant |
| 9. Verify build.sh | `bash -n` check | instant |
| 10. Download sources | Fetches Linux, Qt6, etc. | 5–20 min |
| 11. Extract sources | Unpacks tarballs | ~5 min |
| 12. Build kernel | Compiles Linux 6.10.5 | ~20 min |
| 13. Build init | zaios-init + 4 services | ~1 min |
| 14. Build Qt6 + Shell | 2 hours (or 5 min if cached) | ~2 hours |
| 15. Assemble rootfs | Packs squashfs | ~5 min |
| 16. Build initramfs | BusyBox + switch_root | ~1 min |
| 17. Stage Calamares | Copies binary into rootfs | instant |
| 18. Assemble ISO | xorriso + GRUB | ~2 min |
| 19. Verify ISO | Checks it's valid | ~10 sec |
| 20. Boot-test in QEMU | Boots the ISO for 60s | ~1 min |
| 21. Upload artifact | Makes ISO downloadable | ~5 min |

**Total first run:** ~3 hours (with Chromium skipped)
**Total cached run:** ~30 minutes (Qt6 + sources cached)

---

## Triggering a build

### Option A — Manual trigger (workflow_dispatch)

1. Go to the **Actions** tab in your repo
2. Click **"Build ZAIos ISO"** in the left sidebar
3. Click the **"Run workflow"** dropdown (top right)
4. Choose:
   - **arch:** `x86_64` / `arm64` / `arm`
   - **skip_chromium:** `true` (recommended — saves 4 hours)
   - **verbose:** `false` (set to `true` for debugging)
5. Click **"Run workflow"**

### Option B — Push to main

Any push to `main`/`master` that touches `src/`, `rootfs/`, `calamares/`, `build.sh`, or the workflow file itself triggers an automatic x86_64 build.

### Option C — Pull request

Same as push — opens a PR, runs the build, blocks merge on failure.

### Option D — Tag push (creates a Release)

```bash
git tag v1.0
git push origin v1.0
```

This triggers the build AND attaches the ISO to a new GitHub Release.

---

## Cache strategy

GitHub Actions caches persist for 7 days of inactivity, with a 10 GB total
limit per repo. Our cache usage:

| Cache | Size | Key |
|-------|------|-----|
| `cache/dl/` (source tarballs) | ~3 GB | `zaios-dl-v3-<hash of build.sh>` |
| `cache/src/` (extracted) | ~6 GB | `zaios-src-<arch>-<hash of build.sh>` |
| `build/qt-<arch>/` (Qt6 install) | ~2 GB | `zaios-qt-<arch>-v6.7.2-2` |

The Qt6 cache is **the most valuable** — without it, every build takes 3
hours; with it, only 30 min.

If you change `QT_VERSION` in `build.sh`, bump the cache key (e.g.
`v6.7.2-3`) to force a rebuild.

---

## Downloading the ISO

After a successful build:

1. Go to **https://github.com/<you>/zaios/actions**
2. Click the latest successful run
3. Scroll to the bottom → **"Artifacts"** section
4. Click `zaios-x86_64-1.0-iso` (or whatever arch you built)
5. A zip file downloads — extract it to get the `.iso`

**Note:** GitHub caps artifact downloads at 2 GB per file. ZAIos ISOs are
~800 MB so you're fine.

---

## Disk space on the runner

The default `ubuntu-22.04` runner has 14 GB free. Step 2 frees ~5 GB more
by removing .NET, Android SDK, GHC, etc. We need ~25 GB peak (during Qt6
build). If you still run out of space:

```yaml
# Add to step 2:
sudo rm -rf /usr/local/lib/node_modules /opt/az /usr/lib/postgresql
sudo apt-get remove -y --purge \
    azure-cli google-chrome-stable microsoft-edge-stable \
    firefox postgresql* dotnet* \
    || true
```

---

## Common issues

### "Cache size exceeded"

If you see `Cache size exceeded` errors, the repo's total cache hit 10 GB.
Solutions:
- Reduce cache retention (change `retention-days: 14` to `7`)
- Don't cache `cache/src/` (only cache `cache/dl/` and Qt6)
- Delete old caches manually: `gh actions-cache list` + `gh actions-cache delete`

### "Job timeout at 360 minutes"

The default timeout is 6 hours. If you need more (e.g. building with
Chromium on a cold cache), bump `timeout-minutes: 360` to `720`.

### "Qt6 build failed: out of memory"

The runner has 16 GB RAM. If Qt6 still OOMs:
- Reduce parallelism: change `./build.sh ... --target shell` to
  `./build.sh ... --target shell --jobs 2`
- Skip QtWebEngine: set `skip_chromium: true`

### "Cross-compile toolchain not found"

If you're building for `arm64` or `arm`, the workflow installs the cross
toolchain in step 3. If it still fails:
```bash
sudo apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
# OR
sudo apt-get install -y gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf
```

### "xorriso: not found"

Shouldn't happen (step 3 installs it), but if it does:
```bash
sudo apt-get install -y xorriso grub-pc-bin grub-efi-amd64-bin isolinux
```

### "QEMU boot test failed"

The QEMU test in step 20 boots the ISO for 60 seconds then kills it. If
it fails, the workflow still succeeds (it's a soft check). The ISO is
uploaded regardless. To debug, set `verbose: true` in the workflow
trigger.

---

## Branch protection (recommended)

To prevent merging broken code:

1. Settings → Branches → Add rule for `main`
2. Check "Require status checks to pass before merging"
3. Add "Build x86_64 ISO" as a required check
4. Check "Require branches to be up to date before merging"

Now every PR must build successfully before merge.

---

## Multi-arch build matrix

To build all 3 archs in parallel on every push, edit the workflow's
`strategy.matrix`:

```yaml
strategy:
  fail-fast: false
  matrix:
    arch: [x86_64, arm64, arm]
```

This spawns 3 parallel jobs, each producing its own ISO. Total wall-clock
time is the same as a single build (since they run in parallel).

---

## Self-hosted runner (for faster builds)

If you have a beefy machine at home, you can register it as a self-hosted
runner and use it instead of GitHub's:

1. Repo Settings → Actions → Runners → **"Add runner"**
2. Follow the setup commands on your machine
3. In the workflow, change `runs-on: ubuntu-22.04` to
   `runs-on: self-hosted`

Benefits:
- No 6-hour timeout
- Persistent cache (no 10 GB limit)
- Faster builds (use your 16 cores instead of GitHub's 4)
- Can build private repos for free

---

## Cost

GitHub Actions gives you:
- **Public repos:** Unlimited free minutes
- **Private repos:** 2,000 free minutes/month (then $0.008/minute)

ZAIos is open-source-friendly, so use a **public repo** and you'll never
pay a cent.

---

## Example: trigger from CLI

Install the GitHub CLI:
```bash
sudo apt install gh
gh auth login
```

Then trigger a build without leaving the terminal:
```bash
gh workflow run build.yml \
    -f arch=x86_64 \
    -f skip_chromium=true \
    -f verbose=false
```

Watch the run:
```bash
gh run watch
```

Download the ISO when done:
```bash
gh run download <run-id> -n zaios-x86_64-1.0-iso
```
