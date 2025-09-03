import SwiftUI
import OpenIAP

@MainActor
@available(iOS 15.0, *)
class StoreViewModel: ObservableObject {
    @Published var products: [IapProductData] = []
    @Published var purchases: [IapPurchase] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var purchasingProductIds: Set<String> = []
    @Published var showPurchaseSuccess = false
    @Published var lastPurchasedProduct: IapProductData?
    @Published var isConnectionInitialized = false
    
    private let iapModule = IapModule.shared
    
    init() {
        setupStoreKit()
    }
    
    private func setupStoreKit() {
        Task {
            do {
                _ = try await iapModule.initConnection()
                await MainActor.run {
                    isConnectionInitialized = true
                }
            } catch {
                showErrorMessage("Failed to initialize StoreKit: \(error.localizedDescription)")
            }
        }
    }
    
    private func handlePurchaseSuccess(_ productId: String) {
        print("✅ Purchase successful: \(productId)")
        
        // Remove loading state for this product
        purchasingProductIds.remove(productId)
        
        // Find the purchased product
        if let purchasedProduct = products.first(where: { $0.id == productId }) {
            lastPurchasedProduct = purchasedProduct
            showPurchaseSuccess = true
            print("🎉 Purchase success dialog will show for: \(purchasedProduct.title)")
        }
        
        // Reload purchases to show the new purchase
        Task {
            await loadPurchases()
        }
    }
    
    private func handlePurchaseError(_ error: Error, productId: String?) {
        print("❌ Purchase error: \(error.localizedDescription)")
        
        // Remove loading state for this product if available
        if let productId = productId {
            purchasingProductIds.remove(productId)
        }
        
        // Show error message to user
        showErrorMessage(error.localizedDescription)
    }
    
    func loadProducts() async {
        // Wait for connection to be initialized
        if !isConnectionInitialized {
            do {
                _ = try await iapModule.initConnection()
                await MainActor.run {
                    isConnectionInitialized = true
                }
            } catch {
                showErrorMessage("Failed to initialize connection: \(error.localizedDescription)")
                return
            }
        }
        
        isLoading = true
        do {
            // Real product IDs configured in App Store Connect
            let productIds: Set<String> = [
                "dev.hyo.martie.10bulbs",
                "dev.hyo.martie.30bulbs",
                "dev.hyo.martie.premium"
            ]
            
            products = try await iapModule.fetchProducts(skus: Array(productIds))
            
            if products.isEmpty {
                showErrorMessage("No products found. Please check your App Store Connect configuration for IDs: \(productIds.joined(separator: ", "))")
            }
        } catch {
            showErrorMessage("Failed to load products: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    func loadPurchases() async {
        isLoading = true
        do {
            let purchaseHistory = try await iapModule.getAvailablePurchases(onlyIncludeActiveItems: false)
            purchases = purchaseHistory.sorted { $0.purchaseTime > $1.purchaseTime }
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        isLoading = false
    }
    
    func purchaseProduct(_ product: IapProductData) {
        // Start loading state for this specific product
        purchasingProductIds.insert(product.id)
        
        print("🛒 Starting purchase request for: \(product.title)")
        
        Task {
            do {
                let transactionData = try await iapModule.requestPurchase(
                    sku: product.id,
                    andDangerouslyFinishTransactionAutomatically: true,
                    appAccountToken: nil,
                    quantity: 1,
                    discountOffer: nil
                )
                
                if let _ = transactionData {
                    print("✅ Purchase successful: \(product.title)")
                    await MainActor.run {
                        handlePurchaseSuccess(product.id)
                    }
                } else {
                    print("❌ Purchase failed")
                    await MainActor.run {
                        handlePurchaseError(IapError.purchaseFailed(reason: "Unknown error"), productId: product.id)
                    }
                }
            } catch {
                print("❌ Purchase error: \(error.localizedDescription)")
                await MainActor.run {
                    handlePurchaseError(error, productId: product.id)
                }
            }
        }
    }
    
    func finishPurchase(_ purchase: IapPurchase) async {
        do {
            // In iOS, there's no distinction between consumable and non-consumable for finishing transactions
            // The product type is determined by App Store Connect configuration
            _ = try await iapModule.finishTransaction(transactionIdentifier: purchase.transactionId)
            if let index = purchases.firstIndex(where: { $0.transactionId == purchase.transactionId }) {
                purchases.remove(at: index)
            }
        } catch {
            showErrorMessage(error.localizedDescription)
        }
    }
    
    func restorePurchases() async {
        do {
            let restored = try await iapModule.getAvailablePurchases(onlyIncludeActiveItems: false)
            purchases = restored.sorted { $0.purchaseTime > $1.purchaseTime }
        } catch {
            showErrorMessage(error.localizedDescription)
        }
    }
    
    func presentOfferCodeRedemption() async {
        // This functionality is not available in the new API
        showErrorMessage("Offer code redemption not available in this version")
    }
    
    @MainActor
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}
