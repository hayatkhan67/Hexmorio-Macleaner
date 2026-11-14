import SwiftUI

struct StartupView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(state.startupItems.count) launch agents / daemons").foregroundStyle(.secondary)
                Spacer()
                Button("Rescan") { Task { await state.scanStartup() } }
            }.padding()

            if state.isScanningStartup && state.startupItems.isEmpty {
                ProgressView("Inspecting startup items...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(state.startupItems) {
                    TableColumn("Label") { item in Text(item.label).lineLimit(1) }
                    TableColumn("Type") { item in Text(item.type) }.width(140)
                    TableColumn("Program") { item in Text(item.program.isEmpty ? item.fileName : item.program).lineLimit(1).truncationMode(.middle) }
                    TableColumn("Status") { item in
                        Text(item.isDisabled ? "Disabled" : "Active").foregroundStyle(item.isDisabled ? Color.secondary : Color.green)
                    }.width(80)
                    TableColumn("") { item in
                        if item.canToggle {
                            Button(item.isDisabled ? "Enable" : "Disable") {
                                Task { await state.toggleStartup(item.path) }
                            }
                        } else {
                            Text("System Locked").font(.caption2).foregroundStyle(.secondary)
                        }
                    }.width(100)
                }
            }
        }
        .task { if state.startupItems.isEmpty { await state.scanStartup() } }
    }
}
