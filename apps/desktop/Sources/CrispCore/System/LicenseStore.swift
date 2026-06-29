import Foundation
import OSLog

/// Manages the licensing lifecycle and offline-tolerant validation.
/// Mirrors ModelStore: trial -> key/OAuth gate, state derived on launch, offline-tolerant.
@MainActor
@Observable
public final class LicenseStore {
    public enum State: Equatable {
        case checking
        case trial(daysLeft: Int)
        case active
        case offlineGrace(daysLeft: Int)
        case expired(String)
        case invalid(String)
        
        public var isUsable: Bool {
            switch self {
            case .trial, .active, .offlineGrace: return true
            case .checking, .expired, .invalid: return false
            }
        }
    }
    
    public private(set) var state: State = .checking
    
    private let defaults = UserDefaults.standard
    private static let log = Logger(subsystem: "com.crisp.app", category: "LicenseStore")
    
    // Config
    private let trialDays = 14
    private let offlineGraceDays = 14
    
    // Keys
    private let firstLaunchDateKey = "LicenseStore_FirstLaunchDate"
    private let licenseKeyKey = "LicenseStore_LicenseKey"
    private let lastValidationDateKey = "LicenseStore_LastValidationDate"
    
    public init() {}
    
    /// Called on app launch to determine the current state.
    public func refresh() async {
        state = .checking
        
        // 1. Check if a license key exists
        guard let key = defaults.string(forKey: licenseKeyKey), !key.isEmpty else {
            // No license key, evaluate trial
            state = evaluateTrialState()
            return
        }
        
        // 2. Validate existing key
        do {
            let response = try await PolarAPIClient.shared.validate(key: key)
            if response.isActive {
                // Successfully validated
                defaults.set(Date(), forKey: lastValidationDateKey)
                state = .active
            } else {
                // Key is no longer active (revoked, expired, etc.)
                state = .expired("Your license key is no longer active.")
            }
        } catch let error as PolarAPIError {
            // 3. Network or Server error -> Fallback to Offline Grace
            if case .networkError(_) = error {
                state = evaluateOfflineGrace()
            } else if case .validationFailed(let msg) = error {
                state = .invalid("Validation failed: \(msg)")
            } else {
                state = evaluateOfflineGrace()
            }
        } catch {
            state = evaluateOfflineGrace()
        }
    }
    
    /// Attempt to activate a new license key
    public func activate(key: String) async {
        state = .checking
        do {
            let response = try await PolarAPIClient.shared.validate(key: key)
            if response.isActive {
                defaults.set(key, forKey: licenseKeyKey)
                defaults.set(Date(), forKey: lastValidationDateKey)
                state = .active
            } else {
                state = .invalid("The provided key is not active.")
            }
        } catch {
            state = .invalid("Activation failed. Please check your internet connection and try again.")
        }
    }
    
    /// Remove the license key
    public func deactivate() {
        defaults.removeObject(forKey: licenseKeyKey)
        defaults.removeObject(forKey: lastValidationDateKey)
        state = evaluateTrialState()
    }
    
    // MARK: - Internal Evaluation
    
    private func evaluateTrialState() -> State {
        let now = Date()
        if let firstLaunch = defaults.object(forKey: firstLaunchDateKey) as? Date {
            let daysElapsed = Calendar.current.dateComponents([.day], from: firstLaunch, to: now).day ?? 0
            let daysLeft = max(0, trialDays - daysElapsed)
            if daysLeft > 0 {
                return .trial(daysLeft: daysLeft)
            } else {
                return .expired("Your trial has expired. Please purchase a license to continue.")
            }
        } else {
            // First time launching the app
            defaults.set(now, forKey: firstLaunchDateKey)
            return .trial(daysLeft: trialDays)
        }
    }
    
    private func evaluateOfflineGrace() -> State {
        guard let lastValidation = defaults.object(forKey: lastValidationDateKey) as? Date else {
            return .invalid("Could not verify license status.")
        }
        
        let daysOffline = Calendar.current.dateComponents([.day], from: lastValidation, to: Date()).day ?? 0
        let daysLeft = max(0, offlineGraceDays - daysOffline)
        
        if daysLeft > 0 {
            Self.log.info("Offline validation fallback. \(daysLeft) days of grace remaining.")
            return .offlineGrace(daysLeft: daysLeft)
        } else {
            return .invalid("Offline grace period expired. Please connect to the internet to validate your license.")
        }
    }
}
