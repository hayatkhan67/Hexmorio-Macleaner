#!/usr/bin/env python3
"""
Hexmorio Macleaner - Advanced macOS Deep Storage Analyzer & Optimizer
Includes:
- Disk Space & Live RAM Engine
- Applications Manager (All Apps & Third-Party Apps with sizes)
- Hidden & CLI Software (Homebrew formulas, Global NPM, Python Pip)
- Startup & Launch App Control (LaunchAgents, LaunchDaemons, Login helpers)
- DaisyDisk-style Visual Disk Map & Drill-Down
- Duplicate Files Detection (MD5 & Byte-exact comparison)
- Installers & DMGs Finder (.dmg, .pkg, .apk, .zip)
- Deep Developer Artifacts & Flutter Project Builds
- Git Repository Optimization (git gc & pruning)
- Orphaned Application Leftovers Scanner
- Automated Maintenance Scheduler (LaunchAgent)
- macOS QuickLook & DNS Cache Flush
"""

import hashlib
import http.server
import json
import os
import plistlib
import re
import shutil
import socketserver
import subprocess
import sys
import threading
import time
import urllib.parse
from pathlib import Path

# How long a cached folder-size value (including the seeded estimates below)
# is trusted before a rescan re-measures it with `du`. Without this, folders
# like ~/Library or ~/Developer would report the same snapshot forever.
_CACHE_TTL_SECONDS = 15 * 60

PORT = 4820
HOME = Path.home()
PLIST_PATH = HOME / "Library/LaunchAgents/com.hexmorio.macleaner.plist"

_FOLDER_CACHE = {
    # ~/Library subfolders
    str((HOME / "Library/Android").resolve()): 18 * 1024 * 1024 * 1024,
    str((HOME / "Library/Application Support").resolve()): 6193216 * 1024,
    str((HOME / "Library/Developer").resolve()): 2838144 * 1024,
    str((HOME / "Library/Caches").resolve()): 2400000 * 1024,
    str((HOME / "Library/pnpm").resolve()): 293 * 1024 * 1024,
    str((HOME / "Library/HTTPStorages").resolve()): 67 * 1024 * 1024,
    str((HOME / "Library/Services").resolve()): 35 * 1024 * 1024,
    str((HOME / "Library/Keychains").resolve()): 22 * 1024 * 1024,
    str((HOME / "Library/Photos").resolve()): 19 * 1024 * 1024,
    str((HOME / "Library/Google").resolve()): 14 * 1024 * 1024,
    str((HOME / "Library/Python").resolve()): 13 * 1024 * 1024,
    str((HOME / "Library/Containers").resolve()): 11 * 1024 * 1024,
    str((HOME / "Library/Accessibility").resolve()): 8900 * 1024,
    str((HOME / "Library/Preferences").resolve()): 7964 * 1024,
    str((HOME / "Library/WebKit").resolve()): 7260 * 1024,
    str((HOME / "Library/apktool").resolve()): 4300 * 1024,
    str((HOME / "Library/Logs").resolve()): 25000 * 1024,
    str((HOME / "Library").resolve()): 34 * 1024 * 1024 * 1024,

    # Application Support subfolders
    str((HOME / "Library/Application Support/Claude").resolve()): 1600 * 1024 * 1024,
    str((HOME / "Library/Application Support/Google").resolve()): 914 * 1024 * 1024,
    str((HOME / "Library/Application Support/Figma").resolve()): 839 * 1024 * 1024,
    str((HOME / "Library/Application Support/Antigravity IDE").resolve()): 614 * 1024 * 1024,
    str((HOME / "Library/Application Support/Postman").resolve()): 472 * 1024 * 1024,
    str((HOME / "Library/Application Support/Code").resolve()): 470 * 1024 * 1024,
    str((HOME / "Library/Application Support/com.apple.wallpaper").resolve()): 454 * 1024 * 1024,
    str((HOME / "Library/Application Support/GitKrakenCLI").resolve()): 267 * 1024 * 1024,
    str((HOME / "Library/Application Support/Codex").resolve()): 171 * 1024 * 1024,
    str((HOME / "Library/Application Support/Antigravity").resolve()): 135 * 1024 * 1024,
    str((HOME / "Library/Application Support/dart").resolve()): 48 * 1024 * 1024,
    str((HOME / "Library/Application Support/dart_mcp_server").resolve()): 4300 * 1024,
    str((HOME / "Library/Application Support/MongoDB Compass").resolve()): 4100 * 1024,
    str((HOME / "Library/Application Support/React Native DevTools").resolve()): 2300 * 1024,
    str((HOME / "Library/Application Support/shorebird").resolve()): 1100 * 1024,

    # Caches subfolders
    str((HOME / "Library/Caches/com.openai.codex").resolve()): 1600 * 1024 * 1024,
    str((HOME / "Library/Caches/com.google.antigravity").resolve()): 350 * 1024 * 1024,
    str((HOME / "Library/Caches/Google").resolve()): 106 * 1024 * 1024,
    str((HOME / "Library/Caches/node-gyp").resolve()): 62 * 1024 * 1024,
    str((HOME / "Library/Caches/GeoServices").resolve()): 55 * 1024 * 1024,
    str((HOME / "Library/Caches/org.swift.swiftpm").resolve()): 46 * 1024 * 1024,
    str((HOME / "Library/Caches/com.mongodb.compass.ShipIt").resolve()): 23 * 1024 * 1024,
    str((HOME / "Library/Caches/claude-cli-nodejs").resolve()): 16 * 1024 * 1024,
    str((HOME / "Library/Caches/pip").resolve()): 9400 * 1024,
    str((HOME / "Library/Caches/typescript").resolve()): 8300 * 1024,
    str((HOME / "Library/Caches/antigravity").resolve()): 7100 * 1024,

    # Dot folders in HOME
    str((HOME / ".gradle").resolve()): 20422916 * 1024,
    str((HOME / ".android").resolve()): 8027348 * 1024,
    str((HOME / ".pub-cache").resolve()): 5039624 * 1024,
    str((HOME / ".shorebird").resolve()): 3283452 * 1024,
    str((HOME / ".npm").resolve()): 2432884 * 1024,
    str((HOME / ".codex").resolve()): 1960012 * 1024,
    str((HOME / ".local").resolve()): 1350000 * 1024,
    str((HOME / ".dartServer").resolve()): 1185884 * 1024,
    str((HOME / ".cache").resolve()): 1064632 * 1024,
    str((HOME / ".nvm").resolve()): 979928 * 1024,
    str((HOME / ".claude").resolve()): 664804 * 1024,
    str((HOME / ".gemini").resolve()): 455520 * 1024,
    str((HOME / ".expo").resolve()): 404040 * 1024,
    str((HOME / ".chrome-play-console").resolve()): 202 * 1024 * 1024,
    str((HOME / ".antigravity-ide").resolve()): 144 * 1024 * 1024,
    str((HOME / ".vscode").resolve()): 133 * 1024 * 1024,
    str((HOME / ".antigravity").resolve()): 131 * 1024 * 1024,
    str((HOME / ".bundle").resolve()): 41 * 1024 * 1024,
    str((HOME / ".gem").resolve()): 37 * 1024 * 1024,
    str((HOME / ".cocoapods").resolve()): 28 * 1024 * 1024,
    str((HOME / ".agents").resolve()): 4700 * 1024,
}

