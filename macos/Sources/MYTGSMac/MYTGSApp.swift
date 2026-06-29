import SwiftUI
import MYTGSCore

@main
struct MYTGSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var clockPanel = FloatingClockPanelController()

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
                    model.checkForUpdates()
                }
            }
            SidebarCommands()
        }

        MenuBarExtra("MYTGS", systemImage: "calendar.badge.clock") {
            Button("Show MYTGS") {
                NSApp.activate(ignoringOtherApps: true)
            }
            Button(model.settings.clock.showFloatingClock ? "Hide Floating Clock" : "Show Floating Clock") {
                model.settings.clock.showFloatingClock.toggle()
                model.persistSettings()
                clockPanel.update(schedule: model.todaySchedule, settings: model.settings.clock)
            }
            Divider()
            Button("Refresh") {
                Task { await model.refreshAll() }
            }
            Button("Check for Updates...") {
                model.checkForUpdates()
            }
            Divider()
            Button("Quit MYTGS") {
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
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
