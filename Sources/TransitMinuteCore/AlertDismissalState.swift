import Foundation

public struct AlertDismissalState: Equatable, Sendable {
    private static let maximumConsecutiveAlerts = 3
    private static let muteDuration: TimeInterval = 10 * 60

    private var dismissedTransitDepartureAt: Date?
    private var alertCount: Int
    private var mutedUntil: Date?

    public init(
        dismissedTransitDepartureAt: Date? = nil,
        alertCount: Int = 0,
        mutedUntil: Date? = nil
    ) {
        self.dismissedTransitDepartureAt = dismissedTransitDepartureAt
        self.alertCount = alertCount
        self.mutedUntil = mutedUntil
    }

    public mutating func dismiss(transitDepartureAt: Date) {
        dismissedTransitDepartureAt = transitDepartureAt
    }

    public mutating func recordAlertSent(for _: Date, now: Date = Date()) {
        if let mutedUntil, now >= mutedUntil {
            self.mutedUntil = nil
            alertCount = 0
        }

        alertCount += 1
        if alertCount >= Self.maximumConsecutiveAlerts {
            mutedUntil = now.addingTimeInterval(Self.muteDuration)
            alertCount = 0
        }
    }

    public mutating func clear() {
        dismissedTransitDepartureAt = nil
        alertCount = 0
    }

    public func canAlert(for transitDepartureAt: Date, now: Date = Date()) -> Bool {
        dismissedTransitDepartureAt != transitDepartureAt
            && !isMuted(at: now)
    }

    private func isMuted(at now: Date) -> Bool {
        guard let mutedUntil else {
            return false
        }
        return now < mutedUntil
    }
}
