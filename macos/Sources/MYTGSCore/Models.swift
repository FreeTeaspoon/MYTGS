import Foundation

public struct SchoolSite: Codable, Equatable, Sendable {
    public var name: String
    public var url: URL

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

public struct FireflySession: Codable, Equatable, Sendable {
    public var token: String
    public var deviceID: String
    public var user: FireflyUser
    public var school: SchoolSite

    public init(token: String, deviceID: String, user: FireflyUser, school: SchoolSite) {
        self.token = token
        self.deviceID = deviceID
        self.user = user
        self.school = school
    }
}

public struct FireflyUser: Codable, Equatable, Sendable {
    public var guid: String
    public var username: String
    public var name: String
    public var email: String
    public var canSetTasks: Bool

    public init(guid: String, username: String, name: String, email: String, canSetTasks: Bool) {
        self.guid = guid
        self.username = username
        self.name = name
        self.email = email
        self.canSetTasks = canSetTasks
    }
}

public struct FireflyTask: Codable, Identifiable, Equatable, Sendable {
    public var descriptionDetails: DescriptionDetails?
    public var hideFromRecipients: Bool
    public var title: String
    public var setDate: Date
    public var dueDate: Date
    public var latestActivity: Date
    public var classKeys: [String]
    public var setter: Principal?
    public var coowners: [Principal]
    public var fileAttachments: [FileAttachment]
    public var pageAttachments: [PageAttachment]
    public var addressees: [Address]
    public var recipientsResponses: [RecipientResponse]
    public var deleted: Bool
    public var archived: Bool
    public var draft: Bool
    public var totalMarkOutOf: Double
    public var mark: Double
    public var id: Int

    public init(
        descriptionDetails: DescriptionDetails? = nil,
        hideFromRecipients: Bool = false,
        title: String = "",
        setDate: Date = .distantPast,
        dueDate: Date = .distantPast,
        latestActivity: Date = .distantPast,
        classKeys: [String] = [],
        setter: Principal? = nil,
        coowners: [Principal] = [],
        fileAttachments: [FileAttachment] = [],
        pageAttachments: [PageAttachment] = [],
        addressees: [Address] = [],
        recipientsResponses: [RecipientResponse] = [],
        deleted: Bool = false,
        archived: Bool = false,
        draft: Bool = false,
        totalMarkOutOf: Double = 0,
        mark: Double = 0,
        id: Int
    ) {
        self.descriptionDetails = descriptionDetails
        self.hideFromRecipients = hideFromRecipients
        self.title = title
        self.setDate = setDate
        self.dueDate = dueDate
        self.latestActivity = latestActivity
        self.classKeys = classKeys
        self.setter = setter
        self.coowners = coowners
        self.fileAttachments = fileAttachments
        self.pageAttachments = pageAttachments
        self.addressees = addressees
        self.recipientsResponses = recipientsResponses
        self.deleted = deleted
        self.archived = archived
        self.draft = draft
        self.totalMarkOutOf = totalMarkOutOf
        self.mark = mark
        self.id = id
    }

    enum CodingKeys: String, CodingKey {
        case descriptionDetails
        case hideFromRecipients
        case title
        case setDate
        case dueDate
        case latestActivity = "LatestestActivity"
        case classKeys = "ClassKeys"
        case setter
        case coowners
        case fileAttachments
        case pageAttachments
        case addressees
        case recipientsResponses
        case deleted
        case archived
        case draft
        case totalMarkOutOf
        case mark
        case id
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        descriptionDetails = try container.decodeIfPresent(DescriptionDetails.self, forKey: .descriptionDetails)
        hideFromRecipients = try container.decodeIfPresent(Bool.self, forKey: .hideFromRecipients) ?? false
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        setDate = try container.decodeIfPresent(Date.self, forKey: .setDate) ?? .distantPast
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate) ?? .distantPast
        latestActivity = try container.decodeIfPresent(Date.self, forKey: .latestActivity) ?? setDate
        classKeys = try container.decodeIfPresent([String].self, forKey: .classKeys) ?? []
        setter = try container.decodeIfPresent(Principal.self, forKey: .setter)
        coowners = try container.decodeIfPresent([Principal].self, forKey: .coowners) ?? []
        fileAttachments = try container.decodeIfPresent([FileAttachment].self, forKey: .fileAttachments) ?? []
        pageAttachments = try container.decodeIfPresent([PageAttachment].self, forKey: .pageAttachments) ?? []
        addressees = try container.decodeIfPresent([Address].self, forKey: .addressees) ?? []
        recipientsResponses = try container.decodeIfPresent([RecipientResponse].self, forKey: .recipientsResponses) ?? []
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        draft = try container.decodeIfPresent(Bool.self, forKey: .draft) ?? false
        totalMarkOutOf = try container.decodeIfPresent(Double.self, forKey: .totalMarkOutOf) ?? 0
        mark = try container.decodeIfPresent(Double.self, forKey: .mark) ?? 0
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
    }
}

