import Foundation

public enum EPRParser {
    public enum ParserError: Error, Equatable {
        case missingHeader
        case invalidDay
        case invalidDate
    }

    public static func parse(_ html: String, calendar: Calendar = .mytgs) throws -> EPRCollection {
        let compact = html.replacingOccurrences(of: #"\t|\n|\r"#, with: "", options: .regularExpression)
        guard let header = firstMatch(
            in: compact,
            pattern: #"day\s*?([0-9]0?)[\s:]*(\d{1,2})\s*/\s*(\d{1,2})\s*/\s*(\d{4,})"#,
            options: [.caseInsensitive]
        ) else {
            throw ParserError.missingHeader
        }

        guard let day = Int(header[1]), day <= 10 else {
            throw ParserError.invalidDay
        }
        guard
            let dateDay = Int(header[2]),
            let month = Int(header[3]),
            let year = Int(header[4]),
            let date = calendar.date(from: DateComponents(year: year, month: month, day: dateDay))
        else {
            throw ParserError.invalidDate
        }

        var collection = EPRCollection(date: date, day: day)
        var hadRowErrors = false

        if let table = firstMatch(in: compact, pattern: #"room\s{0,4}changes(?:.|\n)*?<tbody>((?:.|\n)*?)</tbody>"#, options: [.caseInsensitive]) {
            parseRows(
                tableHTML: table[1],
                collection: &collection,
                defaultColumns: TableColumns(period: 0, classCode: 2, teacher: 3, room: 5),
                changeType: .room,
                hadRowErrors: &hadRowErrors
            )
        }

        if let table = firstMatch(in: compact, pattern: #"replacement\s{0,4}teachers(?:.|\n)*?<tbody.*?>((?:.|\n)*?)</tbody.*?>"#, options: [.caseInsensitive]) {
            parseRows(
                tableHTML: table[1],
                collection: &collection,
                defaultColumns: TableColumns(period: 0, classCode: 2, teacher: 5, room: 1),
                changeType: .teacher,
                hadRowErrors: &hadRowErrors
            )
        }

        collection.errors = hadRowErrors
        return collection
    }

    private enum ChangeType {
        case room
        case teacher
    }

    private struct TableColumns {
        var period: Int
        var classCode: Int
        var teacher: Int
        var room: Int
    }

    private static func parseRows(
        tableHTML: String,
        collection: inout EPRCollection,
        defaultColumns: TableColumns,
        changeType: ChangeType,
        hadRowErrors: inout Bool
    ) {
        let rows = matches(in: tableHTML, pattern: #"<tr>([\s\S]*?)</tr>"#, options: [.caseInsensitive]).map { $0[1] }
        guard let header = rows.first else { return }

        var columns = defaultColumns
        let headerColumns = cellValues(in: header)
        for (index, value) in headerColumns.enumerated() {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized.contains("period") {
                columns.period = index
            } else if normalized.hasPrefix("class") {
                columns.classCode = index
            } else if normalized.hasPrefix("replacement teacher") || normalized.hasPrefix("teacher") {
                columns.teacher = index
            } else if normalized.contains("new room") || normalized.contains("room") {
                columns.room = index
            }
        }

        for row in rows.dropFirst() {
            let values = cellValues(in: row)
            guard values.indices.contains(columns.period),
                  values.indices.contains(columns.classCode),
                  values.indices.contains(columns.teacher),
                  values.indices.contains(columns.room),
                  let period = Int(values[columns.period].trimmingCharacters(in: .whitespacesAndNewlines)) else {
                hadRowErrors = true
                continue
            }

            let classCode = values[columns.classCode].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !classCode.isEmpty else { continue }

            let key = "\(classCode)-\(period)"
            var periodChange = collection.changes[key] ?? TimetablePeriod(classCode: classCode, period: period)
            periodChange.period = period
            periodChange.classCode = classCode

            switch changeType {
            case .room:
                periodChange.teacher = values[columns.teacher].trimmingCharacters(in: .whitespacesAndNewlines)
                periodChange.roomCode = values[columns.room].trimmingCharacters(in: .whitespacesAndNewlines)
                periodChange.roomChange = true
            case .teacher:
                periodChange.teacher = values[columns.teacher].trimmingCharacters(in: .whitespacesAndNewlines)
                periodChange.roomCode = values[columns.room].trimmingCharacters(in: .whitespacesAndNewlines)
                periodChange.teacherChange = true
            }

            collection.changes[key] = periodChange
        }
    }

    private static func cellValues(in rowHTML: String) -> [String] {
        matches(in: rowHTML, pattern: #"<[^/]*>\s*([^<>]*?)\s*</"#, options: [.caseInsensitive])
            .map { decodeHTML($0[1].trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    private static func firstMatch(in text: String, pattern: String, options: NSRegularExpression.Options = []) -> [String]? {
        matches(in: text, pattern: pattern, options: options).first
    }

    private static func matches(in text: String, pattern: String, options: NSRegularExpression.Options = []) -> [[String]] {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: nsRange).map { match in
            (0..<match.numberOfRanges).map { index in
                guard let range = Range(match.range(at: index), in: text) else { return "" }
                return String(text[range])
            }
        }
    }

    private static func decodeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
