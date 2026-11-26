import Foundation

/// One highlighted change shown in the What's New sheet.
struct WhatsNewItem: Identifiable {
    var id: String { title }
    let icon: String
    let title: String
    let detail: String
}

/// User-facing highlights for one version. Keep in sync with CHANGELOG.md:
/// a short, friendly subset of it, not the full list.
struct ReleaseNotes: Identifiable {
    var id: String { version }
    let version: String
    let date: String?
    let items: [WhatsNewItem]
}

enum WhatsNew {
    private static let lastSeenKey = "whatsNewLastSeenVersion"

    static let changelogURL = URL(string: "https://github.com/hayatkhan67/Hexmorio-Macleaner/blob/main/CHANGELOG.md")!

    /// Newest first.
    static let releases: [ReleaseNotes] = [
        ReleaseNotes(version: "1.1.0", date: "2026-11-27", items: [
            WhatsNewItem(
                icon: "magnifyingglass",
                title: "Finds projects anywhere",
                detail: "Project Builds, Git Repos, Large Files and Installers now search your whole home folder and connected drives, not just ~/projects."
            ),
            WhatsNewItem(
                icon: "hammer",
                title: "More build folders, measured right",
                detail: "Detects node_modules, Pods, .next, .gradle, DerivedData, target, .venv and more. Multi-GB builds no longer go missing, and source folders named build or dist are left alone."
            ),
            WhatsNewItem(
                icon: "waveform.path.ecg",
                title: "Watches your disk in the background",
                detail: "Rescans builds and caches when free space changes a lot, and warns you once when the disk is 90% full."
            ),
            WhatsNewItem(
                icon: "arrow.down.circle",
                title: "Built-in updates",
                detail: "The app checks for new versions once a day and updates itself in place. Use Check for Updates… in the app menu any time."
            ),
            WhatsNewItem(
                icon: "trash",
                title: "Uninstall from the app",
                detail: "Move apps to the Trash and remove Homebrew or global npm packages right from the Apps and Packages tabs."
            ),
            WhatsNewItem(
                icon: "arrow.uturn.backward.circle",
                title: "Safer Library purge",
                detail: "Application Support and tool folders go to the Trash so you can restore them. Folders with keys or settings, like ~/.ssh and ~/.kube, are locked."
            ),
            WhatsNewItem(
                icon: "lock.shield",
                title: "Fewer permission prompts",
                detail: "1-Click Optimize no longer asks for your password, admin cleanups ask only once, and Full Disk Access is detected on macOS 27."
            ),
            WhatsNewItem(
                icon: "menubar.rectangle",
                title: "Lives in the menu bar",
                detail: "Closing the window removes the Dock icon while the menu bar item keeps running. Start at Login turns on automatically when the app is in Applications."
            ),
        ]),
        ReleaseNotes(version: "1.0.0", date: "2026-11-14", items: [
            WhatsNewItem(
                icon: "flag.checkered",
                title: "First release",
                detail: "Native macOS app with menu bar quick actions: caches, Library folders, apps, packages, startup items, disk map, project builds, leftovers, git repos, duplicates, installers, large files and RAM release."
            ),
        ]),
    ]

    static func notes(for version: String) -> ReleaseNotes? {
        releases.first { $0.version == version }
    }

    /// True once per version that has notes, the first time that version runs.
    static var shouldShowOnLaunch: Bool {
        let current = Updater.currentVersion
        guard notes(for: current) != nil else { return false }
        return UserDefaults.standard.string(forKey: lastSeenKey) != current
    }

    static func markSeen() {
        UserDefaults.standard.set(Updater.currentVersion, forKey: lastSeenKey)
    }
}
