import SwiftUI

struct DuplicatesView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(state.selectedDupePaths.count) files selected").foregroundStyle(.secondary)
                Spacer()
                Button("Delete Selected") {
                    let count = state.selectedDupePaths.count
                    state.confirm(title: "Permanently delete \(count) duplicate files?", message: "") {
                        Task { await state.cleanSelectedDuplicates() }
                    }
                }.disabled(state.selectedDupePaths.isEmpty)
                Button("Rescan") { Task { await state.scanDuplicates() } }
            }.padding()

            if state.isScanningDuplicates && state.duplicates.isEmpty {
                ProgressView("Analyzing exact duplicate files (full-content hash)...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.duplicates.isEmpty {
                Text("No duplicate files found in Downloads or Desktop!").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(state.duplicates.enumerated()), id: \.element.id) { idx, group in
                        Section("Group #\(idx + 1) - \(group.files.count) identical files, \(group.fileSizeFormatted) each") {
                            ForEach(Array(group.files.enumerated()), id: \.element.id) { fIdx, file in
                                HStack {
                                    Toggle("", isOn: Binding(
                                        get: { state.selectedDupePaths.contains(file.path) },
                                        set: { checked in
                                            if checked { state.selectedDupePaths.insert(file.path) }
                                            else { state.selectedDupePaths.remove(file.path) }
                                        }
                                    )).labelsHidden()
                                    Text(file.name).lineLimit(1)
                                    if fIdx == 0 {
                                        Text("NEWEST").font(.caption2).padding(.horizontal, 4).background(.green.opacity(0.2), in: Capsule())
                                    }
                                    Spacer()
                                    Button { state.revealInFinder(file.path) } label: { Image(systemName: "folder") }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task { if state.duplicates.isEmpty { await state.scanDuplicates() } }
    }
}

struct InstallersView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(state.installers.count) installer archives").foregroundStyle(.secondary)
                Spacer()
                Button("Rescan") { Task { await state.scanInstallers() } }
            }.padding()

            if state.isScanningInstallers && state.installers.isEmpty {
                ProgressView("Finding downloaded installer packages...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.installers.isEmpty {
                Text("No installer packages found.").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(state.installers) {
                    TableColumn("Name") { f in Text(f.name) }
                    TableColumn("Size") { f in Text(f.sizeFormatted) }.width(90)
                    TableColumn("Path") { f in Text(f.path).lineLimit(1).truncationMode(.middle) }
                    TableColumn("") { f in
                        HStack {
                            Button { state.revealInFinder(f.path) } label: { Image(systemName: "folder") }.buttonStyle(.plain)
                            Button { state.confirm(title: "Move to Trash?", message: f.path) { Task { await state.deleteLargeFile(f.path) } } } label: {
                                Image(systemName: "trash")
                            }.buttonStyle(.plain)
                        }
                    }.width(60)
                }
            }
        }
        .task { if state.installers.isEmpty { await state.scanInstallers() } }
    }
}

struct LargeFilesView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Found \(state.largeFiles.count) files larger than")
                Picker("", selection: $state.minMB) {
                    Text("25 MB").tag(25)
                    Text("50 MB").tag(50)
                    Text("100 MB").tag(100)
                    Text("250 MB").tag(250)
                    Text("500 MB").tag(500)
                }
                .frame(width: 100)
                .onChange(of: state.minMB) { _, _ in Task { await state.loadLargeFiles() } }
                Spacer()
                Button("Rescan") { Task { await state.loadLargeFiles() } }
            }.padding()

            if state.isScanningLargeFiles && state.largeFiles.isEmpty {
                ProgressView("Scanning for large files...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.largeFiles.isEmpty {
                Text("No files larger than \(state.minMB)MB found.").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(state.largeFiles) {
                    TableColumn("Name") { f in Text(f.name) }
                    TableColumn("Size") { f in Text(f.sizeFormatted) }.width(90)
                    TableColumn("Location") { f in Text(f.path).lineLimit(1).truncationMode(.middle) }
                    TableColumn("") { f in
                        HStack {
                            Button { state.revealInFinder(f.path) } label: { Image(systemName: "folder") }.buttonStyle(.plain)
                            Button { state.confirm(title: "Move to Trash?", message: f.path) { Task { await state.deleteLargeFile(f.path) } } } label: {
                                Image(systemName: "trash")
                            }.buttonStyle(.plain)
                        }
                    }.width(60)
                }
            }
        }
        .task { if state.largeFiles.isEmpty { await state.loadLargeFiles() } }
    }
}
