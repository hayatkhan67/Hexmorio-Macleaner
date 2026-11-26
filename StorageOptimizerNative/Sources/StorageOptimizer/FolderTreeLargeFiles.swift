import Foundation

struct FolderTreeResult {
    var currentPath: String
    var parentPath: String?
    var items: [TreeItem]
}

enum FolderTreeScanner {
    static func scan(path pathStr: String, showHidden: Bool) -> FolderTreeResult {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        var targetPath = pathStr.isEmpty ? home : (pathStr as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: targetPath, isDirectory: &isDir) || !isDir.boolValue {
            targetPath = home
        }

        var items: [TreeItem] = []
        if let entries = try? fm.contentsOfDirectory(atPath: targetPath) {
            for name in entries {
                if !showHidden && name.hasPrefix(".") { continue }
                let full = (targetPath as NSString).appendingPathComponent(name)
                var entryIsDir: ObjCBool = false
                guard fm.fileExists(atPath: full, isDirectory: &entryIsDir) else { continue }

                if entryIsDir.boolValue {
                    let bytes = FolderSizeCache.shared.size(of: full)
                    if bytes > 2 * 1024 * 1024 {
                        items.append(TreeItem(name: name, path: full, isDir: true, sizeBytes: bytes))
                    }
                } else {
                    guard let attrs = try? fm.attributesOfItem(atPath: full) else { continue }
                    let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
                    if size > 5 * 1024 * 1024 {
                        items.append(TreeItem(name: name, path: full, isDir: false, sizeBytes: size))
                    }
                }
            }
        }
        items.sort { $0.sizeBytes > $1.sizeBytes }

        let parent = (targetPath != home && targetPath != "/") ? (targetPath as NSString).deletingLastPathComponent : nil
        return FolderTreeResult(currentPath: targetPath, parentPath: parent, items: Array(items.prefix(50)))
    }
}

enum LargeFilesScanner {
    static let excludedDirs: Set<String> = ProjectLocations.skippedDirectoryNames.union([
        "node_modules", "Pods", ".git", "build", ".build", ".dart_tool",
        ".next", ".nuxt", ".gradle", "DerivedData", "target", ".venv", "venv"
    ])

    static func scan(minMB: Int, maxResults: Int = 100) -> [LargeFile] {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let hasFDA = Permissions.hasFullDiskAccess
        let searchDirs = ProjectLocations.searchRoots(fm: fm, home: home)
        let minBytes = Int64(minMB) * 1024 * 1024

        var results: [LargeFile] = []
        for dir in searchDirs {
            guard fm.fileExists(atPath: dir) else { continue }
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .totalFileAllocatedSizeKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            while true {
                var finished = false
                autoreleasepool {
                    guard let nextObj = enumerator.nextObject() else {
                        finished = true
                        return
                    }
                    guard let url = nextObj as? URL else { return }
                    let name = url.lastPathComponent
                    guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .totalFileAllocatedSizeKey, .fileSizeKey]) else { return }

                    if values.isSymbolicLink == true {
                        if values.isDirectory == true { enumerator.skipDescendants() }
                        return
                    }
                    if values.isDirectory == true {
                        if excludedDirs.contains(name) || values.isPackage == true ||
                           name.hasSuffix(".app") || name.hasSuffix(".photoslibrary") ||
                           (!hasFDA && Permissions.isProtected(url.path)) {
                            enumerator.skipDescendants()
                        }
                        return
                    }
                    let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                    guard size >= minBytes else { return }
                    results.append(LargeFile(name: name, path: url.path, sizeBytes: size))
                }
                if finished { break }
            }
        }
        results.sort { $0.sizeBytes > $1.sizeBytes }
        return Array(results.prefix(maxResults))
    }
}
