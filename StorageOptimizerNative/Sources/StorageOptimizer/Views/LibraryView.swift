import SwiftUI

struct LibraryView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $state.libraryFilter) {
                Text("All Folders").tag("all")
                Text("~/Library").tag("user_library")
                Text("App Support").tag("app_support")
                Text("User Caches").tag("user_caches")
                Text("Hidden Dot Folders").tag("hidden_folders")
                Text("System /Library").tag("system_library")
            }
            .pickerStyle(.segmented)
            .padding()

            if state.isScanningLibrary && state.library == nil {
                ProgressView("Scanning Library, Caches & Hidden directories...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 12)], spacing: 12) {
                        ForEach(state.filteredLibraryItems) { item in
                            LibraryCard(item: item, state: state)
                        }
                    }
                    .padding()
                }
            }
        }
        .task { if state.library == nil { await state.scanLibrary() } }
    }
}

private struct LibraryCard: View {
    let item: LibraryItem
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { Task { await state.loadDiskMap(item.path) } } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.headline)
                        Text(item.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Text(item.sizeFormatted).font(.subheadline).bold().foregroundStyle(.green)
            }
            Text(item.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Divider()
            HStack {
                Button { state.revealInFinder(item.path) } label: { Label("Finder", systemImage: "folder") }
                    .buttonStyle(.bordered)
                if item.canClean {
                    Button {
                        state.confirm(title: "Purge contents of \(item.name)?", message: item.path) {
                            Task { await state.cleanLibraryFolder(item.path, item.name) }
                        }
                    } label: {
                        Label("Purge", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                Spacer()
            }
        }
        .padding()
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
    }
}
