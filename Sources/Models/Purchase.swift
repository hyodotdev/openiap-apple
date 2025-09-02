import Foundation
import StoreKit

public struct IapPurchase: Codable, Equatable {
    public let productId: String
    public let purchaseToken: String
    public let transactionId: String
    public let originalTransactionId: String?
    public let purchaseTime: Date
    public let originalPurchaseTime: Date?
    public let expiryTime: Date?
    public let isAutoRenewing: Bool
    public let purchaseState: PurchaseState
    public let developerPayload: String?
    public let acknowledgementState: AcknowledgementState
    public let quantity: Int
    public let jwsRepresentation: String?
    public let jsonRepresentation: String?
    public let appAccountToken: String?
    
    public enum PurchaseState: String, Codable {
        case pending
        case purchased
        case failed
        case restored
        case deferred
    }
    
    public enum AcknowledgementState: String, Codable {
        case notAcknowledged
        case acknowledged
    }
}

@available(iOS 15.0, macOS 12.0, *)
extension IapPurchase {
    init(from transaction: Transaction, jwsRepresentation: String? = nil) async {
        self.productId = transaction.productID
        self.transactionId = String(transaction.id)
        self.originalTransactionId = transaction.originalID != 0 ? String(transaction.originalID) : nil
        self.purchaseTime = transaction.purchaseDate
        self.originalPurchaseTime = transaction.originalPurchaseDate
        self.expiryTime = transaction.expirationDate
        self.isAutoRenewing = transaction.isUpgraded == false
        self.purchaseToken = jwsRepresentation ?? String(transaction.id)
        self.developerPayload = transaction.appAccountToken?.uuidString
        self.quantity = transaction.purchasedQuantity
        self.jwsRepresentation = jwsRepresentation
        self.jsonRepresentation = String(data: transaction.jsonRepresentation, encoding: .utf8)
        self.appAccountToken = transaction.appAccountToken?.uuidString
        
        switch transaction.ownershipType {
        case .purchased:
            self.purchaseState = .purchased
        case .familyShared:
            self.purchaseState = .restored
        default:
            self.purchaseState = .purchased
        }
        
        self.acknowledgementState = .acknowledged
    }
}

public struct IapReceipt: Codable {
    public let bundleId: String
    public let applicationVersion: String
    public let originalApplicationVersion: String?
    public let creationDate: Date
    public let expirationDate: Date?
    public let inAppPurchases: [IapPurchase]
}