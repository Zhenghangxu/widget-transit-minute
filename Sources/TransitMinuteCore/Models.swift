import Foundation

public struct Coordinate: Codable, Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public func distanceMeters(to other: Coordinate) -> Double {
        let radius = 6_371_000.0
        let latitudeDelta = (other.latitude - latitude) * .pi / 180
        let longitudeDelta = (other.longitude - longitude) * .pi / 180
        let startLatitude = latitude * .pi / 180
        let endLatitude = other.latitude * .pi / 180

        let a = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
            * cos(startLatitude) * cos(endLatitude)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return radius * c
    }
}

public enum PlaceLabel: String, Codable, Equatable, Sendable {
    case home
    case work

    public var title: String {
        switch self {
        case .home: "Home"
        case .work: "Work"
        }
    }
}

public struct SavedPlace: Codable, Equatable, Sendable {
    public var label: PlaceLabel
    public var formattedAddress: String
    public var placeID: String
    public var coordinate: Coordinate

    public init(
        label: PlaceLabel,
        formattedAddress: String,
        placeID: String,
        coordinate: Coordinate
    ) {
        self.label = label
        self.formattedAddress = formattedAddress
        self.placeID = placeID
        self.coordinate = coordinate
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var home: SavedPlace?
    public var work: SavedPlace?
    public var alertsEnabled: Bool
    public var bufferMinutes: Int
    public var refreshPolicy: RefreshPolicy

    public init(
        home: SavedPlace? = nil,
        work: SavedPlace? = nil,
        alertsEnabled: Bool = true,
        bufferMinutes: Int = 1,
        refreshPolicy: RefreshPolicy = .adaptive
    ) {
        self.home = home
        self.work = work
        self.alertsEnabled = alertsEnabled
        self.bufferMinutes = bufferMinutes
        self.refreshPolicy = refreshPolicy
    }

    public var isSetupComplete: Bool {
        home != nil && work != nil
    }
}

public struct DestinationChoice: Equatable, Sendable {
    public var origin: SavedPlace?
    public var destination: SavedPlace?
    public var distanceToHome: Double?
    public var distanceToWork: Double?
}

public struct RouteRequestSnapshot: Equatable, Sendable {
    public var origin: SavedPlace
    public var destination: SavedPlace
    public var requestedAt: Date

    public init(origin: SavedPlace, destination: SavedPlace, requestedAt: Date) {
        self.origin = origin
        self.destination = destination
        self.requestedAt = requestedAt
    }
}

public struct RouteDiagnostics: Equatable, Sendable {
    public var lastRequest: RouteRequestSnapshot?
    public var nextRefreshAt: Date?
    public var lastRouteError: String?
    public var lastRefreshCompletedAt: Date?

    public init(
        lastRequest: RouteRequestSnapshot? = nil,
        nextRefreshAt: Date? = nil,
        lastRouteError: String? = nil,
        lastRefreshCompletedAt: Date? = nil
    ) {
        self.lastRequest = lastRequest
        self.nextRefreshAt = nextRefreshAt
        self.lastRouteError = lastRouteError
        self.lastRefreshCompletedAt = lastRefreshCompletedAt
    }

    public mutating func recordRequest(
        origin: SavedPlace,
        destination: SavedPlace,
        requestedAt: Date
    ) {
        lastRequest = RouteRequestSnapshot(
            origin: origin,
            destination: destination,
            requestedAt: requestedAt
        )
    }

    public mutating func recordSuccess(completedAt: Date) {
        lastRouteError = nil
        lastRefreshCompletedAt = completedAt
    }

    public mutating func recordFailure(_ message: String, completedAt: Date) {
        lastRouteError = message
        lastRefreshCompletedAt = completedAt
    }

    public mutating func recordNextRefresh(at date: Date?) {
        nextRefreshAt = date
    }
}

public enum TransitMode: String, Codable, Equatable, Sendable {
    case bus
    case subway
    case rail
    case transit

    public init(googleVehicleType: String?) {
        switch googleVehicleType?.uppercased() {
        case "BUS":
            self = .bus
        case "SUBWAY":
            self = .subway
        case "RAIL", "TRAIN", "HEAVY_RAIL", "COMMUTER_TRAIN", "HIGH_SPEED_TRAIN",
             "LONG_DISTANCE_TRAIN", "TRAM", "MONORAIL":
            self = .rail
        case nil:
            self = .bus
        default:
            self = .transit
        }
    }
}

public struct TransitPlan: Equatable, Sendable {
    public var origin: SavedPlace
    public var destination: SavedPlace
    public var routeSummary: String
    public var transitMode: TransitMode
    public var departureStopName: String
    public var transitDepartureAt: Date
    public var walkingDuration: TimeInterval
    public var bufferDuration: TimeInterval
    public var arrivalAt: Date