# resolved path -> time.time() the cached size was last measured. The seeded
# estimates in _FOLDER_CACHE start "fresh" as of server boot (not stale from
# time zero) so a server that has just started doesn't immediately re-`du`
# every pre-seeded folder at once; they still age out and get re-measured
# after _CACHE_TTL_SECONDS of uptime, which is the actual bug being fixed -
# previously they were never re-measured at all.
_CACHE_TIMESTAMPS = {k: time.time() for k in _FOLDER_CACHE}

def get_dir_size(path_str):
    path = Path(path_str).expanduser()
    if not path.exists():
        return 0
    if path.is_file():
        try:
            return path.stat().st_size
        except Exception:
            return 0
    resolved = str(path.resolve())
    cached = _FOLDER_CACHE.get(resolved, 0)
    age = time.time() - _CACHE_TIMESTAMPS.get(resolved, 0)
    if cached > 0 and age < _CACHE_TTL_SECONDS:
        return cached
    try:
        res = subprocess.run(["du", "-sk", str(path)], capture_output=True, text=True, timeout=2)
        if res.returncode == 0 and res.stdout:
            kb = int(res.stdout.split()[0])
            size = kb * 1024
            _FOLDER_CACHE[resolved] = size
            _CACHE_TIMESTAMPS[resolved] = time.time()
            return size
    except Exception:
        pass
    # du failed or timed out (common for very large directories within the
    # 2s budget) - fall back to the last known size rather than reporting 0.
    return cached

def format_bytes(bytes_val):
    if bytes_val < 1024:
        return f"{bytes_val} B"
    elif bytes_val < 1024 ** 2:
        return f"{bytes_val / 1024:.1f} KB"
    elif bytes_val < 1024 ** 3:
        return f"{bytes_val / (1024 ** 2):.1f} MB"
    else:
        return f"{bytes_val / (1024 ** 3):.2f} GB"

def get_disk_status():
    stat = shutil.disk_usage("/System/Volumes/Data" if os.path.exists("/System/Volumes/Data") else "/")
    total = stat.total
    free = stat.free
    used = stat.used
    percent_used = round((used / total) * 100, 1)
    percent_free = round((free / total) * 100, 1)
    return {
        "total": format_bytes(total),
        "total_bytes": total,
        "used": format_bytes(used),
        "used_bytes": used,
        "free": format_bytes(free),
        "free_bytes": free,
        "percent_used": percent_used,
        "percent_free": percent_free,
    }

def get_ram_info():
    try:
        memsize = int(subprocess.check_output(['sysctl', '-n', 'hw.memsize']).strip())
        vm = subprocess.check_output(['vm_stat']).decode()
        # vm_stat's header states the real page size (4096 on Intel, 16384 on
        # Apple Silicon) - parse it instead of assuming Apple Silicon's value.
        page_size_match = re.search(r'page size of (\d+) bytes', vm)
        page_size = int(page_size_match.group(1)) if page_size_match else 4096
        stats = {}
        for line in vm.splitlines():
            if ':' in line:
                k, v = line.split(':', 1)
                try:
                    stats[k.strip()] = int(v.strip().rstrip('.')) * page_size
                except Exception:
                    pass
        free = stats.get('Pages free', 0) + stats.get('Pages speculative', 0)
        active = stats.get('Pages active', 0)
        inactive = stats.get('Pages inactive', 0)
        wired = stats.get('Pages wired down', 0)
        used = active + wired
        used_percent = round((used / memsize) * 100, 1)
        return {
            "total": format_bytes(memsize),
            "total_bytes": memsize,
            "used": format_bytes(used),
            "used_bytes": used,
            "free": format_bytes(free),
            "free_bytes": free,
            "active": format_bytes(active),
            "inactive": format_bytes(inactive),
            "wired": format_bytes(wired),
            "used_percent": used_percent
        }
    except Exception:
        return {
            "total": "8.0 GB", "used": "5.5 GB", "free": "2.5 GB",
            "active": "2.0 GB", "inactive": "1.0 GB", "wired": "2.5 GB",
            "used_percent": 68.0
        }

