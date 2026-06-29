import AppKit
import SwiftUI
import MYTGSCore

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(
                        title: "Today",
                        subtitle: model.statusMessage,
                        trailing: {
                            HStack(spacing: 8) {
                                StatusPill(text: model.localAPIRunning ? "Local API On" : "Local API Off", symbol: "network", tint: model.localAPIRunning ? .green : .gray)
                                StatusPill(text: model.session == nil ? "Signed Out" : "Signed In", symbol: model.session == nil ? "person.crop.circle.badge.xmark" : "checkmark.seal", tint: model.session == nil ? .gray : .green)
                            }
                        }
                    )

                    GlassEffectContainer(spacing: 12) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                            PeriodSummaryCard(title: "Now", symbol: "clock", period: model.currentPeriod(at: context.date), fallback: "No active period")
                            PeriodSummaryCard(title: "Next", symbol: "forward", period: model.nextPeriod(after: context.date), fallback: "Day complete")
                            SummaryMetricCard(title: "Tasks", value: "\(model.filteredTasks.count)", detail: model.tasks.isEmpty ? "No tasks loaded" : "Matching current filters", symbol: "checklist")
                            SummaryMetricCard(title: "EPR", value: "\(model.eprPeriods.count)", detail: model.eprPeriods.count == 1 ? "change today" : "changes today", symbol: "exclamationmark.triangle", tint: model.eprPeriods.isEmpty ? .gray : .orange)
                        }
                    }

                    CurrentPeriodStrip(schedule: model.todaySchedule, colors: model.settings.classColors)

                    NativePanel {
                        VStack(alignment: .leading, spacing: 12) {
                            PanelTitle("EPR Changes", systemImage: "exclamationmark.triangle")
                            if model.eprPeriods.isEmpty {
                                EmptyInlineState(title: "No changes loaded", symbol: "checkmark.circle")
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(model.eprPeriods.prefix(4)) { period in
                                        EPRChangeRow(period: period, compact: true)
                                    }
                                }
                            }
                        }
                    }

                    NativePanel {
                        VStack(alignment: .leading, spacing: 12) {
                            PanelTitle("Dashboard", systemImage: "rectangle.3.group")
                            if model.dashboardHTML.isEmpty {
                                EmptyInlineState(title: "Sign in and refresh to load Firefly dashboard messages", symbol: "tray")
                            } else {
                                WebHTMLView(html: model.dashboardHTML)
                                    .frame(minHeight: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 1180, alignment: .leading)
            }
        }
        .navigationTitle("Dashboard")
        .accessibilityIdentifier("screen-Dashboard")
    }
}

struct TasksView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                if model.filteredTasks.isEmpty {
                    ContentUnavailableView(
                        model.tasks.isEmpty ? "No Tasks Loaded" : "No Matching Tasks",
                        systemImage: "checklist",
                        description: Text(model.tasks.isEmpty ? "Sign in and refresh to load Firefly tasks." : "Try a different search or sort option.")
                    )
                    .frame(minWidth: 340)
                } else {
                    List(selection: selectedTaskID) {
                        ForEach(model.filteredTasks) { task in
                            TaskRow(task: task)
                                .tag(task.id)
                        }
                    }
                    .listStyle(.inset)
                    .frame(minWidth: 340)
                }
            }
            .searchable(text: $model.taskCriteria.text, placement: .toolbar, prompt: "Search tasks")

            TaskDetailView(task: model.selectedTask ?? model.filteredTasks.first)
                .frame(minWidth: 440)
        }
        .navigationTitle("Tasks")
        .accessibilityIdentifier("screen-Tasks")
        .toolbar {
            ToolbarItemGroup {
                Picker("Sort", selection: $model.taskCriteria.order) {
                    ForEach(TaskSortOrder.allCases, id: \.self) { order in
                        Text(order.title).tag(order)
                    }
                }
                .pickerStyle(.menu)

                StatusPill(text: "\(model.filteredTasks.count)", symbol: "checklist", tint: .blue)
            }
        }
    }

    private var selectedTaskID: Binding<Int?> {
        Binding(
            get: { model.selectedTask?.id ?? model.filteredTasks.first?.id },
            set: { id in
                model.selectedTask = model.filteredTasks.first { $0.id == id }
            }
        )
    }
}

