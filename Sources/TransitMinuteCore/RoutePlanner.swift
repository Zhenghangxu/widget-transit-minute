import Foundation

public struct RoutePlanner: Sendable {
    public var settings: AppSettings

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public func destinationChoice(from coordinate: Coordinate) -> DestinationChoice {
        guard let home = settings.home, let work = settings.work else {
            return DestinationChoice(origin: nil, destination: nil)
        }

        let distanceToHome = coordinate.distanceMeters(to: home.coordinate)
        let distanceToWork = coordinate.distanceMeters(to: work.coordinate)

        if distanceToHome <= distanceToWork {
            return DestinationChoice(
                origin: home,
                destination: work,
                distanceToHome: distanceToHome,
                distanceToWork: distanceToWork
            )
        }

        return DestinationChoice(
            origin: work,
            destination: home,
            distanceToHome: distanceToHome,
            distanceToWork: distanceToWork
        )
    }
}
