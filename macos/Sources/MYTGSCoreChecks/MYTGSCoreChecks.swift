import Foundation
import MYTGSCore

@main
struct MYTGSCoreChecks {
    static func main() throws {
        try checkEPRParser()
        checkTimetableEngine()
        checkTaskSearch()
        checkLocalAPI()
        checkSettingsStore()
        print("MYTGSCoreChecks passed")
    }

    private static func checkEPRParser() throws {
        let html = """
        <p>Bulletin Day 4: 29/06/2026</p>
        <h2>Room Changes</h2>
        <table><tbody>
        <tr><th>Period</th><th>Old Room</th><th>Class</th><th>Teacher</th><th>Old</th><th>New Room</th></tr>
        <tr><td>2</td><td>A1</td><td>122MM4</td><td>Ms Example</td><td>A1</td><td>B7</td></tr>
        </tbody></table>
        <h2>Replacement Teachers</h2>
        <table><tbody>
        <tr><th>Period</th><th>Room</th><th>Class</th><th>Old</th><th>Note</th><th>Replacement Teacher</th></tr>
        <tr><td>2</td><td>B7</td><td>122MM4</td><td>Old</td><td></td><td>Mr Cover</td></tr>
        </tbody></table>
        """
        let epr = try EPRParser.parse(html)
        precondition(epr.day == 4)
        precondition(epr.changes["122MM4-2"]?.roomCode == "B7")
        precondition(epr.changes["122MM4-2"]?.teacher == "Mr Cover")
        precondition(epr.changes["122MM4-2"]?.roomChange == true)
        precondition(epr.changes["122MM4-2"]?.teacherChange == true)
    }

    private static func checkTimetableEngine() {
        let day = Calendar.mytgs.date(from: DateComponents(year: 2026, month: 6, day: 29))!
        let periods = TimetableEngine.processForUse(events: [], day: day, earlyFinish: false, eventsUpToDate: false)
        precondition(periods.count == 9)
        precondition(periods.first?.description == "Form")
        precondition(periods.contains { $0.description == "Lunch" })

        let start = Calendar.mytgs.date(from: DateComponents(year: 2026, month: 6, day: 29, hour: 9, minute: 45))!
        let end = Calendar.mytgs.date(from: DateComponents(year: 2026, month: 6, day: 29, hour: 10, minute: 35))!
        let event = FireflyEvent(
            guid: "122MM4-A-2-29-6-2026",
            start: start,
            end: end,
            location: "B7",
            subject: "Maths",
            attendees: [EventAttendee(principal: Principal(name: "Ms Example"), role: "Chairperson")]
        )
        let parsed = TimetableEngine.parseEventsToPeriods([event])
        precondition(parsed[2].classCode == "122MM4")
        precondition(parsed[2].roomCode == "B7")
        precondition(parsed[2].teacher == "Ms Example")
    }

    private static func checkTaskSearch() {
        let tasks = [
            FireflyTask(
                title: "Maths homework",
                latestActivity: Date(timeIntervalSince1970: 20),
                classKeys: ["122MM4"],
                setter: Principal(name: "Ms Example"),
                mark: 0,
                id: 100
            ),
            FireflyTask(
                title: "English essay",
                latestActivity: Date(timeIntervalSince1970: 10),
                classKeys: ["122ENG1"],
                setter: Principal(name: "Dr Words"),
                mark: 12,
                id: 200
            )
        ]
        let result = TaskSearch.search(tasks, criteria: TaskSearchCriteria(text: "maths", teacher: "example", classText: "MM4", hideMarked: true))
        precondition(result.map(\.id) == [100])
    }

    private static func checkLocalAPI() {
        let server = LocalAPIServer()
        server.update(state: LocalAPIState(displayName: "Student", timetableDay: "Day 4", userID: "123456", referenceDay: Date(timeIntervalSince1970: 0)))
        let response = server.debugResponse(for: "GET /api/info HTTP/1.1\r\n\r\n")
        precondition(response.contains("\"Name\""))
        precondition(response.contains("\"Day\""))
        precondition(response.contains("\"ID\""))
        precondition(response.contains("Student"))
    }

    private static func checkSettingsStore() {
        let defaults = UserDefaults(suiteName: "MYTGSCoreChecks-\(UUID().uuidString)")!
        let store = UserDefaultsSettingsStore(defaults: defaults)
        var settings = AppSettings()
        settings.localAPI.enabled = true
        settings.clock.placementMode = 2
        store.save(settings)
        precondition(store.load().localAPI.enabled)
        precondition(store.load().clock.placementMode == 2)
    }
}
