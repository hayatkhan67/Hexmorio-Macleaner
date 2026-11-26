import SwiftUI
import AppKit

/// Manages Dock icon visibility so closing the main window removes the app
/// from the Dock and Cmd+Tab switcher while keeping the MenuBarExtra status
/// item running in the background until the user explicitly quits from the
/// status bar.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let nc = NotificationCenter.default
        windowObservers.append(
            nc.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] note in
                guard let closedWindow = note.object as? NSWindow,
                      Self.isMainAppWindow(closedWindow) else { return }
                // Wait one runloop tick for the window's visibility state to update
                DispatchQueue.main.async {
                    self?.updateActivationPolicy(ignoring: closedWindow)
                }
            }
        )
        windowObservers.append(
            nc.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
                guard let keyWindow = note.object as? NSWindow,
                      Self.isMainAppWindow(keyWindow) else { return }
                if NSApp.activationPolicy() != .regular {
                    NSApp.setActivationPolicy(.regular)
                }
            }
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private static func isMainAppWindow(_ window: NSWindow) -> Bool {
        // Only treat normal titled app windows (not MenuBarExtra popovers/panels or status bar windows) as main windows.
        guard window.styleMask.contains(.titled), !(window is NSPanel) else { return false }
        return true
    }

    private func updateActivationPolicy(ignoring closingWindow: NSWindow? = nil) {
        let hasOpenMainWindow = NSApp.windows.contains { win in
            guard win !== closingWindow, win.isVisible, !win.isMiniaturized else { return false }
            return Self.isMainAppWindow(win)
        }
        if hasOpenMainWindow {
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
            }
        } else {
            if NSApp.activationPolicy() != .accessory {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

@main
struct StorageOptimizerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    init() {
        if CommandLine.arguments.contains(AutoClean.argument) {
            AutoClean.runAndExit()
        }
    }

    var body: some Scene {
        Window("Hexmorio Macleaner", id: "main") {
            ContentView(state: state)
                .onAppear {
                    if NSApp.activationPolicy() != .regular {
                        NSApp.setActivationPolicy(.regular)
                    }
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    Task { await state.checkForUpdates(userInitiated: true) }
                }
                Button("What's New…") {
                    state.showWhatsNew = true
                }
            }
        }

        MenuBarExtra("Hexmorio Macleaner", systemImage: "externaldrive.badge.checkmark") {
            MenuBarQuickActionsView(state: state)
        }
        .menuBarExtraStyle(.window)
    }
}
