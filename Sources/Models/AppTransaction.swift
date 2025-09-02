import Foundation
import StoreKit

@available(iOS 16.0, macOS 13.0, *)
public struct IapAppTransaction: Codable {
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
extension IapAppTransaction {
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

public struct IapSubscriptionStatus: Codable {
    public let state: String
    public let renewalInfo: IapRenewalInfo?
}

public struct IapRenewalInfo: Codable {
    public let autoRenewStatus: Bool
    public let autoRenewPreference: String?
    public let expirationReason: Int?
    public let deviceVerification: String?
    public let currentProductID: String?
    public let gracePeriodExpirationDate: Date?
}

public struct IapValidationResult: Codable {
    public let isValid: Bool
    public let receiptData: String
    public let jwsRepresentation: String
    public let latestTransaction: IapPurchase?
}

// MARK: - Product and Transaction serialization models

public struct IapProductData: Codable {
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

public struct IapTransactionData: Codable {
    public let id: String
    public let productId: String
    public let transactionId: String
    public let transactionDate: Double
    public let transactionReceipt: String
    public let platform: String
    public let quantityIOS: Int
    public let originalTransactionDateIOS: Double
    public let originalTransactionIdentifierIOS: String
    public let appAccountToken: String?
    public let productTypeIOS: String
    public let isUpgradedIOS: Bool
    public let ownershipTypeIOS: String
    public let revocationDateIOS: Double?
    public let revocationReasonIOS: Int?
    public let expirationDateIOS: Double?
    public let jwsRepresentationIOS: String?
    public let purchaseToken: String?
    public let environmentIOS: String?
    
    public init(id: String, productId: String, transactionId: String, transactionDate: Double, transactionReceipt: String, platform: String = "ios", quantityIOS: Int, originalTransactionDateIOS: Double, originalTransactionIdentifierIOS: String, appAccountToken: String?, productTypeIOS: String, isUpgradedIOS: Bool, ownershipTypeIOS: String, revocationDateIOS: Double?, revocationReasonIOS: Int?, expirationDateIOS: Double?, jwsRepresentationIOS: String?, purchaseToken: String?, environmentIOS: String?) {
        self.id = id
        self.productId = productId
        self.transactionId = transactionId
        self.transactionDate = transactionDate
        self.transactionReceipt = transactionReceipt
        self.platform = platform
        self.quantityIOS = quantityIOS
        self.originalTransactionDateIOS = originalTransactionDateIOS
        self.originalTransactionIdentifierIOS = originalTransactionIdentifierIOS
        self.appAccountToken = appAccountToken
        self.productTypeIOS = productTypeIOS
        self.isUpgradedIOS = isUpgradedIOS
        self.ownershipTypeIOS = ownershipTypeIOS
        self.revocationDateIOS = revocationDateIOS
        self.revocationReasonIOS = revocationReasonIOS
        self.expirationDateIOS = expirationDateIOS
        self.jwsRepresentationIOS = jwsRepresentationIOS
        self.purchaseToken = purchaseToken
        self.environmentIOS = environmentIOS
    }
}

public struct IapPromotedProduct: Codable {
    public let productIdentifier: String
    public let localizedTitle: String
    public let localizedDescription: String
    public let price: Double
    public let priceLocale: IapPriceLocale
}

public struct IapPriceLocale: Codable {
    public let currencyCode: String
    public let currencySymbol: String
    public let countryCode: String
}

public struct IapReceiptValidation: Codable {
    public let isValid: Bool
    public let receiptData: String
    public let jwsRepresentation: String
    public let latestTransaction: IapTransactionData?
}