import Foundation

enum CleanTargetsCatalog {
    static let home = NSHomeDirectory()

    static let all: [CleanTargetDef] = [
        CleanTargetDef(id: "xcode_derived_data", category: "developer", name: "Xcode DerivedData",
            path: "\(home)/Library/Developer/Xcode/DerivedData",
            description: "Intermediate build artifacts, indexes, and symbol caches.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "xcode_device_support", category: "developer", name: "iOS Device Support Symbols",
            path: "\(home)/Library/Developer/Xcode/iOS DeviceSupport",
            description: "Debug symbols copied from connected physical iOS devices.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "xcode_archives", category: "developer", name: "Xcode App Archives",
            path: "\(home)/Library/Developer/Xcode/Archives",
            description: "Historical build archives produced when exporting or distributing apps.", safety: .review, action: .deleteContents),
        CleanTargetDef(id: "simulators_cache", category: "developer", name: "iOS Simulators State & Caches",
            path: "\(home)/Library/Developer/CoreSimulator/Caches",
            description: "Temporary runtimes and cached simulator container states.", safety: .safe, action: .simErase),
        CleanTargetDef(id: "dart_server", category: "developer", name: "Dart Analysis Server Cache",
            path: "\(home)/.dartServer",
            description: "Persistent code analysis indexes from Flutter and Dart LSP.", safety: .safe, action: .recreateDir),
        CleanTargetDef(id: "pub_cache", category: "developer", name: "Flutter / Dart Pub Cache",
            path: "\(home)/.pub-cache",
            description: "Downloaded Dart packages and hosted dependencies.", safety: .rebuildable, action: .pubClean),
        CleanTargetDef(id: "gradle_caches", category: "developer", name: "Gradle Dependency & Build Cache",
            path: "\(home)/.gradle/caches",
            description: "Downloaded JARs, dependencies, and Gradle execution cache.", safety: .rebuildable, action: .deleteContents),
        CleanTargetDef(id: "android_ndk", category: "developer", name: "Android NDK Toolchains",
            path: "\(home)/Library/Android/sdk/ndk",
            description: "Native Development Kit compilers and C/C++ toolchains.", safety: .review, action: .deleteContents),
        CleanTargetDef(id: "android_system_images", category: "developer", name: "Android Emulator System Images",
            path: "\(home)/Library/Android/sdk/system-images",
            description: "Full OS disk images for Android emulator virtual devices.", safety: .review, action: .deleteContents),
        CleanTargetDef(id: "android_avd", category: "developer", name: "Android Virtual Devices (AVD)",
            path: "\(home)/.android/avd",
            description: "Created virtual device user data and emulators.", safety: .review, action: .deleteContents),
        CleanTargetDef(id: "android_cache", category: "developer", name: "Android Build & CLI Cache",
            path: "\(home)/.android/cache",
            description: "Temporary runtime and CLI cache from Android SDK.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "npm_cache", category: "developer", name: "npm Package Cache",
            path: "\(home)/.npm",
            description: "Cached Node packages and tarballs downloaded by npm.", safety: .safe, action: .npmClean),
        CleanTargetDef(id: "pnpm_cache", category: "developer", name: "pnpm Store",
            path: "\(home)/Library/pnpm",
            description: "Shared package cache from pnpm installations.", safety: .rebuildable, action: .deleteContents),
        CleanTargetDef(id: "shorebird_cache", category: "developer", name: "Shorebird Flutter Cache",
            path: "\(home)/.shorebird",
            description: "Installed Shorebird Flutter engines and tooling.", safety: .review, action: .deleteContents),
        CleanTargetDef(id: "cocoapods_cache", category: "developer", name: "CocoaPods Cache",
            path: "\(home)/Library/Caches/CocoaPods",
            description: "Cached Pod git repositories and prebuilt frameworks.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "chrome_cache", category: "system", name: "Google Chrome User Cache",
            path: "\(home)/Library/Caches/Google",
            description: "Web page assets, cached media, and browsing caches.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "homebrew_cache", category: "system", name: "Homebrew Download Cache",
            path: "\(home)/Library/Caches/Homebrew",
            description: "Downloaded formula bottles and source tarballs.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "postman_shipit", category: "system", name: "Postman Auto-Update Cache",
            path: "\(home)/Library/Caches/com.postmanlabs.mac.ShipIt",
            description: "Staged update archives from Postman ShipIt.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "puppeteer_cache", category: "developer", name: "Puppeteer Browser Cache",
            path: "\(home)/.cache/puppeteer",
            description: "Downloaded headless browser binaries for testing.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "codex_runtimes", category: "developer", name: "Codex Runtimes Cache",
            path: "\(home)/.cache/codex-runtimes",
            description: "Downloaded agent execution environments and runtimes.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "user_logs", category: "system", name: "User Application Logs",
            path: "\(home)/Library/Logs",
            description: "Historical diagnostic crash logs and debug outputs.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "diagnostic_reports", category: "system", name: "macOS Crash & Diagnostic Reports",
            path: "\(home)/Library/Logs/DiagnosticReports",
            description: "System and application crash dumps collected by macOS.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "trash", category: "system", name: "macOS Trash",
            path: "\(home)/.Trash",
            description: "Files discarded to Trash awaiting permanent deletion.", safety: .review, action: .emptyTrash),
        CleanTargetDef(id: "codex_caches", category: "developer", name: "OpenAI Codex Library Caches",
            path: "\(home)/Library/Caches/com.openai.codex",
            description: "Model weights, cached completions, and sessions from Codex.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "antigravity_caches", category: "developer", name: "Google Antigravity Caches",
            path: "\(home)/Library/Caches/com.google.antigravity",
            description: "Temporary execution traces, run logs, and agent tool cache.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "claude_caches", category: "developer", name: "Claude CLI & Desktop Caches",
            path: "\(home)/Library/Caches/claude-cli-nodejs",
            description: "Node runtime and execution cache from Claude CLI.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "http_storages", category: "system", name: "macOS HTTPStorages Network Caches",
            path: "\(home)/Library/HTTPStorages",
            description: "System network response cache and cookie store across macOS apps.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "node_gyp", category: "developer", name: "Node-Gyp C++ Build Cache",
            path: "\(home)/Library/Caches/node-gyp",
            description: "Node header files and C++ native build cache.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "swiftpm_cache", category: "developer", name: "Swift Package Manager Cache",
            path: "\(home)/Library/Caches/org.swift.swiftpm",
            description: "Cached Swift package dependencies and pre-built binaries.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "pip_caches", category: "developer", name: "Python Pip Wheel Cache",
            path: "\(home)/Library/Caches/pip",
            description: "Downloaded Python wheel archives and index caches.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "typescript_cache", category: "developer", name: "TypeScript Compiler Cache",
            path: "\(home)/Library/Caches/typescript",
            description: "Cached symbol tables and AST definitions.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "compass_shipit", category: "developer", name: "MongoDB Compass ShipIt Cache",
            path: "\(home)/Library/Caches/com.mongodb.compass.ShipIt",
            description: "Staged auto-update installation archives.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "general_cache", category: "developer", name: "User ~/.cache Directory",
            path: "\(home)/.cache",
            description: "User CLI tools, runtimes, and application caches.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "expo_cache", category: "developer", name: "Expo & React Native CLI Cache",
            path: "\(home)/.expo",
            description: "Downloaded React Native simulator runtime templates.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "chrome_debug_profiles", category: "developer", name: "Chrome Automation Profiles",
            path: "\(home)/.chrome-play-console",
            description: "Temporary Chrome profiles created during browser automation.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "system_library_caches", category: "system", name: "System /Library/Caches",
            path: "/Library/Caches",
            description: "Root system application caches and helper data.", safety: .safe, action: .deleteContents),
        CleanTargetDef(id: "system_library_logs", category: "system", name: "System /Library/Logs",
            path: "/Library/Logs",
            description: "Historical macOS daemon and system diagnostic logs.", safety: .safe, action: .deleteContents),
    ]
}

