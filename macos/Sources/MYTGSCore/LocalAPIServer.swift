import Foundation
import Network

public struct LocalAPIState: Sendable {
    public var twoWeekTimetable: [[TimetablePeriod]]
    public var displayName: String
    public var timetableDay: String
    public var userID: String
    public var referenceDay: Date
    public var eprChanges: [EPRPeriod]

    public init(
        twoWeekTimetable: [[TimetablePeriod]] = [],
        displayName: String = "",
        timetableDay: String = "",
        userID: String = "",
        referenceDay: Date = Date(),
        eprChanges: [EPRPeriod] = []
    ) {
        self.twoWeekTimetable = twoWeekTimetable
        self.displayName = displayName
        self.timetableDay = timetableDay
        self.userID = userID
        self.referenceDay = referenceDay
        self.eprChanges = eprChanges
    }
}

public enum LocalAPIError: Error, Equatable {
    case listenerUnavailable
}

public final class LocalAPIServer: @unchecked Sendable {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "MYTGS.LocalAPI")
    private let stateLock = NSLock()
    private var state = LocalAPIState()
    private var settings = LocalAPISettings()

    public init() {}

    public var isRunning: Bool {
        listener != nil
    }

    public func update(state: LocalAPIState) {
        stateLock.lock()
        self.state = state
        stateLock.unlock()
    }

    public func start(settings: LocalAPISettings) throws {
        stop()
        self.settings = settings
        let host: NWEndpoint.Host = settings.openNetwork ? .ipv4(.any) : "127.0.0.1"
        let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: settings.port)!)
        listener.service = nil
        listener.newConnectionHandler = { [weak self] connection in
            self?.receive(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
        _ = host
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    public func debugResponse(for request: String) -> String {
        response(for: request)
    }

    private func receive(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let response = self.response(for: request)
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func response(for request: String) -> String {
        let path = request.components(separatedBy: "\r\n").first?
            .split(separator: " ")
            .dropFirst()
            .first
            .map(String.init) ?? "/"

        stateLock.lock()
        let snapshot = state
        let settings = settings
        stateLock.unlock()

        let body: Data
        switch path {
        case "/api/timetable":
            body = (try? MYTGSDateCoding.encoder.encode(snapshot.twoWeekTimetable)) ?? Data("[]".utf8)
        case "/api/info":
            let info = LocalAPIInfo(
                name: settings.hideName ? "Anon" : snapshot.displayName,
                day: snapshot.timetableDay,
                id: settings.hideName ? "000000" : snapshot.userID,
                referenceDay: snapshot.referenceDay
            )
            body = (try? MYTGSDateCoding.encoder.encode(info)) ?? Data("{}".utf8)
        case "/api/epr":
            body = (try? MYTGSDateCoding.encoder.encode(snapshot.eprChanges)) ?? Data("[]".utf8)
        default:
            return httpResponse(status: "404 Not Found", body: Data(#"{"error":"not_found"}"#.utf8), settings: settings)
        }

        return httpResponse(status: "200 OK", body: body, settings: settings)
    }

    private func httpResponse(status: String, body: Data, settings: LocalAPISettings) -> String {
        var headers = [
            "HTTP/1.1 \(status)",
            "Content-Type: application/json; charset=utf-8",
            "Content-Length: \(body.count)",
            "Connection: close"
        ]
        if !settings.corsOrigins.isEmpty {
            headers.append("Access-Control-Allow-Origin: \(settings.corsOrigins.joined(separator: " "))")
        }
        return headers.joined(separator: "\r\n") + "\r\n\r\n" + (String(data: body, encoding: .utf8) ?? "")
    }
}

private struct LocalAPIInfo: Encodable {
    var name: String
    var day: String
    var id: String
    var referenceDay: Date

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case day = "Day"
        case id = "ID"
        case referenceDay = "ReferenceDay"
    }
}