public struct DescriptionDetails: Codable, Equatable, Sendable {
    public var descriptionPageId: Int?
    public var htmlContent: String?
    public var containsQuestions: Bool?
    public var isSimpleDescription: Bool?
}

public struct FileAttachment: Codable, Equatable, Sendable {
    public var resourceId: Int?
    public var fileName: String?
    public var fileType: String?
    public var etag: String?
    public var dateCreated: Date?
}

public struct PageAttachment: Codable, Equatable, Sendable {
    public var pageId: Int?
    public var title: String?
}

public struct Address: Codable, Equatable, Sendable {
    public var principal: Principal?
    public var isGroup: Bool

    public init(principal: Principal? = nil, isGroup: Bool = false) {
        self.principal = principal
        self.isGroup = isGroup
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        principal = try container.decodeIfPresent(Principal.self, forKey: .principal)
        isGroup = try container.decodeIfPresent(Bool.self, forKey: .isGroup) ?? false
    }
}

public struct Principal: Codable, Equatable, Sendable {
    public var sortKey: String?
    public var guid: String?
    public var name: String?
    public var deleted: Bool?

    enum CodingKeys: String, CodingKey {
        case sortKey
        case sortKeySnake = "sort_key"
        case guid
        case name
        case deleted
    }

    public init(sortKey: String? = nil, guid: String? = nil, name: String? = nil, deleted: Bool? = nil) {
        self.sortKey = sortKey
        self.guid = guid
        self.name = name
        self.deleted = deleted
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sortKey = try container.decodeIfPresent(String.self, forKey: .sortKey)
            ?? container.decodeIfPresent(String.self, forKey: .sortKeySnake)
        guid = try container.decodeIfPresent(String.self, forKey: .guid)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(sortKey, forKey: .sortKey)
        try container.encodeIfPresent(guid, forKey: .guid)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(deleted, forKey: .deleted)
    }
}

public struct RecipientResponse: Codable, Equatable, Sendable {
    public var principal: Principal?
    public var responses: [TaskResponse]

    public init(principal: Principal? = nil, responses: [TaskResponse] = []) {
        self.principal = principal
        self.responses = responses
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        principal = try container.decodeIfPresent(Principal.self, forKey: .principal)
        responses = try container.decodeIfPresent([TaskResponse].self, forKey: .responses) ?? []
    }
}

public struct TaskResponse: Codable, Equatable, Sendable {
    public var latestRead: Bool?
    public var authorName: String?
    public var mark: Double?
    public var outOf: Double?
    public var message: String?
    public var versionId: Int?
    public var released: Bool?
    public var releasedTimestamp: Date?
    public var edited: Bool?
    public var authorGuid: String?
    public var eventType: String?
    public var sentTimestamp: Date?
    public var createdTimestamp: Date?
    public var deleted: Bool?
    public var eventGuid: String?
    public var taskAssessmentDetails: AssessmentDetails?
}

public struct AssessmentDetails: Codable, Equatable, Sendable {
    public var assessmentMarkMax: Double?
    public var assessmentDetailsId: Int?
    public var assessmentType: Int?
}

