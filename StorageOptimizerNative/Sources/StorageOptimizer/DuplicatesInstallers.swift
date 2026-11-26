import Foundation
import CryptoKit

struct DuplicatesScanResult {
    var groups: [DuplicateGroup] = []
    var wastedBytes: Int64 = 0
    var wastedFormatted: String { formatBytes(wastedBytes) }
}

enum DuplicatesScanner {
    private static let skippedDirs: Set<String> = ProjectLocations.skippedDirectoryNames.union([
        "node_modules", "Pods", ".git", "build", ".build", ".dart_tool",
        ".next", ".nuxt", ".gradle", "DerivedData", "target", ".venv", "venv"
    ])

    private static let maxDepth = 4

    static func scan() -> DuplicatesScanResult {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let searchDirs = ["\(home)/Downloads", "\(home)/Desktop", "\(home)/Documents"]

        var sizeMap: [Int64: [(path: String, mtime: Date)]] = [:]
        for dir in searchDirs {
            let rootDepth = dir.split(separator: "/").count
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey],
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
                    guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .fileSizeKey, .contentModificationDateKey]) else { return }

                    if values.isSymbolicLink == true {
                        if values.isDirectory == true { enumerator.skipDescendants() }
                        return
                    }
                    if values.isDirectory == true {
                        let depth = url.path.split(separator: "/").count - rootDepth
                        if depth >= maxDepth || skippedDirs.contains(name) || values.isPackage == true {
                            enumerator.skipDescendants()
                        }
                        return
                    }
                    let size = Int64(values.fileSize ?? 0)
                    guard size > 10 * 1024 else { return } // Ignore tiny <10KB files
                    let mtime = values.contentModificationDate ?? .distantPast
                    sizeMap[size, default: []].append((url.path, mtime))
                }
                if finished { break }
            }
        }

        var result = DuplicatesScanResult()
        for (size, files) in sizeMap where files.count > 1 {
            var hashMap: [String: [DuplicateFile]] = [:]
            for (path, mtime) in files {
                guard let digest = fullFileHash(path) else { continue }
                hashMap[digest, default: []].append(DuplicateFile(
                    name: (path as NSString).lastPathComponent, path: path, sizeBytes: size, modified: mtime
                ))
            }
            for (hash, var matches) in hashMap where matches.count > 1 {
                matches.sort { $0.modified > $1.modified }
                result.wastedBytes += Int64(matches.count - 1) * size
                result.groups.append(DuplicateGroup(id: hash, fileSizeBytes: size, files: matches))
            }
        }
        result.groups.sort { ($0.fileSizeBytes * Int64($0.files.count)) > ($1.fileSizeBytes * Int64($1.files.count)) }
        return result
    }

    /// Hashes the *entire* file in streamed chunks - never just a prefix, so
    /// two different files that happen to share a size and leading bytes are
    /// never mistaken for duplicates (and deleted).
    private static func fullFileHash(_ path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            var done = false
            autoreleasepool {
                let chunk = handle.readData(ofLength: 1024 * 1024)
                if chunk.isEmpty {
                    done = true
                } else {
                    hasher.update(data: chunk)
                }
            }
            if done { break }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

struct InstallersScanResult {
    var installers: [InstallerFile] = []
    var totalBytes: Int64 = 0
    var totalFormatted: String { formatBytes(totalBytes) }
}

enum InstallersScanner {
    static let extensions: Set<String> = ["dmg", "pkg", "apk", "ipa", "aab", "iso", "zip", "tar.gz", "tgz", "xip"]

    private static let skippedDirs: Set<String> = ProjectLocations.skippedDirectoryNames.union([
        "node_modules", "Pods", ".git", ".dart_tool", ".next", ".nuxt",
        ".gradle", "DerivedData", "target", ".venv", "venv"
    ])

    private static let maxDepth = 5

    static func scan() -> InstallersScanResult {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let hasFDA = Permissions.hasFullDiskAccess
        var result = InstallersScanResult()
        var seen = Set<String>()

        for root in ProjectLocations.searchRoots(fm: fm, home: home) {
            let rootDepth = root.split(separator: "/").count
            guard let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: root),
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
                        let depth = url.path.split(separator: "/").count - rootDepth
                        if depth >= maxDepth || skippedDirs.contains(name) ||
                           values.isPackage == true || name.hasSuffix(".app") ||
                           (!hasFDA && Permissions.isProtected(url.path)) {
                            enumerator.skipDescendants()
                        }
                        return
                    }

                    let lower = name.lowercased()
                    let ext = (lower as NSString).pathExtension
                    let isTarGz = lower.hasSuffix(".tar.gz")
                    guard extensions.contains(ext) || isTarGz else { return }

                    let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
                    guard size >= 10 * 1024 * 1024 else { return }
                    guard seen.insert(url.path).inserted else { return }

                    result.totalBytes += size
                    result.installers.append(InstallerFile(name: name, path: url.path, sizeBytes: size))
                }
                if finished { break }
            }
        }
        result.installers.sort { $0.sizeBytes > $1.sizeBytes }
        return result
    }
}
