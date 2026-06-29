import SwiftUI
import MYTGSCore

@main
struct MYTGSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var clockPanel = FloatingClockPanelController()
    @StateObject private var updates = UpdateController()

    var body: some Scene {
        WindowGroup("MYTGS") {
            ContentView()
                .environmentObject(model)
                .environmentObject(clockPanel)
                .task {
                    model.bootstrap()
                    clockPanel.update(schedule: model.todaySchedule, settings: model.settings.clock)
                }
                .onChange(of: model.todaySchedule) { _, schedule in
                    clockPanel.update(schedule: schedule, settings: model.settings.clock)
                }
                .onChange(of: model.settings.clock) { _, settings in
                    clockPanel.update(schedule: model.todaySchedule, settings: settings)
                }
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    checkForUpdates()
                }
            }
            SidebarCommands()
        }

        MenuBarExtra("MYTGS", systemImage: "calendar.badge.clock") {
            Text(model.session == nil ? "Signed out" : model.statusMessage)
            if let lastUpdated = model.lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
            }
            Divider()
            Button("Show MYTGS") {
                NSApp.activate(ignoringOtherApps: true)
            }
            Button(model.settings.clock.showFloatingClock ? "Hide Floating Clock" : "Show Floating Clock") {
                model.settings.clock.showFloatingClock.toggle()
                model.persistSettings()
                clockPanel.update(schedule: model.todaySchedule, settings: model.settings.clock)
            }
            Divider()
            Button(model.isRefreshing ? "Refreshing..." : "Refresh") {
                Task { await model.refreshAll() }
            }
            .disabled(model.isRefreshing || model.session == nil)
            Button("Check for Updates...") {
                checkForUpdates()
            }
            Divider()
            Button("Quit MYTGS") {
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .environmentObject(updates)
        }
    }

    private func checkForUpdates() {
        updates.checkForUpdates()
        model.statusMessage = updates.statusMessage
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
