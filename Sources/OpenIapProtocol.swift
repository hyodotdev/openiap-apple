import Foundation
import StoreKit

// MARK: - Event Listeners

@available(iOS 15.0, macOS 14.0, *)
public typealias PurchaseUpdatedListener = @Sendable (OpenIapPurchase) -> Void

@available(iOS 15.0, macOS 14.0, *)
public typealias PurchaseErrorListener = @Sendable (OpenIapError) -> Void

@available(iOS 15.0, macOS 14.0, *)
public typealias PromotedProductListener = @Sendable (String) -> Void

// MARK: - Protocol

@available(iOS 15.0, macOS 14.0, *)
public protocol OpenIapModuleProtocol {
    // Connection Management
    func initConnection() async throws -> Bool
    func endConnection() async throws -> Bool
    
    // Product Management
    func fetchProducts(_ params: OpenIapProductRequest) async throws -> [OpenIapProduct]
    func getAvailablePurchases(_ options: OpenIapGetAvailablePurchasesProps?) async throws -> [OpenIapPurchase]
    
    // Purchase Operations
    func requestPurchase(_ props: OpenIapRequestPurchaseProps) async throws -> OpenIapPurchase
    
    // Transaction Management
    func finishTransaction(transactionIdentifier: String) async throws -> Bool
    func getPendingTransactionsIOS() async throws -> [OpenIapPurchase]
    func clearTransactionIOS() async throws
    func isTransactionVerifiedIOS(sku: String) async -> Bool
    
    // Validation
    func getReceiptDataIOS() async throws -> String?
    func getTransactionJwsIOS(sku: String) async throws -> String?
    func validateReceiptIOS(_ props: OpenIapReceiptValidationProps) async throws -> OpenIapReceiptValidationResult
    
    // Store Information
    func getStorefrontIOS() async throws -> String
    @available(iOS 16.0, macOS 14.0, *)
    func getAppTransactionIOS() async throws -> OpenIapAppTransaction?
    
    // Subscription Management
    func isEligibleForIntroOfferIOS(groupID: String) async -> Bool
    func subscriptionStatusIOS(sku: String) async throws -> [OpenIapSubscriptionStatus]?
    func currentEntitlementIOS(sku: String) async throws -> OpenIapPurchase?
    func latestTransactionIOS(sku: String) async throws -> OpenIapPurchase?
    
    // Refunds (iOS 15+)
    func beginRefundRequestIOS(sku: String) async throws -> String?
    
    // Promoted Products
    func getPromotedProductIOS() async throws -> OpenIapPromotedProduct?
    func requestPurchaseOnPromotedProductIOS() async throws
    
    // Legacy/Compatibility
    func syncIOS() async throws -> Bool
    func presentCodeRedemptionSheetIOS() async throws -> Bool
    func showManageSubscriptionsIOS() async throws -> [[String: Any?]]
}
