# Changelog

All notable changes to Hexmorio Macleaner are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-11-27

### Added
- **Built-in updates** - the app checks GitHub Releases once a day and shows an
  "Update Now" banner (also in the menu bar). Updates install in place and
  relaunch the app. Only builds signed by the same developer are accepted.
  *Check for Updates…* is available in the app menu.
- **One-line install / update command** for users:
  `curl -fsSL https://github.com/hayatkhan67/Hexmorio-Macleaner/releases/latest/download/install.sh | bash`
- **Start at login** - turned on automatically the first time the app runs
  from `/Applications`; toggle it from the header or the menu bar.
- **Full Disk Access banner** - one-click shortcut to grant Full Disk Access,
  which stops macOS from asking about individual folders.
- **`release.sh`** - builds a universal (Apple Silicon + Intel) signed app and
  publishes the zip, dmg, and `install.sh` to GitHub Releases.
- **hexmorio.com branding** - a permanent link in the main window, the menu
  bar popover, and the About box.
- **What's New** - after an update, the app shows the highlights of the new
  version once. Open it again any time with *What's New…* in the app menu or
  from the menu bar popover.
- **Background storage monitor** - checks free disk space every 30 seconds and
  rescans project builds and caches when it changes by 250 MB or more (at most
  every 3 minutes) or every 10 minutes. Shows a one-time warning with the
  reclaimable total when the disk is 90% full.
- **More build artifacts in Project Builds** - `node_modules`, `.dart_tool`,
  `Pods`, `.next`, `.nuxt`, `.turbo`, `.parcel-cache`, `.angular`,
  `.svelte-kit`, project `.gradle`, `DerivedData`, `.venv` / `venv`,
  `__pycache__`, `.pytest_cache`, `CMakeFiles`, and `build`, `.build`, `dist`,
  `target` with labels per tool (Flutter, Gradle, CMake, Rust, Maven, ...).
- **New clean targets** - Xcode Documentation Cache and Gradle Wrapper
  Distributions.
- **Uninstall buttons** - move apps to the Trash, and uninstall Homebrew
  formulas and global npm packages, from the Apps and Packages tabs.
- **System startup items** - items in `/Library/LaunchAgents` and
  `/Library/LaunchDaemons` can now be turned on and off (asks for the
  administrator password).
- **Library purge for more folders** - Application Support folders and tool
  folders in your home (e.g. `~/.nvm`, `~/.pyenv`) can be purged. Their
  contents go to the Trash. Known caches (`~/.npm`, `~/.pub-cache`, `~/.cache`,
  ...) are deleted directly. Folders with keys or settings (`~/.ssh`, `~/.kube`,
  `~/.docker`, `~/.android`, ...) can't be purged.
- Installers tab finds `.ipa`, `.aab`, and `.xip` files.

### Changed
- Builds are now signed with a stable certificate (Developer ID or Apple
  Development) instead of ad-hoc, so granted permissions survive updates.
  Override the certificate with `SIGN_IDENTITY`.
- Project Builds, Git Repos, Large Files, and Installers now search your whole
  home folder and connected external drives (up to 7 levels deep), so projects
  are found wherever you keep them. Library, Trash, media folders, and global
  tool caches are skipped.
- `build`, `.build`, `dist`, and `target` folders are only listed when the
  folder above them belongs to a tool that creates them, and never when git
  tracks files inside them, so source folders with these names are left alone.
- Project build, git, and leftover sizes are measured natively in parallel, so
  multi-GB build folders are no longer dropped by a timeout.
- Folder size measurement allows up to 20 seconds per folder and falls back to
  a native count, so large folders (e.g. the Android SDK) aren't reported as
  empty.
- **Rescan** now clears cached sizes and refreshes every tab already loaded.
  Cached sizes expire after 5 minutes instead of 15.
- App Leftovers matches apps by name and bundle identifier and also checks
  Caches, Containers, and Saved Application State.
- Large Files, Installers, and Duplicates look inside subfolders, not only at
  the top level of Downloads/Desktop.
- `/Library/Caches` and `/Library/Logs` moved from Safe to Review, so 1-Click
  Optimize no longer asks for a password. Selecting several admin targets asks
  for the password once.
- The iOS Simulators target now measures `CoreSimulator/Devices`, where the
  simulator data actually lives.
- Release RAM uses up to 65% of RAM (max 8 GB) and reports free RAM before and
  after.
- Closing the main window removes the Dock icon; the menu bar item keeps
  running until you quit.

### Fixed
- Repeated permission prompts: without Full Disk Access, scans now skip other
  apps' protected data (Containers, Mail, Photos, Contacts, Calendars, ...)
  instead of triggering macOS prompts on every scan.
- Full Disk Access was never detected on macOS 27, so the banner stayed up and
  protected folders were skipped even after granting it.
- Projects weren't detected on Macs that keep them outside `~/projects`.
- Project Builds, Git Repos, and Large Files listed everything twice when
  `~/projects` and `~/Projects` (the same folder on case-insensitive disks)
  were both checked.
- Project Builds now labels sub-apps with their parent (e.g. `shop_app/admin`)
  so different projects' folders with the same name no longer look duplicated.
- Weekly Auto-Clean pointed at a script that only existed on the developer's
  Mac. It now runs the app itself in a headless `--auto-clean` mode, and
  existing schedules are repaired automatically on launch.
- Removed hardcoded folder sizes from the developer's Mac that other Macs
  displayed for the first 15 minutes.
- Folder sizes were discarded whenever a single subfolder was unreadable.
- The largest project build folders disappeared from Project Builds because
  measuring them took longer than 2 seconds.
- **Rescan** kept showing old or 0 B sizes for up to 15 minutes.
- Running a tool with a lot of output could hang the app.
- Cleaning without Full Disk Access triggered repeated "access data from other
  apps" prompts on Apple cache folders.
- The clean result said "successfully" even when the administrator password
  prompt was cancelled.

### Removed
- GitHub Actions build workflow - releases are now published locally with
  `release.sh`.

### Upgrade notes
- Copies older than 1.1.0 have no updater: run the install command above once.
  macOS asks for permissions one more time because the signing changed, then
  never again on later updates.

## [1.0.0] - 2026-11-14

### Added
- Native SwiftUI macOS app with menu bar quick actions.
- Python + browser version (`server.py` / `index.html`).
- Scans for dev and system caches, `~/Library` folders, applications,
  Homebrew/pip/npm packages, startup items, a visual disk map, project builds,
  app leftovers, git repos, duplicates, installers, and large files.
- RAM release, system cache flush, and optional weekly auto-clean.
- Rebranded as Hexmorio Macleaner.
