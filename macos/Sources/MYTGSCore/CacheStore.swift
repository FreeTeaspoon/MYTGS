import Foundation
import SwiftData

@Model
public final class CachedTaskRecord {
    @Attribute(.unique) public var id: Int
    public var payload: Data
    public var updatedAt: Date

    public init(id: Int, payload: Data, updatedAt: Date = Date()) {
        self.id = id
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@Model
public final class CachedCalendarEventRecord {
    @Attribute(.unique) public var uid: String
    public var payload: Data
    public var updatedAt: Date

    public init(uid: String, payload: Data, updatedAt: Date = Date()) {
        self.uid = uid
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@Model
public final class CachedSettingRecord {
    @Attribute(.unique) public var name: String
    public var value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

public protocol TaskCaching: Sendable {
    func loadTasks() throws -> [FireflyTask]
    func saveTasks(_ tasks: [FireflyTask]) throws
    func loadCacheValue(named name: String) throws -> String?
    func saveCacheValue(_ value: String, named name: String) throws
}

public final class SwiftDataCacheStore: TaskCaching, @unchecked Sendable {
    private let container: ModelContainer

    public init(url: URL? = nil) throws {
        let schema = Schema([
            CachedTaskRecord.self,
            CachedCalendarEventRecord.self,
            CachedSettingRecord.self
        ])
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        container = try ModelContainer(for: schema, configurations: [configuration])
    }

    public func loadTasks() throws -> [FireflyTask] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CachedTaskRecord>(sortBy: [SortDescriptor(\CachedTaskRecord.updatedAt, order: .reverse)])
        return try context.fetch(descriptor).compactMap { record in
            try? MYTGSDateCoding.decoder.decode(FireflyTask.self, from: record.payload)
        }
    }

    public func saveTasks(_ tasks: [FireflyTask]) throws {
        let context = ModelContext(container)
        for task in tasks {
            let data = try MYTGSDateCoding.encoder.encode(task)
            let id = task.id
            var descriptor = FetchDescriptor<CachedTaskRecord>(predicate: #Predicate<CachedTaskRecord> { $0.id == id })
            descriptor.fetchLimit = 1
            if let existing = try context.fetch(descriptor).first {
                existing.payload = data
                existing.updatedAt = Date()
            } else {
                context.insert(CachedTaskRecord(id: task.id, payload: data))
            }
        }
        try context.save()
    }

    public func loadCacheValue(named name: String) throws -> String? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CachedSettingRecord>(predicate: #Predicate<CachedSettingRecord> { $0.name == name })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.value
    }

    public func saveCacheValue(_ value: String, named name: String) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CachedSettingRecord>(predicate: #Predicate<CachedSettingRecord> { $0.name == name })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.value = value
        } else {
            context.insert(CachedSettingRecord(name: name, value: value))
        }
        try context.save()
    }
}
