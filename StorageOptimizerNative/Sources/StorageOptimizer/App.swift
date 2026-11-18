import SwiftUI

@main
struct StorageOptimizerApp: App {
    @StateObject private var state = AppState()

    init() {
        if CommandLine.arguments.contains(AutoClean.argument) {
            AutoClean.runAndExit()
        }
    }

    var body: some Scene {
        Window("Hexmorio Macleaner", id: "main") {
            ContentView(state: state)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    Task { await state.checkForUpdates(userInitiated: true) }
                }
            }
        }

        MenuBarExtra("Hexmorio Macleaner", systemImage: "externaldrive.badge.checkmark") {
            MenuBarQuickActionsView(state: state)
        }
        .menuBarExtraStyle(.window)
    }
}
