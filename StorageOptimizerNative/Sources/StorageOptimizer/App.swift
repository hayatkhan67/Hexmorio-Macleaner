import SwiftUI

@main
struct StorageOptimizerApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        Window("Hexmorio Macleaner", id: "main") {
            ContentView(state: state)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Hexmorio Macleaner", systemImage: "externaldrive.badge.checkmark") {
            MenuBarQuickActionsView(state: state)
        }
        .menuBarExtraStyle(.window)
    }
}
