import Foundation

public enum RouteDisplay {
    public static func systemImage(for mode: TransitMode) -> String {
        switch mode {
        case .bus:
            return "bus.fill"
        case .subway, .rail:
            return "train.side.front.car"
        case .transit:
            return "tram.fill"
        }
    }

    public static func badgeText(from routeSummary: String) -> String {
        let trimmed = routeSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let busPrefix = "Bus "
        if trimmed.localizedCaseInsensitiveCompare("Bus") == .orderedSame {
            return trimmed
        }
        if trimmed.lowercased().hasPrefix(busPrefix.lowercased()) {
            return String(trimmed.dropFirst(busPrefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
}
