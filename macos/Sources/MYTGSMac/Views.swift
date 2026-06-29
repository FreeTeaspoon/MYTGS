import SwiftUI
import MYTGSCore

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.largeTitle.bold())
                        Text(model.statusMessage)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusPill(text: model.localAPIRunning ? "Local API On" : "Local API Off", symbol: "network")
                }

                CurrentPeriodStrip(schedule: model.todaySchedule)

                NativePanel {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("EPR Changes", systemImage: "exclamationmark.triangle")
                            .font(.headline)
                        if model.eprPeriods.isEmpty {
                            Text("No changes loaded.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(model.eprPeriods) { period in
                                HStack {
                                    Text("P\(period.period)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    Text(period.classCode)
                                    Spacer()
                                    Text(period.roomCode)
                                    Text(period.teacher)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                NativePanel {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Dashboard", systemImage: "rectangle.3.group")
                            .font(.headline)
                        Text(model.dashboardHTML.isEmpty ? "Sign in and refresh to load Firefly dashboard messages." : model.dashboardHTML.htmlStripped())
                            .textSelection(.enabled)
                            .foregroundStyle(model.dashboardHTML.isEmpty ? .secondary : .primary)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
    }
}

struct TasksView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                List(model.filteredTasks) { task in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title.isEmpty ? "Untitled task" : task.title)
                            .font(.headline)
                        HStack {
                            Text(task.setter?.name ?? "Unknown teacher")
                            Spacer()
                            Text(task.dueDate, style: .date)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.selectedTask = task
                    }
                }
                .searchable(text: $model.taskCriteria.text, placement: .toolbar, prompt: "Search tasks")
            }
            .frame(minWidth: 320)

            TaskDetailView(task: model.selectedTask ?? model.filteredTasks.first)
                .frame(minWidth: 420)
        }
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItemGroup {
                Picker("Sort", selection: $model.taskCriteria.order) {
                    Text("Recent Activity").tag(TaskSortOrder.latestActivity)
                    Text("Oldest Activity").tag(TaskSortOrder.oldestActivity)
                    Text("Latest Due").tag(TaskSortOrder.latestDueDate)
                    Text("Oldest Due").tag(TaskSortOrder.oldestDueDate)
                    Text("Latest Set").tag(TaskSortOrder.latestSetDate)
                    Text("Oldest Set").tag(TaskSortOrder.oldestSetDate)
                }
                .pickerStyle(.menu)
            }
        }
    }
}

struct TaskDetailView: View {
    var task: FireflyTask?

    var body: some View {
        ScrollView {
            if let task {
                VStack(alignment: .leading, spacing: 16) {
                    Text(task.title.isEmpty ? "Untitled task" : task.title)
                        .font(.title.bold())
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                        GridRow {
                            Text("Due").foregroundStyle(.secondary)
                            Text(task.dueDate, style: .date)
                        }
                        GridRow {
                            Text("Set").foregroundStyle(.secondary)
                            Text(task.setDate, style: .date)
                        }
                        GridRow {
                            Text("Teacher").foregroundStyle(.secondary)
                            Text(task.setter?.name ?? "Unknown")
                        }
                        GridRow {
                            Text("ID").foregroundStyle(.secondary)
                            Text("\(task.id)")
                        }
                    }
                    NativePanel {
                        Text(task.descriptionDetails?.htmlContent?.htmlStripped() ?? "No description.")
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(24)
            } else {
                ContentUnavailableView("No Task Selected", systemImage: "checklist", description: Text("Select a task after refreshing from Firefly."))
            }
        }
    }
}

struct TimetableView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CurrentPeriodStrip(schedule: model.todaySchedule)
                NativePanel {
                    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(Array(model.twoWeekTimetable.enumerated()), id: \.offset) { dayIndex, day in
                            GridRow {
                                Text("Day \(dayIndex + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                ForEach(day) { period in
                                    PeriodCell(period: period)
                                        .frame(minWidth: 92, minHeight: 58)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Timetable")
    }
}

struct EPRView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            List(model.eprPeriods) { period in
                HStack {
                    Text("Period \(period.period)")
                        .font(.headline)
                    Text(period.classCode)
                    Spacer()
                    if period.roomChange {
                        Label(period.roomCode, systemImage: "mappin.and.ellipse")
                    }
                    if period.teacherChange {
                        Label(period.teacher, systemImage: "person")
                    }
                }
            }
            WebHTMLView(html: model.eprHTML)
                .frame(minHeight: 240)
        }
        .navigationTitle("EPR")
    }
}

struct AccountView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Firefly") {
                LabeledContent("Name", value: model.session?.user.name ?? "Not signed in")
                LabeledContent("Email", value: model.session?.user.email ?? "-")
                LabeledContent("School", value: model.session?.school.name ?? model.school?.name ?? "-")
                HStack {
                    Button("Sign In") {
                        model.beginLogin()
                    }
                    Button("Sign Out", role: .destructive) {
                        model.logout()
                    }
                    .disabled(model.session == nil)
                }
            }
            Section("Status") {
                Text(model.statusMessage)
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Account")
    }
}

struct CurrentPeriodStrip: View {
    var schedule: [TimetablePeriod]

    var body: some View {
        NativePanel {
            HStack(spacing: 8) {
                ForEach(schedule.prefix(9)) { period in
                    PeriodCell(period: period)
                }
            }
        }
    }
}

struct PeriodCell: View {
    var period: TimetablePeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(period.classCode.isEmpty ? period.description : period.classCode)
                .font(.headline)
                .lineLimit(1)
            Text(period.roomCode.isEmpty ? period.description : period.roomCode)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if period.hasChanges {
                Label("Changed", systemImage: "sparkles")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct NativePanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.separator.opacity(0.35))
            }
    }
}

struct StatusPill: View {
    var text: String
    var symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }
}

extension String {
    func htmlStripped() -> String {
        replacingOccurrences(of: #"(?is)<script[^>]*>.*?</script>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?is)<style[^>]*>.*?</style>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .split(separator: " ")
            .joined(separator: " ")
    }
}
