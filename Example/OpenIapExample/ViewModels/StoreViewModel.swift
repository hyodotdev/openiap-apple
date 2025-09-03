import SwiftUI
import OpenIAP

@MainActor
@available(iOS 15.0, *)
class StoreViewModel: ObservableObject {
    @Published var products: [OpenIapProduct] = []
    @Published var purchases: [OpenIapPurchase] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var purchasingProductIds: Set<String> = []
    @Published var showPurchaseSuccess = false
    @Published var lastPurchasedProduct: OpenIapProduct?
    @Published var isConnectionInitialized = false
    
    private let iapModule = OpenIapModule.shared
    
    init() {
        print("🚀 StoreViewModel Initializing...")
        setupStoreKit()
    }
    
    deinit {
        print("🧹 StoreViewModel Deinitializing - cleaning up listeners...")
        iapModule.removeAllPurchaseUpdatedListeners()
        iapModule.removeAllPurchaseErrorListeners()
    }
    
    private func setupStoreKit() {
        Task {
            do {
                _ = try await iapModule.initConnection()
                
                // Setup purchase event listeners
                setupPurchaseListeners()
                
                await MainActor.run {
                    isConnectionInitialized = true
                }
                print("🔧 StoreKit initialized and purchase listeners setup")
            } catch {
                showErrorMessage("Failed to initialize StoreKit: \(error.localizedDescription)")
            }
        }
    }
    
    private func setupPurchaseListeners() {
        // Add purchase updated listener
        iapModule.addPurchaseUpdatedListener { [weak self] purchase in
            Task { @MainActor in
                print("🎯 Purchase Updated Event Received:")
                print("  • Product ID: \(purchase.id)")
                print("  • Transaction ID: \(purchase.transactionId)")
                print("  • Purchase State: \(purchase.purchaseState)")
                print("  • Purchase Time: \(purchase.purchaseTime)")
                print("  • Is Auto Renewing: \(purchase.isAutoRenewing)")
                print("  • Acknowledgement State: \(purchase.acknowledgementState)")
                
                self?.handlePurchaseUpdated(purchase)
            }
        }
        
        // Add purchase error listener
        iapModule.addPurchaseErrorListener { [weak self] error in
            Task { @MainActor in
                print("💥 Purchase Error Event Received:")
                print("  • Error: \(error)")
                print("  • Description: \(error.localizedDescription)")
                
                self?.handlePurchaseError(error, productId: nil)
            }
        }
        
        print("👂 Purchase event listeners configured")
    }
    
    private func handlePurchaseUpdated(_ purchase: OpenIapPurchase) {
        print("🔄 Processing purchase update for: \(purchase.id)")
        
        switch purchase.purchaseState {
        case .purchased:
            handlePurchaseSuccess(purchase.id)
        case .failed:
            handlePurchaseError(OpenIapError.purchaseFailed(reason: "Purchase failed"), productId: purchase.id)
        case .pending:
            print("⏳ Purchase pending for: \(purchase.id)")
        case .restored:
            print("♻️ Purchase restored for: \(purchase.id)")
            handlePurchaseSuccess(purchase.id)
        case .deferred:
            print("⏸️ Purchase deferred for: \(purchase.id)")
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
            print("🎉 Purchase success dialog will show for: \(purchasedProduct.localizedTitle)")
        }
        
        // Reload purchases to show the new purchase
        Task {
            await loadPurchases()
        }
    }
    
    private func handlePurchaseError(_ error: Error, productId: String?) {
        print("❌ Purchase Error Handler Called:")
        print("  • Error Type: \(type(of: error))")
        print("  • Error Description: \(error.localizedDescription)")
        print("  • Product ID: \(productId ?? "N/A")")
        
        // Remove loading state for this product if available
        if let productId = productId {
            print("  • Removing loading state for product: \(productId)")
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
    
    func purchaseProduct(_ product: OpenIapProduct) {
        // Start loading state for this specific product
        purchasingProductIds.insert(product.id)
        
        print("🛒 Purchase Process Started:")
        print("  • Product ID: \(product.id)")
        print("  • Product Title: \(product.localizedTitle)")
        print("  • Product Price: \(product.localizedPrice)")
        print("  • Product Type: \(product.productType.rawValue)")
        
        Task {
            do {
                print("🔄 Calling requestPurchase API...")
                let transactionData = try await iapModule.requestPurchase(
                    sku: product.id,
                    andDangerouslyFinishTransactionAutomatically: true,
                    appAccountToken: nil,
                    quantity: 1,
                    discountOffer: nil
                )
                
                print("📦 Purchase API Response:")
                if let transaction = transactionData {
                    print("  • Transaction received: \(transaction.transactionId)")
                    print("  • Product ID: \(transaction.id)")
                    print("  • Purchase State: \(transaction.purchaseState)")
                    print("✅ Purchase successful via API: \(product.localizedTitle)")
                    await MainActor.run {
                        handlePurchaseSuccess(product.id)
                    }
                } else {
                    print("  • No transaction data received")
                    print("❌ Purchase failed: No transaction data")
                    await MainActor.run {
                        handlePurchaseError(OpenIapError.purchaseFailed(reason: "No transaction data received"), productId: product.id)
                    }
                }
            } catch {
                print("💥 Purchase API Error:")
                print("  • Error Type: \(type(of: error))")
                print("  • Error Description: \(error.localizedDescription)")
                print("  • Product ID: \(product.id)")
                await MainActor.run {
                    handlePurchaseError(error, productId: product.id)
                }
            }
        }
    }
    
    func finishPurchase(_ purchase: OpenIapPurchase) async {
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
