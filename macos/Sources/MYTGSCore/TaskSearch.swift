import Foundation

public enum TaskSortOrder: Int, CaseIterable, Codable, Sendable {
    case latestActivity
    case oldestActivity
    case latestDueDate
    case oldestDueDate
    case latestSetDate
    case oldestSetDate
}

public struct TaskSearchCriteria: Equatable, Sendable {
    public var text: String
    public var teacher: String
    public var id: String
    public var classText: String
    public var order: TaskSortOrder
    public var includeDeleted: Bool
    public var includeHidden: Bool
    public var hideMarked: Bool

    public init(
        text: String = "",
        teacher: String = "",
        id: String = "",
        classText: String = "",
        order: TaskSortOrder = .latestActivity,
        includeDeleted: Bool = false,
        includeHidden: Bool = false,
        hideMarked: Bool = false
    ) {
        self.text = text
        self.teacher = teacher
        self.id = id
        self.classText = classText
        self.order = order
        self.includeDeleted = includeDeleted
        self.includeHidden = includeHidden
        self.hideMarked = hideMarked
    }
}

public enum TaskSearch {
    public static func search(_ tasks: [FireflyTask], criteria: TaskSearchCriteria) -> [FireflyTask] {
        let text = criteria.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let teacher = criteria.teacher.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let id = criteria.id.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let classText = criteria.classText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered = tasks.filter { task in
            if !criteria.includeDeleted && task.deleted { return false }
            if !criteria.includeHidden && task.hideFromRecipients { return false }
            if criteria.hideMarked && task.mark != 0 { return false }
            if !text.isEmpty && !task.title.lowercased().contains(text) { return false }
            if !id.isEmpty && !String(task.id).contains(id) { return false }
            if !teacher.isEmpty && !(task.setter?.name?.lowercased().contains(teacher) ?? false) { return false }
            if !classText.isEmpty && !task.classKeys.contains(where: { $0.lowercased().contains(classText) }) { return false }
            return true
        }

        switch criteria.order {
        case .latestActivity:
            return filtered.sorted { $0.latestActivity > $1.latestActivity }
        case .oldestActivity:
            return filtered.sorted { $0.latestActivity < $1.latestActivity }
        case .latestDueDate:
            return filtered.sorted { $0.dueDate > $1.dueDate }
        case .oldestDueDate:
            return filtered.sorted { $0.dueDate < $1.dueDate }
        case .latestSetDate:
            return filtered.sorted { $0.setDate > $1.setDate }
        case .oldestSetDate:
            return filtered.sorted { $0.setDate < $1.setDate }
        }
    }
}