public struct FireflyEvent: Codable, Identifiable, Equatable, Sendable {
    public var guid: String
    public var description: String?
    public var start: Date
    public var end: Date
    public var location: String?
    public var subject: String?
    public var attendees: [EventAttendee]
    public var teacher: String?

    public var id: String { guid }

    enum CodingKeys: String, CodingKey {
        case guid
        case description
        case start
        case end
        case location
        case subject
        case attendees
        case teacher = "Teacher"
    }

    public init(
        guid: String,
        description: String? = nil,
        start: Date,
        end: Date,
        location: String? = nil,
        subject: String? = nil,
        attendees: [EventAttendee] = [],
        teacher: String? = nil
    ) {
        self.guid = guid
        self.description = description
        self.start = start
        self.end = end
        self.location = location
        self.subject = subject
        self.attendees = attendees
        self.teacher = teacher
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guid = try container.decodeIfPresent(String.self, forKey: .guid) ?? UUID().uuidString
        description = try container.decodeIfPresent(String.self, forKey: .description)
        start = try container.decodeIfPresent(Date.self, forKey: .start) ?? .distantPast
        end = try container.decodeIfPresent(Date.self, forKey: .end) ?? .distantPast
        location = try container.decodeIfPresent(String.self, forKey: .location)
        subject = try container.decodeIfPresent(String.self, forKey: .subject)
        attendees = try container.decodeIfPresent([EventAttendee].self, forKey: .attendees) ?? []
        teacher = try container.decodeIfPresent(String.self, forKey: .teacher)
    }
}

public struct EventAttendee: Codable, Equatable, Sendable {
    public var principal: Principal?
    public var role: String?

    public init(principal: Principal? = nil, role: String? = nil) {
        self.principal = principal
        self.role = role
    }
}

public struct TimetablePeriod: Codable, Identifiable, Equatable, Sendable {
    public var start: Date
    public var end: Date
    public var description: String
    public var classCode: String
    public var roomCode: String
    public var goToPeriod: Bool
    public var period: Int
    public var teacher: String
    public var teacherChange: Bool
    public var roomChange: Bool

    public var id: String { "\(period)-\(start.timeIntervalSince1970)-\(classCode)" }
    public var hasChanges: Bool { teacherChange || roomChange }

    enum CodingKeys: String, CodingKey {
        case start = "Start"
        case end = "End"
        case description = "Description"
        case classCode = "Classcode"
        case roomCode = "Roomcode"
        case goToPeriod = "GotoPeriod"
        case period
        case teacher = "Teacher"
        case teacherChange = "TeacherChange"
        case roomChange = "RoomChange"
    }

    public init(
        start: Date = .distantPast,
        end: Date = .distantPast,
        description: String = "",
        classCode: String = "",
        roomCode: String = "",
        goToPeriod: Bool = false,
        period: Int = 0,
        teacher: String = "",
        teacherChange: Bool = false,
        roomChange: Bool = false
    ) {
        self.start = start
        self.end = end
        self.description = description
        self.classCode = classCode
        self.roomCode = roomCode
        self.goToPeriod = goToPeriod
        self.period = period
        self.teacher = teacher
        self.teacherChange = teacherChange
        self.roomChange = roomChange
    }
}

public struct BreakPeriod: Equatable, Sendable {
    public var start: DateComponents
    public var end: DateComponents
    public var description: String

    public init(start: DateComponents, end: DateComponents, description: String) {
        self.start = start
        self.end = end
        self.description = description
    }
}

public struct EPRCollection: Codable, Equatable, Sendable {
    public var date: Date?
    public var day: Int
    public var changes: [String: TimetablePeriod]
    public var errors: Bool

    public init(date: Date? = nil, day: Int = 0, changes: [String: TimetablePeriod] = [:], errors: Bool = false) {
        self.date = date
        self.day = day
        self.changes = changes
        self.errors = errors
    }
}

public struct EPRPeriod: Codable, Identifiable, Equatable, Sendable {
    public var period: Int
    public var classCode: String
    public var roomCode: String
    public var teacher: String
    public var teacherChange: Bool
    public var roomChange: Bool

    public var id: String { "\(classCode)-\(period)" }

