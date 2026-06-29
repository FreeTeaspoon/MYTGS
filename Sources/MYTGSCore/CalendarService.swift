import Foundation

public enum CalendarService {
    public static func earlyFinishes(from events: [CalendarEvent], after date: Date = Date(), calendar: Calendar = .mytgs) -> [CalendarEvent] {
        events
            .filter { $0.summary.lowercased().contains("early finish") && $0.start >= calendar.date(byAdding: .day, value: -1, to: date)! }
            .sorted { $0.start < $1.start }
    }

    public static func isEarlyFinishToday(events: [CalendarEvent], override: Bool?, today: Date = Date(), calendar: Calendar = .mytgs) -> Bool {
        if let override {
            return override
        }
        return earlyFinishes(from: events, after: today, calendar: calendar).contains {
            calendar.isDate($0.start, inSameDayAs: today)
        }
    }
}
