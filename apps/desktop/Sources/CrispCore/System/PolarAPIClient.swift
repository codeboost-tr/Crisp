import Foundation

public enum PolarAPIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case validationFailed(String)
}

public struct PolarLicenseValidationResponse: Decodable {
    public let id: String
    public let organizationId: String
    public let key: String
    public let status: String
    public let validatedAt: String?
    
    // Status can be "granted", "revoked", "expired" etc.
    public var isActive: Bool {
        return status == "granted" || status == "active"
    }
}

public final class PolarAPIClient {
    public static let shared = PolarAPIClient()
    
    private let baseURL = "https://api.polar.sh/api/v1"
    
    // TODO: Replace with your actual Polar Organization ID
    private let organizationId = "YOUR_ORG_ID_HERE"
    
    private init() {}
    
    /// Validates a license key against the Polar.sh API.
    /// - Parameter key: The license key input by the user.
    /// - Returns: A `PolarLicenseValidationResponse` indicating the current status of the license.
    public func validate(key: String) async throws -> PolarLicenseValidationResponse {
        guard let url = URL(string: "\(baseURL)/license-keys/validate") else {
            throw PolarAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // According to Polar API, the payload usually requires the organization ID and the key
        let payload: [String: String] = [
            "organization_id": organizationId,
            "key": key
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw PolarAPIError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolarAPIError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(PolarLicenseValidationResponse.self, from: data)
            } catch {
                throw PolarAPIError.invalidResponse
            }
        } else {
            // Handle error response from Polar (e.g., 400 Bad Request, 401 Unauthorized)
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorJson["detail"] as? String {
                throw PolarAPIError.validationFailed(message)
            } else {
                throw PolarAPIError.validationFailed("Invalid license key or server error. (\(httpResponse.statusCode))")
            }
        }
    }
}
