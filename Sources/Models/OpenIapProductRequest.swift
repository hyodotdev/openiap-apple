import Foundation

/// Request product type for filtering when fetching products
/// Maps to literal strings: "inapp", "subs", "all"
public enum OpenIapRequestProductType: String, Codable, Sendable {
    case inapp = "inapp"
    case subs = "subs"
    case all = "all"
}

/// Product request parameters following OpenIAP specification
public struct OpenIapProductRequest: Codable, Equatable, Sendable {
    /// Product SKUs to fetch
    public let skus: [String]
    
    /// Product type filter: "inapp" (default), "subs", or "all"
    public let type: String
    
    public init(skus: [String], type: String = "inapp") {
        self.skus = skus
        self.type = type
    }
    
    /// Convenience initializer with RequestProductType enum
    public init(skus: [String], type: OpenIapRequestProductType = .inapp) {
        self.skus = skus
        self.type = type.rawValue
    }
    
    /// Get the type as RequestProductType enum
    public var requestType: OpenIapRequestProductType {
        return OpenIapRequestProductType(rawValue: type) ?? .inapp
    }
}

// Backward compatibility aliases
public typealias RequestProductType = OpenIapRequestProductType
public typealias ProductRequest = OpenIapProductRequest