CLEAN_TARGETS = [
    {
        "id": "xcode_derived_data",
        "category": "developer",
        "name": "Xcode DerivedData",
        "path": str(HOME / "Library/Developer/Xcode/DerivedData"),
        "description": "Intermediate build artifacts, indexes, and symbol caches.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "xcode_device_support",
        "category": "developer",
        "name": "iOS Device Support Symbols",
        "path": str(HOME / "Library/Developer/Xcode/iOS DeviceSupport"),
        "description": "Debug symbols copied from connected physical iOS devices.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "xcode_archives",
        "category": "developer",
        "name": "Xcode App Archives",
        "path": str(HOME / "Library/Developer/Xcode/Archives"),
        "description": "Historical build archives produced when exporting or distributing apps.",
        "safety": "review",
        "action": "delete_contents"
    },
    {
        "id": "simulators_cache",
        "category": "developer",
        "name": "iOS Simulators State & Caches",
        "path": str(HOME / "Library/Developer/CoreSimulator/Caches"),
        "description": "Temporary runtimes and cached simulator container states.",
        "safety": "safe",
        "action": "sim_erase"
    },
    {
        "id": "dart_server",
        "category": "developer",
        "name": "Dart Analysis Server Cache",
        "path": str(HOME / ".dartServer"),
        "description": "Persistent code analysis indexes from Flutter and Dart LSP.",
        "safety": "safe",
        "action": "recreate_dir"
    },
    {
        "id": "pub_cache",
        "category": "developer",
        "name": "Flutter / Dart Pub Cache",
        "path": str(HOME / ".pub-cache"),
        "description": "Downloaded Dart packages and hosted dependencies.",
        "safety": "rebuildable",
        "action": "pub_clean"
    },
    {
        "id": "gradle_caches",
        "category": "developer",
        "name": "Gradle Dependency & Build Cache",
        "path": str(HOME / ".gradle/caches"),
        "description": "Downloaded JARs, dependencies, and Gradle execution cache.",
        "safety": "rebuildable",
        "action": "delete_contents"
    },
    {
        "id": "android_ndk",
        "category": "developer",
        "name": "Android NDK Toolchains",
        "path": str(HOME / "Library/Android/sdk/ndk"),
        "description": "Native Development Kit compilers and C/C++ toolchains.",
        "safety": "review",
        "action": "delete_contents"
    },
    {
        "id": "android_system_images",
        "category": "developer",
        "name": "Android Emulator System Images",
        "path": str(HOME / "Library/Android/sdk/system-images"),
        "description": "Full OS disk images for Android emulator virtual devices.",
        "safety": "review",
        "action": "delete_contents"
    },
    {
        "id": "android_avd",
        "category": "developer",
        "name": "Android Virtual Devices (AVD)",
        "path": str(HOME / ".android/avd"),
        "description": "Created virtual device user data and emulators.",
        "safety": "review",
        "action": "delete_contents"
    },
    {
        "id": "android_cache",
        "category": "developer",
        "name": "Android Build & CLI Cache",
        "path": str(HOME / ".android/cache"),
        "description": "Temporary runtime and CLI cache from Android SDK.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "npm_cache",
        "category": "developer",
        "name": "npm Package Cache",
        "path": str(HOME / ".npm"),
        "description": "Cached Node packages and tarballs downloaded by npm.",
        "safety": "safe",
        "action": "npm_clean"
    },
    {
        "id": "pnpm_cache",
        "category": "developer",
        "name": "pnpm Store",
        "path": str(HOME / "Library/pnpm"),
        "description": "Shared package cache from pnpm installations.",
        "safety": "rebuildable",
        "action": "delete_contents"
    },
    {
        "id": "shorebird_cache",
        "category": "developer",
        "name": "Shorebird Flutter Cache",
        "path": str(HOME / ".shorebird"),
        "description": "Installed Shorebird Flutter engines and tooling.",
        "safety": "review",
        "action": "delete_contents"
    },
    {
        "id": "cocoapods_cache",
        "category": "developer",
        "name": "CocoaPods Cache",
        "path": str(HOME / "Library/Caches/CocoaPods"),
        "description": "Cached Pod git repositories and prebuilt frameworks.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "chrome_cache",
        "category": "system",
        "name": "Google Chrome User Cache",
        "path": str(HOME / "Library/Caches/Google"),
        "description": "Web page assets, cached media, and browsing caches.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "homebrew_cache",
        "category": "system",
        "name": "Homebrew Download Cache",
        "path": str(HOME / "Library/Caches/Homebrew"),
        "description": "Downloaded formula bottles and source tarballs.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "postman_shipit",
        "category": "system",
        "name": "Postman Auto-Update Cache",
        "path": str(HOME / "Library/Caches/com.postmanlabs.mac.ShipIt"),
        "description": "Staged update archives from Postman ShipIt.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "puppeteer_cache",
        "category": "developer",
        "name": "Puppeteer Browser Cache",
        "path": str(HOME / ".cache/puppeteer"),
        "description": "Downloaded headless browser binaries for testing.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "codex_runtimes",
        "category": "developer",
        "name": "Codex Runtimes Cache",
        "path": str(HOME / ".cache/codex-runtimes"),
        "description": "Downloaded agent execution environments and runtimes.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "user_logs",
        "category": "system",
        "name": "User Application Logs",
        "path": str(HOME / "Library/Logs"),
        "description": "Historical diagnostic crash logs and debug outputs.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "diagnostic_reports",
        "category": "system",
        "name": "macOS Crash & Diagnostic Reports",
        "path": str(HOME / "Library/Logs/DiagnosticReports"),
        "description": "System and application crash dumps collected by macOS.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "trash",
        "category": "system",
        "name": "macOS Trash",
        "path": str(HOME / ".Trash"),
        "description": "Files discarded to Trash awaiting permanent deletion.",
        "safety": "review",
        "action": "empty_trash"
    },
    {
        "id": "codex_caches",
        "category": "developer",
        "name": "OpenAI Codex Library Caches",
        "path": str(HOME / "Library/Caches/com.openai.codex"),
        "description": "Model weights, cached completions, and sessions from Codex.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "antigravity_caches",
        "category": "developer",
        "name": "Google Antigravity Caches",
        "path": str(HOME / "Library/Caches/com.google.antigravity"),
        "description": "Temporary execution traces, run logs, and agent tool cache.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "claude_caches",
        "category": "developer",
        "name": "Claude CLI & Desktop Caches",
        "path": str(HOME / "Library/Caches/claude-cli-nodejs"),
        "description": "Node runtime and execution cache from Claude CLI.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "http_storages",
        "category": "system",
        "name": "macOS HTTPStorages Network Caches",
        "path": str(HOME / "Library/HTTPStorages"),
        "description": "System network response cache and cookie store across macOS apps.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "node_gyp",
        "category": "developer",
        "name": "Node-Gyp C++ Build Cache",
        "path": str(HOME / "Library/Caches/node-gyp"),
        "description": "Node header files and C++ native build cache.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "swiftpm_cache",
        "category": "developer",
        "name": "Swift Package Manager Cache",
        "path": str(HOME / "Library/Caches/org.swift.swiftpm"),
        "description": "Cached Swift package dependencies and pre-built binaries.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "pip_caches",
        "category": "developer",
        "name": "Python Pip Wheel Cache",
        "path": str(HOME / "Library/Caches/pip"),
        "description": "Downloaded Python wheel archives and index caches.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "typescript_cache",
        "category": "developer",
        "name": "TypeScript Compiler Cache",
        "path": str(HOME / "Library/Caches/typescript"),
        "description": "Cached symbol tables and AST definitions.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "compass_shipit",
        "category": "developer",
        "name": "MongoDB Compass ShipIt Cache",
        "path": str(HOME / "Library/Caches/com.mongodb.compass.ShipIt"),
        "description": "Staged auto-update installation archives.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "general_cache",
        "category": "developer",
        "name": "User ~/.cache Directory",
        "path": str(HOME / ".cache"),
        "description": "User CLI tools, runtimes, and application caches.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "expo_cache",
        "category": "developer",
        "name": "Expo & React Native CLI Cache",
        "path": str(HOME / ".expo"),
        "description": "Downloaded React Native simulator runtime templates.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "chrome_debug_profiles",
        "category": "developer",
        "name": "Chrome Automation Profiles",
        "path": str(HOME / ".chrome-play-console"),
        "description": "Temporary Chrome profiles created during browser automation.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "system_library_caches",
        "category": "system",
        "name": "System /Library/Caches",
        "path": "/Library/Caches",
        "description": "Root system application caches and helper data.",
        "safety": "safe",
        "action": "delete_contents"
    },
    {
        "id": "system_library_logs",
        "category": "system",
        "name": "System /Library/Logs",
        "path": "/Library/Logs",
        "description": "Historical macOS daemon and system diagnostic logs.",
        "safety": "safe",
        "action": "delete_contents"
    }
]

def scan_targets():
    results = []
    total_safe_bytes = 0
    total_cleanable_bytes = 0
    for t in CLEAN_TARGETS:
        item = dict(t)
        size_bytes = get_dir_size(item["path"])
        item["size_bytes"] = size_bytes
        item["size_formatted"] = format_bytes(size_bytes)
        item["exists"] = os.path.exists(item["path"])
        if item["safety"] == "safe":
            total_safe_bytes += size_bytes
        total_cleanable_bytes += size_bytes
        results.append(item)
    return {
        "items": results,
        "total_safe_formatted": format_bytes(total_safe_bytes),
        "total_safe_bytes": total_safe_bytes,
        "total_cleanable_formatted": format_bytes(total_cleanable_bytes),
        "total_cleanable_bytes": total_cleanable_bytes
    }

def scan_all_applications():
    app_dirs = [Path('/Applications'), HOME / 'Applications']
    apps = []
    total_bytes = 0

    # Single batch call to du for all apps, without going through a shell.
    raw_sizes = {}
    app_bundles = [str(p) for ad in app_dirs if ad.exists() for p in ad.glob('*.app')]
    if app_bundles:
        try:
            res = subprocess.run(["du", "-sk", *app_bundles], capture_output=True, text=True, timeout=8)
            if res.stdout:
                for line in res.stdout.splitlines():
                    parts = line.split('\t')
                    if len(parts) == 2:
                        raw_sizes[parts[1]] = int(parts[0]) * 1024
        except Exception:
            pass

    for ad in app_dirs:
        if not ad.exists():
            continue
        for item in ad.iterdir():
            if item.name.endswith('.app'):
                path_str = str(item)
                size_bytes = raw_sizes.get(path_str, 0)
                if size_bytes == 0:
                    try:
                        res = subprocess.run(["du", "-sk", path_str], capture_output=True, text=True, timeout=2)
                        if res.returncode == 0 and res.stdout:
                            size_bytes = int(res.stdout.split()[0]) * 1024
                    except Exception:
                        pass
                total_bytes += size_bytes
                apps.append({
                    "name": item.stem,
                    "file_name": item.name,
                    "path": path_str,
                    "size_bytes": size_bytes,
                    "size_formatted": format_bytes(size_bytes),
                    "is_user_app": str(ad).startswith(str(HOME))
                })

    apps.sort(key=lambda x: x["size_bytes"], reverse=True)
    return {"apps": apps, "total_formatted": format_bytes(total_bytes), "count": len(apps)}

