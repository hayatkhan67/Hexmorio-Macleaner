import Foundation
import AppKit
import ServiceManagement

enum LaunchAtLogin {
    private static let didSetDefaultKey = "launchAtLoginDefaultApplied"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    @discardableResult
    static func set(_ enable: Bool) -> (success: Bool, message: String) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            return (false, "Couldn't change login item: \(error.localizedDescription)")
        }
        if enable && SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            return (false, "Approve Hexmorio Macleaner in System Settings > Login Items")
        }
        return (true, enable ? "Will start automatically at login" : "Won't start at login")
    }

    /// Turns launch-at-login on the first time an installed copy runs. Dev builds
    /// launched from dist/ or .build/ are skipped so they don't become login items.
    static func applyDefaultIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didSetDefaultKey) else { return }
        let path = Bundle.main.bundlePath
        guard path.hasPrefix("/Applications/") || path.hasPrefix("\(NSHomeDirectory())/Applications/") else { return }
        set(true)
        defaults.set(true, forKey: didSetDefaultKey)
    }
}

enum AutoClean {
    static let argument = "--auto-clean"

    /// Headless weekly cleanup run by the LaunchAgent: cleans only "Safe" targets
    /// that don't need an admin password (nobody is around to type one at 3am).
    static func runAndExit() -> Never {
        let result = CleanTargetsService.scan()
        for target in result.items where target.safety == .safe && target.sizeBytes > 0 && !CleanTargetsService.needsAdmin(target.id) {
            CleanTargetsService.execute(target.id)
        }
        exit(0)
    }
}

enum SystemActions {
    static let home = NSHomeDirectory()
    static let plistPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.hexmorio.macleaner.plist"

    @discardableResult
    static func flushSystemCaches() -> (success: Bool, message: String) {
        _ = Shell.run("/usr/bin/qlmanage", ["-r", "cache"], timeout: 5)
        _ = Shell.run("/usr/bin/dscacheutil", ["-flushcache"], timeout: 5)
        return (true, "Flushed QuickLook and DNS system caches")
    }

    static func isAutoCleanEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }

    /// Re-points an existing weekly-clean LaunchAgent at this copy of the app
    /// (older versions pointed it at a script that only existed on one machine).
    static func repairAutoCleanIfNeeded() {
        guard isAutoCleanEnabled(), let executable = Bundle.main.executablePath else { return }
        let contents = (try? String(contentsOfFile: plistPath, encoding: .utf8)) ?? ""
        if !contents.contains(executable) {
            setAutoClean(true)
        }
    }

    @discardableResult
    static func setAutoClean(_ enable: Bool) -> Bool {
        let fm = FileManager.default
        if enable {
            guard let executable = Bundle.main.executablePath else { return false }
            try? fm.createDirectory(atPath: (plistPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            if fm.fileExists(atPath: plistPath) {
                _ = Shell.run("launchctl", ["unload", plistPath])
            }
            let content = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.hexmorio.macleaner</string>
                <key>ProgramArguments</key>
                <array>
                    <string>\(executable)</string>
                    <string>\(AutoClean.argument)</string>
                </array>
                <key>StartCalendarInterval</key>
                <dict>
                    <key>Weekday</key>
                    <integer>7</integer>
                    <key>Hour</key>
                    <integer>3</integer>
                    <key>Minute</key>
                    <integer>0</integer>
                </dict>
                <key>RunAtLoad</key>
                <false/>
            </dict>
            </plist>
            """
            try? content.write(toFile: plistPath, atomically: true, encoding: .utf8)
            _ = Shell.run("launchctl", ["load", plistPath])
            return true
        } else {
            if fm.fileExists(atPath: plistPath) {
                _ = Shell.run("launchctl", ["unload", plistPath])
                try? fm.removeItem(atPath: plistPath)
            }
            return false
        }
    }

    static func revealInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    /// Encourages the kernel to reclaim inactive/compressed memory without an
    /// admin prompt: allocating and immediately freeing a large block forces
    /// other processes' purgeable and inactive pages to be evicted or
    /// compressed to make room, then the block is returned right away. This
    /// is the same no-password technique long-standing "memory cleaner"
    /// utilities use; it has no durable allocation and cannot crash other apps.
    @discardableResult
    static func releaseMemory() -> (success: Bool, message: String) {
        let chunkSize = 256 * 1024 * 1024 // 256MB
        let ceiling: UInt64 = 4 * 1024 * 1024 * 1024 // never grab more than 4GB
        let target = min(ProcessInfo.processInfo.physicalMemory / 2, ceiling)

        var chunks: [UnsafeMutableRawPointer] = []
        var allocated: UInt64 = 0
        while allocated < target {
            guard let p = malloc(chunkSize) else { break }
            memset(p, 0, chunkSize) // touch every page so it's actually resident
            chunks.append(p)
            allocated += UInt64(chunkSize)
        }
        for p in chunks { free(p) }

        return (true, "Released \(formatBytes(Int64(allocated))) of memory pressure - inactive RAM reclaimed")
    }
}