    public init(
        origin: SavedPlace,
        destination: SavedPlace,
        routeSummary: String,
        transitMode: TransitMode = .bus,
        departureStopName: String,
        transitDepartureAt: Date,
        walkingDuration: TimeInterval,
        bufferDuration: TimeInterval,
        arrivalAt: Date
    ) {
        self.origin = origin
        self.destination = destination
        self.routeSummary = routeSummary
        self.transitMode = transitMode
        self.departureStopName = departureStopName
        self.transitDepartureAt = transitDepartureAt
        self.walkingDuration = walkingDuration
        self.bufferDuration = bufferDuration
        self.arrivalAt = arrivalAt
    }

    public var leaveAt: Date {
        transitDepartureAt.addingTimeInterval(-(walkingDuration + bufferDuration))
    }
}

public enum CountdownMode: Equatable, Sendable {
    case setupNeeded
    case locating
    case planning
    case ready(TimeInterval)
    case leaveNow
    case missed
    case error(String)
}

public enum CountdownUrgency: Equatable, Sendable {
    case normal
    case warning
    case critical
}

public struct CountdownState: Equatable, Sendable {
    public var mode: CountdownMode
    public var plan: TransitPlan?

    public init(mode: CountdownMode, plan: TransitPlan? = nil) {
        self.mode = mode
        self.plan = plan
    }

    public init(plan: TransitPlan, now: Date) {
        let secondsUntilLeave = plan.leaveAt.timeIntervalSince(now)
        let secondsSinceTransitDeparture = now.timeIntervalSince(plan.transitDepartureAt)

        if secondsSinceTransitDeparture > 60 {
            self.mode = .missed
        } else if secondsUntilLeave <= 0 {
            self.mode = .leaveNow
        } else {
            self.mode = .ready(secondsUntilLeave)
        }
        self.plan = plan
    }

    public var menuBarTitle: String {
        switch mode {
        case .setupNeeded:
            return "Set up"
        case .locating:
            return "Locating"
        case .planning:
            return "Planning"
        case .ready(let seconds):
            let minutes = max(1, Int(ceil(seconds / 60)))
            return "\(minutes) min"
        case .leaveNow:
            return "Leave now"
        case .missed:
            return "Missed"
        case .error:
            return "--"
        }
    }

    public var urgency: CountdownUrgency {
        switch mode {
        case .ready(let seconds):
            let minutes = max(1, Int(ceil(seconds / 60)))
            if minutes < 2 {
                return .critical
            }
            if minutes < 5 {
                return .warning
            }
            return .normal
        case .leaveNow:
            return .critical
        case .setupNeeded, .locating, .planning, .missed, .error:
            return .normal
        }
    }

    public var shouldAlert: Bool {
        mode == .leaveNow
    }
}

public enum RefreshPolicy: Codable, Equatable, Sendable {
    case adaptive
    case fixed(TimeInterval)

    public func interval(secondsUntilLeave: TimeInterval) -> TimeInterval {
        switch self {
        case .adaptive:
            if secondsUntilLeave <= 5 * 60 {
                return 10
            }
            if secondsUntilLeave <= 30 * 60 {
                return 60
            }
            return 300
        case .fixed(let interval):
            return max(10, interval)
        }
    }
}

public enum APIKeyValidator {
    public static func looksValid(_ key: String) -> Bool {
        !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public extension SavedPlace {
    static let previewHome = SavedPlace(
        label: .home,
        formattedAddress: "Home",
        placeID: "home-preview",
        coordinate: Coordinate(latitude: 45.5017, longitude: -73.5673)
    )

    static let previewWork = SavedPlace(
        label: .work,
        formattedAddress: "Work",
        placeID: "work-preview",
        coordinate: Coordinate(latitude: 45.5062, longitude: -73.5758)
    )
}

public extension AppSettings {
    static func preview(home: SavedPlace?, work: SavedPlace?) -> AppSettings {
        AppSettings(home: home, work: work)
    }
}
