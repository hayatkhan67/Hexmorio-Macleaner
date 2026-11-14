import Foundation

struct StartupScanResult {
    var items: [StartupItem] = []
}

enum StartupScanner {
    static let home = NSHomeDirectory()

    static let launchDirs: [(String, String)] = [
        ("User LaunchAgent", "\(home)/Library/LaunchAgents"),
        ("System LaunchAgent", "/Library/LaunchAgents"),
        ("System LaunchDaemon", "/Library/LaunchDaemons"),
    ]

    static func scan() -> StartupScanResult {
        let fm = FileManager.default
        var result = StartupScanResult()

        for (type, dir) in launchDirs {
            guard let files = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for fileName in files where fileName.hasSuffix(".plist") || fileName.hasSuffix(".plist.disabled") {
                let isDisabled = fileName.hasSuffix(".disabled")
                let fullPath = (dir as NSString).appendingPathComponent(fileName)
                var label = fileName.replacingOccurrences(of: ".plist.disabled", with: "")
                    .replacingOccurrences(of: ".plist", with: "")
                var program = ""

                if let data = fm.contents(atPath: fullPath),
                   let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                    label = (plist["Label"] as? String) ?? label
                    if let args = plist["ProgramArguments"] as? [String], let first = args.first {
                        program = first
                    } else if let prog = plist["Program"] as? String {
                        program = prog
                    }
                }

                result.items.append(StartupItem(
                    fileName: fileName, path: fullPath, type: type, label: label, program: program,
                    isDisabled: isDisabled, canToggle: dir.hasPrefix(home)
                ))
            }
        }
        return result
    }

    @discardableResult
    static func toggle(_ pathStr: String?) -> (success: Bool, message: String) {
        guard let pathStr, !pathStr.isEmpty else { return (false, "Empty path") }
        guard FileManager.default.fileExists(atPath: pathStr), pathStr.hasPrefix(home) else {
            return (false, "Permission denied or file not found")
        }
        let path = pathStr as NSString
        do {
            if path.pathExtension == "disabled" || pathStr.hasSuffix(".disabled") {
                let newPath = String(pathStr.dropLast(".disabled".count))
                try FileManager.default.moveItem(atPath: pathStr, toPath: newPath)
                _ = Shell.run("launchctl", ["load", newPath])
                return (true, "Enabled startup item")
            } else {
                _ = Shell.run("launchctl", ["unload", pathStr])
                let newPath = pathStr + ".disabled"
                try FileManager.default.moveItem(atPath: pathStr, toPath: newPath)
                return (true, "Disabled startup item")
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
