import XCTest
@testable import TransitMinuteCore

final class RoutePlannerTests: XCTestCase {
    func testChoosesWorkWhenCurrentLocationIsCloserToHome() {
        let planner = RoutePlanner(
            settings: .preview(
                home: SavedPlace.previewHome,
                work: SavedPlace.previewWork
            )
        )

        let choice = planner.destinationChoice(
            from: Coordinate(latitude: 45.5018, longitude: -73.5673)
        )

        XCTAssertEqual(choice.origin?.label, .home)
        XCTAssertEqual(choice.destination?.label, .work)
    }

    func testChoosesHomeWhenCurrentLocationIsCloserToWork() {
        let planner = RoutePlanner(
            settings: .preview(
                home: SavedPlace.previewHome,
                work: SavedPlace.previewWork
            )
        )

        let choice = planner.destinationChoice(
            from: Coordinate(latitude: 45.5063, longitude: -73.5759)
        )

        XCTAssertEqual(choice.origin?.label, .work)
        XCTAssertEqual(choice.destination?.label, .home)
    }

    func testComputesLeaveTimeFromTransitDepartureMinusWalkAndBuffer() {
        let departure = Date(timeIntervalSince1970: 1_800)
        let plan = TransitPlan(
            origin: .previewHome,
            destination: .previewWork,
            routeSummary: "Bus 24",
            departureStopName: "Sherbrooke / Saint-Laurent",
            transitDepartureAt: departure,
            walkingDuration: 420,
            bufferDuration: 60,
            arrivalAt: Date(timeIntervalSince1970: 3_600)
        )

        XCTAssertEqual(plan.leaveAt, Date(timeIntervalSince1970: 1_320))
    }

    func testCountdownStateIsReadyBeforeLeaveTime() {
        let plan = TransitPlan(
            origin: .previewHome,
            destination: .previewWork,
            routeSummary: "Bus 24",
            departureStopName: "Sherbrooke / Saint-Laurent",
            transitDepartureAt: Date(timeIntervalSince1970: 2_000),
            walkingDuration: 300,
            bufferDuration: 0,
            arrivalAt: Date(timeIntervalSince1970: 3_000)
        )

        let state = CountdownState(plan: plan, now: Date(timeIntervalSince1970: 1_580))

        XCTAssertEqual(state.menuBarTitle, "2 min")
        XCTAssertFalse(state.shouldAlert)
    }

    func testCountdownStateAlertsWhenItIsTimeToLeave() {
        let plan = TransitPlan(
            origin: .previewHome,
            destination: .previewWork,
            routeSummary: "Bus 24",
            departureStopName: "Sherbrooke / Saint-Laurent",
            transitDepartureAt: Date(timeIntervalSince1970: 2_000),
            walkingDuration: 300,
            bufferDuration: 0,
            arrivalAt: Date(timeIntervalSince1970: 3_000)
        )

        let state = CountdownState(plan: plan, now: Date(timeIntervalSince1970: 1_705))

        XCTAssertEqual(state.menuBarTitle, "Leave now")
        XCTAssertTrue(state.shouldAlert)
    }

    func testCountdownUrgencyIsCriticalForOneDisplayedMinute() {
        let plan = TransitPlan(
            origin: .previewHome,
            destination: .previewWork,
            routeSummary: "Bus 24",
            departureStopName: "Main St",
            transitDepartureAt: Date(timeIntervalSince1970: 1_000),
            walkingDuration: 0,
            bufferDuration: 0,
            arrivalAt: Date(timeIntervalSince1970: 1_200)
        )

        let state = CountdownState(
            plan: plan,
            now: Date(timeIntervalSince1970: 941)
        )

        XCTAssertEqual(state.menuBarTitle, "1 min")
        XCTAssertEqual(state.urgency, .critical)
    }

    func testCountdownUrgencyIsWarningForTwoThroughFourDisplayedMinutes() {
        let plan = TransitPlan(
            origin: .previewHome,
            destination: .previewWork,
            routeSummary: "Bus 24",
            departureStopName: "Main St",
            transitDepartureAt: Date(timeIntervalSince1970: 1_000),
            walkingDuration: 0,
            bufferDuration: 0,
            arrivalAt: Date(timeIntervalSince1970: 1_200)
        )

        XCTAssertEqual(
            CountdownState(plan: plan, now: Date(timeIntervalSince1970: 880)).urgency,
            .warning
        )
        XCTAssertEqual(
            CountdownState(plan: plan, now: Date(timeIntervalSince1970: 760)).urgency,
            .warning
        )
    }

    func testCountdownUrgencyIsNormalAtFiveDisplayedMinutes() {
        let plan = TransitPlan(
            origin: .previewHome,
            destination: .previewWork,
            routeSummary: "Bus 24",
            departureStopName: "Main St",
            transitDepartureAt: Date(timeIntervalSince1970: 1_000),
            walkingDuration: 0,
            bufferDuration: 0,
            arrivalAt: Date(timeIntervalSince1970: 1_200)
        )

        let state = CountdownState(
            plan: plan,
            now: Date(timeIntervalSince1970: 720)
        )

        XCTAssertEqual(state.menuBarTitle, "5 min")
        XCTAssertEqual(state.urgency, .normal)
    }

    func testCountdownUrgencyIsCriticalWhenLeavingNow() {
        let state = CountdownState(mode: .leaveNow)

        XCTAssertEqual(state.urgency, .critical)
    }

    func testAdaptiveRefreshUsesShortIntervalNearDeparture() {
        let policy = RefreshPolicy.adaptive

        XCTAssertEqual(policy.interval(secondsUntilLeave: 31 * 60), 300)
        XCTAssertEqual(policy.interval(secondsUntilLeave: 10 * 60), 60)
        XCTAssertEqual(policy.interval(secondsUntilLeave: 4 * 60), 10)
    }

    func testRejectsBlankApiKeys() {
        XCTAssertFalse(APIKeyValidator.looksValid("   "))
        XCTAssertTrue(APIKeyValidator.looksValid("AIza-example-key"))
    }
}
