import Foundation

/// Request product type for filtering when fetching products
/// Maps to literal strings: "in-app" (preferred), legacy "inapp" (deprecated, removal scheduled for 1.2.0), "subs", "all"
public enum OpenIapRequestProductType: String, Codable, Sendable {
    internal static let legacyInAppRawValue = "inapp"
    internal static let modernInAppRawValue = "in-app"

    @available(*, deprecated, message: "'inapp' is deprecated and will be removed in 1.2.0. Use .inApp instead.")
    case inapp = "inapp"
    case inApp = "in-app"
    case subs = "subs"
    case all = "all"

    internal var normalizedRawValue: String {
        if rawValue == Self.legacyInAppRawValue {
            return Self.modernInAppRawValue
        }
        return rawValue
    }
}

/// Product request parameters following OpenIAP specification
public struct OpenIapProductRequest: Codable, Equatable, Sendable {
    /// Product SKUs to fetch
    public let skus: [String]
    
    /// Product type filter: "in-app" (default), "subs", or "all". The legacy value "inapp" is still accepted but will be removed in 1.2.0.
    public let type: String

    private enum CodingKeys: String, CodingKey {
        case skus
        case type
    }

    /// Create request specifying raw type string. Passing `nil` or an empty string defaults to "in-app".
    public init(skus: [String], type: String? = nil) {
        self.skus = skus
        self.type = OpenIapProductRequest.normalizeType(type)
    }
    
    /// Convenience initializer with RequestProductType enum
    public init(skus: [String], type: OpenIapRequestProductType = .inApp) {
        self.skus = skus
        self.type = type.normalizedRawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let skus = try container.decode([String].self, forKey: .skus)
        let rawType = try container.decodeIfPresent(String.self, forKey: .type)
        self.init(skus: skus, type: rawType ?? OpenIapProductRequest.defaultTypeValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(skus, forKey: .skus)
        try container.encode(type, forKey: .type)
    }
    
    /// Get the type as RequestProductType enum
    public var requestType: OpenIapRequestProductType {
        if let parsedType = OpenIapRequestProductType(rawValue: type) {
            if parsedType.rawValue == OpenIapRequestProductType.legacyInAppRawValue {
                return .inApp
            }
            return parsedType
        }

        let normalized = OpenIapProductRequest.normalizeType(type)
        return OpenIapRequestProductType(rawValue: normalized) ?? .inApp
    }

    private static let defaultTypeValue = OpenIapRequestProductType.modernInAppRawValue

    private static func normalizeType(_ rawType: String?) -> String {
        guard let rawType else {
            return defaultTypeValue
        }

        let trimmed = rawType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return defaultTypeValue
        }

        if let productType = OpenIapRequestProductType(rawValue: trimmed) {
            return productType.normalizedRawValue
        }

        let lowered = trimmed.lowercased()
        switch lowered {
        case OpenIapRequestProductType.legacyInAppRawValue, OpenIapRequestProductType.modernInAppRawValue:
            return OpenIapRequestProductType.modernInAppRawValue
        case OpenIapRequestProductType.subs.rawValue:
            return OpenIapRequestProductType.subs.rawValue
        case OpenIapRequestProductType.all.rawValue:
            return OpenIapRequestProductType.all.rawValue
        default:
            return defaultTypeValue
        }
    }
}

// Backward compatibility aliases
public typealias RequestProductType = OpenIapRequestProductType
public typealias ProductRequest = OpenIapProductRequest
