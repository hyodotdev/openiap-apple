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
    private var purchaseSubscription: Subscription?
    private var errorSubscription: Subscription?
    
    init() {
        print("🚀 StoreViewModel Initializing...")
        setupStoreKit()
    }
    
    deinit {
        print("🧹 StoreViewModel Deinitializing - cleaning up listeners...")
        // Note: Listeners will be automatically cleaned up when the module is deallocated
        // We cannot call @MainActor methods from deinit
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
        purchaseSubscription = iapModule.purchaseUpdatedListener { [weak self] purchase in
            Task { @MainActor in
                print("🎯 Purchase Updated Event Received:")
                print("  • Product ID: \(purchase.id)")
                print("  • Transaction ID: \(purchase.id)")
                print("  • Transaction Date: \(purchase.transactionDate)")
                print("  • Purchase Time: \(purchase.transactionDate)")
                print("  • Product ID from Purchase: \(purchase.productId)")
                
                self?.handlePurchaseUpdated(purchase)
            }
        }
        
        // Add purchase error listener
        errorSubscription = iapModule.purchaseErrorListener { [weak self] error in
            Task { @MainActor in
                print("💥 Purchase Error Event Received:")
                print("  • Error Code: \(error.code)")
                print("  • Message: \(error.message)")
                print("  • Product ID: \(error.productId ?? "N/A")")
                
                self?.handlePurchaseError(error, productId: error.productId)
            }
        }
        
        print("👂 Purchase event listeners configured")
    }
    
    private func handlePurchaseUpdated(_ purchase: OpenIapPurchase) {
        print("🔄 Processing purchase update for: \(purchase.id)")
        
        // Since we receive this through the success event, treat as successful
        handlePurchaseSuccess(purchase.productId)
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
            
            // IMPORTANT: Server-side receipt validation should be done here
            Task {
                await validateAndFinishPurchase(productId: productId)
            }
        }
        
        // Reload purchases to show the new purchase
        Task {
            await loadPurchases()
        }
    }
    
    private func validateAndFinishPurchase(productId: String) async {
        print("📋 Starting receipt validation for product: \(productId)")
        
        // STEP 1: Get the receipt data
        do {
            guard let receiptData = try await iapModule.getReceiptDataIOS() else {
                print("⚠️ No receipt data available")
                return
            }
            print("📦 Receipt data obtained, length: \(receiptData.count) bytes")
            
            // STEP 2: Validate receipt with your own server
            // IMPORTANT: Never validate receipts client-side in production!
            // This is just an example. In production, send the receipt to your server.
            /*
            Example server validation:
            
            let validated = await validateWithServer(receiptData: receiptData, productId: productId)
            
            func validateWithServer(receiptData: String, productId: String) async -> Bool {
                // Send receipt to your backend server
                let url = URL(string: "https://your-server.com/api/validate-receipt")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body = [
                    "receipt": receiptData,
                    "productId": productId,
                    "platform": "ios"
                ]
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                // Parse response and return validation result
                return true // or false based on server response
            }
            */
            
            // STEP 3: After successful validation, finish the transaction
            // Find the transaction ID for this product
            let purchases = try await iapModule.getAvailablePurchases(PurchaseOptions())
            if let purchase = purchases.first(where: { $0.productId == productId }) {
                print("🔍 Found purchase to finish: \(purchase.id)")
                
                // Check if it's a subscription or consumable
                let isSubscription = products.first(where: { $0.id == productId })?.typeIOS.isSubs ?? false
                
                if isSubscription {
                    print("📅 Subscription transaction - auto-renewed, no need to finish manually")
                    // Subscriptions are automatically finished by StoreKit
                    // You should still validate the receipt on your server
                } else {
                    // For consumables and non-consumables, finish the transaction
                    let finished = try await iapModule.finishTransaction(transactionIdentifier: purchase.id)
                    if finished {
                        print("✅ Transaction finished successfully: \(purchase.id)")
                    } else {
                        print("⚠️ Transaction could not be finished: \(purchase.id)")
                    }
                }
            }
            
        } catch {
            print("❌ Receipt validation/finish error: \(error)")
            showErrorMessage("Failed to validate receipt: \(error.localizedDescription)")
        }
    }
    
    private func handlePurchaseError(_ error: PurchaseError, productId: String?) {
        print("❌ Purchase Error Handler Called:")
        print("  • Error Code: \(error.code)")
        print("  • Error Message: \(error.message)")
        print("  • Product ID: \(error.productId ?? productId ?? "N/A")")
        
        // Remove loading state for this product if available
        let targetProductId = error.productId ?? productId
        if let targetProductId = targetProductId {
            print("  • Removing loading state for product: \(targetProductId)")
            purchasingProductIds.remove(targetProductId)
        }
        
        // Show error message to user
        showErrorMessage(error.message)
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
            let productIds: [String] = [
                "dev.hyo.martie.10bulbs",
                "dev.hyo.martie.30bulbs",
                "dev.hyo.martie.premium"
            ]
            
            let request = ProductRequest(skus: productIds, type: .all)
            products = try await iapModule.fetchProducts(request)
            
            if products.isEmpty {
                showErrorMessage("No products found. Please check your App Store Connect configuration for IDs: \(productIds.joined(separator: ", "))")
            }
        } catch {
            showErrorMessage("Failed to load products: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    func loadPurchases() async {
        // Ensure connection is initialized first
        if !isConnectionInitialized {
            do {
                _ = try await iapModule.initConnection()
                isConnectionInitialized = true
                print("✅ Connection initialized for purchases")
            } catch {
                showErrorMessage("Failed to initialize connection: \(error.localizedDescription)")
                isLoading = false
                return
            }
        }
        
        isLoading = true
        do {
            // Only load ACTIVE purchases (not all history)
            let options = PurchaseOptions(onlyIncludeActiveItemsIOS: true)
            let activePurchases = try await iapModule.getAvailablePurchases(options)
            purchases = activePurchases.sorted { $0.transactionDate > $1.transactionDate }
            print("📦 Loaded \(purchases.count) active purchases")
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
        print("  • Product Title: \(product.title)")
        print("  • Product Price: \(product.displayPrice)")
        print("  • Product Type: \(product.type) (iOS: \(product.typeIOS.rawValue))")
        
        // Check if this is a re-subscription
        let wasPreviouslySubscribed = purchases.contains { $0.productId == product.id }
        if wasPreviouslySubscribed {
            print("  ⚠️ Re-subscribing to previously cancelled subscription")
            print("  ⏳ This may take 10-30 seconds in Sandbox environment")
        }
        
        Task {
            do {
                print("🔄 Calling requestPurchase API...")
                let props = RequestPurchaseProps(
                    sku: product.id,
                    andDangerouslyFinishTransactionAutomatically: true,
                    appAccountToken: nil,
                    quantity: 1
                )
                let transaction = try await iapModule.requestPurchase(props)
                
                print("📦 Purchase API Response:")
                print("  • Transaction received: \(transaction.id)")
                print("  • Product ID: \(transaction.productId)")
                print("  • Transaction Date: \(transaction.transactionDate)")
                print("✅ Purchase successful via API: \(product.title)")
                await MainActor.run {
                    handlePurchaseSuccess(product.id)
                }
            } catch {
                print("💥 Purchase API Error:")
                print("  • Error Type: \(type(of: error))")
                print("  • Error Description: \(error.localizedDescription)")
                print("  • Product ID: \(product.id)")
                await MainActor.run {
                    let purchaseError: PurchaseError
                    if let openIapError = error as? OpenIapError {
                        purchaseError = PurchaseError(from: openIapError, productId: product.id)
                    } else {
                        purchaseError = PurchaseError(from: error, productId: product.id)
                    }
                    handlePurchaseError(purchaseError, productId: product.id)
                }
            }
        }
    }
    
    func finishPurchase(_ purchase: OpenIapPurchase) async {
        do {
            // In iOS, there's no distinction between consumable and non-consumable for finishing transactions
            // The product type is determined by App Store Connect configuration
            _ = try await iapModule.finishTransaction(transactionIdentifier: purchase.id)
            if let index = purchases.firstIndex(where: { $0.id == purchase.id }) {
                purchases.remove(at: index)
            }
        } catch {
            showErrorMessage(error.localizedDescription)
        }
    }
    
    func restorePurchases() async {
        // Ensure connection is initialized first
        if !isConnectionInitialized {
            do {
                _ = try await iapModule.initConnection()
                isConnectionInitialized = true
                print("✅ Connection initialized for restore")
            } catch {
                showErrorMessage("Failed to initialize connection: \(error.localizedDescription)")
                return
            }
        }
        
        do {
            // Only restore ACTIVE items, not entire history
            let options = PurchaseOptions(onlyIncludeActiveItemsIOS: true)
            let restored = try await iapModule.getAvailablePurchases(options)
            purchases = restored.sorted { $0.transactionDate > $1.transactionDate }
            print("📦 Restored \(purchases.count) active purchases")
            
            if purchases.isEmpty {
                showErrorMessage("No active purchases to restore")
            } else {
                showErrorMessage("Restored \(purchases.count) active purchase(s)")
            }
        } catch {
            showErrorMessage(error.localizedDescription)
        }
    }
    
    func manageSubscriptions() async {
        print("🔧 Opening subscription management...")
        
        // Ensure connection is initialized first
        if !isConnectionInitialized {
            do {
                _ = try await iapModule.initConnection()
                isConnectionInitialized = true
                print("✅ Connection initialized for manage subscriptions")
            } catch {
                showErrorMessage("Failed to initialize connection: \(error.localizedDescription)")
                return
            }
        }
        
        do {
            let shown = try await iapModule.showManageSubscriptionsIOS()
            if shown {
                print("✅ Subscription management sheet presented")
                
                // Wait a moment and then refresh purchases to check for changes
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await loadPurchases()
                await loadProducts()
            } else {
                print("⚠️ Could not show subscription management")
                showErrorMessage("Unable to open subscription settings")
            }
        } catch {
            print("❌ Error showing subscription management: \(error)")
            showErrorMessage("Failed to open subscription settings: \(error.localizedDescription)")
        }
    }
    
    func presentOfferCodeRedemption() async {
        // This functionality is not available in the new API
        showErrorMessage("Offer code redemption not available in this version")
    }
    
    // MARK: - Debug/Testing Methods
    
    #if DEBUG
    /// Clear all transactions for testing (Sandbox only)
    func clearAllTransactions() async {
        print("🧪 Clearing all transactions for testing...")
        
        // Clear local purchase cache
        purchases.removeAll()
        
        // Also clear the products to force reload
        products.removeAll()
        
        // Reinitialize connection to clear StoreKit cache
        isConnectionInitialized = false
        do {
            _ = try await iapModule.initConnection()
            isConnectionInitialized = true
            print("✅ Connection reinitialized")
        } catch {
            print("❌ Failed to reinitialize: \(error)")
        }
        
        // Force refresh from StoreKit
        await loadProducts()
        await loadPurchases()
        
        print("✅ Local transaction cache cleared and reloaded.")
    }
    
    /// Sync subscription status with StoreKit
    func syncSubscriptions() async {
        print("🔄 Syncing subscription status...")
        
        // Ensure connection
        if !isConnectionInitialized {
            do {
                _ = try await iapModule.initConnection()
                isConnectionInitialized = true
            } catch {
                showErrorMessage("Failed to initialize connection: \(error.localizedDescription)")
                return
            }
        }
        
        // Try to sync with StoreKit (may fail on simulator or with network issues)
        do {
            #if targetEnvironment(simulator)
            print("⚠️ Sync may not work properly on simulator")
            showErrorMessage("Sync may not work on simulator. Please test on a real device.")
            #else
            _ = try await iapModule.syncIOS()
            print("✅ Synced with StoreKit")
            #endif
        } catch {
            print("⚠️ Sync failed (this is normal on simulator): \(error)")
            // Continue anyway - just reload what we have
        }
        
        // Always reload purchases to reflect current state
        await loadPurchases()
        await loadProducts()
        
        print("✅ Subscription status refreshed")
    }
    
    /// Finish only unfinished transactions
    func finishUnfinishedTransactions() async {
        print("🔄 Processing unfinished transactions...")
        
        do {
            // Get pending transactions specifically
            let pendingPurchases = try await iapModule.getPendingTransactionsIOS()
            print("📋 Found \(pendingPurchases.count) pending transactions")
            
            for purchase in pendingPurchases {
                do {
                    _ = try await iapModule.finishTransaction(transactionIdentifier: purchase.id)
                    print("✅ Finished pending transaction: \(purchase.id)")
                } catch {
                    print("⚠️ Could not finish transaction \(purchase.id): \(error)")
                }
            }
            
            if pendingPurchases.isEmpty {
                print("✨ No pending transactions to finish")
            }
        } catch {
            print("❌ Error getting pending transactions: \(error)")
        }
        
        // Reload after finishing
        await loadPurchases()
        print("✅ Transaction processing completed")
    }
    
    /// Clear transaction history (for testing)
    func clearTransactionHistory() async {
        print("🗑️ Clearing transaction history...")
        
        do {
            try await iapModule.clearTransactionIOS()
            print("✅ Transaction history cleared")
        } catch {
            print("❌ Failed to clear transactions: \(error)")
        }
        
        // Reload
        await loadPurchases()
    }
    #endif
    
    @MainActor
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}
