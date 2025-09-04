import Foundation

/// Request product type for filtering when fetching products
/// Maps to literal strings: "inapp", "subs", "all"
public enum RequestProductType: String, Codable {
    case inapp = "inapp"
    case subs = "subs"
    case all = "all"
}

/// Product request parameters following OpenIAP specification
public struct ProductRequest: Codable, Equatable {
    /// Product SKUs to fetch
    public let skus: [String]
    
    /// Product type filter: "inapp" (default), "subs", or "all"
    public let type: String
    
    public init(skus: [String], type: String = "inapp") {
        self.skus = skus
        self.type = type
    }
    
    /// Convenience initializer with RequestProductType enum
    public init(skus: [String], type: RequestProductType = .inapp) {
        self.skus = skus
        self.type = type.rawValue
    }
    
    /// Get the type as RequestProductType enum
    public var requestType: RequestProductType {
        return RequestProductType(rawValue: type) ?? .inapp
    }
}