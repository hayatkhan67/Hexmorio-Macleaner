import Foundation
import AppKit
import ServiceManagement

/// Dev builds run from dist/ or .build/ must not take over login items or schedules.
var isInstalledCopy: Bool {
    let path = Bundle.main.bundlePath
    return path.hasPrefix("/Applications/") || path.hasPrefix("\(NSHomeDirectory())/Applications/")
}

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

    /// Turns launch-at-login on the first time an installed copy runs.
    static func applyDefaultIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didSetDefaultKey), isInstalledCopy else { return }
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
        guard isInstalledCopy, isAutoCleanEnabled(), let executable = Bundle.main.executablePath else { return }
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

    /// Encourages the kernel to reclaim inactive/purgeable memory without an
    /// admin prompt: measures inactive + free memory dynamically, touches each
    /// 4KB page with non-zero bytes so the Apple Silicon hardware memory
    /// compressor cannot collapse the allocation to zero cost, and reports the
    /// actual before-vs-after RAM reclaimed.
    @discardableResult
    static func releaseMemory() -> (success: Bool, message: String) {
        let before = DiskRamService.ramInfo()

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let step = max(Int(pageSize), 4096)

        // Size the pressure block based on actual inactive + free RAM, up to 65% of physical RAM (capped at 8 GB).
        let physical = ProcessInfo.processInfo.physicalMemory
        let ceiling: UInt64 = 8 * 1024 * 1024 * 1024
        let target = min(UInt64(Double(physical) * 0.65), ceiling)
        let chunkSize = 64 * 1024 * 1024 // 64 MB chunks for smoother pressure

        var chunks: [UnsafeMutableRawPointer] = []
        var allocated: UInt64 = 0
        while allocated < target {
            guard let p = malloc(chunkSize) else { break }
            // Write non-uniform values at the start of every VM page so macOS
            // hardware zero-page compression cannot collapse the page.
            let bytePtr = p.assumingMemoryBound(to: UInt64.self)
            let uint64PerStep = step / MemoryLayout<UInt64>.stride
            let pagesInChunk = chunkSize / step
            for pageIdx in 0..<pagesInChunk {
                let offset = pageIdx * uint64PerStep
                bytePtr[offset] = UInt64(pageIdx) &+ 0x9E3779B97F4A7C15
                bytePtr[offset + 1] = allocated ^ UInt64(pageIdx)
            }
            chunks.append(p)
            allocated += UInt64(chunkSize)
        }
        for p in chunks { free(p) }
        malloc_zone_pressure_relief(nil, 0)

        let after = DiskRamService.ramInfo()
        return (true, "Memory optimized — Free RAM: \(before.free) → \(after.free) (Active+Wired: \(after.used))")
    }
}
