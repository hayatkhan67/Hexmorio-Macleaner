import SwiftUI

struct DiskMapView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { Task { await state.loadDiskMap("") } } label: { Label("Home", systemImage: "house") }
                if let parent = state.diskMapParent {
                    Button { Task { await state.loadDiskMap(parent) } } label: { Label("Up", systemImage: "arrow.up") }
                }
                Text(state.diskMapPath).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Spacer()
                Toggle("Hidden", isOn: $state.diskMapShowHidden)
                    .toggleStyle(.switch)
                    .onChange(of: state.diskMapShowHidden) { _, _ in
                        Task { await state.loadDiskMap(state.diskMapPath) }
                    }
                Button("Rescan") { Task { await state.loadDiskMap(state.diskMapPath) } }
            }.padding()

            if state.isScanningDiskMap && state.diskMapItems.isEmpty {
                ProgressView("Analyzing folder distribution...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.diskMapItems.isEmpty {
                Text("Folder is empty or contents are below the size threshold.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let maxSize = max(state.diskMapItems.map(\.sizeBytes).max() ?? 1, 1)
                List(state.diskMapItems) { item in
                    HStack {
                        Image(systemName: item.isDir ? "folder.fill" : "doc")
                            .foregroundStyle(item.isDir ? Color.yellow : Color.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).bold()
                            ProgressView(value: Double(item.sizeBytes), total: Double(maxSize))
                        }
                        Text(item.sizeFormatted).font(.subheadline).bold().foregroundStyle(.green)
                        if item.isDir {
                            Button { Task { await state.loadDiskMap(item.path) } } label: { Image(systemName: "arrow.right") }
                                .buttonStyle(.plain)
                        }
                        Button { state.revealInFinder(item.path) } label: { Image(systemName: "folder") }
                            .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if item.isDir { Task { await state.loadDiskMap(item.path) } }
                    }
                }
            }
        }
        .task { if state.diskMapPath.isEmpty { await state.loadDiskMap("") } }
    }
}
