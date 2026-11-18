import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case optimizer = "Dev & System Caches"
    case library = "Library & Other Folders"
    case apps = "All Applications"
    case packages = "Brew, Pip & CLI Tools"
    case startup = "Startup & Launch Control"
    case diskMap = "Visual Disk Map"
    case projects = "Project Builds"
    case leftovers = "App Leftovers"
    case git = "Git Repos"
    case duplicates = "Duplicates"
    case installers = "Installers"
    case largeFiles = "Large Files"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .optimizer: return "wand.and.stars"
        case .library: return "folder.fill"
        case .apps: return "app.badge"
        case .packages: return "shippingbox"
        case .startup: return "power"
        case .diskMap: return "chart.pie"
        case .projects: return "hammer"
        case .leftovers: return "trash.slash"
        case .git: return "point.3.connected.trianglepath.dotted"
        case .duplicates: return "doc.on.doc"
        case .installers: return "archivebox"
        case .largeFiles: return "doc.zipper"
        }
    }
}

struct ContentView: View {
    @ObservedObject var state: AppState
    @State private var selectedTab: Tab = .optimizer

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon).tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            VStack(spacing: 0) {
                if let update = state.availableUpdate {
                    Banner(
                        icon: "arrow.down.circle.fill", tint: .blue,
                        text: "Version \(update.version) is available (you have \(Updater.currentVersion)).",
                        actionTitle: state.isUpdating ? "Updating…" : "Update Now"
                    ) { Task { await state.installUpdate() } }
                    .disabled(state.isUpdating)
                }
                if !state.hasFullDiskAccess {
                    Banner(
                        icon: "lock.shield", tint: .orange,
                        text: "Grant Full Disk Access once so macOS stops asking for folder permissions and protected folders can be measured.",
                        actionTitle: "Open Settings"
                    ) { Permissions.openFullDiskAccessSettings() }
                }
                HeaderBar(state: state)
                Divider()
                StatCardsRow(state: state)
                Divider()
                tabContent
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .task { await state.rescanAll() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.refreshPermissions()
        }
        .overlay(alignment: .bottomTrailing) {
            HexmorioWatermark().padding(10)
        }
        .overlay(alignment: .bottom) {
            if let toast = state.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring, value: state.toast)
            }
        }
        .alert(item: $state.pendingAction) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                primaryButton: .destructive(Text("Confirm")) { action.perform() },
                secondaryButton: .cancel()
            )
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .optimizer: OptimizerView(state: state)
        case .library: LibraryView(state: state)
        case .apps: AppsView(state: state)
        case .packages: PackagesView(state: state)
        case .startup: StartupView(state: state)
        case .diskMap: DiskMapView(state: state)
        case .projects: ProjectsView(state: state)
        case .leftovers: LeftoversView(state: state)
        case .git: GitReposView(state: state)
        case .duplicates: DuplicatesView(state: state)
        case .installers: InstallersView(state: state)
        case .largeFiles: LargeFilesView(state: state)
        }
    }
}

private struct HeaderBar: View {
    @ObservedObject var state: AppState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hexmorio Macleaner").font(.title2).bold()
                Text(state.statusText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Start at Login", isOn: Binding(
                get: { state.launchAtLogin },
                set: { _ in state.toggleLaunchAtLogin() }
            ))
            .toggleStyle(.checkbox)
            Button(state.autoCleanEnabled ? "Auto-Clean: On" : "Auto-Clean: Off") {
                Task { await state.toggleAutoClean() }
            }
            Button("Flush System") { Task { await state.systemFlush() } }
            Button {
                Task { await state.releaseMemory() }
            } label: {
                if state.isReleasingMemory {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Release RAM")
                }
            }
            .disabled(state.isReleasingMemory)
            Button("Rescan") { Task { await state.rescanAll() } }
            Button {
                let ids = state.targets.filter { $0.safety == .safe && $0.sizeBytes > 0 }.map(\.id)
                guard !ids.isEmpty else { state.showToast("No safe caches to clean right now."); return }
                state.confirm(title: "Optimize all safe targets?", message: "This cleans \(formatBytes(state.safeTotalBytes)) of safe caches.") {
                    Task { await state.cleanTargets(ids: ids) }
                }
            } label: {
                Label("1-Click Optimize (\(formatBytes(state.safeTotalBytes)))", systemImage: "bolt.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
    }
}

private struct StatCardsRow: View {
    @ObservedObject var state: AppState

    var body: some View {
        HStack(spacing: 12) {
            StatCard(title: "Disk Storage", value: "\(state.disk.percentUsed)% used", detail: "\(state.disk.free) free of \(state.disk.total)")
            StatCard(title: "Memory (RAM)", value: "\(state.ram.usedPercent)% used", detail: "\(state.ram.free) free of \(state.ram.total)")
            StatCard(title: "Cleanable Caches", value: formatBytes(state.safeTotalBytes), detail: "Rebuildable: \(formatBytes(state.rebuildableBytes))")
            StatCard(title: "Project Builds", value: "\(state.projects.count) detected", detail: formatBytes(state.projects.reduce(0) { $0 + $1.sizeBytes }))
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct Banner: View {
    let icon: String
    let tint: Color
    let text: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).font(.callout)
            Spacer()
            Button(actionTitle, action: action)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12))
    }
}

private struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        Label(toast.message, systemImage: toast.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
            .foregroundStyle(toast.isError ? .red : .green)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 8)
    }
}
