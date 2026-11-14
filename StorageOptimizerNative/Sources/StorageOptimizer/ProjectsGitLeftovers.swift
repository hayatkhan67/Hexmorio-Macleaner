import Foundation

enum ProjectBuildsScanner {
    static func scan() -> [ProjectArtifact] {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let projectsDir = "\(home)/projects"
        guard fm.fileExists(atPath: projectsDir) else { return [] }

        var results: [ProjectArtifact] = []
        guard let topLevel = try? fm.contentsOfDirectory(atPath: projectsDir) else { return [] }

        for projectName in topLevel where !projectName.hasPrefix(".") {
            let projectPath = (projectsDir as NSString).appendingPathComponent(projectName)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectPath, isDirectory: &isDir), isDir.boolValue else { continue }

            var candidates = [projectPath]
            if let subs = try? fm.contentsOfDirectory(atPath: projectPath) {
                let excluded: Set<String> = ["node_modules", "Pods", ".git", "build"]
                for sub in subs where !sub.hasPrefix(".") && !excluded.contains(sub) {
                    let subPath = (projectPath as NSString).appendingPathComponent(sub)
                    var subIsDir: ObjCBool = false
                    if fm.fileExists(atPath: subPath, isDirectory: &subIsDir), subIsDir.boolValue {
                        candidates.append(subPath)
                    }
                }
            }

            for candidate in candidates {
                for target in ["build", ".dart_tool", "ios/Pods", "node_modules"] {
                    let targetPath = (candidate as NSString).appendingPathComponent(target)
                    guard fm.fileExists(atPath: targetPath) else { continue }
                    // node_modules can hold tens of thousands of small files,
                    // so `du` needs more time than the other, flatter targets.
                    let timeout: TimeInterval = target == "node_modules" ? 8 : 2
                    let du = Shell.run("du", ["-sk", targetPath], timeout: timeout)
                    guard du.ok, let field = du.stdout.split(separator: "\t").first, let kb = Int64(field), kb > 1024 else { continue }
                    let bytes = kb * 1024
                    let typeLabel: String
                    switch target {
                    case "build": typeLabel = "Flutter Build"
                    case ".dart_tool": typeLabel = "Dart Tool Cache"
                    case "node_modules": typeLabel = "Node Modules"
                    default: typeLabel = "CocoaPods Pods"
                    }
                    results.append(ProjectArtifact(
                        project: (candidate as NSString).lastPathComponent, type: target.replacingOccurrences(of: "ios/", with: ""),
                        typeLabel: typeLabel, path: targetPath, sizeBytes: bytes
                    ))
                }
            }
        }
        results.sort { $0.sizeBytes > $1.sizeBytes }
        return results
    }
}

enum GitReposScanner {
    static func scan() -> [GitRepo] {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let projectsDir = "\(home)/projects"
        guard fm.fileExists(atPath: projectsDir), let items = try? fm.contentsOfDirectory(atPath: projectsDir) else { return [] }

        var results: [GitRepo] = []
        for name in items where !name.hasPrefix(".") {
            let projectPath = (projectsDir as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectPath, isDirectory: &isDir), isDir.boolValue else { continue }
            let gitDir = (projectPath as NSString).appendingPathComponent(".git")
            guard fm.fileExists(atPath: gitDir) else { continue }
            let du = Shell.run("du", ["-sk", gitDir], timeout: 2)
            guard du.ok, let field = du.stdout.split(separator: "\t").first, let kb = Int64(field), kb > 2048 else { continue }
            results.append(GitRepo(name: name, path: projectPath, sizeBytes: kb * 1024))
        }
        results.sort { $0.sizeBytes > $1.sizeBytes }
        return results
    }

    @discardableResult
    static func optimize(_ path: String) -> (success: Bool, message: String) {
        let result = Shell.run("git", ["-C", path, "gc", "--prune=now"], timeout: 15)
        return result.ok ? (true, "Optimized git repository") : (false, result.stderr)
    }
}

enum LeftoversScanner {
    static func scan() -> [LeftoverItem] {
        let fm = FileManager.default
        let home = NSHomeDirectory()

        var installedApps = Set<String>()
        for dir in ["/Applications", "\(home)/Applications"] {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                installedApps.insert((item as NSString).deletingPathExtension.lowercased())
            }
        }

        let appSupport = "\(home)/Library/Application Support"
        guard let items = try? fm.contentsOfDirectory(atPath: appSupport) else { return [] }

        var results: [LeftoverItem] = []
        for name in items where !name.hasPrefix(".") && !name.hasPrefix("com.apple") {
            let full = (appSupport as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { continue }

            let cleanName = name.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
            let matched = installedApps.contains { cleanName.contains($0) || $0.contains(cleanName) }
            guard !matched else { continue }

            let du = Shell.run("du", ["-sk", full], timeout: 2)
            guard du.ok, let field = du.stdout.split(separator: "\t").first, let kb = Int64(field), kb > 5120 else { continue }
            results.append(LeftoverItem(name: name, path: full, sizeBytes: kb * 1024))
        }
        results.sort { $0.sizeBytes > $1.sizeBytes }
        return results
    }
}
