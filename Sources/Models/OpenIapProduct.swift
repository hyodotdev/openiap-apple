import Foundation
import StoreKit

/// Product type for categorizing products
/// Maps to literal strings: "inapp", "subs"
public enum OpenIapProductType: String, Codable {
    case inapp = "inapp"
    case subs = "subs"
}

public struct OpenIapProduct: Codable, Equatable {
    // MARK: - ProductCommon fields
    public let id: String
    public let title: String
    public let description: String
    public let type: String  // "inapp" or "subs" for Android compatibility
    public let displayName: String?
    public let displayPrice: String
    public let currency: String
    public let price: Double?
    public let debugDescription: String?
    public let platform: String  // Always "ios"
    
    // MARK: - ProductIOS specific fields
    public let displayNameIOS: String
    public let isFamilyShareableIOS: Bool
    public let jsonRepresentationIOS: String
    public let subscriptionInfoIOS: SubscriptionInfo?
    public let typeIOS: OpenIapProductTypeIOS  // Detailed iOS product type
    
    // MARK: - ProductSubscriptionIOS specific fields (when type == "subs")
    public let discountsIOS: [Discount]?
    public let introductoryPriceIOS: String?
    public let introductoryPriceAsAmountIOS: String?
    public let introductoryPricePaymentModeIOS: String?  // PaymentMode as String
    public let introductoryPriceNumberOfPeriodsIOS: String?
    public let introductoryPriceSubscriptionPeriodIOS: String?  // SubscriptionPeriodIOS as String
    public let subscriptionPeriodNumberIOS: String?
    public let subscriptionPeriodUnitIOS: String?  // SubscriptionPeriodIOS as String

    // Discount structure for ProductSubscriptionIOS
    public struct Discount: Codable, Equatable {
        /// Discount identifier
        public let identifier: String
        
        /// Discount type (introductory, subscription)
        public let type: String
        
        /// Number of billing periods
        public let numberOfPeriods: Int
        
        /// Formatted discount price
        public let price: String
        
        /// Raw discount price value
        public let priceAmount: Double
        
        /// Payment mode (payAsYouGo, payUpFront, freeTrial)
        public let paymentMode: String
        
        /// Subscription period for discount
        public let subscriptionPeriod: String
    }
    
    // SubscriptionInfo matching OpenIAP spec
    public struct SubscriptionInfo: Codable, Equatable {
        public let introductoryOffer: SubscriptionOffer?
        public let promotionalOffers: [SubscriptionOffer]?
        public let subscriptionGroupId: String
        public let subscriptionPeriod: SubscriptionPeriod
    }
    
    public struct SubscriptionOffer: Codable, Equatable {
        public let displayPrice: String
        public let id: String
        public let paymentMode: PaymentMode
        public let period: SubscriptionPeriod
        public let periodCount: Int
        public let price: Double
        public let type: OfferType
        
        public enum PaymentMode: String, Codable, Equatable {
            case unknown = ""
            case freeTrial = "FREETRIAL"
            case payAsYouGo = "PAYASYOUGO"
            case payUpFront = "PAYUPFRONT"
        }
        
        public enum OfferType: String, Codable, Equatable {
            case introductory = "introductory"
            case promotional = "promotional"
        }
    }
    
    public struct SubscriptionPeriod: Codable, Equatable {
        public let unit: PeriodUnit
        public let value: Int
        
        public enum PeriodUnit: String, Codable, Equatable {
            case unknown = ""
            case day = "DAY"
            case week = "WEEK"
            case month = "MONTH"
            case year = "YEAR"
        }
    }
    
    /// Get the type as ProductType enum
    public var productType: OpenIapProductType {
        return OpenIapProductType(rawValue: type) ?? .inapp
    }
}

// MARK: - iOS Product Type Enum (Detailed)
public enum OpenIapProductTypeIOS: String, Codable, CaseIterable {
    case consumable
    case nonConsumable
    case autoRenewableSubscription
    case nonRenewingSubscription
    
