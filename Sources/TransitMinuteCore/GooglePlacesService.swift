import Foundation

public struct PlaceSuggestion: Identifiable, Equatable, Sendable {
    public var id: String { placeID }
    public var placeID: String
    public var primaryText: String
    public var secondaryText: String

    public init(placeID: String, primaryText: String, secondaryText: String) {
        self.placeID = placeID
        self.primaryText = primaryText
        self.secondaryText = secondaryText
    }
}

public enum GoogleServiceError: LocalizedError, Equatable {
    case invalidAPIKey
    case requestFailed(String)
    case noRoutes
    case malformedResponse

    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            "Enter a Google API key first."
        case .requestFailed(let message):
            message
        case .noRoutes:
            "No transit route was found."
        case .malformedResponse:
            "Google returned a response this app could not read."
        }
    }
}

struct GoogleErrorResponse: Decodable {
    var error: GoogleError?

    struct GoogleError: Decodable {
        var code: Int?
        var message: String
        var status: String?
    }
}

public protocol PlacesProviding: Sendable {
    func suggestions(for query: String, apiKey: String) async throws -> [PlaceSuggestion]
    func placeDetails(placeID: String, label: PlaceLabel, apiKey: String) async throws -> SavedPlace
}

public struct GooglePlacesService: PlacesProviding {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func suggestions(for query: String, apiKey: String) async throws -> [PlaceSuggestion] {
        guard APIKeyValidator.looksValid(apiKey) else {
            throw GoogleServiceError.invalidAPIKey
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }

        var components = URLComponents(string: "https://places.googleapis.com/v1/places:autocomplete")
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey)
        ]
        guard let url = components?.url else {
            throw GoogleServiceError.malformedResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AutocompleteRequest(input: trimmedQuery))

        let response: AutocompleteResponse = try await decodedResponse(for: request)
        return response.suggestions.compactMap { suggestion in
            guard let prediction = suggestion.placePrediction else {
                return nil
            }
            return PlaceSuggestion(
                placeID: prediction.placeID,
                primaryText: prediction.structuredFormat?.mainText?.text ?? prediction.text.text,
                secondaryText: prediction.structuredFormat?.secondaryText?.text ?? ""
            )
        }
    }

    public func placeDetails(placeID: String, label: PlaceLabel, apiKey: String) async throws -> SavedPlace {
        guard APIKeyValidator.looksValid(apiKey) else {
            throw GoogleServiceError.invalidAPIKey
        }

        var components = URLComponents(string: "https://places.googleapis.com/v1/places/\(placeID)")
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey)
        ]
        guard let url = components?.url else {
            throw GoogleServiceError.malformedResponse
        }

        var request = URLRequest(url: url)
        request.setValue("id,formattedAddress,location", forHTTPHeaderField: "X-Goog-FieldMask")

        let place: PlaceDetailsResponse = try await decodedResponse(for: request)
        return SavedPlace(
            label: label,
            formattedAddress: place.formattedAddress,
            placeID: place.id,
            coordinate: Coordinate(
                latitude: place.location.latitude,
                longitude: place.location.longitude
            )
        )
    }

    private func decodedResponse<T: Decodable>(for request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw GoogleServiceError.requestFailed(
                GoogleErrorMessage.make(
                    prefix: "Places request failed",
                    statusCode: httpResponse.statusCode,
                    data: data
                )
            )
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GoogleServiceError.malformedResponse
        }
    }
}

private struct AutocompleteRequest: Encodable {
    var input: String
}

private struct AutocompleteResponse: Decodable {
    var suggestions: [Suggestion]

    struct Suggestion: Decodable {
        var placePrediction: Prediction?
    }

    struct Prediction: Decodable {
        var placeID: String
        var text: TextValue
        var structuredFormat: StructuredFormat?

        enum CodingKeys: String, CodingKey {
            case placeID = "placeId"
            case text
            case structuredFormat
        }
    }

    struct StructuredFormat: Decodable {
        var mainText: TextValue?
        var secondaryText: TextValue?
    }

    struct TextValue: Decodable {
        var text: String
    }
}

private struct PlaceDetailsResponse: Decodable {
    var id: String
    var formattedAddress: String
    var location: Location

    struct Location: Decodable {
        var latitude: Double
        var longitude: Double
    }
}