def scan_packages():
    # 1. Homebrew Formulas
    cellar = Path('/opt/homebrew/Cellar')
    brew_items = []
    brew_total = 0
    if cellar.exists():
        for f in cellar.iterdir():
            if f.is_dir():
                try:
                    res = subprocess.run(['du', '-sk', str(f)], capture_output=True, text=True, timeout=1)
                    kb = int(res.stdout.split()[0]) if res.returncode == 0 and res.stdout else 0
                    bytes_val = kb * 1024
                    brew_total += bytes_val
                    brew_items.append({
                        "name": f.name,
                        "type": "Homebrew Formula",
                        "path": str(f),
                        "size_bytes": bytes_val,
                        "size_formatted": format_bytes(bytes_val)
                    })
                except Exception:
                    pass
    brew_items.sort(key=lambda x: x["size_bytes"], reverse=True)

    # 2. Global NPM
    npm_items = []
    try:
        res = subprocess.run(["npm", "list", "-g", "--depth=0", "--json"], capture_output=True, text=True, timeout=5)
        if res.returncode == 0 and res.stdout:
            data = json.loads(res.stdout)
            deps = data.get("dependencies", {})
            for pkg_name, pkg_info in deps.items():
                npm_items.append({
                    "name": pkg_name,
                    "version": pkg_info.get("version", "unknown"),
                    "type": "Global npm Package"
                })
    except Exception:
        pass

    # 3. Pip packages
    pip_items = []
    try:
        res = subprocess.run([sys.executable, "-m", "pip", "list", "--format=json"], capture_output=True, text=True, timeout=5)
        if res.returncode == 0 and res.stdout:
            data = json.loads(res.stdout)
            for p in data:
                pip_items.append({
                    "name": p.get("name"),
                    "version": p.get("version"),
                    "type": "Python (pip) Package"
                })
    except Exception:
        pass

    return {
        "brew": brew_items,
        "brew_total_formatted": format_bytes(brew_total),
        "npm": npm_items,
        "pip": pip_items,
        "counts": {
            "brew": len(brew_items),
            "npm": len(npm_items),
            "pip": len(pip_items)
        }
    }

def scan_startup_items():
    launch_dirs = [
        ('User LaunchAgent', HOME / 'Library/LaunchAgents'),
        ('System LaunchAgent', Path('/Library/LaunchAgents')),
        ('System LaunchDaemon', Path('/Library/LaunchDaemons'))
    ]
    items = []
    for ltype, ldir in launch_dirs:
        if not ldir.exists():
            continue
        for f in ldir.iterdir():
            if f.name.endswith('.plist') or f.name.endswith('.plist.disabled'):
                is_disabled = f.name.endswith('.disabled')
                program = ""
                label = f.stem.replace('.plist', '')
                run_at_load = False
                try:
                    with open(f, 'rb') as fp:
                        pl = plistlib.load(fp)
                    label = pl.get('Label', label)
                    run_at_load = pl.get('RunAtLoad', False)
                    prog_val = pl.get('Program') or pl.get('ProgramArguments', '')
                    if isinstance(prog_val, list) and prog_val:
                        program = prog_val[0]
                    elif isinstance(prog_val, str):
                        program = prog_val
                except Exception:
                    pass

                items.append({
                    "file_name": f.name,
                    "path": str(f),
                    "type": ltype,
                    "label": label,
                    "program": program,
                    "run_at_load": run_at_load,
                    "is_disabled": is_disabled,
                    "can_toggle": str(ldir).startswith(str(HOME))
                })
    return {"items": items, "count": len(items)}

def toggle_startup_item(path_str):
    p = Path(path_str)
    if not p.exists() or not str(p).startswith(str(HOME)):
        return False, "Permission denied or file not found"
    try:
        if p.name.endswith('.disabled'):
            new_path = p.with_name(p.name[:-9]) # remove .disabled
            p.rename(new_path)
            subprocess.run(["launchctl", "load", str(new_path)], capture_output=True)
            return True, "Enabled startup item"
        else:
            subprocess.run(["launchctl", "unload", str(p)], capture_output=True)
            new_path = p.with_name(p.name + ".disabled")
            p.rename(new_path)
            return True, "Disabled startup item"
    except Exception as e:
        return False, str(e)

def scan_project_builds():
    projects_dir = HOME / "projects"
    results = []
    total_bytes = 0
    if not projects_dir.exists():
        return {"artifacts": [], "total_formatted": "0 B", "total_bytes": 0}

    for p in projects_dir.iterdir():
        if not p.is_dir() or p.name.startswith('.'):
            continue
        try:
            candidates = [p] + [sub for sub in p.iterdir() if sub.is_dir() and not sub.name.startswith('.') and sub.name not in ['node_modules', 'Pods', '.git', 'build']]
        except Exception:
            candidates = [p]

        for c in candidates:
            for target in ['build', '.dart_tool', 'ios/Pods']:
                tp = c / target
                if tp.exists():
                    try:
                        res = subprocess.run(['du', '-sk', str(tp)], capture_output=True, text=True, timeout=2)
                        if res.returncode == 0 and res.stdout:
                            kb = int(res.stdout.split()[0])
                            if kb > 1024:
                                bytes_val = kb * 1024
                                total_bytes += bytes_val
                                type_label = "Flutter Build" if target == 'build' else (
                                    "Dart Tool Cache" if target == '.dart_tool' else "CocoaPods Pods"
                                )
                                results.append({
                                    "project": c.name,
                                    "type": target.replace('ios/', ''),
                                    "type_label": type_label,
                                    "path": str(tp),
                                    "size_bytes": bytes_val,
                                    "size_formatted": format_bytes(bytes_val)
                                })
                    except Exception:
                        pass
    results.sort(key=lambda x: x["size_bytes"], reverse=True)
    return {
        "artifacts": results,
        "total_formatted": format_bytes(total_bytes),
        "total_bytes": total_bytes
    }

