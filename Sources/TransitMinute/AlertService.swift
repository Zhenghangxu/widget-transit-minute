import Foundation
import TransitMinuteCore
import UserNotifications

struct AlertService {
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func sendDepartureAlert(plan: TransitPlan) async {
        let content = UNMutableNotificationContent()
        content.title = "Time to leave"
        content.body = "Head to \(plan.departureStopName) for \(plan.routeSummary)."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "transit-minute-departure-\(plan.leaveAt.timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