private struct TaskRow: View {
    var task: FireflyTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(task.title.isEmpty ? "Untitled task" : task.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 10)
                DueBadge(date: task.dueDate)
            }

            HStack(spacing: 8) {
                Label(task.setter?.name ?? "Unknown teacher", systemImage: "person")
                if !task.classKeys.isEmpty {
                    Label(task.classKeys.prefix(2).joined(separator: ", "), systemImage: "person.3")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct TaskDetailView: View {
    var task: FireflyTask?

    var body: some View {
        ScrollView {
            if let task {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(
                        title: task.title.isEmpty ? "Untitled task" : task.title,
                        subtitle: task.setter?.name ?? "Unknown teacher",
                        trailing: {
                            DueBadge(date: task.dueDate)
                        }
                    )

                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            StatusPill(text: "Set \(task.setDate.formatted(date: .abbreviated, time: .omitted))", symbol: "calendar.badge.plus", tint: .blue)
                            StatusPill(text: "Activity \(task.latestActivity.formatted(date: .abbreviated, time: .omitted))", symbol: "waveform.path.ecg", tint: .purple)
                            StatusPill(text: "ID \(task.id)", symbol: "number", tint: .gray)
                        }
                    }

                    NativePanel {
                        VStack(alignment: .leading, spacing: 12) {
                            PanelTitle("Details", systemImage: "doc.text")
                            Text(task.descriptionDetails?.htmlContent?.htmlStripped().nilIfEmpty ?? "No description.")
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !task.classKeys.isEmpty {
                        NativePanel {
                            VStack(alignment: .leading, spacing: 10) {
                                PanelTitle("Classes", systemImage: "person.3")
                                FlowPills(values: task.classKeys)
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 860, alignment: .leading)
            } else {
                ContentUnavailableView("No Task Selected", systemImage: "checklist", description: Text("Select a task after refreshing from Firefly."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
            }
        }
    }
}

struct TimetableView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Timetable",
                    subtitle: model.lastUpdated.map { "Updated \($0.formatted(date: .omitted, time: .shortened))" } ?? "Two-week timetable"
                )

                CurrentPeriodStrip(schedule: model.todaySchedule, colors: model.settings.classColors)

                NativePanel {
                    VStack(alignment: .leading, spacing: 12) {
                        PanelTitle("Next Two Weeks", systemImage: "calendar")
                        ScrollView(.horizontal) {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(model.twoWeekTimetable.enumerated()), id: \.offset) { dayIndex, day in
                                    TimetableDayRow(dayNumber: dayIndex + 1, periods: day, colors: model.settings.classColors)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 1180, alignment: .leading)
        }
        .navigationTitle("Timetable")
        .accessibilityIdentifier("screen-Timetable")
    }
}

private struct TimetableDayRow: View {
    var dayNumber: Int
    var periods: [TimetablePeriod]
    var colors: [String: String]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("Day \(dayNumber)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 54, height: 70, alignment: .topLeading)
                .padding(.top, 10)

            ForEach(periods) { period in
                PeriodCell(period: period, color: periodColor(for: period, colors: colors))
                    .frame(width: 116, height: 70)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct EPRView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "EPR",
                    subtitle: model.eprPeriods.isEmpty ? "No changes loaded" : "\(model.eprPeriods.count) change\(model.eprPeriods.count == 1 ? "" : "s") loaded",
                    trailing: {
                        StatusPill(text: model.eprCollection.errors ? "Parser Warning" : "Ready", symbol: model.eprCollection.errors ? "exclamationmark.triangle" : "checkmark.circle", tint: model.eprCollection.errors ? .orange : .green)
                    }
                )

                if model.eprPeriods.isEmpty {
                    ContentUnavailableView("No EPR Changes", systemImage: "checkmark.circle", description: Text("Refresh after signing in to load today's EPR list."))
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(model.eprPeriods) { period in
                            EPRChangeRow(period: period)
                        }
                    }
                }

                NativePanel {
                    VStack(alignment: .leading, spacing: 12) {
                        PanelTitle("Original EPR Page", systemImage: "safari")
                        WebHTMLView(html: model.eprHTML)
                            .frame(minHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .navigationTitle("EPR")
        .accessibilityIdentifier("screen-EPR")
    }
}

struct AccountView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Account",
                    subtitle: model.session == nil ? "Not signed in" : model.session?.user.email ?? "Signed in",
                    trailing: {
                        StatusPill(text: model.session == nil ? "Signed Out" : "Signed In", symbol: model.session == nil ? "person.crop.circle.badge.xmark" : "checkmark.seal", tint: model.session == nil ? .gray : .green)
                    }
                )

                NativePanel {
                    VStack(alignment: .leading, spacing: 12) {
                        PanelTitle("Firefly", systemImage: "person.crop.circle")
                        AccountRow(label: "Name", value: model.session?.user.name ?? "Not signed in")
                        AccountRow(label: "Email", value: model.session?.user.email ?? "-")
                        AccountRow(label: "School", value: model.session?.school.name ?? model.school?.name ?? "-")
                        Divider()
                        HStack {
                            Button {
                                model.beginLogin()
                            } label: {
                                Label("Sign In", systemImage: "person.badge.key")
                            }
                            .disabled(model.isRefreshing)

                            Button(role: .destructive) {
                                model.logout()
                            } label: {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                            .disabled(model.session == nil)
                        }
                    }
                }

                NativePanel {
                    VStack(alignment: .leading, spacing: 12) {
                        PanelTitle("Status", systemImage: "info.circle")
                        Text(model.statusMessage)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle("Account")
        .accessibilityIdentifier("screen-Account")
    }
}

struct CurrentPeriodStrip: View {
    var schedule: [TimetablePeriod]
    var colors: [String: String] = [:]

    var body: some View {
        NativePanel {
            VStack(alignment: .leading, spacing: 12) {
                PanelTitle("Today", systemImage: "clock")
                if schedule.isEmpty {
                    EmptyInlineState(title: "No timetable loaded", symbol: "calendar.badge.exclamationmark")
                } else {
                    ScrollView(.horizontal) {
                        GlassEffectContainer(spacing: 8) {
                            HStack(spacing: 8) {
                                ForEach(schedule.prefix(9)) { period in
                                    PeriodCell(period: period, color: periodColor(for: period, colors: colors))
                                        .frame(width: 118, height: 72)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }
}

struct PeriodCell: View {
    var period: TimetablePeriod
    var color: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(period.displayClass)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(period.displayRoom)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Text(period.timeRange)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if period.hasChanges {
                    Image(systemName: "sparkles")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .glassEffect(in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.22))
                .frame(width: 3)
        }
        .accessibilityLabel("\(period.displayClass), \(period.displayRoom), \(period.timeRange)")
    }
}

private struct PeriodSummaryCard: View {
    var title: String
    var symbol: String
    var period: TimetablePeriod?
    var fallback: String

    var body: some View {
        SummaryMetricCard(
            title: title,
            value: period?.displayClass ?? "MYTGS",
            detail: period.map { "\($0.displayRoom) - \($0.timeRange)" } ?? fallback,
            symbol: symbol,
            tint: period == nil ? .gray : .blue
        )
    }
}

private struct SummaryMetricCard: View {
    var title: String
    var value: String
    var detail: String
    var symbol: String
    var tint: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .glassEffect(in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 36, height: 36)
                .padding(12)
        }
    }
}

struct NativePanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        content
            .padding(16)
            .background(.regularMaterial, in: shape)
            .glassEffect(in: shape)
            .overlay {
                shape.strokeBorder(.separator.opacity(0.32))
            }
    }
}

struct StatusPill: View {
    var text: String
    var symbol: String
    var tint: Color = .accentColor

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(tint)
            .background(.thinMaterial, in: Capsule())
            .glassEffect(in: Capsule())
    }
}

private struct PageHeader<Trailing: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var trailing: Trailing

    init(title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 16)
            trailing
        }
    }
}

private extension PageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
        trailing = EmptyView()
    }
}

private struct PanelTitle: View {
    var title: String
    var systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
    }
}

