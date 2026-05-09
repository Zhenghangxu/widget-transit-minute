import Foundation
import XCTest
@testable import TransitMinuteCore

final class AlertDismissalStateTests: XCTestCase {
    func testAllowsFirstSecondAndThirdAlertBeforeGlobalMute() {
        var state = AlertDismissalState()
        let transitDepartureAt = Date(timeIntervalSince1970: 1_800)
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(state.canAlert(for: transitDepartureAt, now: now))

        state.recordAlertSent(for: transitDepartureAt, now: now)

        XCTAssertTrue(state.canAlert(for: transitDepartureAt, now: now.addingTimeInterval(30)))

        state.recordAlertSent(for: transitDepartureAt, now: now.addingTimeInterval(30))

        XCTAssertTrue(state.canAlert(for: transitDepartureAt, now: now.addingTimeInterval(60)))
    }

    func testBlocksFourthAlertDuringGlobalMute() {
        var state = AlertDismissalState()
        let transitDepartureAt = Date(timeIntervalSince1970: 1_800)
        let now = Date(timeIntervalSince1970: 1_000)

        state.recordAlertSent(for: transitDepartureAt, now: now)
        state.recordAlertSent(for: transitDepartureAt, now: now.addingTimeInterval(30))
        state.recordAlertSent(for: transitDepartureAt, now: now.addingTimeInterval(60))

        XCTAssertFalse(state.canAlert(for: transitDepartureAt, now: now.addingTimeInterval(61)))
    }

    func testDifferentBusDepartureCannotAlertDuringGlobalMute() {
        var state = AlertDismissalState()
        let firstTransitDepartureAt = Date(timeIntervalSince1970: 1_800)
        let nextTransitDepartureAt = Date(timeIntervalSince1970: 3_600)
        let now = Date(timeIntervalSince1970: 1_000)

        state.recordAlertSent(for: firstTransitDepartureAt, now: now)
        state.recordAlertSent(for: firstTransitDepartureAt, now: now.addingTimeInterval(30))
        state.recordAlertSent(for: firstTransitDepartureAt, now: now.addingTimeInterval(60))

        XCTAssertFalse(state.canAlert(for: nextTransitDepartureAt, now: now.addingTimeInterval(61)))
    }

    func testAlertsResumeAfterGlobalMuteExpires() {
        var state = AlertDismissalState()
        let transitDepartureAt = Date(timeIntervalSince1970: 1_800)
        let now = Date(timeIntervalSince1970: 1_000)

        state.recordAlertSent(for: transitDepartureAt, now: now)
        state.recordAlertSent(for: transitDepartureAt, now: now.addingTimeInterval(30))
        state.recordAlertSent(for: transitDepartureAt, now: now.addingTimeInterval(60))

        XCTAssertFalse(state.canAlert(for: transitDepartureAt, now: now.addingTimeInterval(659)))
        XCTAssertTrue(state.canAlert(for: transitDepartureAt, now: now.addingTimeInterval(660)))
    }

    func testClearDoesNotRemoveActiveGlobalMute() {
        var state = AlertDismissalState()
        let transitDepartureAt = Date(timeIntervalSince1970: 1_800)
        let now = Date(timeIntervalSince1970: 1_000)

        state.recordAlertSent(for: transitDepartureAt, now: now)
        state.recordAlertSent(for: transitDepartureAt, now: now.addingTimeInterval(30))
        state.recordAlertSent(for: transitDepartureAt, now: now.addingTimeInterval(60))
        state.clear()

        XCTAssertFalse(state.canAlert(for: transitDepartureAt, now: now.addingTimeInterval(61)))
    }

    func testDismissedBusDepartureDoesNotAlertAgain() {
        var state = AlertDismissalState()
        let transitDepartureAt = Date(timeIntervalSince1970: 1_800)
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(state.canAlert(for: transitDepartureAt, now: now))

        state.dismiss(transitDepartureAt: transitDepartureAt)

        XCTAssertFalse(state.canAlert(for: transitDepartureAt, now: now))
    }

    func testNewBusDepartureCanAlertAfterPriorDismissal() {
        var state = AlertDismissalState()

        state.dismiss(transitDepartureAt: Date(timeIntervalSince1970: 1_800))

        XCTAssertTrue(
            state.canAlert(
                for: Date(timeIntervalSince1970: 3_600),
                now: Date(timeIntervalSince1970: 1_000)
            )
        )
    }

    func testClearAllowsSameBusDepartureToAlertAgain() {
        var state = AlertDismissalState()
        let transitDepartureAt = Date(timeIntervalSince1970: 1_800)

        state.dismiss(transitDepartureAt: transitDepartureAt)
        state.clear()

        XCTAssertTrue(state.canAlert(for: transitDepartureAt, now: Date(timeIntervalSince1970: 1_000)))
    }
}
