import Foundation
import MYTGSCore
import XCTest

final class MYTGSCoreTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testFireflyClientUsesFixturesWithoutNetwork() async throws {
        let router = FixtureRouter()
        let client = FireflyClient(deviceID: "TT-TEST-DEVICE", session: makeSession(router: router))

        let school = try await client.lookupSchool()
        XCTAssertEqual(school.name, "MYTGS Synthetic School")
        XCTAssertEqual(school.url.absoluteString, "https://mytgs.firefly.test")
        let lookupURL = try XCTUnwrap(router.request(path: "/appgateway/school/MYTGS")?.url)
        XCTAssertEqual(lookupURL.scheme, "http")

        let loginURL = await client.loginURL(for: school)
        XCTAssertEqual(loginURL.scheme, "https")
        XCTAssertEqual(loginURL.path, "/login/api/loginui")
        XCTAssertEqual(queryItem("app_id", in: loginURL), "android_tasks")
        XCTAssertEqual(queryItem("device_id", in: loginURL), "TT-TEST-DEVICE")

        let session = try await client.validateSSO(token: "SECRET-TOKEN", school: school)
        XCTAssertEqual(session.user.guid, "student-guid-0001")
        XCTAssertEqual(session.user.username, "999999")
        XCTAssertEqual(session.user.email, "sample.student@example.test")

        let dashboard = try await client.fetchDashboard(session: session)
        XCTAssertTrue(dashboard.contains("Synthetic dashboard notice"))
        XCTAssertFalse(dashboard.contains("ffContainer"))

        let eprHTML = try await client.fetchEPR(session: session)
        let epr = try EPRParser.parse(eprHTML)
        XCTAssertEqual(epr.day, 4)
        XCTAssertEqual(epr.changes["122MM4-2"]?.roomCode, "B7")

        let taskIDs = try await client.fetchTaskIDs(session: session, watermark: .distantPast)
        XCTAssertEqual(taskIDs.count, 51)
        XCTAssertEqual(router.request(path: "/api/v2/apps/tasks/ids/filterby")?.httpMethod, "POST")
        XCTAssertEqual(router.header("Content-Type", path: "/api/v2/apps/tasks/ids/filterby"), "application/json; charset=UTF-8")

        let tasks = try await client.fetchTasks(session: session, ids: taskIDs)
        XCTAssertEqual(tasks.map(\.id), [1001, 1051])
        XCTAssertEqual(router.taskChunkIDs.map(\.count), [50, 1])
        XCTAssertEqual(tasks[0].title, "Maths Investigation")
        XCTAssertEqual(tasks[0].classKeys, ["122MM4"])
        XCTAssertEqual(tasks[0].mark, 9)
        XCTAssertEqual(tasks[0].totalMarkOutOf, 12)
        XCTAssertEqual(tasks[0].recipientsResponses.first?.responses.count, 1)
        XCTAssertGreaterThan(tasks[0].latestActivity, tasks[0].setDate)