    public init(period: Int, classCode: String, roomCode: String, teacher: String, teacherChange: Bool, roomChange: Bool) {
        self.period = period
        self.classCode = classCode
        self.roomCode = roomCode
        self.teacher = teacher
        self.teacherChange = teacherChange
        self.roomChange = roomChange
    }
}

public struct CalendarEvent: Codable, Identifiable, Equatable, Sendable {
    public var uid: String
    public var summary: String
    public var name: String?
    public var location: String?
    public var status: String?
    public var description: String?
    public var start: Date
    public var end: Date
    public var userCreated: Bool

    public var id: String { uid }

    public init(
        uid: String,
        summary: String,
        name: String? = nil,
        location: String? = nil,
        status: String? = nil,
        description: String? = nil,
        start: Date,
        end: Date,
        userCreated: Bool = false
    ) {
        self.uid = uid
        self.summary = summary
        self.name = name
        self.location = location
        self.status = status
        self.description = description
        self.start = start
        self.end = end
        self.userCreated = userCreated
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var launchAtLogin: Bool
    public var startMinimized: Bool
    public var silentUpdates: Bool
    public var todayEarlyFinishOverride: Bool?
    public var clock: ClockSettings
    public var bell: BellSettings
    public var localAPI: LocalAPISettings
    public var calendarURL: URL?
    public var classColors: [String: String]

    public init(
        launchAtLogin: Bool = false,
        startMinimized: Bool = false,
        silentUpdates: Bool = true,
        todayEarlyFinishOverride: Bool? = nil,
        clock: ClockSettings = ClockSettings(),
        bell: BellSettings = BellSettings(),
        localAPI: LocalAPISettings = LocalAPISettings(),
        calendarURL: URL? = nil,
        classColors: [String: String] = [:]
    ) {
        self.launchAtLogin = launchAtLogin
        self.startMinimized = startMinimized
        self.silentUpdates = silentUpdates
        self.todayEarlyFinishOverride = todayEarlyFinishOverride
        self.clock = clock
        self.bell = bell
        self.localAPI = localAPI
        self.calendarURL = calendarURL
        self.classColors = classColors
    }
}

public struct ClockSettings: Codable, Equatable, Sendable {
    public var showFloatingClock: Bool
    public var fadeOnHover: Bool
    public var hideOnFinish: Bool
    public var combineDoubles: Bool
    public var screenPreference: Int
    public var placementMode: Int
    public var horizontalOffset: Double
    public var verticalOffset: Double
    public var tablePositionPreference: Bool

    public init(
        showFloatingClock: Bool = true,
        fadeOnHover: Bool = true,
        hideOnFinish: Bool = false,
        combineDoubles: Bool = true,
        screenPreference: Int = 0,
        placementMode: Int = 0,
        horizontalOffset: Double = 0,
        verticalOffset: Double = 0,
        tablePositionPreference: Bool = false
    ) {
        self.showFloatingClock = showFloatingClock
        self.fadeOnHover = fadeOnHover
        self.hideOnFinish = hideOnFinish
        self.combineDoubles = combineDoubles
        self.screenPreference = screenPreference
        self.placementMode = placementMode
        self.horizontalOffset = horizontalOffset
        self.verticalOffset = verticalOffset
        self.tablePositionPreference = tablePositionPreference
    }
}

public struct BellSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var volume: Double
    public var outputDeviceID: String?

    public init(enabled: Bool = false, volume: Double = 75, outputDeviceID: String? = nil) {
        self.enabled = enabled
        self.volume = volume
        self.outputDeviceID = outputDeviceID
    }
}

public struct LocalAPISettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var port: UInt16
    public var hideName: Bool
    public var openNetwork: Bool
    public var corsOrigins: [String]

    public init(enabled: Bool = false, port: UInt16 = 13_693, hideName: Bool = false, openNetwork: Bool = false, corsOrigins: [String] = []) {
        self.enabled = enabled
        self.port = port
        self.hideName = hideName
        self.openNetwork = openNetwork
        self.corsOrigins = corsOrigins
    }
}
