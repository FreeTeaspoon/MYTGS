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
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    @State private var selection: AppSection? = .dashboard

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 215, max: 260)
        } detail: {
            detail
                .frame(minWidth: 820, minHeight: 560)
                .toolbar { detailToolbar }
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

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.symbol)
                    .tag(section)
            }
            .listStyle(.sidebar)

            SidebarStatusFooter()
                .environmentObject(model)
        }
        .navigationTitle("MYTGS")
    }

    @ViewBuilder
    private var detail: some View {
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

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                Task { await model.refreshAll() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(model.isRefreshing || model.session == nil)
            .help(model.session == nil ? "Sign in before refreshing" : "Refresh MYTGS")
        }

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                if model.session == nil {
                    model.beginLogin()
                } else {
                    selection = .account
                }
            } label: {
                Label(
                    model.session == nil ? "Sign In" : "Account",
                    systemImage: model.session == nil ? "person.badge.key" : "checkmark.seal"
                )
            }
            .help(model.session == nil ? "Sign in to Firefly" : "Show account")

            Button {
                model.settings.clock.showFloatingClock.toggle()
                model.persistSettings()
                clockPanel.update(schedule: model.todaySchedule, settings: model.settings.clock)
            } label: {
                Label(
                    model.settings.clock.showFloatingClock ? "Hide Floating Clock" : "Show Floating Clock",
                    systemImage: model.settings.clock.showFloatingClock ? "clock.badge.checkmark" : "macwindow.on.rectangle"
                )
            }
            .help("Toggle the floating timetable clock")
        }
    }
}

private struct SidebarStatusFooter: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(model.session == nil ? "Signed out" : "Signed in", systemImage: model.session == nil ? "person.crop.circle.badge.xmark" : "person.crop.circle.badge.checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(model.session == nil ? Color.gray : Color.green)

            Text(model.lastUpdated.map { "Updated \($0.formatted(date: .omitted, time: .shortened))" } ?? model.statusMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
    }
}
