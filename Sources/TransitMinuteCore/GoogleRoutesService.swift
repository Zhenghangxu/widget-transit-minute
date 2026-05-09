import Foundation

public protocol RoutesProviding: Sendable {
    func transitPlan(
        origin: SavedPlace,
        destination: SavedPlace,
        apiKey: String,
        bufferMinutes: Int
    ) async throws -> TransitPlan
}

public struct GoogleRoutesService: RoutesProviding {
    private let session: URLSession
    private let clock: @Sendable () -> Date

    public init(
        session: URLSession = .shared,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.session = session
        self.clock = clock
    }

    public func transitPlan(
        origin: SavedPlace,
        destination: SavedPlace,
        apiKey: String,
        bufferMinutes: Int
    ) async throws -> TransitPlan {
        guard APIKeyValidator.looksValid(apiKey) else {
            throw GoogleServiceError.invalidAPIKey
        }

        return try await computeTransitPlan(
            origin: origin,
            destination: destination,
            apiKey: apiKey,
            bufferMinutes: bufferMinutes
        )
    }

    private func computeTransitPlan(
        origin: SavedPlace,
        destination: SavedPlace,
        apiKey: String,
        bufferMinutes: Int
    ) async throws -> TransitPlan {
        guard let url = URL(string: "https://routes.googleapis.com/directions/v2:computeRoutes") else {
            throw GoogleServiceError.malformedResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("routes.description,routes.legs.duration,routes.legs.staticDuration,routes.legs.steps.staticDuration,routes.legs.steps.transitDetails,routes.legs.steps.transitDetails.transitLine.vehicle.type", forHTTPHeaderField: "X-Goog-FieldMask")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RoutesRequest(
                origin: .init(location: .init(latLng: origin.coordinate)),
                destination: .init(location: .init(latLng: destination.coordinate)),
                travelMode: "TRANSIT",
                computeAlternativeRoutes: true,
                departureTime: ISO8601DateFormatter().string(from: clock())
            )
        )

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw GoogleServiceError.requestFailed(
                GoogleErrorMessage.make(
                    prefix: "Routes request failed",
                    statusCode: httpResponse.statusCode,
                    data: data
                )
            )
        }

        let decoded: RoutesResponse
        do {
            decoded = try JSONDecoder.googleRoutes.decode(RoutesResponse.self, from: data)
        } catch {
            throw GoogleServiceError.malformedResponse
        }

        guard let route = decoded.routes.first,
              let leg = route.legs.first else {
            throw GoogleServiceError.noRoutes
        }

        guard let transitStep = leg.steps.first(where: { $0.transitDetails != nil }),
              let transitDetails = transitStep.transitDetails,
              let departureTime = transitDetails.stopDetails.departureTime else {
            throw GoogleServiceError.noRoutes
        }

        let walkingDuration = leg.steps
            .prefix { $0.transitDetails == nil }
            .map(\.durationSeconds)
            .reduce(0, +)

        return TransitPlan(
            origin: origin,
            destination: destination,
            routeSummary: route.description ?? transitDetails.localizedLineName,
            transitMode: transitDetails.transitMode,
            departureStopName: transitDetails.stopDetails.departureStop.name,
            transitDepartureAt: departureTime,
            walkingDuration: walkingDuration,
            bufferDuration: TimeInterval(max(0, bufferMinutes) * 60),
            arrivalAt: departureTime.addingTimeInterval(leg.durationSeconds)
        )
    }
}

private struct RoutesRequest: Encodable {
    var origin: Waypoint
    var destination: Waypoint
    var travelMode: String
    var computeAlternativeRoutes: Bool
    var departureTime: String
}

private struct Waypoint: Encodable {
    var location: Location

    struct Location: Encodable {
        var latLng: Coordinate
    }
}

private struct RoutesResponse: Decodable {
    var routes: [Route]

    struct Route: Decodable {
        var description: String?
        var legs: [Leg]
    }

    struct Leg: Decodable {
        var steps: [Step]
        var duration: String?
        var staticDuration: String?

        var durationSeconds: TimeInterval {
            DurationParser.seconds(from: duration ?? staticDuration)
        }
    }

    struct Step: Decodable {
        var staticDuration: String?
        var transitDetails: TransitDetails?

        var durationSeconds: TimeInterval {
            DurationParser.seconds(from: staticDuration)
        }
    }

    struct TransitDetails: Decodable {
        var stopDetails: StopDetails
        var transitLine: TransitLine?

        var localizedLineName: String {
            transitLine?.nameShort ?? transitLine?.name ?? "Transit"
        }

        var transitMode: TransitMode {
            TransitMode(googleVehicleType: transitLine?.vehicle?.type)
        }
    }

    struct StopDetails: Decodable {
        var departureStop: TransitStop
        var departureTime: Date?
    }

    struct TransitStop: Decodable {
        var name: String
    }

    struct TransitLine: Decodable {
        var name: String?
        var nameShort: String?
        var vehicle: TransitVehicle?
    }

    struct TransitVehicle: Decodable {
        var type: String?
    }
}

enum GoogleErrorMessage {
    static func make(prefix: String, statusCode: Int, data: Data) -> String {
        if let decoded = try? JSONDecoder().decode(GoogleErrorResponse.self, from: data),
           let error = decoded.error {
            return "\(prefix) with HTTP \(statusCode): \(error.message)"
        }

        if let rawBody = String(data: data, encoding: .utf8),
           !rawBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(prefix) with HTTP \(statusCode): \(rawBody)"
        }

        return "\(prefix) with HTTP \(statusCode)."
    }
}

private enum DurationParser {
    static func seconds(from value: String?) -> TimeInterval {
        guard let value else {
            return 0
        }
        return TimeInterval(value.replacingOccurrences(of: "s", with: "")) ?? 0
    }
}

private extension JSONDecoder {
    static var googleRoutes: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
