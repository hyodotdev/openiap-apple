import Foundation

/// Event types for IAP event system
/// Following OpenIAP specification
public enum OpenIapEvent: String, Codable {
    case PURCHASE_UPDATED = "PURCHASE_UPDATED"
    case PURCHASE_ERROR = "PURCHASE_ERROR"
    case PROMOTED_PRODUCT_IOS = "PROMOTED_PRODUCT_IOS"
}

/// Subscription token for event listeners
public class Subscription {
    public let id: UUID
    public let eventType: OpenIapEvent
    internal var onRemove: (() -> Void)?
    
    public init(eventType: OpenIapEvent, onRemove: (() -> Void)? = nil) {
        self.id = UUID()
        self.eventType = eventType
        self.onRemove = onRemove
    }
    
    deinit {
        // Auto-cleanup when subscription is deallocated (on main thread)
        if let onRemove {
            Task { await MainActor.run { onRemove() } }
        }
    }
}
