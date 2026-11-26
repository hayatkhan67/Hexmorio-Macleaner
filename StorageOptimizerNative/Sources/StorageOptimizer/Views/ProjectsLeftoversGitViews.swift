import SwiftUI

struct ProjectsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(state.projects.count) build artifacts").foregroundStyle(.secondary)
                Spacer()
                Button("Clean All Builds") {
                    let totalBytes = state.projects.reduce(0) { $0 + $1.sizeBytes }
                    state.confirm(title: "Clean all \(state.projects.count) project build & cache directories (\(formatBytes(totalBytes)))?", message: "They will regenerate on next build or package install.") {
                        Task { await state.cleanAllProjectBuilds() }
                    }
                }.disabled(state.projects.isEmpty)
                Button("Rescan") { Task { await state.scanProjects() } }
            }.padding()

            if state.isScanningProjects && state.projects.isEmpty {
                ProgressView("Scanning project build folders...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(state.projects) {
                    TableColumn("Project") { a in Text(a.project) }
                    TableColumn("Type") { a in Text(a.typeLabel) }.width(140)
                    TableColumn("Size") { a in Text(a.sizeFormatted) }.width(90)
                    TableColumn("Path") { a in Text(a.path).lineLimit(1).truncationMode(.middle) }
                    TableColumn("") { a in
                        HStack {
                            Button { state.revealInFinder(a.path) } label: { Image(systemName: "folder") }.buttonStyle(.plain)
                            Button("Clean") {
                                state.confirm(title: "Delete build directory?", message: "\(a.project) - \(a.typeLabel)\n\(a.path)") {
                                    Task { await state.cleanProjectPath(a.path, "\(a.project) - \(a.typeLabel)") }
                                }
                            }
                        }
                    }.width(120)
                }
            }
        }
        .task { if state.projects.isEmpty { await state.scanProjects() } }
    }
}

struct LeftoversView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(state.leftovers.count) orphaned folders").foregroundStyle(.secondary)
                Spacer()
                Button("Rescan") { Task { await state.scanLeftovers() } }
            }.padding()

            if state.isScanningLeftovers && state.leftovers.isEmpty {
                ProgressView("Finding app leftovers...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.leftovers.isEmpty {
                Text("No orphaned application folders found!").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(state.leftovers) {
                    TableColumn("Name") { item in Text(item.name) }
                    TableColumn("Size") { item in Text(item.sizeFormatted) }.width(90)
                    TableColumn("Path") { item in Text(item.path).lineLimit(1).truncationMode(.middle) }
                    TableColumn("") { item in
                        HStack {
                            Button { state.revealInFinder(item.path) } label: { Image(systemName: "folder") }.buttonStyle(.plain)
                            Button("Delete") {
                                state.confirm(title: "Delete leftover folder?", message: "\(item.name)\n\(item.path)") {
                                    Task { await state.cleanLeftoverPath(item.path, item.name) }
                                }
                            }
                        }
                    }.width(120)
                }
            }
        }
        .task { if state.leftovers.isEmpty { await state.scanLeftovers() } }
    }
}

struct GitReposView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(state.gitRepos.count) heavy repos (>2MB .git)").foregroundStyle(.secondary)
                Spacer()
                Button("Compress All") {
                    state.confirm(title: "Run git gc on all repositories?", message: "") {
                        Task { await state.optimizeAllGitRepos() }
                    }
                }.disabled(state.gitRepos.isEmpty)
                Button("Rescan") { Task { await state.scanGitRepos() } }
            }.padding()

            if state.isScanningGit && state.gitRepos.isEmpty {
                ProgressView("Analyzing git repositories...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.gitRepos.isEmpty {
                Text("All git repositories are lean!").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(state.gitRepos) {
                    TableColumn("Repo") { r in Text(r.name) }
                    TableColumn("Size") { r in Text(r.sizeFormatted) }.width(90)
                    TableColumn("Path") { r in Text(r.path).lineLimit(1).truncationMode(.middle) }
                    TableColumn("") { r in
                        Button("Compress (gc)") { Task { await state.optimizeSingleGit(r.path, r.name) } }
                    }.width(140)
                }
            }
        }
        .task { if state.gitRepos.isEmpty { await state.scanGitRepos() } }
    }
}
