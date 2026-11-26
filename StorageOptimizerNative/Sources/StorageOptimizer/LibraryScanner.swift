import Foundation

enum FolderDescriptions {
    static let map: [String: [String: String]] = [
        "user_library": [
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
            "Services": "macOS contextual services and quick-action menu helpers.",
        ],
        "app_support": [
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
            "shorebird": "Shorebird Flutter code-push CLI state.",
        ],
        "user_caches": [
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
            "antigravity": "Antigravity runtime caches and session files.",
        ],
        "hidden_folders": [
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
            ".cocoapods": "CocoaPods master spec repository clone.",
        ],
        "system_library": [
            "Caches": "Global system and root daemon cache files.",
            "Logs": "macOS system daemons, launchd, and diagnostic crash logs.",
            "Application Support": "System-wide application shared resources and helper tools.",
            "Developer": "Command Line Tools and system developer assets.",
        ],
    ]

    static func describe(category: String, name: String) -> String {
        map[category]?[name] ?? "\(name) directory in \(category.replacingOccurrences(of: "_", with: " ").capitalized)."
    }
}

struct LibraryScanResult {
    var userLibrary: [LibraryItem] = []
    var appSupport: [LibraryItem] = []
    var userCaches: [LibraryItem] = []
    var hiddenFolders: [LibraryItem] = []
    var systemLibrary: [LibraryItem] = []
    var userLibraryBytes: Int64 = 0
    var appSupportBytes: Int64 = 0
    var userCachesBytes: Int64 = 0
    var hiddenFoldersBytes: Int64 = 0
    var systemLibraryBytes: Int64 = 0
    var grandTotalBytes: Int64 { userLibraryBytes + hiddenFoldersBytes + systemLibraryBytes }
}

enum LibraryScanner {
    static func scan() -> LibraryScanResult {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        var result = LibraryScanResult()

        func listDirs(_ path: String) -> [String] {
            (try? fm.contentsOfDirectory(atPath: path)) ?? []
        }

        // 1. ~/Library subfolders
        let libPath = "\(home)/Library"
        let cleanableUserLib: Set<String> = ["Caches", "Logs", "HTTPStorages", "Saved Application State"]
        for name in listDirs(libPath) where !name.hasPrefix(".") {
            let full = (libPath as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { continue }
            let size = FolderSizeCache.shared.size(of: full)
            guard size > 2 * 1024 * 1024 else { continue }
            result.userLibraryBytes += size
            result.userLibrary.append(LibraryItem(
                name: name, path: full, category: "user_library", sizeBytes: size,
                description: FolderDescriptions.describe(category: "user_library", name: name),
                canClean: cleanableUserLib.contains(name)
            ))
        }
        result.userLibrary.sort { $0.sizeBytes > $1.sizeBytes }

        // 2. Application Support
        let appSupPath = "\(home)/Library/Application Support"
        for name in listDirs(appSupPath) where !name.hasPrefix(".") && !name.hasPrefix("com.apple.") {
            let full = (appSupPath as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { continue }
            let size = FolderSizeCache.shared.size(of: full)
            guard size > 1 * 1024 * 1024 else { continue }
            result.appSupportBytes += size
            result.appSupport.append(LibraryItem(
                name: name, path: full, category: "app_support", sizeBytes: size,
                description: FolderDescriptions.describe(category: "app_support", name: name),
                // Application Support holds real app data (databases, message history,
                // vaults), so purging it is recoverable: contents go to the Trash.
                canClean: true,
                trashOnClean: true
            ))
        }
        result.appSupport.sort { $0.sizeBytes > $1.sizeBytes }

        // 3. ~/Library/Caches
        let cachesPath = "\(home)/Library/Caches"
        for name in listDirs(cachesPath) where !name.hasPrefix(".") {
            let full = (cachesPath as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { continue }
            let size = FolderSizeCache.shared.size(of: full)
            guard size > 500 * 1024 else { continue }
            result.userCachesBytes += size
            result.userCaches.append(LibraryItem(
                name: name, path: full, category: "user_caches", sizeBytes: size,
                description: FolderDescriptions.describe(category: "user_caches", name: name),
                canClean: true
            ))
        }
        result.userCaches.sort { $0.sizeBytes > $1.sizeBytes }

        // 4. Hidden dot folders in HOME (tools, SDKs, package managers, and CLI state)
        // Credentials, keys and tool config: listed for visibility, never purgeable.
        let sensitiveDotFolders: Set<String> = [
            ".ssh", ".gnupg", ".aws", ".azure", ".config", ".kube", ".docker", ".android",
            ".password-store", ".terraform.d", ".local", ".gradle", ".m2",
            ".claude", ".codex", ".gemini", ".cursor", ".vscode", ".windsurf",
        ]
        // Pure download/build caches that tools rebuild on demand: safe to delete permanently.
        let rebuildableDotFolders: Set<String> = [
            ".cache", ".expo", ".chrome-play-console", ".npm", ".pnpm-store", ".pub-cache",
            ".cocoapods", ".dartServer", ".node-gyp", ".electron", ".electron-gyp", ".yarn",
        ]
        for name in listDirs(home) where name.hasPrefix(".") && name != "." && name != ".." && name != ".Trash" {
            let full = (home as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { continue }
            let size = FolderSizeCache.shared.size(of: full)
            guard size > 5 * 1024 * 1024 else { continue }
            result.hiddenFoldersBytes += size
            result.hiddenFolders.append(LibraryItem(
                name: name, path: full, category: "hidden_folders", sizeBytes: size,
                description: FolderDescriptions.describe(category: "hidden_folders", name: name),
                canClean: !sensitiveDotFolders.contains(name),
                // Anything that isn't a known rebuildable cache (SDK managers, app state,
                // unknown tools) goes to the Trash so a wrong click can be undone.
                trashOnClean: !rebuildableDotFolders.contains(name)
            ))
        }
        result.hiddenFolders.sort { $0.sizeBytes > $1.sizeBytes }

        // 5. /Library (system)
        let sysLibPath = "/Library"
        for name in listDirs(sysLibPath) where !name.hasPrefix(".") {
            let full = (sysLibPath as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { continue }
            let size = FolderSizeCache.shared.size(of: full)
            guard size > 5 * 1024 * 1024 else { continue }
            result.systemLibraryBytes += size
            result.systemLibrary.append(LibraryItem(
                name: name, path: full, category: "system_library", sizeBytes: size,
                description: FolderDescriptions.describe(category: "system_library", name: name),
                canClean: ["Caches", "Logs"].contains(name)
            ))
        }
        result.systemLibrary.sort { $0.sizeBytes > $1.sizeBytes }

        return result
    }
}
