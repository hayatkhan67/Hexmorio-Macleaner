# Hexmorio Macleaner

A macOS disk-space and system-cleanup tool by [Hexmorio](http://hexmorio.com/). It scans developer caches, app
leftovers, duplicate files, build artifacts, startup items, and more, then
lets you reclaim space with one click. Ships as two independent
implementations of the same feature set:

| | [`server.py`](server.py) + [`index.html`](index.html) | [`StorageOptimizerNative/`](StorageOptimizerNative) |
|---|---|---|
| Runtime | Python 3 stdlib HTTP server + browser tab | Native SwiftUI macOS app |
| Dependencies | Python 3 (no pip packages needed) | Xcode / Swift toolchain to build |
| RAM footprint | A Python process + a browser tab | ~20-50 MB, no browser |
| Menu bar quick actions | No | Yes |
| Best for | Quick use on any Mac with Python 3 | A real, double-clickable app |

Both share the same safety rules (a protected-paths list that refuses to
touch system-critical folders) and the same set of scans.

## Features

- **Dev & System Caches** - Xcode DerivedData, CocoaPods, npm/yarn/pnpm
  caches, pip, Homebrew, Gradle, simulators, and more, rated Safe /
  Rebuildable / Review.
- **Library & Other Folders** - size breakdown of `~/Library` subfolders.
- **All Applications** - every installed `.app` by size.
- **Brew, Pip & CLI Tools** - installed Homebrew formulas, global npm
  packages, and pip packages.
- **Startup & Launch Control** - LaunchAgents/LaunchDaemons, enable/disable.
- **Visual Disk Map** - drill into any folder by size.
- **Project Builds** - `build/`, `.dart_tool/`, `ios/Pods`, and `node_modules`
  directories, auto-detected under common project folders (`~/projects`,
  `~/Developer`, `~/Code`, `~/dev`, `~/workspace`, `~/Documents/projects`, ...).
- **App Leftovers** - Application Support data for apps you've uninstalled.
- **Git Repos** - run `git gc` on repos with bloated `.git` directories.
- **Duplicates** - full-file-hash duplicate finder.
- **Installers** - old `.dmg`/`.pkg` installers in Downloads.
- **Large Files** - find anything over a size threshold.
- **Menu bar widget** (native app only) - quick-clean safe caches, release
  RAM, or flush system caches without opening the main window.
- **RAM release** - reclaims inactive/compressed memory on demand, no
  password required.
- **Weekly auto-clean** - an optional LaunchAgent that runs a safe cleanup
  every Sunday at 3am.
- **Start at login** (native app only) - on by default once installed in
  `/Applications`; toggle it from the header or the menu bar.
- **Built-in updates** (native app only) - checks GitHub Releases daily and
  updates itself in place (or use *Check for Updates…* in the app menu).

## Installing / updating the native app

Run this in Terminal - it installs the latest release into `/Applications`, or
updates an existing copy:

```bash
curl -fsSL https://github.com/hayatkhan67/Hexmorio-Macleaner/releases/latest/download/install.sh | bash
```

After that, the app keeps itself up to date.

**Already have an older copy?** Versions before the built-in updater can't
update themselves, so run the command above once. macOS will ask for
permissions one more time (the new version is signed differently), and then
never again on later updates.

On first launch, click **Open Settings** on the orange banner and enable
**Hexmorio Macleaner** under *Full Disk Access*. That one grant stops macOS
from asking about individual folders. Without it the app skips other apps'
protected data (Containers, Mail, Photos, ...) instead of triggering prompts.

## Running the web version

```bash
python3 server.py
```

Then open `http://127.0.0.1:4820` in your browser. Nothing is installed
outside this folder; the server only binds to `127.0.0.1` and refuses
cross-origin requests.

## Building the native app

```bash
cd StorageOptimizerNative
./build.sh
open "dist/Hexmorio Macleaner.app"
```

This needs Xcode or the Swift toolchain (`swift build`) and macOS 14+. The
script produces a double-clickable `.app` under `dist/` with no Python or
browser dependency.

`build.sh` signs with your first *Developer ID Application* or *Apple
Development* certificate (override with `SIGN_IDENTITY="..."`). A stable
signing identity matters: macOS ties granted permissions to it, so ad-hoc
builds would make users re-grant permissions after every update.

### Publishing a release

```bash
cd StorageOptimizerNative
./release.sh 1.1.0 "What changed in this version"
```

This bumps the version in `Info.plist`, builds a universal (Apple Silicon +
Intel) signed app, and publishes `Hexmorio-Macleaner.zip`, a `.dmg`, and
`install.sh` to GitHub Releases with the `gh` CLI. Installed apps see the new
version within a day. Always release with the same signing certificate. The
in-app updater refuses builds signed by anyone else.

The app isn't notarized, so a `.dmg` downloaded in a browser is flagged by
Gatekeeper on first launch: right-click the app and choose **Open**. The
`install.sh` command and the in-app updater don't have this problem.

## Safety

This tool deletes real files on your Mac. Both implementations share:

- A **protected-paths list** that refuses to operate on system-critical
  directories regardless of what's requested.
- A **Safe / Rebuildable / Review** rating on every cache target - "Review"
  items are never included in one-click/bulk actions.
- Deletions from the Large Files / Duplicates views go to the **Trash**, not
  `rm`.
- System-level cache targets prompt for your admin password explicitly
  (native app) rather than failing silently.

That said: **back up anything you can't afford to lose**, and review what a
target does before cleaning it. There is no warranty - see [LICENSE](LICENSE).

## License

MIT - see [LICENSE](LICENSE).