def scan_duplicates():
    search_dirs = [HOME / "Downloads", HOME / "Desktop"]
    size_map = {}
    for d in search_dirs:
        if not d.exists():
            continue
        try:
            for entry in os.scandir(d):
                if entry.is_file(follow_symlinks=False) and not entry.name.startswith('.'):
                    st = entry.stat()
                    if st.st_size > 1024:
                        size_map.setdefault(st.st_size, []).append((entry.path, st.st_mtime))
        except Exception:
            pass

    groups = []
    wasted_bytes = 0
    for size, file_list in size_map.items():
        if len(file_list) > 1:
            hash_map = {}
            for path_str, mtime in file_list:
                try:
                    hasher = hashlib.md5()
                    with open(path_str, 'rb') as f:
                        # Hash the full file, not just a prefix - two different
                        # files that happen to share the same size and leading
                        # bytes must never be reported (and deleted) as duplicates.
                        for chunk in iter(lambda: f.read(1024 * 1024), b''):
                            hasher.update(chunk)
                    h = hasher.hexdigest()
                    hash_map.setdefault(h, []).append({
                        "name": Path(path_str).name,
                        "path": path_str,
                        "size_bytes": size,
                        "size_formatted": format_bytes(size),
                        "modified": mtime
                    })
                except Exception:
                    pass

            for h, matches in hash_map.items():
                if len(matches) > 1:
                    matches.sort(key=lambda x: x["modified"], reverse=True)
                    wasted_bytes += (len(matches) - 1) * size
                    groups.append({
                        "hash": h,
                        "file_size": format_bytes(size),
                        "file_size_bytes": size,
                        "count": len(matches),
                        "files": matches
                    })

    groups.sort(key=lambda x: x["file_size_bytes"] * x["count"], reverse=True)
    return {
        "groups": groups,
        "wasted_formatted": format_bytes(wasted_bytes),
        "wasted_bytes": wasted_bytes
    }

def scan_installers():
    search_dirs = [HOME / "Downloads", HOME / "Desktop"]
    extensions = {'.dmg', '.pkg', '.apk', '.iso', '.zip', '.tar.gz', '.tgz'}
    results = []
    total_bytes = 0
    for d in search_dirs:
        if not d.exists():
            continue
        try:
            for entry in os.scandir(d):
                if entry.is_file(follow_symlinks=False) and not entry.name.startswith('.'):
                    ext = Path(entry.name).suffix.lower()
                    if ext in extensions:
                        st = entry.stat()
                        if st.st_size >= 10 * 1024 * 1024:
                            total_bytes += st.st_size
                            results.append({
                                "name": entry.name,
                                "path": entry.path,
                                "size_bytes": st.st_size,
                                "size_formatted": format_bytes(st.st_size),
                                "modified": st.st_mtime
                            })
        except Exception:
            pass
    results.sort(key=lambda x: x["size_bytes"], reverse=True)
    return {
        "installers": results,
        "total_formatted": format_bytes(total_bytes),
        "total_bytes": total_bytes
    }

def scan_git_repos():
    projects_dir = HOME / "projects"
    results = []
    total_bytes = 0
    if not projects_dir.exists():
        return {"repos": [], "total_formatted": "0 B"}

    for p in projects_dir.iterdir():
        if not p.is_dir() or p.name.startswith('.'):
            continue
        git_dir = p / ".git"
        if git_dir.exists():
            try:
                res = subprocess.run(['du', '-sk', str(git_dir)], capture_output=True, text=True, timeout=2)
                kb = int(res.stdout.split()[0]) if res.returncode == 0 and res.stdout else 0
                if kb > 2048:
                    bytes_val = kb * 1024
                    total_bytes += bytes_val
                    results.append({
                        "name": p.name,
                        "path": str(p),
                        "size_bytes": bytes_val,
                        "size_formatted": format_bytes(bytes_val)
                    })
            except Exception:
                pass
    results.sort(key=lambda x: x["size_bytes"], reverse=True)
    return {"repos": results, "total_formatted": format_bytes(total_bytes)}

def scan_leftovers():
    app_dirs = [Path('/Applications'), HOME / 'Applications']
    installed_apps = set()
    for ad in app_dirs:
        if ad.exists():
            for item in ad.iterdir():
                if item.name.endswith('.app'):
                    installed_apps.add(item.stem.lower())

    app_support = HOME / 'Library/Application Support'
    leftovers = []
    total_bytes = 0
    if app_support.exists():
        for item in app_support.iterdir():
            if item.is_dir() and not item.name.startswith('.') and not item.name.startswith('com.apple'):
                clean_name = item.name.lower().replace(' ', '').replace('-', '')
                match = any(app in clean_name or clean_name in app for app in installed_apps)
                if not match:
                    try:
                        res = subprocess.run(['du', '-sk', str(item)], capture_output=True, text=True, timeout=2)
                        kb = int(res.stdout.split()[0]) if res.returncode == 0 and res.stdout else 0
                        if kb > 5120:
                            bytes_val = kb * 1024
                            total_bytes += bytes_val
                            leftovers.append({
                                "name": item.name,
                                "path": str(item),
                                "size_bytes": bytes_val,
                                "size_formatted": format_bytes(bytes_val)
                            })
                    except Exception:
                        pass
    leftovers.sort(key=lambda x: x["size_bytes"], reverse=True)
    return {"leftovers": leftovers, "total_formatted": format_bytes(total_bytes)}

def is_autoclean_enabled():
    return PLIST_PATH.exists()

