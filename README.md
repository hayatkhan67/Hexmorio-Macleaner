# Hexmorio Macleaner

A macOS disk-space and system-cleanup tool by Hexmorio. It scans developer caches, app
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
  directories under `~/projects`.
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
script produces a double-clickable, ad-hoc-signed `.app` under `dist/` with
no Python or browser dependency - `swift build -c release` alone also works
if you just want to run the binary directly.

To package it as a `.dmg` for distribution:

```bash
./package-dmg.sh   # after build.sh; outputs dist/Hexmorio Macleaner.dmg
```

**[`.github/workflows/build-dmg.yml`](.github/workflows/build-dmg.yml)** does
this automatically on every push: it builds the app, packages the dmg, and
uploads it as a workflow artifact. Pushing a tag like `v1.0.0` also attaches
the dmg to a GitHub Release.

The app is only ad-hoc signed (no paid Apple Developer ID), so macOS
Gatekeeper will flag it as from an unidentified developer on first launch.
Right-click the app and choose **Open**, or run
`xattr -cr "Hexmorio Macleaner.app"`, to get past that once.

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