private struct EmptyInlineState: View {
    var title: String
    var symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}

private struct DueBadge: View {
    var date: Date

    var body: some View {
        Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(tint)
            .background(.thinMaterial, in: Capsule())
            .glassEffect(in: Capsule())
    }

    private var tint: Color {
        if Calendar.current.isDateInToday(date) { return .orange }
        if date < Date() { return .red }
        return .secondaryText
    }
}

private struct EPRChangeRow: View {
    var period: EPRPeriod
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            Text("P\(period.period)")
                .font(.headline.monospacedDigit())
                .frame(width: 42, alignment: .leading)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(period.classCode)
                    .font(.headline)
                if !compact {
                    Text(changeSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            if period.roomChange {
                StatusPill(text: period.roomCode, symbol: "mappin.and.ellipse", tint: .orange)
            }
            if period.teacherChange {
                StatusPill(text: period.teacher, symbol: "person", tint: .blue)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .glassEffect(in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel("Period \(period.period), \(period.classCode), \(changeSummary)")
    }

    private var changeSummary: String {
        [period.roomChange ? "Room \(period.roomCode)" : nil, period.teacherChange ? "Teacher \(period.teacher)" : nil]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

private struct AccountRow: View {
    var label: String
    var value: String

    var body: some View {
        LabeledContent {
            Text(value)
                .textSelection(.enabled)
                .foregroundStyle(value == "-" ? .secondary : .primary)
        } label: {
            Text(label)
        }
    }
}

private struct FlowPills: View {
    var values: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(values, id: \.self) { value in
                StatusPill(text: value, symbol: "tag", tint: .blue)
            }
        }
    }
}

private extension TaskSortOrder {
    var title: String {
        switch self {
        case .latestActivity: "Recent Activity"
        case .oldestActivity: "Oldest Activity"
        case .latestDueDate: "Latest Due"
        case .oldestDueDate: "Oldest Due"
        case .latestSetDate: "Latest Set"
        case .oldestSetDate: "Oldest Set"
        }
    }
}

private extension TimetablePeriod {
    var displayClass: String {
        classCode.nilIfEmpty ?? description.nilIfEmpty ?? "Period \(period)"
    }

    var displayRoom: String {
        roomCode.nilIfEmpty ?? teacher.nilIfEmpty ?? description.nilIfEmpty ?? "No room"
    }

    var timeRange: String {
        "\(start.formatted(date: .omitted, time: .shortened))-\(end.formatted(date: .omitted, time: .shortened))"
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Color {
    static let secondaryText = Color(nsColor: .secondaryLabelColor)

    init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}

private func periodColor(for period: TimetablePeriod, colors: [String: String]) -> Color {
    if let custom = colors[period.classCode], let color = Color(hexString: custom) {
        return color
    }

    let palette: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo]
    let key = period.classCode.nilIfEmpty ?? period.description
    let index = key.unicodeScalars.reduce(0) { $0 + Int($1.value) } % palette.count
    return palette[index]
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
