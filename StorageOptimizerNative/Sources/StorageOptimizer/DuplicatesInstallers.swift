import Foundation
import CryptoKit

struct DuplicatesScanResult {
    var groups: [DuplicateGroup] = []
    var wastedBytes: Int64 = 0
    var wastedFormatted: String { formatBytes(wastedBytes) }
}

enum DuplicatesScanner {
    static func scan() -> DuplicatesScanResult {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let searchDirs = ["\(home)/Downloads", "\(home)/Desktop"]

        var sizeMap: [Int64: [(path: String, mtime: Date)]] = [:]
        for dir in searchDirs {
            guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for name in entries where !name.hasPrefix(".") {
                let full = (dir as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: full, isDirectory: &isDir), !isDir.boolValue else { continue }
                guard let attrs = try? fm.attributesOfItem(atPath: full) else { continue }
                let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
                guard size > 1024 else { continue }
                let mtime = (attrs[.modificationDate] as? Date) ?? .distantPast
                sizeMap[size, default: []].append((full, mtime))
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
            let chunk = handle.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
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
    static let extensions: Set<String> = ["dmg", "pkg", "apk", "iso", "zip", "tar.gz", "tgz"]

    static func scan() -> InstallersScanResult {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        var result = InstallersScanResult()

        for dir in ["\(home)/Downloads", "\(home)/Desktop"] {
            guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for name in entries where !name.hasPrefix(".") {
                let ext = (name as NSString).pathExtension.lowercased()
                let isTarGz = name.lowercased().hasSuffix(".tar.gz")
                guard extensions.contains(ext) || isTarGz else { continue }
                let full = (dir as NSString).appendingPathComponent(name)
                guard let attrs = try? fm.attributesOfItem(atPath: full) else { continue }
                let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
                guard size >= 10 * 1024 * 1024 else { continue }
                result.totalBytes += size
                result.installers.append(InstallerFile(name: name, path: full, sizeBytes: size))
            }
        }
        result.installers.sort { $0.sizeBytes > $1.sizeBytes }
        return result
    }
}