    public var isSubs: Bool {
        switch self {
        case .autoRenewableSubscription:
            return true
        case .consumable, .nonConsumable, .nonRenewingSubscription:
            return false
        }
    }
    
    // Convert to common type for Android compatibility
    public var commonType: String {
        switch self {
        case .autoRenewableSubscription:
            return "subs"
        case .consumable, .nonConsumable, .nonRenewingSubscription:
            return "inapp"
        }
    }
}

// Backward compatibility aliases
public typealias ProductType = OpenIapProductType
public typealias ProductTypeIOS = OpenIapProductTypeIOS


@available(iOS 15.0, macOS 12.0, *)
extension OpenIapProduct {
    init(from product: Product) async {
        
        // Core ProductCommon properties
        self.id = product.id
        self.title = product.displayName
        self.description = product.description
        self.displayName = product.displayName
        self.displayPrice = product.displayPrice
        self.currency = product.priceFormatStyle.currencyCode
        self.price = NSDecimalNumber(decimal: product.price).doubleValue
        self.debugDescription = nil
        self.platform = "ios"
        
        // iOS-specific required fields
        self.displayNameIOS = product.displayName
        self.isFamilyShareableIOS = product.isFamilyShareable
        self.jsonRepresentationIOS = String(data: product.jsonRepresentation, encoding: .utf8) ?? ""
        
        // Map StoreKit type to cross-platform compatible string: "inapp" | "subs"
        // and set detailed iOS product type
        switch product.type {
        case .consumable:
            self.type = "inapp"
            self.typeIOS = .consumable
        case .nonConsumable:
            self.type = "inapp"
            self.typeIOS = .nonConsumable
        case .autoRenewable:
            self.type = "subs"
            self.typeIOS = .autoRenewableSubscription
        case .nonRenewable:
            self.type = "subs"
            self.typeIOS = .nonRenewingSubscription
        default:
            self.type = "inapp"  // fallback to inapp
            self.typeIOS = .consumable
        }
        
        // Handle subscription info and ProductSubscriptionIOS fields
        if let subscription = product.subscription {
            var introOffer: SubscriptionOffer? = nil
            
            if let intro = subscription.introductoryOffer {
                introOffer = SubscriptionOffer(
                    displayPrice: intro.displayPrice,
                    id: intro.id ?? "",
                    paymentMode: intro.paymentMode.toOpenIapPaymentMode(),
                    period: SubscriptionPeriod(
                        unit: intro.period.unit.toOpenIapPeriodUnit(),
                        value: intro.period.value
                    ),
                    periodCount: intro.periodCount,
                    price: NSDecimalNumber(decimal: intro.price).doubleValue,
                    type: .introductory
                )
            }
            
            let promoOffers = subscription.promotionalOffers.map { offer in
                SubscriptionOffer(
                    displayPrice: offer.displayPrice,
                    id: offer.id ?? "",
                    paymentMode: offer.paymentMode.toOpenIapPaymentMode(),
                    period: SubscriptionPeriod(
                        unit: offer.period.unit.toOpenIapPeriodUnit(),
                        value: offer.period.value
                    ),
                    periodCount: offer.periodCount,
                    price: NSDecimalNumber(decimal: offer.price).doubleValue,
                    type: .promotional
                )
            }
            
            let subInfo = SubscriptionInfo(
                introductoryOffer: introOffer,
                promotionalOffers: promoOffers.isEmpty ? nil : promoOffers,
                subscriptionGroupId: subscription.subscriptionGroupID,
                subscriptionPeriod: SubscriptionPeriod(
                    unit: subscription.subscriptionPeriod.unit.toOpenIapPeriodUnit(),
                    value: subscription.subscriptionPeriod.value
                )
            )
            
            self.subscriptionInfoIOS = subInfo
            
            // ProductSubscriptionIOS specific fields
            if let intro = subscription.introductoryOffer {
                self.introductoryPriceIOS = intro.displayPrice
                self.introductoryPriceAsAmountIOS = String(NSDecimalNumber(decimal: intro.price).doubleValue)
                self.introductoryPricePaymentModeIOS = intro.paymentMode.toOpenIapPaymentMode().rawValue
                self.introductoryPriceNumberOfPeriodsIOS = String(intro.periodCount)
                self.introductoryPriceSubscriptionPeriodIOS = intro.period.unit.toOpenIapPeriodUnit().rawValue
            } else {
                self.introductoryPriceIOS = nil
                self.introductoryPriceAsAmountIOS = nil
                self.introductoryPricePaymentModeIOS = nil
                self.introductoryPriceNumberOfPeriodsIOS = nil
                self.introductoryPriceSubscriptionPeriodIOS = nil
            }
            
            self.subscriptionPeriodNumberIOS = String(subscription.subscriptionPeriod.value)
            self.subscriptionPeriodUnitIOS = subscription.subscriptionPeriod.unit.toOpenIapPeriodUnit().rawValue
            
            // Build discounts array from all offers
            var discounts: [Discount] = []
            
            if let intro = subscription.introductoryOffer {
                discounts.append(Discount(
                    identifier: intro.id ?? "",
                    type: "introductory",
                    numberOfPeriods: intro.periodCount,
                    price: intro.displayPrice,
                    priceAmount: NSDecimalNumber(decimal: intro.price).doubleValue,
                    paymentMode: intro.paymentMode.toOpenIapPaymentMode().rawValue,
                    subscriptionPeriod: intro.period.toISO8601Period()
                ))
            }
            
            for offer in subscription.promotionalOffers {
                discounts.append(Discount(
                    identifier: offer.id ?? "",
                    type: "promotional",
                    numberOfPeriods: offer.periodCount,
                    price: offer.displayPrice,
                    priceAmount: NSDecimalNumber(decimal: offer.price).doubleValue,
                    paymentMode: offer.paymentMode.toOpenIapPaymentMode().rawValue,
                    subscriptionPeriod: offer.period.toISO8601Period()
                ))
            }
            
            self.discountsIOS = discounts.isEmpty ? nil : discounts
        } else {
            self.subscriptionInfoIOS = nil
            self.discountsIOS = nil
            self.introductoryPriceIOS = nil
            self.introductoryPriceAsAmountIOS = nil
            self.introductoryPricePaymentModeIOS = nil
            self.introductoryPriceNumberOfPeriodsIOS = nil
            self.introductoryPriceSubscriptionPeriodIOS = nil
            self.subscriptionPeriodNumberIOS = nil
            self.subscriptionPeriodUnitIOS = nil
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
extension Product.SubscriptionPeriod.Unit {
    func toOpenIapPeriodUnit() -> OpenIapProduct.SubscriptionPeriod.PeriodUnit {
        switch self {
        case .day:
            return .day
        case .week:
            return .week
        case .month:
            return .month
        case .year:
            return .year
        @unknown default:
            return .unknown
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
extension Product.SubscriptionOffer.PaymentMode {
    func toOpenIapPaymentMode() -> OpenIapProduct.SubscriptionOffer.PaymentMode {
        switch self {
        case .payAsYouGo:
            return .payAsYouGo
        case .payUpFront:
            return .payUpFront
        case .freeTrial:
            return .freeTrial
        default:
            return .unknown
        }
    }
}

// MARK: - ISO 8601 Period Conversion

@available(iOS 15.0, macOS 12.0, *)
extension Product.SubscriptionPeriod {
    /// Convert to ISO 8601 duration format (P1M, P3M, P1Y, etc.)
    func toISO8601Period() -> String {
        switch unit {
        case .day:
            return "P\(value)D"
        case .week:
            return "P\(value)W"
        case .month:
            return "P\(value)M"
        case .year:
            return "P\(value)Y"
        @unknown default:
            return "P0D"
        }
    }
}