struct CleanScanResult {
    var items: [CleanTarget] = []
    var totalSafeBytes: Int64 = 0
    var totalCleanableBytes: Int64 = 0
    var totalSafeFormatted: String { formatBytes(totalSafeBytes) }
    var totalCleanableFormatted: String { formatBytes(totalCleanableBytes) }
}

enum CleanTargetsService {
    static func scan() -> CleanScanResult {
        var result = CleanScanResult()
        for def in CleanTargetsCatalog.all {
            let size = FolderSizeCache.shared.size(of: def.path)
            let exists = FileManager.default.fileExists(atPath: def.path)
            result.items.append(CleanTarget(
                id: def.id, category: def.category, name: def.name, path: def.path,
                description: def.description, safety: def.safety, action: def.action,
                sizeBytes: size, exists: exists
            ))
            if def.safety == .safe { result.totalSafeBytes += size }
            result.totalCleanableBytes += size
        }
        return result
    }

    /// Items whose system-level action commonly needs admin rights when run
    /// as a plain user (the two /Library/... targets).
    static func needsAdmin(_ id: String) -> Bool {
        id == "system_library_caches" || id == "system_library_logs"
    }

    @discardableResult
    static func execute(_ targetId: String, asAdmin: Bool = false) -> (success: Bool, message: String) {
        guard let def = CleanTargetsCatalog.all.first(where: { $0.id == targetId }) else {
            return (false, "Target not found")
        }
        let fm = FileManager.default

        if asAdmin {
            // Route the whole purge through a single authorized shell command
            // rather than per-file prompts.
            let quoted = def.path.replacingOccurrences(of: "'", with: "'\\''")
            let result = Shell.runAsAdmin("rm -rf '\(quoted)'/* '\(quoted)'/.[!.]* 2>/dev/null; exit 0")
            FolderSizeCache.shared.invalidate(def.path)
            if result.status == 0 {
                return (true, "Cleaned successfully")
            }
            return (false, result.stderr.isEmpty ? "Admin cleanup failed" : result.stderr)
        }

        var failures: [String] = []
        func purgeContents(_ path: String) {
            guard let items = try? fm.contentsOfDirectory(atPath: path) else { return }
            for name in items {
                let itemPath = (path as NSString).appendingPathComponent(name)
                do { try fm.removeItem(atPath: itemPath) }
                catch { failures.append("\(name): \(error.localizedDescription)") }
            }
        }

        switch def.action {
        case .deleteContents:
            if fm.fileExists(atPath: def.path) { purgeContents(def.path) }
        case .recreateDir:
            try? fm.removeItem(atPath: def.path)
            try? fm.createDirectory(atPath: def.path, withIntermediateDirectories: true)
        case .npmClean:
            _ = Shell.run("npm", ["cache", "clean", "--force"], timeout: 10)
            try? fm.removeItem(atPath: def.path)
        case .pubClean:
            _ = Shell.run("dart", ["pub", "cache", "clean", "-f"], timeout: 15)
        case .simErase:
            _ = Shell.run("xcrun", ["simctl", "erase", "all"], timeout: 15)
            _ = Shell.run("xcrun", ["simctl", "delete", "unavailable"], timeout: 10)
            if fm.fileExists(atPath: def.path) { purgeContents(def.path) }
        case .emptyTrash:
            if fm.fileExists(atPath: def.path) { purgeContents(def.path) }
        }

        FolderSizeCache.shared.invalidate(def.path)
        if !failures.isEmpty {
            return (false, "Cleaned with \(failures.count) item(s) skipped (e.g. \(failures[0])) - they may need administrator permission")
        }
        return (true, "Cleaned successfully")
    }
}
