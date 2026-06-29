import Foundation

public enum TimetableEngine {
    public static let recessPeriods: [BreakPeriod] = [
        BreakPeriod(start: components(hour: 10, minute: 35), end: components(hour: 10, minute: 50), description: "Recess"),
        BreakPeriod(start: components(hour: 10, minute: 5), end: components(hour: 10, minute: 20), description: "Recess"),
        BreakPeriod(start: components(hour: 10, minute: 25), end: components(hour: 10, minute: 40), description: "Recess")
    ]

    public static let lunchPeriods: [BreakPeriod] = [
        BreakPeriod(start: components(hour: 12, minute: 40), end: components(hour: 13, minute: 25), description: "Lunch"),
        BreakPeriod(start: components(hour: 12, minute: 10), end: components(hour: 13, minute: 25), description: "Long Lunch"),
        BreakPeriod(start: components(hour: 12, minute: 20), end: components(hour: 12, minute: 55), description: "Short Lunch")
    ]

    public static let defaultPeriods: [[BreakPeriod]] = [
        [
            BreakPeriod(start: components(hour: 8, minute: 15), end: components(hour: 8, minute: 45), description: "Form"),
            BreakPeriod(start: components(hour: 8, minute: 15), end: components(hour: 8, minute: 14), description: "No Form"),
            BreakPeriod(start: components(hour: 8, minute: 15), end: components(hour: 8, minute: 45), description: "Form")
        ],
        [
            BreakPeriod(start: components(hour: 8, minute: 50), end: components(hour: 9, minute: 40), description: "Period 1"),
            BreakPeriod(start: components(hour: 8, minute: 20), end: components(hour: 9, minute: 10), description: "Period 1"),
            BreakPeriod(start: components(hour: 8, minute: 50), end: components(hour: 9, minute: 35), description: "Period 1")
        ],
        [
            BreakPeriod(start: components(hour: 9, minute: 45), end: components(hour: 10, minute: 35), description: "Period 2"),
            BreakPeriod(start: components(hour: 9, minute: 15), end: components(hour: 10, minute: 5), description: "Period 2"),
            BreakPeriod(start: components(hour: 9, minute: 40), end: components(hour: 10, minute: 25), description: "Period 2")
        ],
        [
            BreakPeriod(start: components(hour: 10, minute: 55), end: components(hour: 11, minute: 45), description: "Period 3"),
            BreakPeriod(start: components(hour: 10, minute: 25), end: components(hour: 11, minute: 15), description: "Period 3"),
            BreakPeriod(start: components(hour: 10, minute: 45), end: components(hour: 11, minute: 30), description: "Period 3")
        ],
        [
            BreakPeriod(start: components(hour: 11, minute: 50), end: components(hour: 12, minute: 40), description: "Period 4"),
            BreakPeriod(start: components(hour: 11, minute: 20), end: components(hour: 12, minute: 10), description: "Period 4"),
            BreakPeriod(start: components(hour: 11, minute: 35), end: components(hour: 12, minute: 20), description: "Period 4")
        ],
        [
            BreakPeriod(start: components(hour: 13, minute: 30), end: components(hour: 14, minute: 20), description: "Period 5"),
            BreakPeriod(start: components(hour: 13, minute: 30), end: components(hour: 14, minute: 20), description: "Period 5"),
            BreakPeriod(start: components(hour: 13, minute: 0), end: components(hour: 13, minute: 45), description: "Period 5")
        ],
        [
            BreakPeriod(start: components(hour: 14, minute: 25), end: components(hour: 15, minute: 15), description: "Period 6"),
            BreakPeriod(start: components(hour: 14, minute: 25), end: components(hour: 15, minute: 15), description: "Period 6"),
            BreakPeriod(start: components(hour: 13, minute: 50), end: components(hour: 14, minute: 35), description: "Period 6")
        ]
    ]

