import Foundation

/// Represents an active subscription with platform-specific details
/// Following OpenIAP ActiveSubscription specification
public struct OpenIapActiveSubscription: Codable, Equatable, Sendable {
    /// Product identifier
    public let productId: String
    
    /// Always true for active subscriptions
    public let isActive: Bool
    
    /// Transaction identifier for backend validation
    public let transactionId: String
    
    /// JWT token (iOS) or purchase token (Android) for backend validation
    public let purchaseToken: String?
    
    /// Transaction timestamp (Unix timestamp in milliseconds)
    public let transactionDate: Double
    
    /// Subscription expiration date (iOS only)
    public let expirationDateIOS: Date?
    
    /// Auto-renewal status (Android only) - Always nil on iOS
    public let autoRenewingAndroid: Bool?
    
    /// Environment: 'Sandbox' | 'Production' (iOS only)
    public let environmentIOS: String?
    
    /// True if subscription expires within 7 days
    public let willExpireSoon: Bool?
    
    /// Days remaining until expiration (iOS only)
    public let daysUntilExpirationIOS: Int?
    
    public init(
        productId: String,
        isActive: Bool = true,  // Default to true for active subscriptions
        transactionId: String,
        purchaseToken: String? = nil,
        transactionDate: Double,
        expirationDateIOS: Date? = nil,
        autoRenewingAndroid: Bool? = nil,
        environmentIOS: String? = nil,
        willExpireSoon: Bool? = nil,
        daysUntilExpirationIOS: Int? = nil
    ) {
        self.productId = productId
        self.isActive = isActive
        self.transactionId = transactionId
        self.purchaseToken = purchaseToken
        self.transactionDate = transactionDate
        self.expirationDateIOS = expirationDateIOS
        self.autoRenewingAndroid = autoRenewingAndroid  // Always nil for iOS
        self.environmentIOS = environmentIOS
        
        // Calculate willExpireSoon if not provided
        if let willExpireSoon = willExpireSoon {
            self.willExpireSoon = willExpireSoon
        } else if let expirationDate = expirationDateIOS {
            let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
            self.willExpireSoon = daysUntilExpiration <= 7 && daysUntilExpiration >= 0
        } else {
            self.willExpireSoon = nil
        }
        
        // Calculate daysUntilExpirationIOS if not provided
        if let daysUntilExpirationIOS = daysUntilExpirationIOS {
            self.daysUntilExpirationIOS = daysUntilExpirationIOS
        } else if let expirationDate = expirationDateIOS {
            self.daysUntilExpirationIOS = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day
        } else {
            self.daysUntilExpirationIOS = nil
        }
    }
}

// MARK: - StoreKit 2 Integration
import StoreKit

@available(iOS 15.0, macOS 14.0, *)
extension OpenIapActiveSubscription {
    /// Create ActiveSubscription from StoreKit 2 Transaction and Status
    init(from transaction: Transaction, status: Product.SubscriptionInfo.Status, environment: String? = nil, jwsRepresentation: String? = nil) {
        self.productId = transaction.productID
        self.isActive = true  // Only called for active subscriptions
        self.transactionId = String(transaction.id)
        self.purchaseToken = jwsRepresentation ?? String(transaction.id)
        self.transactionDate = transaction.purchaseDate.timeIntervalSince1970 * 1000  // Unix timestamp in milliseconds
        self.expirationDateIOS = transaction.expirationDate
        self.autoRenewingAndroid = nil  // Android-only field
        
        // Use provided environment or derive from transaction
        if let environment = environment {
            self.environmentIOS = environment
        } else if #available(iOS 16.0, macOS 14.0, *) {
            self.environmentIOS = transaction.environment.rawValue
        } else {
            self.environmentIOS = nil
        }
        
        // Calculate days until expiration and willExpireSoon
        if let expirationDate = transaction.expirationDate {
            let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
            self.daysUntilExpirationIOS = daysUntilExpiration
            self.willExpireSoon = daysUntilExpiration <= 7 && daysUntilExpiration >= 0
        } else {
            self.daysUntilExpirationIOS = nil
            self.willExpireSoon = false
        }
    }
}

