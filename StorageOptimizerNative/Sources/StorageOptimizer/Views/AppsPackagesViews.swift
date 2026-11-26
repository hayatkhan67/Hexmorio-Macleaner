import SwiftUI

struct AppsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(state.apps.count) applications").foregroundStyle(.secondary)
                Spacer()
                Button("Rescan") { Task { await state.scanApps() } }
            }.padding()

            if state.isScanningApps && state.apps.isEmpty {
                ProgressView("Scanning all installed applications...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(state.apps) {
                    TableColumn("Name") { app in
                        HStack {
                            Text(app.name)
                            if app.isUserApp {
                                Text("User App").font(.caption2).padding(.horizontal, 4).background(.quaternary, in: Capsule())
                            }
                        }
                    }
                    TableColumn("Size") { app in Text(app.sizeFormatted) }.width(90)
                    TableColumn("Path") { app in Text(app.path).lineLimit(1).truncationMode(.middle) }
                    TableColumn("") { app in
                        HStack {
                            Button { state.revealInFinder(app.path) } label: { Image(systemName: "folder") }
                                .buttonStyle(.plain)
                            Button {
                                state.confirm(title: "Move \(app.name) to Trash?", message: app.path) {
                                    Task { await state.uninstallApp(app.path, app.name) }
                                }
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }.width(80)
                }
            }
        }
        .task { if state.apps.isEmpty { await state.scanApps() } }
    }
}

struct PackagesView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let pkgs = state.packages {
                    Text("Brew: \(pkgs.brew.count) (\(pkgs.brewTotalFormatted))  ·  npm: \(pkgs.npm.count)  ·  pip: \(pkgs.pip.count)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Run brew cleanup") { Task { await state.runBrewCleanup() } }
                Button("Rescan") { Task { await state.scanPackages() } }
            }.padding()

            if state.isScanningPackages && state.packages == nil {
                ProgressView("Scanning Homebrew, npm and pip...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let pkgs = state.packages {
                HSplitView {
                    List(pkgs.brew) { b in
                        HStack {
                            Text(b.name)
                            Spacer()
                            Text(b.sizeFormatted).foregroundStyle(.green)
                            Button {
                                state.confirm(title: "Uninstall Homebrew package '\(b.name)'?", message: b.path) {
                                    Task { await state.uninstallBrewPackage(b.name) }
                                }
                            } label: { Image(systemName: "trash").foregroundStyle(.red) }
                            .buttonStyle(.plain)
                        }
                    }
                    List(pkgs.npm) { n in
                        HStack {
                            Text(n.name)
                            Spacer()
                            Text(n.version).foregroundStyle(.secondary)
                            Button {
                                state.confirm(title: "Uninstall global npm package '\(n.name)'?", message: "Runs: npm uninstall -g \(n.name)") {
                                    Task { await state.uninstallNpmPackage(n.name) }
                                }
                            } label: { Image(systemName: "trash").foregroundStyle(.red) }
                            .buttonStyle(.plain)
                        }
                    }
                    List(pkgs.pip) { p in
                        HStack { Text(p.name); Spacer(); Text(p.version).foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .task { if state.packages == nil { await state.scanPackages() } }
    }
}
