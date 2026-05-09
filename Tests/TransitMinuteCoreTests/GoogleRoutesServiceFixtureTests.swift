import Foundation
import XCTest
@testable import TransitMinuteCore

final class GoogleRoutesServiceFixtureTests: XCTestCase {
    func testParsesRecordedTransitRouteFixture() async throws {
        let service = GoogleRoutesService(
            session: .fixtureSession(responses: [
                .init(statusCode: 200, body: fixtureData(named: "routes-success"))
            ]),
            clock: { Date(timeIntervalSince1970: 1_000) }
        )

        let plan = try await service.transitPlan(
            origin: .previewHome,
            destination: .previewWork,
            apiKey: "AIza-fixture-key",
            bufferMinutes: 2
        )

        XCTAssertEqual(plan.routeSummary, "Bus 90")
        XCTAssertEqual(plan.transitMode, .bus)
        XCTAssertEqual(plan.departureStopName, "Main St / King St")
        XCTAssertEqual(plan.transitDepartureAt, ISO8601DateFormatter().date(from: "2026-05-07T12:30:00Z"))
        XCTAssertEqual(plan.walkingDuration, 240)
        XCTAssertEqual(plan.bufferDuration, 120)
        XCTAssertEqual(plan.arrivalAt, ISO8601DateFormatter().date(from: "2026-05-07T13:00:00Z"))
    }

    func testLetsGoogleChooseSupportedTransitModes() async throws {
        let service = GoogleRoutesService(
            session: .fixtureSession(responses: [
                .init(statusCode: 200, body: fixtureData(named: "routes-fallback"))
            ]),
            clock: { Date(timeIntervalSince1970: 1_000) }
        )

        let plan = try await service.transitPlan(
            origin: .previewHome,
            destination: .previewWork,
            apiKey: "AIza-fixture-key",
            bufferMinutes: 1
        )

        XCTAssertEqual(plan.routeSummary, "Green Line")
        XCTAssertEqual(plan.departureStopName, "Central Station")
        XCTAssertEqual(plan.walkingDuration, 300)
        XCTAssertEqual(plan.bufferDuration, 60)
        XCTAssertEqual(FixtureURLProtocol.requestedBodies.count, 1)
        XCTAssertEqual(FixtureURLProtocol.requestedFieldMasks.count, 1)
        XCTAssertTrue(
            try XCTUnwrap(FixtureURLProtocol.requestedFieldMasks.first ?? nil)
                .contains("routes.legs.steps.transitDetails.transitLine.vehicle.type")
        )

        let body = try XCTUnwrap(FixtureURLProtocol.requestedBodies.first ?? nil)
        let requestJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertNil(requestJSON["transitPreferences"])
    }

    func testParsesSubwayTransitModeFixture() async throws {
        let service = GoogleRoutesService(
            session: .fixtureSession(responses: [
                .init(statusCode: 200, body: fixtureData(named: "routes-subway"))
            ]),
            clock: { Date(timeIntervalSince1970: 1_000) }
        )

        let plan = try await service.transitPlan(
            origin: .previewHome,
            destination: .previewWork,
            apiKey: "AIza-fixture-key",
            bufferMinutes: 1
        )

        XCTAssertEqual(plan.routeSummary, "Blue Line")
        XCTAssertEqual(plan.transitMode, .subway)
    }

    private func fixtureData(named name: String) -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: "json")!
        return try! Data(contentsOf: url)
    }
}

private struct FixtureResponse {
    var statusCode: Int
    var body: Data
}

private final class FixtureURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responses: [FixtureResponse] = []
    nonisolated(unsafe) static var requestedBodies: [Data?] = []
    nonisolated(unsafe) static var requestedFieldMasks: [String?] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requestedBodies.append(request.httpBody ?? request.httpBodyStream?.readAllData())
        Self.requestedFieldMasks.append(request.value(forHTTPHeaderField: "X-Goog-FieldMask"))
        let response = Self.responses.removeFirst()
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension InputStream {
    func readAllData() -> Data {
        open()
        defer { close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while hasBytesAvailable {
            let count = read(&buffer, maxLength: buffer.count)
            guard count > 0 else {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }
}

private extension URLSession {
    static func fixtureSession(responses: [FixtureResponse]) -> URLSession {
        FixtureURLProtocol.responses = responses
        FixtureURLProtocol.requestedBodies = []
        FixtureURLProtocol.requestedFieldMasks = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
