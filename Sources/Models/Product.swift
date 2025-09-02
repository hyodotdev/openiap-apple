import Foundation
import StoreKit

public struct IapProduct: Codable, Equatable {
    public let productId: String
    public let productType: ProductType
    public let localizedTitle: String
    public let localizedDescription: String
    public let price: Decimal
    public let localizedPrice: String
    public let currencyCode: String?
    public let countryCode: String?
    public let subscriptionPeriod: SubscriptionPeriod?
    public let introductoryPrice: IntroductoryOffer?
    public let discounts: [Discount]?
    
    // Computed property for convenience
    public var formattedPrice: String {
        return localizedPrice
    }
    
    public enum ProductType: String, Codable {
        case consumable
        case nonConsumable
        case autoRenewableSubscription
        case nonRenewingSubscription
    }
    
    public struct SubscriptionPeriod: Codable, Equatable {
        public let unit: PeriodUnit
        public let value: Int
        
        public enum PeriodUnit: String, Codable {
            case day
            case week
            case month
            case year
        }
    }
    
    public struct IntroductoryOffer: Codable, Equatable {
        public let price: Decimal
        public let localizedPrice: String
        public let period: SubscriptionPeriod
        public let numberOfPeriods: Int
        public let paymentMode: PaymentMode
        
        public enum PaymentMode: String, Codable {
            case payAsYouGo
            case payUpFront
            case freeTrial
        }
    }
    
    public struct Discount: Codable, Equatable {
        public let identifier: String
        public let type: DiscountType
        public let price: Decimal
        public let localizedPrice: String
        public let period: SubscriptionPeriod?
        public let numberOfPeriods: Int
        
        public enum DiscountType: String, Codable {
            case introductory
            case subscription
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
extension IapProduct {
    init(from product: Product) async {
        self.productId = product.id
        self.localizedTitle = product.displayName
        self.localizedDescription = product.description
        self.price = product.price
        self.localizedPrice = product.displayPrice
        self.currencyCode = product.priceFormatStyle.currencyCode
        self.countryCode = nil
        
        switch product.type {
        case .consumable:
            self.productType = .consumable
        case .nonConsumable:
            self.productType = .nonConsumable
        case .autoRenewable:
            self.productType = .autoRenewableSubscription
        case .nonRenewable:
            self.productType = .nonRenewingSubscription
        default:
            self.productType = .nonConsumable
        }
        
        if let subscription = product.subscription {
            self.subscriptionPeriod = SubscriptionPeriod(
                unit: subscription.subscriptionPeriod.unit.toPeriodUnit(),
                value: subscription.subscriptionPeriod.value
            )
            
            if let introOffer = subscription.introductoryOffer {
                self.introductoryPrice = IntroductoryOffer(
                    price: introOffer.price,
                    localizedPrice: introOffer.displayPrice,
                    period: SubscriptionPeriod(
                        unit: introOffer.period.unit.toPeriodUnit(),
                        value: introOffer.period.value
                    ),
                    numberOfPeriods: introOffer.periodCount,
                    paymentMode: introOffer.paymentMode.toPaymentMode()
                )
            } else {
                self.introductoryPrice = nil
            }
            
            self.discounts = subscription.promotionalOffers.map { offer in
                Discount(
                    identifier: offer.id ?? "",
                    type: .subscription,
                    price: offer.price,
                    localizedPrice: offer.displayPrice,
                    period: SubscriptionPeriod(
                        unit: offer.period.unit.toPeriodUnit(),
                        value: offer.period.value
                    ),
                    numberOfPeriods: offer.periodCount
                )
            }
        } else {
            self.subscriptionPeriod = nil
            self.introductoryPrice = nil
            self.discounts = nil
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
extension Product.SubscriptionPeriod.Unit {
    func toPeriodUnit() -> IapProduct.SubscriptionPeriod.PeriodUnit {
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
            return .month
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
extension Product.SubscriptionOffer.PaymentMode {
    func toPaymentMode() -> IapProduct.IntroductoryOffer.PaymentMode {
        switch self {
        case .payAsYouGo:
            return .payAsYouGo
        case .payUpFront:
            return .payUpFront
        case .freeTrial:
            return .freeTrial
        default:
            return .payAsYouGo
        }
    }
}