    public static func processForUse(
        events: [FireflyEvent],
        day: Date,
        earlyFinish: Bool,
        eventsUpToDate: Bool,
        findForDay: Bool = true,
        calendar: Calendar = .mytgs
    ) -> [TimetablePeriod] {
        let dayEvents = findForDay ? eventsForDay(events, date: day, calendar: calendar) : events
        var periods = parseEventsToPeriods(dayEvents, calendar: calendar)
        let modified = periods.filter { !$0.roomCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let weekday = calendar.component(.weekday, from: day)
        let isWeekend = weekday == 1 || weekday == 7
        let position = schedulePosition(for: day, earlyFinish: earlyFinish, calendar: calendar)

        if isWeekend {
            return overlapChecked(modified)
        }

        if eventsUpToDate && modified.isEmpty {
            return []
        }

        periods = fillInTable(periods, day: day, earlyFinish: earlyFinish, calendar: calendar)
        let recess = recessPeriods[position]
        let lunch = lunchPeriods[position]
        periods.append(
            TimetablePeriod(
                start: date(on: day, matching: recess.start, calendar: calendar),
                end: date(on: day, matching: recess.end, calendar: calendar),
                description: recess.description,
                classCode: "Recess",
                period: 7
            )
        )
        periods.append(
            TimetablePeriod(
                start: date(on: day, matching: lunch.start, calendar: calendar),
                end: date(on: day, matching: lunch.end, calendar: calendar),
                description: lunch.description,
                classCode: lunch.description,
                period: 8
            )
        )
        return overlapChecked(periods)
    }

    public static func parseEventsToPeriods(_ events: [FireflyEvent], calendar: Calendar = .mytgs) -> [TimetablePeriod] {
        var table = Array(repeating: TimetablePeriod(), count: 7)
        let expression = try? NSRegularExpression(pattern: #"(\w*?)-(.)-(\d)-([0-3]?\d)-([0-1]?\d)-(\d{4})"#)

        for event in events {
            guard
                let expression,
                let match = expression.firstMatch(in: event.guid, range: NSRange(event.guid.startIndex..., in: event.guid)),
                match.numberOfRanges >= 4,
                let classRange = Range(match.range(at: 1), in: event.guid),
                let periodRange = Range(match.range(at: 3), in: event.guid),
                let period = Int(event.guid[periodRange])
            else {
                continue
            }

            table[period] = TimetablePeriod(
                start: event.start,
                end: event.end,
                description: event.subject ?? "",
                classCode: String(event.guid[classRange]),
                roomCode: event.location ?? "",
                goToPeriod: period != 0,
                period: period,
                teacher: event.teacher ?? chairperson(from: event) ?? ""
            )
        }

        if table[0].start != .distantPast {
            table[0].start = date(on: table[0].start, matching: defaultPeriods[0][0].start, calendar: calendar)
        }

        return table
    }

    public static func eventsForDay(_ events: [FireflyEvent], date: Date, calendar: Calendar = .mytgs) -> [FireflyEvent] {
        events.filter { calendar.isDate($0.start, inSameDayAs: date) }
    }

    public static func fillInTable(
        _ periods: [TimetablePeriod],
        day: Date,
        earlyFinish: Bool,
        calendar: Calendar = .mytgs
    ) -> [TimetablePeriod] {
        var result = Array(periods.prefix(7))
        while result.count < 7 {
            result.append(TimetablePeriod())
        }

        let position = schedulePosition(for: day, earlyFinish: earlyFinish, calendar: calendar)
        for index in 0..<7 {
            let fallback = defaultPeriods[index][position]
            if result[index].classCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let code = fallback.description.localizedCaseInsensitiveContains("period")
                    ? "P\(fallback.description.suffix(1))"
                    : fallback.description
                result[index] = TimetablePeriod(
                    start: date(on: day, matching: fallback.start, calendar: calendar),
                    end: date(on: day, matching: fallback.end, calendar: calendar),
                    description: fallback.description,
                    classCode: code,
                    roomCode: "",
                    goToPeriod: fallback.description != "No Form",
                    period: index
                )
            } else if earlyFinish {
                result[index].start = date(on: day, matching: fallback.start, calendar: calendar)
                result[index].end = date(on: day, matching: fallback.end, calendar: calendar)
            }
        }

        return result
    }

    public static func overlapChecked(_ periods: [TimetablePeriod]) -> [TimetablePeriod] {
        var sorted = periods.sorted { $0.start < $1.start }
        guard sorted.count > 1 else { return sorted }
        for index in 0..<(sorted.count - 1) where sorted[index].start != .distantPast {
            if sorted[index + 1].goToPeriod {
                let candidateEnd = sorted[index + 1].start.addingTimeInterval(-5 * 60)
                if candidateEnd > sorted[index].start && candidateEnd < sorted[index].end {
                    sorted[index].end = candidateEnd
                }
            }
        }
        return sorted
    }

    public static func applyEPR(_ epr: EPRCollection, to periods: [TimetablePeriod], notifyOnlyToday: Bool = true, calendar: Calendar = .mytgs) -> [TimetablePeriod] {
        guard let eprDate = epr.date else { return periods }
        if notifyOnlyToday && !calendar.isDateInToday(eprDate) {
            return periods
        }

        return periods.map { period in
            var updated = period
            if let change = epr.changes["\(period.classCode)-\(period.period)"] {
                updated.roomCode = change.roomCode
                updated.teacher = change.teacher
                updated.teacherChange = change.teacherChange
                updated.roomChange = change.roomChange
            }
            return updated
        }
    }

    public static func currentTimetableDay(referenceDate: Date, firstDayDate: Date, firstDayNumber: Int, calendar: Calendar = .mytgs) -> Int {
        let start = calendar.startOfDay(for: firstDayDate)
        let current = calendar.startOfDay(for: referenceDate)
        guard let difference = calendar.dateComponents([.day], from: start, to: current).day else {
            return firstDayNumber
        }
        let adjusted = (firstDayNumber - 1 + difference) % 10
        return adjusted < 0 ? adjusted + 11 : adjusted + 1
    }

    private static func schedulePosition(for day: Date, earlyFinish: Bool, calendar: Calendar) -> Int {
        if earlyFinish {
            return 2
        }
        return calendar.component(.weekday, from: day) == 4 ? 1 : 0
    }

    private static func chairperson(from event: FireflyEvent) -> String? {
        event.attendees.first { $0.role == "Chairperson" }?.principal?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func components(hour: Int, minute: Int) -> DateComponents {
        DateComponents(hour: hour, minute: minute, second: 0)
    }

    private static func date(on day: Date, matching components: DateComponents, calendar: Calendar) -> Date {
        let base = calendar.dateComponents([.year, .month, .day], from: day)
        var combined = DateComponents()
        combined.calendar = calendar
        combined.year = base.year
        combined.month = base.month
        combined.day = base.day
        combined.hour = components.hour
        combined.minute = components.minute
        combined.second = components.second ?? 0
        return calendar.date(from: combined) ?? day
    }
}
