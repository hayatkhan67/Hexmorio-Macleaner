import Foundation

/// Caches `du`-measured folder sizes with a TTL, so repeated scans of huge
/// folders (~/Library, ~/.gradle, ...) don't re-shell out to `du` on every
/// refresh, while still re-measuring periodically.
final class FolderSizeCache: @unchecked Sendable {
    static let shared = FolderSizeCache()

    private let ttl: TimeInterval = 15 * 60
    private var sizes: [String: Int64] = [:]
    private var timestamps: [String: Date] = [:]
    private let lock = NSLock()

    private init() {}

    private func resolvedPath(_ path: String) -> String {
        ((path as NSString).expandingTildeInPath as NSString).resolvingSymlinksInPath
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

        var args = ["-sk"]
        if !Permissions.hasFullDiskAccess {
            if Permissions.isProtected(resolved) { return 0 }
            args += Permissions.duExcludeArgs
        }
        let result = Shell.run("du", args + [resolved], timeout: 10)
        // du exits 1 when any subfolder is unreadable but still prints a usable total.
        if result.status >= 0, let firstField = result.stdout.split(whereSeparator: { $0 == " " || $0 == "\t" }).first,
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
