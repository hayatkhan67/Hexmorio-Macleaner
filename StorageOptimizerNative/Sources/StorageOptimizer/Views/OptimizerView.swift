import SwiftUI

struct OptimizerView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Category", selection: $state.currentCategory) {
                    Text("All").tag("all")
                    Text("Developer").tag("developer")
                    Text("System & Apps").tag("system")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)

                Spacer()

                Text("\(state.selectedIds.count) selected").font(.caption).foregroundStyle(.secondary)

                Button("Clean Selected") {
                    let ids = Array(state.selectedIds)
                    state.confirm(title: "Clean \(ids.count) selected targets?", message: "This frees up the selected caches.") {
                        Task { await state.cleanTargets(ids: ids) }
                    }
                }
                .disabled(state.selectedIds.isEmpty)
            }
            .padding()

            if state.isScanningTargets && state.targets.isEmpty {
                ProgressView("Scanning targets...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 12)], spacing: 12) {
                        ForEach(state.filteredTargets) { target in
                            TargetCard(target: target, isSelected: state.selectedIds.contains(target.id), state: state)
                        }
                    }
                    .padding()
                }
            }
        }
        .task { if state.targets.isEmpty { await state.scanTargets() } }
    }
}

private struct TargetCard: View {
    let target: CleanTarget
    let isSelected: Bool
    @ObservedObject var state: AppState

    var badgeColor: Color {
        switch target.safety {
        case .safe: return .green
        case .rebuildable: return .orange
        case .review: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { _ in state.toggleTargetSelection(target.id) }
                ))
                .labelsHidden()

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(target.name).font(.headline)
                        Text(target.safety.rawValue)
                            .font(.caption2).bold()
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(badgeColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(badgeColor)
                    }
                    Text(target.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Text(target.sizeFormatted).font(.subheadline).bold().foregroundStyle(target.sizeBytes == 0 ? Color.secondary : Color.green)
            }

            Divider()

            HStack {
                Button { state.revealInFinder(target.path) } label: { Image(systemName: "folder") }
                    .buttonStyle(.plain)
                Text(target.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Clean") {
                    state.confirm(title: "Clean \"\(target.name)\"?", message: target.path) {
                        Task { await state.cleanTargets(ids: [target.id]) }
                    }
                }
                .disabled(target.sizeBytes == 0)
            }
        }
        .padding()
        .background(.quaternary.opacity(isSelected ? 0.4 : 0.2), in: RoundedRectangle(cornerRadius: 10))
    }
}
