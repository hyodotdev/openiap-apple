import Foundation

public struct ActiveSubscription {
    public let productId: String
    public let isActive: Bool
    public let expirationDateIOS: Date?
    public let autoRenewingAndroid: Bool?
    public let environmentIOS: String?
    public let willExpireSoon: Bool?
    public let daysUntilExpirationIOS: Int?
    
    public init(
        productId: String,
        isActive: Bool,
        expirationDateIOS: Date? = nil,
        autoRenewingAndroid: Bool? = nil,
        environmentIOS: String? = nil,
        willExpireSoon: Bool? = nil,
        daysUntilExpirationIOS: Int? = nil
    ) {
        self.productId = productId
        self.isActive = isActive
        self.expirationDateIOS = expirationDateIOS
        self.autoRenewingAndroid = autoRenewingAndroid
        self.environmentIOS = environmentIOS
        self.willExpireSoon = willExpireSoon
        self.daysUntilExpirationIOS = daysUntilExpirationIOS
    }
}