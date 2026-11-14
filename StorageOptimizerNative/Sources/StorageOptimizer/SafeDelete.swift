import Foundation

/// Every destructive path-based action in the app goes through this - no
/// exceptions. This is the single safety boundary that prevents a scanner
/// bug or a bad click from deleting something outside the user's home
/// directory or a known-safe system cache location.
enum SafeDelete {
    static let home = NSHomeDirectory()

    static let protectedPaths: Set<String> = {
        let home = NSHomeDirectory()
        return [
            home,
            "\(home)/Library",
            "\(home)/Desktop",
            "\(home)/Documents",
            "\(home)/Downloads",
            "\(home)/Pictures",
            "/", "/System", "/Library", "/Applications",
            "/usr", "/bin", "/sbin", "/private", "/etc", "/var",
        ]
    }()

    static func resolve(_ path: String) -> String {
        ((path as NSString).expandingTildeInPath as NSString).resolvingSymlinksInPath
    }

    static func safetyError(for resolved: String) -> String? {
        if protectedPaths.contains(resolved) {
            return "Security error: protected system or root folder cannot be deleted"
        }
        let isInHome = resolved.hasPrefix(home)
        let isInSysCache = resolved.hasPrefix("/Library/Caches") || resolved.hasPrefix("/Library/Logs")
        if !(isInHome || isInSysCache) {
            return "Security error: path must be inside user home or safe system cache"
        }
        return nil
    }

    @discardableResult
    static func deletePath(_ pathStr: String?) -> (success: Bool, message: String) {
        guard let pathStr, !pathStr.isEmpty else { return (false, "Empty path") }
        let resolved = resolve(pathStr)
        guard FileManager.default.fileExists(atPath: resolved) else { return (false, "Path does not exist") }
        if let err = safetyError(for: resolved) { return (false, err) }
        do {
            try FileManager.default.removeItem(atPath: resolved)
            FolderSizeCache.shared.invalidate(resolved)
            return (true, "Removed successfully")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    @discardableResult
    static func cleanFolderContents(_ pathStr: String?) -> (success: Bool, message: String) {
        guard let pathStr, !pathStr.isEmpty else { return (false, "Empty path") }
        let resolved = resolve(pathStr)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir), isDir.boolValue else {
            return (false, "Directory does not exist")
        }
        if let err = safetyError(for: resolved) { return (false, err) }

        var failures: [String] = []
        let fm = FileManager.default
        do {
            for name in try fm.contentsOfDirectory(atPath: resolved) {
                let itemPath = (resolved as NSString).appendingPathComponent(name)
                do {
                    try fm.removeItem(atPath: itemPath)
                } catch {
                    failures.append("\(name): \(error.localizedDescription)")
                }
            }
        } catch {
            return (false, error.localizedDescription)
        }
        FolderSizeCache.shared.invalidate(resolved)
        if !failures.isEmpty {
            return (false, "Removed most items, but \(failures.count) could not be deleted (e.g. \(failures[0])) - they may need administrator permission")
        }
        return (true, "Contents purged successfully")
    }

    /// Uses the real Finder Trash (FileManager.trashItem), which handles
    /// name collisions for us instead of the manual rename-on-collision hack
    /// the old Python backend needed.
    @discardableResult
    static func moveToTrash(_ pathStr: String?) -> (success: Bool, message: String) {
        guard let pathStr, !pathStr.isEmpty else { return (false, "Empty path") }
        let resolved = resolve(pathStr)
        guard FileManager.default.fileExists(atPath: resolved) else { return (false, "Path does not exist") }
        if let err = safetyError(for: resolved) { return (false, err) }
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: resolved), resultingItemURL: nil)
            FolderSizeCache.shared.invalidate(resolved)
            return (true, "Moved to Trash")
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