        let start = Calendar.mytgs.date(from: DateComponents(year: 2026, month: 6, day: 29))!
        let end = Calendar.mytgs.date(from: DateComponents(year: 2026, month: 6, day: 30))!
        let events = try await client.fetchEvents(session: session, start: start, end: end)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].teacher, "Ms Synthetic")
        XCTAssertEqual(router.request(path: "/_api/1.0/graphql")?.httpMethod, "POST")
        XCTAssertEqual(router.header("Content-Type", path: "/_api/1.0/graphql"), "application/x-www-form-urlencoded; charset=UTF-8")
        XCTAssertTrue(router.body(path: "/_api/1.0/graphql").contains("data=query Query"))

        let profileImage = try await client.fetchProfileImage(session: session)
        XCTAssertEqual(String(data: profileImage, encoding: .utf8), "synthetic image bytes\n")

        let loggedOut = try await client.logout(session: session)
        XCTAssertTrue(loggedOut)
        XCTAssertEqual(queryItem("ffauth_device_id", in: router.request(path: "/login/api/deletetoken")!.url!), "TT-TEST-DEVICE")
        XCTAssertEqual(queryItem("ffauth_secret", in: router.request(path: "/login/api/deletetoken")!.url!), "SECRET-TOKEN")
    }

    func testFireflyHTTPErrorMapsToClientError() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, Data())
        }

        let client = FireflyClient(session: makeMockSession())
        do {
            _ = try await client.lookupSchool()
            XCTFail("Expected bad response error")
        } catch let error as FireflyClientError {
            XCTAssertEqual(error, .badResponse(503))
        }
    }

    func testInfoPlistAllowsOnlyFireflyGatewayInsecureHTTP() throws {
        var repoRoot = URL(fileURLWithPath: #filePath)
        repoRoot.deleteLastPathComponent()
        repoRoot.deleteLastPathComponent()
        repoRoot.deleteLastPathComponent()

        let plistURL = repoRoot.appending(path: "Config/MYTGS-Info.plist")
        let data = try Data(contentsOf: plistURL)
        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        let plist = try XCTUnwrap(object as? [String: Any])
        let ats = try XCTUnwrap(plist["NSAppTransportSecurity"] as? [String: Any])
        XCTAssertNil(ats["NSAllowsArbitraryLoads"])

        let domains = try XCTUnwrap(ats["NSExceptionDomains"] as? [String: Any])
        XCTAssertEqual(Set(domains.keys), ["appgateway.ffhost.co.uk"])

        let gateway = try XCTUnwrap(domains["appgateway.ffhost.co.uk"] as? [String: Any])
        XCTAssertEqual(gateway["NSExceptionAllowsInsecureHTTPLoads"] as? Bool, true)
    }

    func testEPRParserWithFixture() throws {
        let epr = try EPRParser.parse(Fixture.string("epr", "html"))
        XCTAssertEqual(epr.day, 4)
        XCTAssertFalse(epr.errors)
        XCTAssertEqual(epr.changes["122MM4-2"]?.teacher, "Mr Cover")
        XCTAssertEqual(epr.changes["122MM4-2"]?.roomCode, "B7")
        XCTAssertEqual(epr.changes["122MM4-2"]?.teacherChange, true)
        XCTAssertEqual(epr.changes["122MM4-2"]?.roomChange, true)
    }

    func testTimetableEventAndEarlyFinishLogic() throws {
        let day = Calendar.mytgs.date(from: DateComponents(year: 2026, month: 6, day: 29))!
        let normal = TimetableEngine.processForUse(events: [], day: day, earlyFinish: false, eventsUpToDate: false)
        let early = TimetableEngine.processForUse(events: [], day: day, earlyFinish: true, eventsUpToDate: false)
        XCTAssertEqual(normal.count, 9)
        XCTAssertEqual(early.count, 9)
        XCTAssertEqual(normal[1].description, "Period 1")
        XCTAssertEqual(Calendar.mytgs.component(.hour, from: normal[1].start), 8)
        XCTAssertEqual(Calendar.mytgs.component(.minute, from: normal[1].start), 50)
        let normalPeriod5 = try XCTUnwrap(normal.first { $0.period == 5 })
        let earlyPeriod5 = try XCTUnwrap(early.first { $0.period == 5 })
        XCTAssertLessThan(earlyPeriod5.start, normalPeriod5.start)
        XCTAssertEqual(Calendar.mytgs.component(.hour, from: earlyPeriod5.start), 13)
        XCTAssertEqual(Calendar.mytgs.component(.minute, from: earlyPeriod5.start), 0)
        XCTAssertTrue(TimetableEngine.processForUse(events: [], day: day, earlyFinish: false, eventsUpToDate: true).isEmpty)

        let event = FireflyEvent(
            guid: "122MM4-A-2-29-6-2026",
            start: Calendar.mytgs.date(from: DateComponents(year: 2026, month: 6, day: 29, hour: 9, minute: 45))!,
            end: Calendar.mytgs.date(from: DateComponents(year: 2026, month: 6, day: 29, hour: 10, minute: 35))!,
            location: "B7",
            subject: "Maths",
            attendees: [EventAttendee(principal: Principal(name: "Ms Synthetic"), role: "Chairperson")]
        )
        let parsed = TimetableEngine.parseEventsToPeriods([event])
        XCTAssertEqual(parsed[2].classCode, "122MM4")
        XCTAssertEqual(parsed[2].teacher, "Ms Synthetic")
    }

    func testTaskSearchFilteringAndSorting() throws {
        let tasks = try MYTGSDateCoding.decoder.decode([FireflyTask].self, from: Fixture.data("tasks-chunk-1", "json"))
            + MYTGSDateCoding.decoder.decode([FireflyTask].self, from: Fixture.data("tasks-chunk-2", "json"))
        let result = TaskSearch.search(
            tasks,
            criteria: TaskSearchCriteria(text: "maths", teacher: "synthetic", classText: "", hideMarked: false)
        )
        XCTAssertEqual(result.map(\.id), [1001])

        let sorted = TaskSearch.search(tasks, criteria: TaskSearchCriteria(order: .latestDueDate))
        XCTAssertEqual(sorted.map(\.id), [1051, 1001])
    }

    func testSettingsPersistence() {
        let defaults = UserDefaults(suiteName: "MYTGSCoreTests-\(UUID().uuidString)")!
        let store = UserDefaultsSettingsStore(defaults: defaults)
        var settings = AppSettings()
        settings.localAPI.enabled = true
        settings.localAPI.corsOrigins = ["https://tools.example.test"]
        settings.clock.placementMode = 3
        settings.classColors["122MM4"] = "#3478f6"
        store.save(settings)

        let loaded = store.load()
        XCTAssertTrue(loaded.localAPI.enabled)
        XCTAssertEqual(loaded.localAPI.corsOrigins, ["https://tools.example.test"])
        XCTAssertEqual(loaded.clock.placementMode, 3)
        XCTAssertEqual(loaded.classColors["122MM4"], "#3478f6")
    }

    func testLocalAPIJSONShapeAndPrivacySettings() throws {
        let server = LocalAPIServer()
        let referenceDay = Calendar.mytgs.date(from: DateComponents(year: 2026, month: 6, day: 29))!
        let period = TimetablePeriod(
            start: referenceDay,
            end: referenceDay.addingTimeInterval(50 * 60),
            description: "Maths",
            classCode: "122MM4",
            roomCode: "B7",
            goToPeriod: true,
            period: 2,
            teacher: "Ms Synthetic"
        )
        server.update(
            state: LocalAPIState(
                twoWeekTimetable: [[period]],
                displayName: "Sample Student",
                timetableDay: "Day 4",
                userID: "999999",
                referenceDay: referenceDay,
                eprChanges: [
                    EPRPeriod(period: 2, classCode: "122MM4", roomCode: "B7", teacher: "Mr Cover", teacherChange: true, roomChange: true)
                ]
            )
        )
        try server.start(settings: LocalAPISettings(enabled: true, port: 13_694, hideName: true, corsOrigins: ["https://tools.example.test"]))
        defer { server.stop() }

        let info = server.debugResponse(for: "GET /api/info HTTP/1.1\r\n\r\n")
        XCTAssertTrue(info.contains("\"Name\" : \"Anon\""))
        XCTAssertTrue(info.contains("\"ID\" : \"000000\""))
        XCTAssertTrue(info.contains("Access-Control-Allow-Origin: https://tools.example.test"))

        let timetable = server.debugResponse(for: "GET /api/timetable HTTP/1.1\r\n\r\n")
        XCTAssertTrue(timetable.contains("\"Classcode\" : \"122MM4\""))

        let epr = server.debugResponse(for: "GET /api/epr HTTP/1.1\r\n\r\n")
        XCTAssertTrue(epr.contains("\"teacherChange\" : true"))

        let missing = server.debugResponse(for: "GET /api/missing HTTP/1.1\r\n\r\n")
        XCTAssertTrue(missing.contains("404 Not Found"))
    }

    func testFixturesStaySyntheticAndSafeToCommit() throws {
        let unsafeFragments = [
            "REAL_STUDENT_NAME",
            "REAL_STUDENT_SURNAME",
            "real.school.example",
            "fireflycloud.net",
            "@real-school.example",
            "REAL_STUDENT_ID"
        ]
        for fixture in Fixture.allFixtureNames {
            let text = String(data: Fixture.data(fixture.name, fixture.ext), encoding: .utf8) ?? ""
            for fragment in unsafeFragments {
                XCTAssertFalse(text.localizedCaseInsensitiveContains(fragment), "\(fixture.name).\(fixture.ext) contains \(fragment)")
            }
        }
    }
}

