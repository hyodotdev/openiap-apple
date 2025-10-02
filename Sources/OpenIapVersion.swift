import Foundation

/// OpenIAP version management
public struct OpenIapVersion {
    /// Current OpenIAP Apple SDK version
    public static let current: String = {
        // Try to load version from openiap-versions.json
        if let version = loadVersionFromJSON() {
            return version
        }
        // Fallback to hardcoded version
        return "1.2.5"
    }()

    /// OpenIAP GraphQL version for reference
    public static let gqlVersion: String = {
        // Try to load GQL version from openiap-versions.json
        if let version = loadGQLVersionFromJSON() {
            return version
        }
        // Fallback to hardcoded version
        return "1.0.10"
    }()

    private static func loadVersionFromJSON() -> String? {
        #if SWIFT_PACKAGE
        guard let url = Bundle.module.url(forResource: "openiap-versions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["apple"] as? String else {
            return nil
        }
        return version
        #else
        // For CocoaPods or direct integration, use Bundle.main or return nil
        guard let url = Bundle.main.url(forResource: "openiap-versions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["apple"] as? String else {
            return nil
        }
        return version
        #endif
    }

    private static func loadGQLVersionFromJSON() -> String? {
        #if SWIFT_PACKAGE
        guard let url = Bundle.module.url(forResource: "openiap-versions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["gql"] as? String else {
            return nil
        }
        return version
        #else
        // For CocoaPods or direct integration, use Bundle.main or return nil
        guard let url = Bundle.main.url(forResource: "openiap-versions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["gql"] as? String else {
            return nil
        }
        return version
        #endif
    }
}

// MARK: - Version Info

/// Namespace for OpenIAP version information
public enum OpenIapVersionInfo {
    /// Current OpenIAP Apple SDK version
    public static var sdkVersion: String {
        OpenIapVersion.current
    }

    /// OpenIAP GraphQL version for reference
    public static var gqlVersion: String {
        OpenIapVersion.gqlVersion
    }
}