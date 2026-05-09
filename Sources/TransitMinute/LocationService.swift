import CoreLocation
import Foundation
import TransitMinuteCore

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    var onCoordinate: ((Coordinate) -> Void)?
    var onStatusChange: ((LocationStatus) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            onStatusChange?(.requestingPermission)
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            onStatusChange?(.requestingLocation)
            manager.requestLocation()
        case .denied, .restricted:
            onStatusChange?(.denied)
            break
        @unknown default:
            onStatusChange?(.unavailable)
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                onStatusChange?(.authorized)
            case .denied, .restricted:
                onStatusChange?(.denied)
            case .notDetermined:
                onStatusChange?(.requestingPermission)
            @unknown default:
                onStatusChange?(.unavailable)
            }
            requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            return
        }
        Task { @MainActor in
            onStatusChange?(.located)
            onCoordinate?(
                Coordinate(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            )
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            onStatusChange?(.failed(error.localizedDescription))
        }
    }
}

enum LocationStatus: Equatable {
    case idle
    case requestingPermission
    case authorized
    case requestingLocation
    case located
    case denied
    case unavailable
    case failed(String)

    var message: String {
        switch self {
        case .idle:
            "Location has not been requested yet."
        case .requestingPermission:
            "Waiting for macOS location permission."
        case .authorized:
            "Location permission granted."
        case .requestingLocation:
            "Requesting your current location."
        case .located:
            "Current location found."
        case .denied:
            "Location permission is denied. Enable it in System Settings or use manual mode."
        case .unavailable:
            "Location is unavailable on this Mac."
        case .failed(let message):
            "Location failed: \(message)"
        }
    }
}
