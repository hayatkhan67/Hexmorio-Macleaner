import SwiftUI

/// Sheet listing what changed: the running version first (or the newest
/// release when running an untagged dev build), then earlier versions.
struct WhatsNewView: View {
    let onClose: () -> Void

    private var current: ReleaseNotes? {
        WhatsNew.notes(for: Updater.currentVersion) ?? WhatsNew.releases.first
    }

    /// Releases older than the one shown (the list is newest first).
    private var earlier: [ReleaseNotes] {
        guard let current, let index = WhatsNew.releases.firstIndex(where: { $0.id == current.id }) else { return [] }
        return Array(WhatsNew.releases.dropFirst(index + 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let current {
                        ForEach(current.items) { item in
                            WhatsNewRow(item: item)
                        }
                    }
                    if !earlier.isEmpty {
                        Divider()
                        ForEach(earlier) { release in
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(release.items) { WhatsNewRow(item: $0, compact: true) }
                                }
                                .padding(.top, 8)
                            } label: {
                                Text(versionLabel(release)).font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }
                .padding(24)
            }
            Divider()
            footer
        }
        .frame(width: 520, height: 560)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            Text("What's New in Hexmorio Macleaner")
                .font(.title2.bold())
            if let current {
                Text(versionLabel(current))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack {
            Link("Full changelog", destination: WhatsNew.changelogURL)
            Spacer()
            Button("Continue", action: onClose)
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private func versionLabel(_ release: ReleaseNotes) -> String {
        if let date = release.date { return "Version \(release.version) · \(date)" }
        return "Version \(release.version)"
    }
}

private struct WhatsNewRow: View {
    let item: WhatsNewItem
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.icon)
                .font(compact ? .body : .title2)
                .foregroundStyle(.tint)
                .frame(width: compact ? 20 : 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(compact ? .callout.weight(.semibold) : .headline)
                Text(item.detail)
                    .font(compact ? .caption : .callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
