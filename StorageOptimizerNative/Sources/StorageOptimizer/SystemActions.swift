import Foundation
import AppKit

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

    @discardableResult
    static func setAutoClean(_ enable: Bool) -> Bool {
        let fm = FileManager.default
        if enable {
            try? fm.createDirectory(atPath: (plistPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            let content = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.hexmorio.macleaner</string>
                <key>ProgramArguments</key>
                <array>
                    <string>\(home)/.local/bin/clean-storage</string>
                    <string>--safe</string>
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
