import Foundation
import AppKit

enum Permissions {
    /// These locations are readable only with Full Disk Access, and probing them never
    /// shows a prompt. Several are tried because their presence varies by macOS version
    /// (macOS 27 has no per-user TCC.db at all).
    static var hasFullDiskAccess: Bool {
        let home = NSHomeDirectory()
        let fileProbes = [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            "\(home)/Library/Application Support/com.apple.TCC/TCC.db",
        ]
        for path in fileProbes {
            if let handle = FileHandle(forReadingAtPath: path) {
                try? handle.close()
                return true
            }
        }
        let dirProbes = ["Safari", "Mail", "Messages", "Cookies"].map { "\(home)/Library/\($0)" }
        return dirProbes.contains { (try? FileManager.default.contentsOfDirectory(atPath: $0)) != nil }
    }

    // Touching these without Full Disk Access makes macOS show "access data from other apps",
    // Contacts, Calendars, Photos, etc. prompts - repeatedly, on every scan.
    static let protectedNames: [String] = [
        "Containers", "Group Containers", "Daemon Containers", "Mail", "Messages", "Safari",
        "Calendars", "Reminders", "AddressBook", "CallHistoryDB", "CallHistoryTransactions",
        "Mobile Documents", "CloudStorage", "HomeKit", "IdentityServices", "Cookies",
        "Suggestions", "Biome", "DuetExpertCenter", "Metadata", "Accounts", "Sharing",
        "com.apple.TCC", "Knowledge", "MobileSync", "FileProvider", "*.photoslibrary",
    ]

    static func isProtected(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent
        return protectedNames.contains { fnmatch($0, name, 0) == 0 }
    }

    /// Apple's own TCC-protected subdirectories inside `~/Library/Caches`,
    /// `~/Library/Logs`, and `~/Library/HTTPStorages`. Attempting to delete these
    /// without Full Disk Access pops up repeated macOS "Hexmorio Macleaner would
    /// like to access data from other apps" alerts during cleanup.
    private static let appleProtectedPrefixes: [String] = [
        "com.apple.", "CloudKit", "FamilyCircle", "PassKit", "GeoServices",
        "GameKit", "HomeKit", "Safari", "Mail", "Messages"
    ]

    static func isProtectedOrAppleCache(name: String, fullPath: String) -> Bool {
        if isProtected(fullPath) { return true }
        return appleProtectedPrefixes.contains { name == $0 || name.hasPrefix($0) }
    }

    /// `du -I` masks that keep a parent-folder measurement out of protected subfolders.
    static var duExcludeArgs: [String] {
        protectedNames.flatMap { ["-I", $0] }
    }

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
