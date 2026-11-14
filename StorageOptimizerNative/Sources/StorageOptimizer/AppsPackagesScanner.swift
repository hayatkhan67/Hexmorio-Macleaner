import Foundation

struct AppsScanResult {
    var apps: [AppInfo] = []
    var totalBytes: Int64 = 0
    var totalFormatted: String { formatBytes(totalBytes) }
}

enum AppsScanner {
    static func scan() -> AppsScanResult {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let appDirs = ["/Applications", "\(home)/Applications"]

        // Batch `du` over every .app bundle at once, same trick the Python
        // backend used, to avoid one subprocess per app.
        var bundlePaths: [String] = []
        for dir in appDirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                bundlePaths.append((dir as NSString).appendingPathComponent(item))
            }
        }

        var rawSizes: [String: Int64] = [:]
        if !bundlePaths.isEmpty {
            let result = Shell.run("du", ["-sk"] + bundlePaths, timeout: 15)
            for line in result.stdout.split(separator: "\n") {
                let parts = line.split(separator: "\t", maxSplits: 1)
                if parts.count == 2, let kb = Int64(parts[0]) {
                    rawSizes[String(parts[1])] = kb * 1024
                }
            }
        }

        var scanResult = AppsScanResult()
        for path in bundlePaths {
            let size = rawSizes[path] ?? 0
            let isUserApp = path.hasPrefix(home)
            let name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
            scanResult.apps.append(AppInfo(name: name, path: path, sizeBytes: size, isUserApp: isUserApp))
            scanResult.totalBytes += size
        }
        scanResult.apps.sort { $0.sizeBytes > $1.sizeBytes }
        return scanResult
    }
}

struct PackagesScanResult {
    var brew: [BrewPackage] = []
    var npm: [NpmPackage] = []
    var pip: [PipPackage] = []
    var brewTotalBytes: Int64 = 0
    var brewTotalFormatted: String { formatBytes(brewTotalBytes) }
}

enum PackagesScanner {
    static func scan() -> PackagesScanResult {
        var result = PackagesScanResult()
        let fm = FileManager.default

        // 1. Homebrew formulas
        for cellar in ["/opt/homebrew/Cellar", "/usr/local/Cellar"] {
            guard fm.fileExists(atPath: cellar), let items = try? fm.contentsOfDirectory(atPath: cellar) else { continue }
            for name in items {
                let full = (cellar as NSString).appendingPathComponent(name)
                let du = Shell.run("du", ["-sk", full], timeout: 2)
                guard du.ok, let field = du.stdout.split(separator: "\t").first, let kb = Int64(field) else { continue }
                let bytes = kb * 1024
                result.brewTotalBytes += bytes
                result.brew.append(BrewPackage(name: name, path: full, sizeBytes: bytes))
            }
        }
        result.brew.sort { $0.sizeBytes > $1.sizeBytes }

        // 2. Global npm packages
        let npmResult = Shell.run("npm", ["list", "-g", "--depth=0", "--json"], timeout: 5)
        if npmResult.ok, let data = npmResult.stdout.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let deps = json["dependencies"] as? [String: Any] {
            for (name, info) in deps {
                let version = (info as? [String: Any])?["version"] as? String ?? "unknown"
                result.npm.append(NpmPackage(name: name, version: version))
            }
        }
        result.npm.sort { $0.name < $1.name }

        // 3. Pip packages
        let pipResult = Shell.run("python3", ["-m", "pip", "list", "--format=json"], timeout: 5)
        if pipResult.ok, let data = pipResult.stdout.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for p in arr {
                guard let name = p["name"] as? String else { continue }
                result.pip.append(PipPackage(name: name, version: p["version"] as? String ?? "unknown"))
            }
        }
        result.pip.sort { $0.name < $1.name }

        return result
    }
}
