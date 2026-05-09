import XCTest
@testable import TransitMinuteCore

final class RouteDiagnosticsTests: XCTestCase {
    func testRecordsRouteRequestAndRefreshLifecycle() {
        let requestedAt = Date(timeIntervalSince1970: 100)
        let completedAt = Date(timeIntervalSince1970: 110)
        let nextRefreshAt = Date(timeIntervalSince1970: 410)
        var diagnostics = RouteDiagnostics()

        diagnostics.recordRequest(
            origin: .previewHome,
            destination: .previewWork,
            requestedAt: requestedAt
        )
        diagnostics.recordFailure("Routes request failed", completedAt: completedAt)

        XCTAssertEqual(diagnostics.lastRequest?.origin.label, .home)
        XCTAssertEqual(diagnostics.lastRequest?.destination.label, .work)
        XCTAssertEqual(diagnostics.lastRequest?.requestedAt, requestedAt)
        XCTAssertEqual(diagnostics.lastRouteError, "Routes request failed")
        XCTAssertEqual(diagnostics.lastRefreshCompletedAt, completedAt)

        diagnostics.recordSuccess(completedAt: completedAt)
        diagnostics.recordNextRefresh(at: nextRefreshAt)

        XCTAssertNil(diagnostics.lastRouteError)
        XCTAssertEqual(diagnostics.lastRefreshCompletedAt, completedAt)
        XCTAssertEqual(diagnostics.nextRefreshAt, nextRefreshAt)
    }
}