private enum Fixture {
    static let allFixtureNames: [(name: String, ext: String)] = [
        ("school-lookup", "xml"),
        ("sso", "xml"),
        ("dashboard", "html"),
        ("epr", "html"),
        ("task-ids", "json"),
        ("tasks-chunk-1", "json"),
        ("tasks-chunk-2", "json"),
        ("graphql-events", "json"),
        ("profile-image", "bin"),
        ("logout-ok", "txt")
    ]

    static func data(_ name: String, _ ext: String) -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext)
            ?? Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"),
              let data = try? Data(contentsOf: url) else {
            fatalError("Missing fixture \(name).\(ext)")
        }
        return data
    }

    static func string(_ name: String, _ ext: String) -> String {
        String(data: data(name, ext), encoding: .utf8) ?? ""
    }
}

private final class FixtureRouter {
    private let lock = NSLock()
    private var storedRequests: [URLRequest] = []
    private var storedTaskChunkIDs: [[Int]] = []

    var taskChunkIDs: [[Int]] {
        lock.withLock { storedTaskChunkIDs }
    }

    func route(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        lock.withLock {
            storedRequests.append(request)
        }

        guard let url = request.url else {
            throw URLError(.badURL)
        }

        let data: Data
        if url.host == "appgateway.ffhost.co.uk", url.path == "/appgateway/school/MYTGS" {
            data = Fixture.data("school-lookup", "xml")
        } else {
            switch url.path {
            case "/login/api/sso":
                data = Fixture.data("sso", "xml")
            case "/dashboard":
                data = Fixture.data("dashboard", "html")
            case "/administration-1/extra-period-roster-epr":
                data = Fixture.data("epr", "html")
            case "/api/v2/apps/tasks/ids/filterby":
                data = Fixture.data("task-ids", "json")
            case "/api/v2/apps/tasks/byIds":
                let ids = try taskIDs(from: request)
                lock.withLock {
                    storedTaskChunkIDs.append(ids)
                }
                data = ids.count == 50 ? Fixture.data("tasks-chunk-1", "json") : Fixture.data("tasks-chunk-2", "json")
            case "/_api/1.0/graphql":
                data = Fixture.data("graphql-events", "json")
            case "/profilepic.aspx":
                data = Fixture.data("profile-image", "bin")
            case "/login/api/deletetoken":
                data = Fixture.data("logout-ok", "txt")
            default:
                throw URLError(.unsupportedURL)
            }
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": contentType(for: url.path)]
        )!
        return (response, data)
    }

