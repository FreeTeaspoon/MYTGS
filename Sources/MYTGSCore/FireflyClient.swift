import Foundation

public enum FireflyClientError: Error, Equatable, LocalizedError {
    case invalidSchoolResponse
    case schoolNotFound
    case missingSession
    case invalidSSO
    case badResponse(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidSchoolResponse:
            "Firefly returned an unexpected school lookup response."
        case .schoolNotFound:
            "Firefly could not find the MYTGS school site."
        case .missingSession:
            "MYTGS is not signed in."
        case .invalidSSO:
            "Firefly accepted the login page but did not return a valid SSO profile."
        case .badResponse(let statusCode):
            "Firefly returned HTTP \(statusCode)."
        }
    }
}

public actor FireflyClient {
    public let schoolCode: String
    public let appID: String
    public let deviceID: String
    private let session: URLSession

    public init(
        schoolCode: String = "MYTGS",
        appID: String = "android_tasks",
        deviceID: String = "TT\(Host.current().localizedName ?? ProcessInfo.processInfo.hostName)",
        session: URLSession = .shared
    ) {
        self.schoolCode = schoolCode
        self.appID = appID
        self.deviceID = deviceID
        self.session = session
    }

    public func lookupSchool() async throws -> SchoolSite {
        let url = URL(string: "http://appgateway.ffhost.co.uk/appgateway/school/\(schoolCode)")!
        let (data, response) = try await session.data(from: url)
        try validate(response)
        let parser = SchoolXMLParser()
        guard let site = parser.parse(data) else {
            throw FireflyClientError.schoolNotFound
        }
        return site
    }

    public func loginURL(for school: SchoolSite) -> URL {
        school.url
            .appending(path: "login/api/loginui")
            .withQueryItems([
                URLQueryItem(name: "app_id", value: appID),
                URLQueryItem(name: "device_id", value: deviceID)
            ])
    }

    public func validateSSO(token: String, school: SchoolSite) async throws -> FireflySession {
        let url = school.url
            .appending(path: "login/api/sso")
            .withAuthQueryItems(deviceID: deviceID, token: token)
        let (data, response) = try await session.data(from: url)
        try validate(response)
        guard let xml = String(data: data, encoding: .utf8),
              let user = parseSSO(xml) else {
            throw FireflyClientError.invalidSSO
        }
        return FireflySession(token: token, deviceID: deviceID, user: user, school: school)
    }

    public func fetchDashboard(session: FireflySession) async throws -> String {
        let url = session.school.url
            .appending(path: "dashboard")
            .withAuthQueryItems(deviceID: session.deviceID, token: session.token)
        let (data, response) = try await self.session.data(from: url)
        try validate(response)
        let page = String(data: data, encoding: .utf8) ?? ""
        return HTMLHelpers.dashboardMessageHTML(in: page) ?? ""
    }

    public func fetchEPR(session: FireflySession) async throws -> String {
        let url = session.school.url
            .appending(path: "administration-1/extra-period-roster-epr")
            .withAuthQueryItems(deviceID: session.deviceID, token: session.token)
        let (data, response) = try await self.session.data(from: url)
        try validate(response)
        let page = String(data: data, encoding: .utf8) ?? ""
        return HTMLHelpers.elementInnerHTML(id: "ffContainer", in: page) ?? page
    }

    public func fetchTaskIDs(session: FireflySession, watermark: Date) async throws -> [Int] {
        let url = session.school.url
            .appending(path: "api/v2/apps/tasks/ids/filterby")
            .withAuthQueryItems(deviceID: session.deviceID, token: session.token)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        _ = watermark
        request.httpBody = Data()
        let (data, response) = try await self.session.data(for: request)
        try validate(response)
        return try JSONDecoder().decode([Int].self, from: data)
    }

    public func fetchTasks(session: FireflySession, ids: [Int]) async throws -> [FireflyTask] {
        guard !ids.isEmpty else { return [] }
        var tasks: [FireflyTask] = []
        for chunk in ids.chunked(into: 50) {
            tasks.append(contentsOf: try await fetchTaskChunk(session: session, ids: chunk))
        }
        return normalize(tasks)
    }

    public func fetchEvents(session: FireflySession, start: Date, end: Date) async throws -> [FireflyEvent] {
        let url = session.school.url
            .appending(path: "_api/1.0/graphql")
            .withAuthQueryItems(deviceID: session.deviceID, token: session.token)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let query = """
        data=query Query{events(for_guid:"\(session.user.guid)",start:"\(formatter.string(from: start))",end:"\(formatter.string(from: end))"){guid,description,start,end,location,subject,attendees{principal{guid,name,sort_key,group{guid,name,sort_key,personal_colour}},role}}}
        """
        request.httpBody = query.data(using: .utf8)
        let (data, response) = try await self.session.data(for: request)
        try validate(response)
        let decoded = try MYTGSDateCoding.decoder.decode(GraphQLResponse.self, from: data)
        return decoded.data.events.map { event in
            var event = event
            event.teacher = event.attendees.first { $0.role == "Chairperson" }?.principal?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            return event
        }
    }

    public func fetchProfileImage(session: FireflySession) async throws -> Data {
        let url = session.school.url
            .appending(path: "profilepic.aspx")
            .withQueryItems([
                URLQueryItem(name: "guid", value: session.user.guid),
                URLQueryItem(name: "size", value: "regular"),
                URLQueryItem(name: "ffauth_device_id", value: session.deviceID),
                URLQueryItem(name: "ffauth_secret", value: session.token)
            ])
        let (data, response) = try await self.session.data(from: url)
        try validate(response)
        return data
    }

    public func logout(session: FireflySession) async throws -> Bool {
        let url = session.school.url
            .appending(path: "login/api/deletetoken")
            .withQueryItems([
                URLQueryItem(name: "app_id", value: appID),
                URLQueryItem(name: "ffauth_device_id", value: session.deviceID),
                URLQueryItem(name: "ffauth_secret", value: session.token)
            ])
        let (data, response) = try await self.session.data(from: url)
        try validate(response)
        return String(data: data, encoding: .utf8) == "OK"
    }

    private func fetchTaskChunk(session: FireflySession, ids: [Int]) async throws -> [FireflyTask] {
        let url = session.school.url
            .appending(path: "api/v2/apps/tasks/byIds")
            .withAuthQueryItems(deviceID: session.deviceID, token: session.token)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["ids": ids])
        let (data, response) = try await self.session.data(for: request)
        try validate(response)
        return try MYTGSDateCoding.decoder.decode([FireflyTask].self, from: data)
    }

    private func normalize(_ tasks: [FireflyTask]) -> [FireflyTask] {
        tasks.map { task in
            var task = task
            task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
            task.classKeys = task.addressees.compactMap { address in
                guard address.isGroup, let name = address.principal?.name else { return nil }
                return name.replacingOccurrences(of: #"^Class"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            var latest = task.setDate
            var responses = task.recipientsResponses
            for recipientIndex in responses.indices {
                var deduped: [String: TaskResponse] = [:]
                var anonymousIndex = 0
                for response in responses[recipientIndex].responses.sorted(by: { ($0.sentTimestamp ?? .distantPast) < ($1.sentTimestamp ?? .distantPast) }) {
                    if let mark = response.mark, mark != 0 {
                        task.mark = mark
                        task.totalMarkOutOf = response.taskAssessmentDetails?.assessmentMarkMax ?? response.outOf ?? task.totalMarkOutOf
                    }
                    if let created = response.createdTimestamp, created > latest {
                        latest = created
                    }
                    let key = response.eventGuid ?? "anonymous-\(anonymousIndex)"
                    if response.eventGuid == nil {
                        anonymousIndex += 1
                    }
                    deduped[key] = response
                }
                responses[recipientIndex].responses = Array(deduped.values)
            }
            task.recipientsResponses = responses
            task.latestActivity = latest
            return task
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(response.statusCode) else {
            throw FireflyClientError.badResponse(response.statusCode)
        }
    }

    private func parseSSO(_ xml: String) -> FireflyUser? {
        let pattern = #"identifier="(.*?)"\s+username="(.*?)"\s+name="(.*?)"\s+email="(.*?)"\s+canSetTask="(.*?)""#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
              match.numberOfRanges == 6 else {
            return nil
        }
        func group(_ index: Int) -> String {
            guard let range = Range(match.range(at: index), in: xml) else { return "" }
            return String(xml[range])
        }
        let canSet = ["yes", "true", "1"].contains(group(5).lowercased())
        return FireflyUser(guid: group(1), username: group(2), name: group(3), email: group(4), canSetTasks: canSet)
    }
}

private struct GraphQLResponse: Decodable {
    var data: GraphQLData
}

private struct GraphQLData: Decodable {
    var events: [FireflyEvent]
}

private final class SchoolXMLParser: NSObject, XMLParserDelegate {
    private var exists = false
    private var enabled = false
    private var ssl = true
    private var currentElement = ""
    private var schoolName = ""
    private var address = ""

    func parse(_ data: Data) -> SchoolSite? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse(), exists, enabled, !address.isEmpty else {
            return nil
        }
        let scheme = ssl ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(address)") else {
            return nil
        }
        return SchoolSite(name: schoolName, url: url)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "response" {
            exists = attributeDict["exists"] == "true"
            enabled = attributeDict["enabled"] == "true"
        } else if elementName == "address" {
            ssl = attributeDict["ssl"] != "false"
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if currentElement == "school" || currentElement == "name" {
            schoolName += value
        } else if currentElement == "address" {
            address += value
        }
    }
}

private enum HTMLHelpers {
    static func dashboardMessageHTML(in html: String) -> String? {
        guard let container = elementInnerHTML(id: "ffContainer", in: html) else {
            return nil
        }
        return elementInnerHTML(attributeName: "data-ff-component-type", value: "html", in: container)
    }

    static func elementInnerHTML(id: String, in html: String) -> String? {
        elementInnerHTML(attributeName: "id", value: id, in: html)
    }

    private static func elementInnerHTML(attributeName: String, value: String, in html: String) -> String? {
        let attribute = NSRegularExpression.escapedPattern(for: attributeName)
        let escapedValue = NSRegularExpression.escapedPattern(for: value)
        let pattern = #"<([A-Za-z0-9]+)\b[^>]*\b\#(attribute)\s*=\s*["']\#(escapedValue)["'][^>]*>"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              match.numberOfRanges >= 2,
              let elementRange = Range(match.range(at: 0), in: html),
              let tagRange = Range(match.range(at: 1), in: html),
              let closingIndex = closingTagStart(for: String(html[tagRange]), after: elementRange.upperBound, in: html) else {
            return nil
        }
        return String(html[elementRange.upperBound..<closingIndex])
    }

    private static func closingTagStart(for tagName: String, after startIndex: String.Index, in html: String) -> String.Index? {
        let tag = NSRegularExpression.escapedPattern(for: tagName)
        let pattern = #"<\s*(/?)\s*\#(tag)\b[^>]*>"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        var depth = 1
        let searchRange = NSRange(startIndex..<html.endIndex, in: html)
        for match in expression.matches(in: html, range: searchRange) {
            guard let fullRange = Range(match.range(at: 0), in: html),
                  let slashRange = Range(match.range(at: 1), in: html) else {
                continue
            }
            let isClosingTag = !html[slashRange].isEmpty
            let isSelfClosingTag = html[fullRange].trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("/>")
            if isClosingTag {
                depth -= 1
            } else if !isSelfClosingTag {
                depth += 1
            }
            if depth == 0 {
                return fullRange.lowerBound
            }
        }
        return nil
    }
}

private extension URL {
    func withAuthQueryItems(deviceID: String, token: String) -> URL {
        withQueryItems([
            URLQueryItem(name: "ffauth_device_id", value: deviceID),
            URLQueryItem(name: "ffauth_secret", value: token)
        ])
    }

    func withQueryItems(_ queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        components.queryItems = (components.queryItems ?? []) + queryItems
        return components.url ?? self
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
