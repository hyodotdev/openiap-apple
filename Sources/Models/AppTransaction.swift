import Foundation
import StoreKit

@available(iOS 16.0, macOS 13.0, *)
public struct OpenIapAppTransaction: Codable {
    public let bundleId: String
    public let appVersion: String
    public let originalAppVersion: String
    public let originalPurchaseDate: Date
    public let deviceVerification: String
    public let deviceVerificationNonce: String
    public let environment: String
    public let signedDate: Date
    public let appId: String
    public let appVersionId: String
    public let preorderDate: Date?
    
    // iOS 18.4+ properties
    public let appTransactionId: String?
    public let originalPlatform: String?
}

@available(iOS 16.0, macOS 13.0, *)
extension OpenIapAppTransaction {
    init(from appTransaction: AppTransaction) {
        self.bundleId = appTransaction.bundleID
        self.appVersion = appTransaction.appVersion
        self.originalAppVersion = appTransaction.originalAppVersion
        self.originalPurchaseDate = appTransaction.originalPurchaseDate
        self.deviceVerification = appTransaction.deviceVerification.base64EncodedString()
        self.deviceVerificationNonce = appTransaction.deviceVerificationNonce.uuidString
        self.environment = appTransaction.environment.rawValue
        self.signedDate = appTransaction.signedDate
        self.appId = String(describing: appTransaction.appID)
        self.appVersionId = String(describing: appTransaction.appVersionID)
        self.preorderDate = appTransaction.preorderDate
        
        #if swift(>=6.1)
        if #available(iOS 18.4, *) {
            self.appTransactionId = appTransaction.appTransactionID
            self.originalPlatform = appTransaction.originalPlatform.rawValue
        } else {
            self.appTransactionId = nil
            self.originalPlatform = nil
        }
        #else
        self.appTransactionId = nil
        self.originalPlatform = nil
        #endif
    }
}

public struct OpenIapSubscriptionStatus: Codable {
    public let state: String
    public let renewalInfo: OpenIapRenewalInfo?
}

public struct OpenIapRenewalInfo: Codable {
    public let autoRenewStatus: Bool
    public let autoRenewPreference: String?
    public let expirationReason: Int?
    public let deviceVerification: String?
    public let currentProductID: String?
    public let gracePeriodExpirationDate: Date?
}

public struct OpenIapValidationResult: Codable {
    public let isValid: Bool
    public let receiptData: String
    public let jwsRepresentation: String
    public let latestTransaction: OpenIapPurchase?
}

// MARK: - Product and Transaction serialization models

public struct OpenIapProductData: Codable {
    public let id: String
    public let title: String
    public let description: String
    public let price: Decimal
    public let displayPrice: String
    public let currency: String?
    public let type: String
    public let platform: String
    
    public init(id: String, title: String, description: String, price: Decimal, displayPrice: String, currency: String?, type: String, platform: String = "ios") {
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.displayPrice = displayPrice
        self.currency = currency
        self.type = type
        self.platform = platform
    }
}

// IapTransactionData is deprecated - use OpenIapPurchase instead
// This type has been merged into OpenIapPurchase for better API consistency

public struct OpenIapPromotedProduct: Codable {
    public let productIdentifier: String
    public let localizedTitle: String
    public let localizedDescription: String
    public let price: Double
    public let priceLocale: OpenIapPriceLocale
}

public struct OpenIapPriceLocale: Codable {
    public let currencyCode: String
    public let currencySymbol: String
    public let countryCode: String
}

public struct OpenIapReceiptValidation: Codable {
    public let isValid: Bool
    public let receiptData: String
    public let jwsRepresentation: String
    public let latestTransaction: OpenIapPurchase?
}