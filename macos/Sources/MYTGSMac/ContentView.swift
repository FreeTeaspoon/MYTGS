import SwiftUI
import MYTGSCore

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case tasks = "Tasks"
    case timetable = "Timetable"
    case epr = "EPR"
    case account = "Account"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dashboard: "house"
        case .tasks: "checklist"
        case .timetable: "calendar"
        case .epr: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
        case .account: "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var clockPanel: FloatingClockPanelController
    @State private var selection: AppSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationTitle("MYTGS")
            .toolbar {
                ToolbarItem {
                    Button {
                        Task { await model.refreshAll() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        } detail: {
            Group {
                switch selection ?? .dashboard {
                case .dashboard:
                    DashboardView()
                case .tasks:
                    TasksView()
                case .timetable:
                    TimetableView()
                case .epr:
                    EPRView()
                case .account:
                    AccountView()
                }
            }
            .frame(minWidth: 760, minHeight: 520)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        model.beginLogin()
                    } label: {
                        Label(model.session == nil ? "Sign In" : "Signed In", systemImage: model.session == nil ? "person.badge.key" : "checkmark.seal")
                    }
                    Button {
                        model.settings.clock.showFloatingClock.toggle()
                        model.persistSettings()
                        clockPanel.update(schedule: model.todaySchedule, settings: model.settings.clock)
                    } label: {
                        Label("Floating Clock", systemImage: "macwindow.on.rectangle")
                    }
                }
            }
        }
        .sheet(isPresented: $model.showingLogin) {
            if let url = model.loginURL {
                LoginWebView(url: url) { token in
                    model.completeLogin(with: token)
                }
                .frame(width: 860, height: 620)
            }
        }
    }
}
