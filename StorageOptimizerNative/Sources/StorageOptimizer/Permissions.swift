import Foundation
import AppKit

enum Permissions {
    /// TCC.db is only readable with Full Disk Access, and probing it never shows a prompt.
    static var hasFullDiskAccess: Bool {
        let path = "\(NSHomeDirectory())/Library/Application Support/com.apple.TCC/TCC.db"
        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        try? handle.close()
        return true
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
