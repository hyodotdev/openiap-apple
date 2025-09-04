import Foundation

// Simple receipt model for compatibility
public struct OpenIapReceipt: Codable, Equatable {
    public let bundleId: String
    public let applicationVersion: String
    public let originalApplicationVersion: String?
    public let creationDate: Date
    public let expirationDate: Date?
    public let inAppPurchases: [OpenIapPurchase]
    
    public init(
        bundleId: String,
        applicationVersion: String,
        originalApplicationVersion: String? = nil,
        creationDate: Date,
        expirationDate: Date? = nil,
        inAppPurchases: [OpenIapPurchase]
    ) {
        self.bundleId = bundleId
        self.applicationVersion = applicationVersion
        self.originalApplicationVersion = originalApplicationVersion
        self.creationDate = creationDate
        self.expirationDate = expirationDate
        self.inAppPurchases = inAppPurchases
    }
}