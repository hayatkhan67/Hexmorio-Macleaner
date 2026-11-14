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
    static let excludedDirs: Set<String> = ["node_modules", "Pods", ".git", "build", ".dart_tool"]

    static func scan(minMB: Int, maxResults: Int = 50) -> [LargeFile] {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let searchDirs = ["\(home)/Downloads", "\(home)/Desktop", "\(home)/Documents", "\(home)/projects"]
        let minBytes = Int64(minMB) * 1024 * 1024

        var results: [LargeFile] = []
        for dir in searchDirs {
            guard fm.fileExists(atPath: dir) else { continue }
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]) else { continue }
                if values.isDirectory == true {
                    if excludedDirs.contains(url.lastPathComponent) {
                        enumerator.skipDescendants()
                    }
                    continue
                }
                guard let size = values.fileSize, Int64(size) >= minBytes else { continue }
                results.append(LargeFile(name: url.lastPathComponent, path: url.path, sizeBytes: Int64(size)))
            }
        }
        results.sort { $0.sizeBytes > $1.sizeBytes }
        return Array(results.prefix(maxResults))
    }
}