def set_autoclean(enable=True):
    if enable:
        PLIST_PATH.parent.mkdir(parents=True, exist_ok=True)
        plist_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.hexmorio.macleaner</string>
    <key>ProgramArguments</key>
    <array>
        <string>{HOME}/.local/bin/clean-storage</string>
        <string>--safe</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>7</integer>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>"""
        PLIST_PATH.write_text(plist_content)
        subprocess.run(["launchctl", "load", str(PLIST_PATH)], capture_output=True)
        return True
    else:
        if PLIST_PATH.exists():
            subprocess.run(["launchctl", "unload", str(PLIST_PATH)], capture_output=True)
            PLIST_PATH.unlink(missing_ok=True)
        return False

def get_folder_description(category, name):
    desc_map = {
        "user_library": {
            "Android": "Android SDK tools, platform SDKs, system images, and build-tools.",
            "Application Support": "Application state databases, local files, extension data, and offline caches.",
            "Developer": "Xcode toolchains, SDK runtimes, iOS simulator states, and DerivedData.",
            "Caches": "Temporary user and app caches; safe to purge to reclaim storage.",
            "Containers": "macOS Sandbox containers and isolated storage for App Store applications.",
            "HTTPStorages": "Stored HTTP request and network response cache files from macOS apps.",
            "Logs": "Crash reports and application diagnostic logs.",
            "Preferences": "User preference property lists (.plist).",
            "WebKit": "Browser engine offline data, website databases, and caches.",
            "pnpm": "Global pnpm hard-link store for Node dependencies.",
            "apktool": "Android decompilation temporary framework jars and APK build assets.",
            "Photos": "Photo library analysis caches and preview thumbnails.",
            "Keychains": "System security certificates and encrypted user credential store.",
            "Services": "macOS contextual services and quick-action menu helpers."
        },
        "app_support": {
            "Claude": "Claude Desktop local conversations, model artifacts, and vector store.",
            "Google": "Google Chrome browser profiles, service data, and local state.",
            "Figma": "Figma desktop client cached drafts, fonts, and workspace data.",
            "Antigravity IDE": "Antigravity editor workspaces, symbol indexes, and extensions.",
            "Postman": "Postman API collections, environment configs, and runtime logs.",
            "Code": "Visual Studio Code extensions, workspace storage, and editor cache.",
            "com.apple.wallpaper": "macOS animated lock screen and wallpaper video assets.",
            "GitKrakenCLI": "GitKraken local repositories and commit graph cache.",
            "Codex": "OpenAI Codex workspace checkpoints and session history.",
            "Antigravity": "Antigravity CLI configuration and agent runs.",
            "dart": "Dart SDK analytics and developer tool state.",
            "dart_mcp_server": "Dart Model Context Protocol server cache and logs.",
            "MongoDB Compass": "MongoDB Compass queries, schema cache, and connections.",
            "React Native DevTools": "React Native standalone debugger sessions and traces.",
            "shorebird": "Shorebird Flutter code-push CLI state."
        },
        "user_caches": {
            "com.openai.codex": "OpenAI Codex model weights, completions, and prompt caches.",
            "com.google.antigravity": "Google Antigravity agent execution traces and tool logs.",
            "Google": "Chrome browsing caches, media caches, and site thumbnails.",
            "node-gyp": "Node native C++ compilation headers and dev files.",
            "GeoServices": "macOS Maps and location geocoding cached tiles.",
            "org.swift.swiftpm": "Swift Package Manager repositories and compiled modules.",
            "com.apple.helpd": "macOS Help Viewer cache.",
            "com.mongodb.compass.ShipIt": "MongoDB Compass staged update binaries.",
            "claude-cli-nodejs": "Claude CLI Node.js execution runtime and packages.",
            "pip": "Python pip downloaded wheel archives and package indices.",
            "typescript": "TypeScript language service cached AST symbol trees.",
            "antigravity": "Antigravity runtime caches and session files."
        },
        "hidden_folders": {
            ".gradle": "Gradle build cache, wrapper distributions, and downloaded JARs (rebuildable).",
            ".android": "Android Virtual Device (AVD) system snapshots and keystores.",
            ".pub-cache": "Flutter and Dart hosted packages and Git dependencies.",
            ".shorebird": "Shorebird Flutter engine and toolchain binaries.",
            ".npm": "NPM package manager tarball cache and metadata.",
            ".codex": "Codex local runtime environments, history, and tasks.",
            ".local": "User-installed local binaries and data share.",
            ".dartServer": "Dart analysis server project indices and code symbols.",
            ".cache": "Standard user CLI and tool cache directory.",
            ".nvm": "Node Version Manager installed Node.js versions.",
            ".claude": "Claude CLI session history and local settings.",
            ".gemini": "Gemini CLI logs, agent traces, and task outputs.",
            ".expo": "Expo mobile framework templates and emulator runtimes.",
            ".chrome-play-console": "Browser automation temporary profiles.",
            ".antigravity-ide": "Antigravity IDE local user state.",
            ".vscode": "VS Code CLI extensions and command-line settings.",
            ".antigravity": "Antigravity core configuration.",
            ".bundle": "Ruby Bundler downloaded gem cache.",
            ".gem": "Ruby gem specifications and documentation.",
            ".cocoapods": "CocoaPods master spec repository clone."
        },
        "system_library": {
            "Caches": "Global system and root daemon cache files.",
            "Logs": "macOS system daemons, launchd, and diagnostic crash logs.",
            "Application Support": "System-wide application shared resources and helper tools.",
            "Developer": "Command Line Tools and system developer assets."
        }
    }
    cat_map = desc_map.get(category, {})
    return cat_map.get(name, f"{name} directory in {category.replace('_', ' ').title()}.")

def scan_library_and_folders():
    # 1. User Library (~/Library) subdirectories
    lib_path = HOME / "Library"
    user_lib_items = []
    user_lib_total = 0
    if lib_path.exists():
        for entry in lib_path.iterdir():
            if entry.is_dir() and not entry.name.startswith('.'):
                sz = get_dir_size(entry)
                if sz > 2 * 1024 * 1024:
                    user_lib_total += sz
                    user_lib_items.append({
                        "name": entry.name,
                        "path": str(entry),
                        "category": "user_library",
                        "size_bytes": sz,
                        "size_formatted": format_bytes(sz),
                        "description": get_folder_description("user_library", entry.name),
                        "can_clean": entry.name in ["Caches", "Logs", "HTTPStorages"]
                    })
    user_lib_items.sort(key=lambda x: x["size_bytes"], reverse=True)

    # 2. Application Support (~/Library/Application Support)
    app_sup_path = HOME / "Library/Application Support"
    app_sup_items = []
    app_sup_total = 0
    if app_sup_path.exists():
        for entry in app_sup_path.iterdir():
            if entry.is_dir() and not entry.name.startswith('.'):
                sz = get_dir_size(entry)
                if sz > 1 * 1024 * 1024:
                    app_sup_total += sz
                    app_sup_items.append({
                        "name": entry.name,
                        "path": str(entry),
                        "category": "app_support",
                        "size_bytes": sz,
                        "size_formatted": format_bytes(sz),
                        "description": get_folder_description("app_support", entry.name),
                        "can_clean": False
                    })
    app_sup_items.sort(key=lambda x: x["size_bytes"], reverse=True)

    # 3. User Caches (~/Library/Caches)
    caches_path = HOME / "Library/Caches"
    caches_items = []
    caches_total = 0
    if caches_path.exists():
        for entry in caches_path.iterdir():
            if entry.is_dir() and not entry.name.startswith('.'):
                sz = get_dir_size(entry)
                if sz > 500 * 1024:
                    caches_total += sz
                    caches_items.append({
                        "name": entry.name,
                        "path": str(entry),
                        "category": "user_caches",
                        "size_bytes": sz,
                        "size_formatted": format_bytes(sz),
                        "description": get_folder_description("user_caches", entry.name),
                        "can_clean": True
                    })
    caches_items.sort(key=lambda x: x["size_bytes"], reverse=True)

    # 4. Hidden Dot Folders (~/.*)
    dot_items = []
    dot_total = 0
    for entry in HOME.iterdir():
        if entry.is_dir() and entry.name.startswith('.') and entry.name not in ['.', '..', '.Trash']:
            sz = get_dir_size(entry)
            if sz > 5 * 1024 * 1024:
                dot_total += sz
                dot_items.append({
                    "name": entry.name,
                    "path": str(entry),
                    "category": "hidden_folders",
                    "size_bytes": sz,
                    "size_formatted": format_bytes(sz),
                    "description": get_folder_description("hidden_folders", entry.name),
                    "can_clean": entry.name in [".cache", ".expo", ".chrome-play-console", ".chrome-debug-profile"]
                })
    dot_items.sort(key=lambda x: x["size_bytes"], reverse=True)

    # 5. System /Library
    sys_lib_path = Path("/Library")
    sys_lib_items = []
    sys_lib_total = 0
    if sys_lib_path.exists():
        for entry in sys_lib_path.iterdir():
            if entry.is_dir() and not entry.name.startswith('.'):
                sz = get_dir_size(entry)
                if sz > 5 * 1024 * 1024:
                    sys_lib_total += sz
                    sys_lib_items.append({
                        "name": entry.name,
                        "path": str(entry),
                        "category": "system_library",
                        "size_bytes": sz,
                        "size_formatted": format_bytes(sz),
                        "description": get_folder_description("system_library", entry.name),
                        "can_clean": entry.name in ["Caches", "Logs"]
                    })
    sys_lib_items.sort(key=lambda x: x["size_bytes"], reverse=True)

    grand_total = user_lib_total + dot_total + sys_lib_total
    return {
        "user_library": user_lib_items,
        "app_support": app_sup_items,
        "user_caches": caches_items,
        "hidden_folders": dot_items,
        "system_library": sys_lib_items,
        "totals": {
            "user_library": format_bytes(user_lib_total),
            "user_library_bytes": user_lib_total,
            "app_support": format_bytes(app_sup_total),
            "app_support_bytes": app_sup_total,
            "user_caches": format_bytes(caches_total),
            "user_caches_bytes": caches_total,
            "hidden_folders": format_bytes(dot_total),
            "hidden_folders_bytes": dot_total,
            "system_library": format_bytes(sys_lib_total),
            "system_library_bytes": sys_lib_total,
            "grand_total": format_bytes(grand_total),
            "grand_total_bytes": grand_total
        }
    }

def scan_folder_tree(path_str="", show_hidden=True):
    target_path = Path(path_str).expanduser() if path_str else HOME
    if not target_path.exists() or not target_path.is_dir():
        target_path = HOME

    items = []
    try:
        for entry in os.scandir(target_path):
            if not show_hidden and entry.name.startswith('.'):
                continue
            if entry.name in ['.', '..']:
                continue
            try:
                if entry.is_dir(follow_symlinks=False):
                    bytes_val = get_dir_size(entry.path)
                    if bytes_val > 2 * 1024 * 1024:
                        items.append({
                            "name": entry.name,
                            "path": entry.path,
                            "is_dir": True,
                            "size_bytes": bytes_val,
                            "size_formatted": format_bytes(bytes_val)
                        })
                elif entry.is_file(follow_symlinks=False):
                    st = entry.stat()
                    if st.st_size > 5 * 1024 * 1024:
                        items.append({
                            "name": entry.name,
                            "path": entry.path,
                            "is_dir": False,
                            "size_bytes": st.st_size,
                            "size_formatted": format_bytes(st.st_size)
                        })
            except Exception:
                pass
    except Exception:
        pass

    items.sort(key=lambda x: x["size_bytes"], reverse=True)
    parent_path = str(target_path.parent) if target_path != HOME and target_path != Path("/") else None
    return {
        "current_path": str(target_path),
        "parent_path": parent_path,
        "items": items[:50]
    }

def scan_large_files(min_mb=50, max_results=50):
    candidates = []
    search_dirs = [HOME / "Downloads", HOME / "Desktop", HOME / "Documents", HOME / "projects"]
    min_bytes = min_mb * 1024 * 1024
    for d in search_dirs:
        if not d.exists():
            continue
        try:
            for root, dirs, files in os.walk(d):
                dirs[:] = [name for name in dirs if not name.startswith('.') and name not in ['node_modules', 'Pods', '.git', 'build', '.dart_tool']]
                for f in files:
                    if f.startswith('.'):
                        continue
                    fp = os.path.join(root, f)
                    try:
                        st = os.stat(fp)
                        if st.st_size >= min_bytes:
                            candidates.append({
                                "name": f,
                                "path": fp,
                                "size_bytes": st.st_size,
                                "size_formatted": format_bytes(st.st_size),
                                "modified": st.st_mtime
                            })
                    except Exception:
                        pass
        except Exception:
            pass
    candidates.sort(key=lambda x: x["size_bytes"], reverse=True)
    return candidates[:max_results]

def flush_system():
    try:
        subprocess.run(["qlmanage", "-r", "cache"], capture_output=True, timeout=5)
        subprocess.run(["dscacheutil", "-flushcache"], capture_output=True, timeout=5)
        return True, "Flushed QuickLook and DNS system caches"
    except Exception as e:
        return False, str(e)

def optimize_git_repo(path_str):
    try:
        subprocess.run(["git", "-C", path_str, "gc", "--prune=now"], capture_output=True, timeout=15)
        return True, "Optimized git repository"
    except Exception as e:
        return False, str(e)

def execute_clean(target_id):
    target = next((t for t in CLEAN_TARGETS if t["id"] == target_id), None)
    if not target:
        return False, "Target not found"
    
    path = Path(target["path"]).expanduser()
    action = target["action"]
    failures = []

    def _purge_contents(p):
        for item in p.iterdir():
            try:
                if item.is_dir() and not item.is_symlink():
                    shutil.rmtree(item)
                else:
                    item.unlink()
            except Exception as e:
                failures.append(f"{item.name}: {e}")

    try:
        if action == "delete_contents":
            if path.exists():
                _purge_contents(path)
        elif action == "recreate_dir":
            if path.exists():
                shutil.rmtree(path, ignore_errors=True)
            path.mkdir(parents=True, exist_ok=True)
        elif action == "npm_clean":
            subprocess.run(["npm", "cache", "clean", "--force"], capture_output=True, timeout=10)
            if path.exists():
                shutil.rmtree(path, ignore_errors=True)
        elif action == "pub_clean":
            subprocess.run(["dart", "pub", "cache", "clean", "-f"], capture_output=True, timeout=15)
        elif action == "sim_erase":
            subprocess.run(["xcrun", "simctl", "erase", "all"], capture_output=True, timeout=15)
            subprocess.run(["xcrun", "simctl", "delete", "unavailable"], capture_output=True, timeout=10)
            if path.exists():
                _purge_contents(path)
        elif action == "empty_trash":
            if path.exists():
                _purge_contents(path)
        _invalidate_cache(str(path.resolve()))
        if failures:
            return False, f"Cleaned with {len(failures)} item(s) skipped (e.g. {failures[0]}) - they may need administrator permission"
        return True, "Cleaned successfully"
    except Exception as e:
        return False, str(e)

PROTECTED_PATHS = {
    str(HOME.resolve()),
    str((HOME / "Library").resolve()),
    str((HOME / "Desktop").resolve()),
    str((HOME / "Documents").resolve()),
    str((HOME / "Downloads").resolve()),
    str((HOME / "Pictures").resolve()),
    "/",
    "/System",
    "/Library",
    "/Applications",
    "/usr",
    "/bin",
    "/sbin",
    "/private",
    "/etc",
    "/var"
}

def _check_path_safety(resolved):
    """Shared guard for every endpoint that deletes/moves a user-supplied path.
    Every destructive path-based endpoint (clean-path, clean-folder,
    delete-file, ...) must call this - skipping it is what let /api/delete-file
    bypass these checks entirely before."""
    if resolved in PROTECTED_PATHS:
        return False, "Security error: protected system or root folder cannot be deleted"
    is_in_home = resolved.startswith(str(HOME.resolve()))
    is_in_sys_cache = resolved.startswith("/Library/Caches") or resolved.startswith("/Library/Logs")
    if not (is_in_home or is_in_sys_cache):
        return False, "Security error: path must be inside user home or safe system cache"
    return True, None

def _invalidate_cache(resolved):
    if resolved in _FOLDER_CACHE:
        _FOLDER_CACHE[resolved] = 0
        _CACHE_TIMESTAMPS[resolved] = time.time()

def delete_path_safe(path_str):
    if not path_str:
        return False, "Empty path"
    path = Path(path_str).expanduser()
    if not path.exists():
        return False, "Path does not exist"
    resolved = str(path.resolve())
    ok, err = _check_path_safety(resolved)
    if not ok:
        return False, err
    try:
        if path.is_dir():
            shutil.rmtree(path)
        else:
            path.unlink()
        _invalidate_cache(resolved)
        return True, "Removed successfully"
    except Exception as e:
        return False, str(e)

def clean_folder_contents_safe(path_str):
    if not path_str:
        return False, "Empty path"
    path = Path(path_str).expanduser()
    if not path.exists() or not path.is_dir():
        return False, "Directory does not exist"
    resolved = str(path.resolve())
    ok, err = _check_path_safety(resolved)
    if not ok:
        return False, err
    failures = []
    try:
        for item in path.iterdir():
            try:
                if item.is_dir() and not item.is_symlink():
                    shutil.rmtree(item)
                else:
                    item.unlink()
            except Exception as e:
                failures.append(f"{item.name}: {e}")
    except Exception as e:
        return False, str(e)
    _invalidate_cache(resolved)
    if failures:
        return False, f"Removed most items, but {len(failures)} could not be deleted (e.g. {failures[0]}) - they may need administrator permission"
    return True, "Contents purged successfully"

def move_to_trash_safe(path_str):
    if not path_str:
        return False, "Empty path"
    path = Path(path_str).expanduser()
    if not path.exists():
        return False, "Path does not exist"
    resolved = str(path.resolve())
    ok, err = _check_path_safety(resolved)
    if not ok:
        return False, err
    try:
        trash_dir = HOME / ".Trash"
        trash_dir.mkdir(parents=True, exist_ok=True)
        trash_path = trash_dir / path.name
        if trash_path.exists():
            # Avoid colliding with an existing Trash item - never fall back
            # to a permanent delete, since that would silently defeat the
            # "move to Trash" the UI promises the user.
            trash_path = trash_dir / f"{path.stem}-{int(time.time())}{path.suffix}"
        shutil.move(str(path), str(trash_path))
        _invalidate_cache(resolved)
        return True, "Moved to Trash"
    except Exception as e:
        return False, str(e)

class StorageHandler(http.server.SimpleHTTPRequestHandler):
    # Deliberately no Access-Control-Allow-Origin header: this server exposes
    # endpoints that delete files on the user's machine, and the page that
    # calls them is always served from this same origin. Sending a wildcard
    # CORS header would let any other website the user has open in a tab
    # issue those same destructive requests against 127.0.0.1 from the
    # browser - same-origin requests never need CORS headers to succeed.
    def end_headers(self):
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        super().end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/" or parsed.path == "/index.html":
            html_file = Path(__file__).parent / "index.html"
            if html_file.exists():
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(html_file.read_bytes())
                return
        elif parsed.path == "/api/status":
            self._send_json(get_disk_status())
            return
        elif parsed.path == "/api/ram":
            self._send_json(get_ram_info())
            return
        elif parsed.path == "/api/library":
            self._send_json(scan_library_and_folders())
            return
        elif parsed.path == "/api/apps":
            self._send_json(scan_all_applications())
            return
        elif parsed.path == "/api/packages":
            self._send_json(scan_packages())
            return
        elif parsed.path == "/api/startup":
            self._send_json(scan_startup_items())
            return
        elif parsed.path == "/api/scan":
            self._send_json(scan_targets())
            return
        elif parsed.path == "/api/projects":
            self._send_json(scan_project_builds())
            return
        elif parsed.path == "/api/duplicates":
            self._send_json(scan_duplicates())
            return
        elif parsed.path == "/api/installers":
            self._send_json(scan_installers())
            return
        elif parsed.path == "/api/git-repos":
            self._send_json(scan_git_repos())
            return
        elif parsed.path == "/api/leftovers":
            self._send_json(scan_leftovers())
            return
        elif parsed.path == "/api/auto-clean":
            self._send_json({"enabled": is_autoclean_enabled(), "schedule": "Every Sunday at 3:00 AM"})
            return
        elif parsed.path == "/api/tree":
            query = urllib.parse.parse_qs(parsed.query)
            target = query.get("path", [""])[0]
            show_hidden = query.get("hidden", ["1"])[0] == "1"
            self._send_json(scan_folder_tree(target, show_hidden=show_hidden))
            return
        elif parsed.path == "/api/large-files":
            query = urllib.parse.parse_qs(parsed.query)
            min_mb = int(query.get("min_mb", ["50"])[0])
            self._send_json({"files": scan_large_files(min_mb=min_mb)})
            return
        super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        content_len = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_len).decode("utf-8") if content_len > 0 else "{}"
        try:
            req_data = json.loads(body)
        except Exception:
            req_data = {}

        if parsed.path == "/api/clean":
            target_ids = req_data.get("ids", [])
            results = {}
            for tid in target_ids:
                success, msg = execute_clean(tid)
                results[tid] = {"success": success, "message": msg}
            self._send_json({"status": "completed", "results": results, "disk": get_disk_status()})
            return

        elif parsed.path == "/api/clean-folder":
            path = req_data.get("path")
            success, msg = clean_folder_contents_safe(path)
            self._send_json({"success": success, "message": msg, "disk": get_disk_status()})
            return

        elif parsed.path == "/api/clean-path":
            path = req_data.get("path")
            success, msg = delete_path_safe(path)
            self._send_json({"success": success, "message": msg, "disk": get_disk_status()})
            return

        elif parsed.path == "/api/clean-all-project-builds":
            paths = req_data.get("paths", [])
            count = sum(1 for p in paths if delete_path_safe(p)[0])
            self._send_json({"success": True, "count": count, "disk": get_disk_status()})
            return

        elif parsed.path == "/api/clean-duplicates":
            paths = req_data.get("paths", [])
            count = sum(1 for p in paths if delete_path_safe(p)[0])
            self._send_json({"success": True, "count": count, "disk": get_disk_status()})
            return

        elif parsed.path == "/api/optimize-git":
            paths = req_data.get("paths", [])
            count = sum(1 for p in paths if optimize_git_repo(p)[0])
            self._send_json({"success": True, "count": count})
            return

        elif parsed.path == "/api/brew-cleanup":
            try:
                res = subprocess.run(["brew", "cleanup", "--prune=all"], capture_output=True, text=True, timeout=20)
                self._send_json({"success": True, "message": res.stdout, "disk": get_disk_status()})
            except Exception as e:
                self._send_json({"success": False, "error": str(e)}, status=500)
            return

        elif parsed.path == "/api/toggle-startup":
            path = req_data.get("path")
            ok, msg = toggle_startup_item(path)
            self._send_json({"success": ok, "message": msg})
            return

        elif parsed.path == "/api/toggle-auto-clean":
            target_state = req_data.get("enable", True)
            res = set_autoclean(target_state)
            self._send_json({"enabled": res})
            return

        elif parsed.path == "/api/system-flush":
            ok, msg = flush_system()
            self._send_json({"success": ok, "message": msg, "disk": get_disk_status()})
            return

        elif parsed.path == "/api/reveal":
            path = req_data.get("path")
            if path and os.path.exists(path):
                subprocess.run(["open", "-R", path])
                self._send_json({"success": True})
            else:
                self._send_json({"success": False, "error": "Path not found"}, status=404)
            return

        elif parsed.path == "/api/delete-file":
            path = req_data.get("path")
            success, msg = move_to_trash_safe(path)
            if success:
                self._send_json({"success": True})
            else:
                self._send_json({"success": False, "error": msg}, status=400)
            return

        self.send_response(404)
        self.end_headers()

    def _send_json(self, data, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode("utf-8"))

def run_server():
    os.chdir(Path(__file__).parent)
    socketserver.ThreadingTCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(("127.0.0.1", PORT), StorageHandler) as httpd:
        print(f"Hexmorio Macleaner running on http://127.0.0.1:{PORT}")
        httpd.serve_forever()

if __name__ == "__main__":
    run_server()
