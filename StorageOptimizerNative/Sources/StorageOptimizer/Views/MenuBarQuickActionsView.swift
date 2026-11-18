import SwiftUI
import AppKit

/// The popover shown from the menu bar status item - lets the user clean
/// safe caches or free up RAM without opening the main window.
struct MenuBarQuickActionsView: View {
    @ObservedObject var state: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var isCleaning = false

    private var safeIds: [String] { state.targets.filter { $0.safety == .safe && $0.sizeBytes > 0 }.map(\.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "externaldrive.badge.checkmark")
                Text("Hexmorio Macleaner").font(.headline)
                Spacer()
            }

            HStack(spacing: 16) {
                statColumn(title: "Disk", percent: state.disk.percentUsed, detail: "\(state.disk.free) free")
                statColumn(title: "Memory", percent: state.ram.usedPercent, detail: "\(state.ram.free) free")
            }

            Divider()

            Button {
                isCleaning = true
                Task {
                    await state.cleanTargets(ids: safeIds)
                    isCleaning = false
                }
            } label: {
                HStack {
                    if isCleaning { ProgressView().controlSize(.small) } else { Image(systemName: "bolt.fill") }
                    Text("Quick Clean Safe Caches (\(formatBytes(state.safeTotalBytes)))")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(isCleaning || safeIds.isEmpty)

            Button {
                Task { await state.releaseMemory() }
            } label: {
                HStack {
                    if state.isReleasingMemory { ProgressView().controlSize(.small) } else { Image(systemName: "memorychip") }
                    Text("Release RAM")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(state.isReleasingMemory)

            Button {
                Task { await state.systemFlush() }
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Flush System Caches")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let toast = state.toast {
                Text(toast.message)
                    .font(.caption)
                    .foregroundStyle(toast.isError ? Color.red : Color.secondary)
                    .lineLimit(2)
            }

            Divider()

            if let update = state.availableUpdate {
                Button {
                    Task { await state.installUpdate() }
                } label: {
                    HStack {
                        if state.isUpdating { ProgressView().controlSize(.small) } else { Image(systemName: "arrow.down.circle.fill") }
                        Text("Update to \(update.version)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(state.isUpdating)
            }

            Toggle("Start at Login", isOn: Binding(
                get: { state.launchAtLogin },
                set: { _ in state.toggleLaunchAtLogin() }
            ))
            .toggleStyle(.checkbox)

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text("Open Hexmorio Macleaner")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HexmorioWatermark()
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
        .padding(14)
        .frame(width: 280)
        .task {
            if state.targets.isEmpty { await state.scanTargets() }
            if state.disk.total == "--" { await state.refreshDiskAndRam() }
        }
    }

    @ViewBuilder
    private func statColumn(title: String, percent: Double, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(Int(percent))%").font(.title3).bold()
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
