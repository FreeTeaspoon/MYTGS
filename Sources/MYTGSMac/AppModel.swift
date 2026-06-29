import AppKit
import Foundation
import MYTGSCore
import ServiceManagement
import SwiftUI
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings
    @Published var school: SchoolSite?
    @Published var session: FireflySession?
    @Published var dashboardHTML = ""
    @Published var tasks: [FireflyTask] = []
    @Published var taskCriteria = TaskSearchCriteria()
    @Published var selectedTask: FireflyTask?
    @Published var todaySchedule: [TimetablePeriod] = []
    @Published var twoWeekTimetable: [[TimetablePeriod]] = []
    @Published var eprCollection = EPRCollection()
    @Published var eprHTML = ""
    @Published var statusMessage = "Ready"
    @Published var showingLogin = false
    @Published var loginURL: URL?
    @Published var localAPIRunning = false
    @Published var updateStatus = "Sparkle integration pending Xcode project setup"

    private let settingsStore: SettingsPersisting
    private let tokenStore: TokenStore
    private let firefly: FireflyClient
    private let localAPI = LocalAPIServer()
    private let bellPlayer = BellPlayer()
    private var cache: TaskCaching?

    init(
        settingsStore: SettingsPersisting = UserDefaultsSettingsStore(),
        tokenStore: TokenStore = KeychainTokenStore(),
        firefly: FireflyClient = FireflyClient()
    ) {
        self.settingsStore = settingsStore
        self.tokenStore = tokenStore
        self.firefly = firefly
        settings = settingsStore.load()
        cache = try? SwiftDataCacheStore()
        tasks = (try? cache?.loadTasks()) ?? []
        todaySchedule = TimetableEngine.processForUse(events: [], day: Date(), earlyFinish: false, eventsUpToDate: false)
        twoWeekTimetable = Self.makeTwoWeekTimetable(reference: Date())
        updateLocalAPISnapshot()
    }

    var filteredTasks: [FireflyTask] {
        TaskSearch.search(tasks, criteria: taskCriteria)
    }

    var eprPeriods: [EPRPeriod] {
        eprCollection.changes.values
            .map {
                EPRPeriod(
                    period: $0.period,
                    classCode: $0.classCode,
                    roomCode: $0.roomCode,
                    teacher: $0.teacher,
                    teacherChange: $0.teacherChange,
                    roomChange: $0.roomChange
                )
            }
            .sorted { lhs, rhs in
                lhs.period == rhs.period ? lhs.classCode < rhs.classCode : lhs.period < rhs.period
            }
    }

    func bootstrap() {
        requestNotifications()
        applyLaunchAtLogin()
        configureLocalAPI()
        Task { await restoreSessionIfPossible() }
    }

    func persistSettings() {
        settingsStore.save(settings)
        applyLaunchAtLogin()
        configureLocalAPI()
        updateLocalAPISnapshot()
    }

    func beginLogin() {
        Task {
            do {
                statusMessage = "Locating Firefly..."
                let located = try await firefly.lookupSchool()
                school = located
                loginURL = await firefly.loginURL(for: located)
                showingLogin = true
                statusMessage = "Login required"
            } catch {
                statusMessage = "Could not locate Firefly: \(error.localizedDescription)"
            }
        }
    }

    func completeLogin(with token: String) {
        Task {
            guard let school else {
                statusMessage = "Login failed: school is not loaded"
                return
            }
            do {
                let validated = try await firefly.validateSSO(token: token, school: school)
                try tokenStore.saveToken(token)
                session = validated
                showingLogin = false
                statusMessage = "Logged in as \(validated.user.name)"
                await refreshAll()
            } catch {
                statusMessage = "Login failed: \(error.localizedDescription)"
            }
        }
    }

    func logout() {
        Task {
            if let session {
                _ = try? await firefly.logout(session: session)
            }
            try? tokenStore.deleteToken()
            session = nil
            dashboardHTML = ""
            statusMessage = "Logged out"
            updateLocalAPISnapshot()
        }
    }

    func refreshAll() async {
        guard let session else {
            statusMessage = "Sign in to refresh MYTGS"
            return
        }
        do {
            statusMessage = "Refreshing..."
            let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let end = Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date()

            dashboardHTML = try await refreshStep("dashboard") {
                try await firefly.fetchDashboard(session: session)
            }
            eprHTML = try await refreshStep("EPR") {
                try await firefly.fetchEPR(session: session)
            }
            eprCollection = (try? EPRParser.parse(eprHTML)) ?? EPRCollection(errors: true)
            let eventList = try await refreshStep("timetable") {
                try await firefly.fetchEvents(session: session, start: start, end: end)
            }
            let ids = try await refreshStep("task IDs") {
                try await firefly.fetchTaskIDs(session: session, watermark: .distantPast)
            }
            let fetchedTasks = try await refreshStep("tasks") {
                try await firefly.fetchTasks(session: session, ids: ids)
            }
            tasks = fetchedTasks
            try? cache?.saveTasks(fetchedTasks)

            let early = CalendarService.isEarlyFinishToday(events: [], override: settings.todayEarlyFinishOverride)
            let schedule = TimetableEngine.processForUse(events: eventList, day: Date(), earlyFinish: early, eventsUpToDate: true)
            todaySchedule = TimetableEngine.applyEPR(eprCollection, to: schedule)
            twoWeekTimetable = Self.makeTwoWeekTimetable(reference: Date(), events: eventList, earlyFinish: early)
            updateLocalAPISnapshot()
            notifyForEPRChanges()
            if settings.bell.enabled {
                bellPlayer.prepare(volume: settings.bell.volume)
            }
            statusMessage = "Updated \(Date().formatted(date: .omitted, time: .shortened))"
        } catch {
            statusMessage = "Refresh failed: \(error.localizedDescription)"
        }
    }

    private func refreshStep<T>(_ name: String, operation: () async throws -> T) async throws -> T {
        do {
            statusMessage = "Refreshing \(name)..."
            return try await operation()
        } catch {
            throw RefreshStepError(step: name, underlying: error)
        }
    }

    func checkForUpdates() {
        updateStatus = "Updater will be enabled in the signed app bundle"
        statusMessage = updateStatus
    }

    private func restoreSessionIfPossible() async {
        guard session == nil, let token = try? tokenStore.loadToken(), !token.isEmpty else { return }
        do {
            let located = try await firefly.lookupSchool()
            school = located
            session = try await firefly.validateSSO(token: token, school: located)
            await refreshAll()
        } catch {
            statusMessage = "Saved login could not be restored"
        }
    }

    private func configureLocalAPI() {
        if settings.localAPI.enabled {
            do {
                try localAPI.start(settings: settings.localAPI)
                localAPIRunning = true
            } catch {
                localAPIRunning = false
                statusMessage = "Local API failed to start"
            }
        } else {
            localAPI.stop()
            localAPIRunning = false
        }
    }

    private func updateLocalAPISnapshot() {
        localAPI.update(
            state: LocalAPIState(
                twoWeekTimetable: twoWeekTimetable,
                displayName: session?.user.name ?? "",
                timetableDay: "Day \(TimetableEngine.currentTimetableDay(referenceDate: Date(), firstDayDate: Date(), firstDayNumber: eprCollection.day == 0 ? 1 : eprCollection.day))",
                userID: session?.user.username ?? "",
                referenceDay: eprCollection.date ?? Date(),
                eprChanges: eprPeriods
            )
        )
    }

    private func requestNotifications() {
        guard isRunningFromAppBundle else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notifyForEPRChanges() {
        guard isRunningFromAppBundle, !eprPeriods.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = "MYTGS EPR Changes"
        content.body = "\(eprPeriods.count) class change\(eprPeriods.count == 1 ? "" : "s") today"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "mytgs-epr-\(Date().timeIntervalSince1970)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func applyLaunchAtLogin() {
        guard isRunningFromAppBundle else { return }
        do {
            if settings.launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            statusMessage = "Launch at login could not be changed outside an app bundle"
        }
    }

    private var isRunningFromAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
            || (Bundle.main.infoDictionary?["CFBundlePackageType"] as? String) == "APPL"
    }

    private static func makeTwoWeekTimetable(reference: Date, events: [FireflyEvent] = [], earlyFinish: Bool = false) -> [[TimetablePeriod]] {
        let calendar = Calendar.current
        return (0..<10).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: reference) ?? reference
            return TimetableEngine.processForUse(events: events, day: day, earlyFinish: earlyFinish, eventsUpToDate: !events.isEmpty)
        }
    }
}

private final class BellPlayer {
    private var volume: Double = 0.75

    func prepare(volume: Double) {
        self.volume = volume / 100
    }

    func playTestBell() {
        NSSound.beep()
    }
}
