import XCTest
@testable import TransitMinuteCore

final class RouteDisplayTests: XCTestCase {
    func testBadgeRemovesLeadingBusPrefix() {
        XCTAssertEqual(RouteDisplay.badgeText(from: "Bus 90"), "90")
    }

    func testBadgePreservesNonBusNames() {
        XCTAssertEqual(RouteDisplay.badgeText(from: "Blue Line"), "Blue Line")
    }

    func testBadgeTrimsWhitespace() {
        XCTAssertEqual(RouteDisplay.badgeText(from: "  Bus 24  "), "24")
    }

    func testBusModeUsesBusIcon() {
        XCTAssertEqual(RouteDisplay.systemImage(for: .bus), "bus.fill")
    }

    func testSubwayModeUsesAvailableRailIcon() {
        XCTAssertEqual(RouteDisplay.systemImage(for: .subway), "train.side.front.car")
    }
}
