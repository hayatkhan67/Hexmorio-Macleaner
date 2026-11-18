# Changelog

All notable changes to Hexmorio Macleaner are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).

## [1.1.0] - Unreleased

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

### Changed
- Builds are now signed with a stable certificate (Developer ID or Apple
  Development) instead of ad-hoc, so granted permissions survive updates.
  Override the certificate with `SIGN_IDENTITY`.
- Project Builds, Git Repos, and Large Files now auto-detect common project
  folders (`~/projects`, `~/Developer`, `~/Code`, `~/dev`, `~/workspace`,
  `~/Documents/projects`, ...) instead of only `~/projects`.
- Folder size measurement allows up to 10 seconds per folder so large folders
  (e.g. the Android SDK) aren't reported as empty.

### Fixed
- Repeated permission prompts: without Full Disk Access, scans now skip other
  apps' protected data (Containers, Mail, Photos, Contacts, Calendars, ...)
  instead of triggering macOS prompts on every scan.
- Projects weren't detected on Macs that keep them outside `~/projects`.
- Weekly Auto-Clean pointed at a script that only existed on the developer's
  Mac. It now runs the app itself in a headless `--auto-clean` mode, and
  existing schedules are repaired automatically on launch.
- Removed hardcoded folder sizes from the developer's Mac that other Macs
  displayed for the first 15 minutes.
- Folder sizes were discarded whenever a single subfolder was unreadable.

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
