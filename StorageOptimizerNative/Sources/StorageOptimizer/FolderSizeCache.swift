import Foundation

/// Caches directory sizes with a TTL so repeated UI refreshes don't re-walk
/// huge trees unnecessarily, while providing fast native allocated-size
/// calculation and explicit cache clearing on user-initiated Rescan.
final class FolderSizeCache: @unchecked Sendable {
    static let shared = FolderSizeCache()

    private let ttl: TimeInterval = 5 * 60
    private var sizes: [String: Int64] = [:]
    private var timestamps: [String: Date] = [:]
    private let lock = NSLock()

    private init() {}

    private func resolvedPath(_ path: String) -> String {
        ((path as NSString).expandingTildeInPath as NSString).resolvingSymlinksInPath
    }

    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        sizes.removeAll()
        timestamps.removeAll()
    }

    func invalidate(_ path: String) {
        let resolved = resolvedPath(path)
        lock.lock(); defer { lock.unlock() }
        sizes.removeValue(forKey: resolved)
        timestamps.removeValue(forKey: resolved)
    }

    /// Computes on-disk allocated size using native URLResourceValues inside
    /// `autoreleasepool` blocks. Never times out, spawns zero subprocesses,
    /// and skips protected directories when Full Disk Access isn't granted.
    static func fastDirectorySize(atPath pathStr: String, checkProtected: Bool = false) -> Int64 {
        let fm = FileManager.default
        let expanded = (pathStr as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: expanded, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            let attrs = try? fm.attributesOfItem(atPath: expanded)
            return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        }

        let skipProtected = checkProtected && !Permissions.hasFullDiskAccess
        if skipProtected && Permissions.isProtected(expanded) { return 0 }

        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey
        ]
        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: expanded),
            includingPropertiesForKeys: keys,
            options: []
        ) else { return 0 }

        let keySet = Set(keys)
        var total: Int64 = 0
        var count = 0

        while true {
            var shouldBreak = false
            autoreleasepool {
                guard let nextObj = enumerator.nextObject() else {
                    shouldBreak = true
                    return
                }
                guard let url = nextObj as? URL else { return }
                count += 1

                if skipProtected && Permissions.isProtected(url.path) {
                    enumerator.skipDescendants()
                    return
                }

                guard let values = try? url.resourceValues(forKeys: keySet) else { return }
                if values.isSymbolicLink == true { return }
                if values.isRegularFile == true {
                    let fileBytes = values.totalFileAllocatedSize
                        ?? values.fileAllocatedSize
                        ?? values.fileSize
                        ?? 0
                    total += Int64(fileBytes)
                }
            }
            if shouldBreak { break }
        }
        return total
    }

    /// Returns cached size if fresh; otherwise measures using `du -sk` with a
    /// generous timeout and falls back to native `fastDirectorySize` if `du`
    /// times out so large folders are never dropped as 0 B.
    func size(of pathStr: String, forceRefresh: Bool = false) -> Int64 {
        let expanded = (pathStr as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue {
            let attrs = try? FileManager.default.attributesOfItem(atPath: expanded)
            return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        }
        let resolved = resolvedPath(pathStr)

        if !forceRefresh {
            lock.lock()
            let cached = sizes[resolved]
            let ts = timestamps[resolved] ?? .distantPast
            lock.unlock()
            if let cached, Date().timeIntervalSince(ts) < ttl {
                return cached
            }
        }

        let hasFDA = Permissions.hasFullDiskAccess
        if !hasFDA && Permissions.isProtected(resolved) { return 0 }

        var args = ["-sk"]
        if !hasFDA {
            args += Permissions.duExcludeArgs
        }
        let result = Shell.run("/usr/bin/du", args + [resolved], timeout: 20)
        // du exits 1 when any subfolder is unreadable but still prints a usable total line at the end.
        if let lastLine = result.stdout.split(separator: "\n").last,
           let firstField = lastLine.split(whereSeparator: { $0 == " " || $0 == "\t" }).first,
           let kb = Int64(firstField) {
            let bytes = kb * 1024
            lock.lock()
            sizes[resolved] = bytes
            timestamps[resolved] = Date()
            lock.unlock()
            return bytes
        }

        // If `du` timed out on a huge tree, fall back to native enumeration so we never report 0 B.
        let fallbackBytes = Self.fastDirectorySize(atPath: resolved, checkProtected: true)
        lock.lock()
        sizes[resolved] = fallbackBytes
        timestamps[resolved] = Date()
        lock.unlock()
        return fallbackBytes
    }
}
