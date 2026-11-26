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

                // Items in ~/Library/LaunchAgents, /Library/LaunchAgents, and /Library/LaunchDaemons
                // are all user- or third-party-managed and can be toggled (system folders use admin prompt).
                let canToggle = dir.hasPrefix(home) || dir == "/Library/LaunchAgents" || dir == "/Library/LaunchDaemons"

                result.items.append(StartupItem(
                    fileName: fileName, path: fullPath, type: type, label: label, program: program,
                    isDisabled: isDisabled, canToggle: canToggle
                ))
            }
        }
        return result
    }

    @discardableResult
    static func toggle(_ pathStr: String?) -> (success: Bool, message: String) {
        guard let pathStr, !pathStr.isEmpty else { return (false, "Empty path") }
        guard FileManager.default.fileExists(atPath: pathStr) else {
            return (false, "Startup file not found")
        }

        let isDisable = !pathStr.hasSuffix(".disabled")
        let targetPath = isDisable ? (pathStr + ".disabled") : String(pathStr.dropLast(".disabled".count))

        // 1. User LaunchAgents (~/Library/LaunchAgents): no admin password needed
        if pathStr.hasPrefix(home) {
            do {
                if isDisable {
                    _ = Shell.run("launchctl", ["unload", pathStr])
                    try FileManager.default.moveItem(atPath: pathStr, toPath: targetPath)
                    return (true, "Disabled startup item")
                } else {
                    try FileManager.default.moveItem(atPath: pathStr, toPath: targetPath)
                    _ = Shell.run("launchctl", ["load", targetPath])
                    return (true, "Enabled startup item")
                }
            } catch {
                return (false, error.localizedDescription)
            }
        }

        // 2. System LaunchAgents & LaunchDaemons (/Library/LaunchAgents, /Library/LaunchDaemons):
        // Require administrator authorization via native macOS prompt.
        guard pathStr.hasPrefix("/Library/LaunchAgents/") || pathStr.hasPrefix("/Library/LaunchDaemons/") else {
            return (false, "Cannot modify Apple-protected SIP startup items")
        }

        let isDaemon = pathStr.hasPrefix("/Library/LaunchDaemons/")
        let uid = getuid()
        let domain = isDaemon ? "system" : "gui/\(uid)"
        let qSrc = pathStr.replacingOccurrences(of: "'", with: "'\\''")
        let qDst = targetPath.replacingOccurrences(of: "'", with: "'\\''")

        let cmd: String
        if isDisable {
            cmd = "launchctl bootout \(domain) '\(qSrc)' 2>/dev/null || launchctl unload '\(qSrc)' 2>/dev/null || true; mv '\(qSrc)' '\(qDst)'"
        } else {
            cmd = "mv '\(qSrc)' '\(qDst)' && (launchctl bootstrap \(domain) '\(qDst)' 2>/dev/null || launchctl load '\(qDst)' 2>/dev/null || true)"
        }

        let res = Shell.runAsAdmin(cmd)
        if res.ok {
            return (true, isDisable ? "Disabled system startup item" : "Enabled system startup item")
        }
        return (false, res.stderr.isEmpty ? "Administrator authorization cancelled or failed" : res.stderr)
    }
}
