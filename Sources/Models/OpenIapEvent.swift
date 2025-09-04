import Foundation

/// Event types for IAP event system
/// Following OpenIAP specification
public enum OpenIapEvent: String, Codable {
    case PURCHASE_UPDATED = "PURCHASE_UPDATED"
    case PURCHASE_ERROR = "PURCHASE_ERROR"
    case PROMOTED_PRODUCT_IOS = "PROMOTED_PRODUCT_IOS"
}

/// Subscription token for event listeners
public struct Subscription {
    public let id: UUID
    public let eventType: OpenIapEvent
    
    public init(eventType: OpenIapEvent) {
        self.id = UUID()
        self.eventType = eventType
    }
}