    func request(path: String) -> URLRequest? {
        lock.withLock {
            storedRequests.first { $0.url?.path == path }
        }
    }

    func header(_ name: String, path: String) -> String? {
        request(path: path)?.value(forHTTPHeaderField: name)
    }

    func body(path: String) -> String {
        guard let request = request(path: path),
              let data = request.bodyData else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func taskIDs(from request: URLRequest) throws -> [Int] {
        guard let data = request.bodyData,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: [Int]],
              let ids = object["ids"] else {
            throw URLError(.cannotParseResponse)
        }
        return ids
    }

    private func contentType(for path: String) -> String {
        if path.hasSuffix(".json")
            || path == "/api/v2/apps/tasks/ids/filterby"
            || path == "/api/v2/apps/tasks/byIds"
            || path == "/_api/1.0/graphql" {
            "application/json"
        } else if path.hasSuffix(".xml") || path == "/login/api/sso" {
            "application/xml"
        } else {
            "text/html"
        }
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeSession(router: FixtureRouter) -> URLSession {
    MockURLProtocol.requestHandler = { request in
        try router.route(request)
    }
    return makeMockSession()
}

private func makeMockSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}

private func queryItem(_ name: String, in url: URL) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?
        .first { $0.name == name }?
        .value
}

private extension URLRequest {
    var bodyData: Data? {
        if let httpBody {
            return httpBody
        }
        guard let stream = httpBodyStream else {
            return nil
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count > 0 {
                data.append(buffer, count: count)
            } else {
                break
            }
        }
        return data
    }
}
