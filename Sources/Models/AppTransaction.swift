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

// OpenIapProductData is deprecated - use OpenIapProduct instead
// This type has been merged into OpenIapProduct for better API consistency

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