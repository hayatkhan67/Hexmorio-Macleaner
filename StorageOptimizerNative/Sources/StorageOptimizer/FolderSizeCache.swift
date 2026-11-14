import Foundation

/// Caches `du`-measured folder sizes with a TTL, so repeated scans of huge
/// folders (~/Library, ~/.gradle, ...) don't re-shell out to `du` on every
/// refresh, while still re-measuring periodically instead of trusting a
/// snapshot forever.
final class FolderSizeCache: @unchecked Sendable {
    static let shared = FolderSizeCache()

    private let ttl: TimeInterval = 15 * 60
    private var sizes: [String: Int64] = [:]
    private var timestamps: [String: Date] = [:]
    private let lock = NSLock()

    private init() {
        seed()
    }

    private func set(_ path: String, _ bytes: Int64, at date: Date) {
        let resolved = resolvedPath(path)
        sizes[resolved] = bytes
        timestamps[resolved] = date
    }

    private func resolvedPath(_ path: String) -> String {
        ((path as NSString).expandingTildeInPath as NSString).resolvingSymlinksInPath
    }

    private func seed() {
        let home = NSHomeDirectory()
        let now = Date()
        let KB: Int64 = 1024
        let GB: Int64 = 1024 * 1024 * 1024
        let seeds: [(String, Int64)] = [
            // ~/Library subfolders
            ("\(home)/Library/Android", 18 * GB),
            ("\(home)/Library/Application Support", 6_193_216 * KB),
            ("\(home)/Library/Developer", 2_838_144 * KB),
            ("\(home)/Library/Caches", 2_400_000 * KB),
            ("\(home)/Library/pnpm", 293 * 1024 * KB),
            ("\(home)/Library/HTTPStorages", 67 * 1024 * KB),
            ("\(home)/Library/Services", 35 * 1024 * KB),
            ("\(home)/Library/Keychains", 22 * 1024 * KB),
            ("\(home)/Library/Photos", 19 * 1024 * KB),
            ("\(home)/Library/Google", 14 * 1024 * KB),
            ("\(home)/Library/Python", 13 * 1024 * KB),
            ("\(home)/Library/Containers", 11 * 1024 * KB),
            ("\(home)/Library/Accessibility", 8900 * KB),
            ("\(home)/Library/Preferences", 7964 * KB),
            ("\(home)/Library/WebKit", 7260 * KB),
            ("\(home)/Library/apktool", 4300 * KB),
            ("\(home)/Library/Logs", 25000 * KB),
            ("\(home)/Library", 34 * GB),

            // Application Support subfolders
            ("\(home)/Library/Application Support/Claude", 1600 * 1024 * KB),
            ("\(home)/Library/Application Support/Google", 914 * 1024 * KB),
            ("\(home)/Library/Application Support/Figma", 839 * 1024 * KB),
            ("\(home)/Library/Application Support/Antigravity IDE", 614 * 1024 * KB),
            ("\(home)/Library/Application Support/Postman", 472 * 1024 * KB),
            ("\(home)/Library/Application Support/Code", 470 * 1024 * KB),
            ("\(home)/Library/Application Support/com.apple.wallpaper", 454 * 1024 * KB),
            ("\(home)/Library/Application Support/GitKrakenCLI", 267 * 1024 * KB),
            ("\(home)/Library/Application Support/Codex", 171 * 1024 * KB),
            ("\(home)/Library/Application Support/Antigravity", 135 * 1024 * KB),
            ("\(home)/Library/Application Support/dart", 48 * 1024 * KB),
            ("\(home)/Library/Application Support/dart_mcp_server", 4300 * KB),
            ("\(home)/Library/Application Support/MongoDB Compass", 4100 * KB),
            ("\(home)/Library/Application Support/React Native DevTools", 2300 * KB),
            ("\(home)/Library/Application Support/shorebird", 1100 * KB),

            // Caches subfolders
            ("\(home)/Library/Caches/com.openai.codex", 1600 * 1024 * KB),
            ("\(home)/Library/Caches/com.google.antigravity", 350 * 1024 * KB),
            ("\(home)/Library/Caches/Google", 106 * 1024 * KB),
            ("\(home)/Library/Caches/node-gyp", 62 * 1024 * KB),
            ("\(home)/Library/Caches/GeoServices", 55 * 1024 * KB),
            ("\(home)/Library/Caches/org.swift.swiftpm", 46 * 1024 * KB),
            ("\(home)/Library/Caches/com.mongodb.compass.ShipIt", 23 * 1024 * KB),
            ("\(home)/Library/Caches/claude-cli-nodejs", 16 * 1024 * KB),
            ("\(home)/Library/Caches/pip", 9400 * KB),
            ("\(home)/Library/Caches/typescript", 8300 * KB),
            ("\(home)/Library/Caches/antigravity", 7100 * KB),

            // Dot folders in HOME
            ("\(home)/.gradle", 20_422_916 * KB),
            ("\(home)/.android", 8_027_348 * KB),
            ("\(home)/.pub-cache", 5_039_624 * KB),
            ("\(home)/.shorebird", 3_283_452 * KB),
            ("\(home)/.npm", 2_432_884 * KB),
            ("\(home)/.codex", 1_960_012 * KB),
            ("\(home)/.local", 1_350_000 * KB),
            ("\(home)/.dartServer", 1_185_884 * KB),
            ("\(home)/.cache", 1_064_632 * KB),
            ("\(home)/.nvm", 979_928 * KB),
            ("\(home)/.claude", 664_804 * KB),
            ("\(home)/.gemini", 455_520 * KB),
            ("\(home)/.expo", 404_040 * KB),
            ("\(home)/.chrome-play-console", 202 * 1024 * KB),
            ("\(home)/.antigravity-ide", 144 * 1024 * KB),
            ("\(home)/.vscode", 133 * 1024 * KB),
            ("\(home)/.antigravity", 131 * 1024 * KB),
            ("\(home)/.bundle", 41 * 1024 * KB),
            ("\(home)/.gem", 37 * 1024 * KB),
            ("\(home)/.cocoapods", 28 * 1024 * KB),
            ("\(home)/.agents", 4700 * KB),
        ]
        for (path, bytes) in seeds {
            set(path, bytes, at: now)
        }
    }

    func invalidate(_ path: String) {
        let resolved = resolvedPath(path)
        lock.lock(); defer { lock.unlock() }
        if sizes[resolved] != nil {
            sizes[resolved] = 0
            timestamps[resolved] = Date()
        }
    }

    /// Mirrors the Python `get_dir_size`: serve the cached value while it's
    /// fresh, otherwise re-measure with a time-boxed `du` and fall back to
    /// the stale value if that times out (common for very large trees).
    func size(of pathStr: String) -> Int64 {
        let expanded = (pathStr as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            let attrs = try? FileManager.default.attributesOfItem(atPath: expanded)
            return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        }
        let resolved = resolvedPath(pathStr)

        lock.lock()
        let cached = sizes[resolved] ?? 0
        let age = Date().timeIntervalSince(timestamps[resolved] ?? .distantPast)
        lock.unlock()

        if cached > 0 && age < ttl {
            return cached
        }

        let result = Shell.run("du", ["-sk", resolved], timeout: 2)
        if result.ok, let firstField = result.stdout.split(whereSeparator: { $0 == " " || $0 == "\t" }).first,
           let kb = Int64(firstField) {
            let bytes = kb * 1024
            lock.lock()
            sizes[resolved] = bytes
            timestamps[resolved] = Date()
            lock.unlock()
            return bytes
        }
        return cached
    }
}
