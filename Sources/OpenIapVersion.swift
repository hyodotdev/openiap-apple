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
        return "1.2.3"
    }()

    /// OpenIAP GraphQL version for reference
    public static let gqlVersion: String = {
        // Try to load GQL version from openiap-versions.json
        if let version = loadGQLVersionFromJSON() {
            return version
        }
        // Fallback to hardcoded version
        return "1.0.9"
    }()

    private static func loadVersionFromJSON() -> String? {
        guard let url = Bundle.module.url(forResource: "openiap-versions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["apple"] as? String else {
            return nil
        }
        return version
    }

    private static func loadGQLVersionFromJSON() -> String? {
        guard let url = Bundle.module.url(forResource: "openiap-versions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["gql"] as? String else {
            return nil
        }
        return version
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