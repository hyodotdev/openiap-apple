import SwiftUI
import OpenIAP

@available(iOS 15.0, *)
struct PurchaseFlowScreen: View {
    @StateObject private var iapStore = OpenIapStore()
    
    // UI State
    @State private var showPurchaseResult = false
    @State private var purchaseResultMessage = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Product IDs configured in App Store Connect
    private let productIds: [String] = [
        "dev.hyo.martie.10bulbs",
        "dev.hyo.martie.30bulbs",
        "dev.hyo.martie.premium"
    ]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                HeaderCardView()
                
                ProductsSection()
                
                if showPurchaseResult {
                    PurchaseResultSection()
                }
                
                InstructionsCard()
                
                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
        .background(AppColors.background)
        .navigationTitle("Purchase Flow")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: loadProducts) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(iapStore.status.isLoading)
            }
        }
        .onAppear {
            setupIapProvider()
        }
        .onDisappear {
            teardownConnection()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    @ViewBuilder
    private func HeaderCardView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cart.fill")
                    .font(.largeTitle)
                    .foregroundColor(AppColors.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Purchase Flow")
                        .font(.headline)
                    
                    Text("Test product purchases")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text("Purchase consumable and non-consumable iapStore.products. Events are handled through OpenIapStore callbacks.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func ProductsSection() -> some View {
        LazyVStack(spacing: 16) {
            ForEach(iapStore.products, id: \.id) { product in
                ProductCard(
                    product: product,
                    isPurchasing: iapStore.status.isPurchasing(product.id)
                ) {
                    purchaseProduct(product)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // moved ProductCard to Screens/uis/ProductCard.swift
    
    @ViewBuilder
    private func PurchaseResultSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                Text("Purchase Result")
                    .font(.headline)
                
                Spacer()
                
                Button("Dismiss") {
                    showPurchaseResult = false
                    purchaseResultMessage = ""
                }
                .font(.caption)
                .foregroundColor(AppColors.primary)
            }
            
            Text(purchaseResultMessage)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func InstructionsCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppColors.primary)
                Text("Instructions")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                InstructionRow(
                    number: "1",
                    text: "Products are loaded from App Store Connect"
                )
                InstructionRow(
                    number: "2", 
                    text: "Tap Purchase to initiate transaction"
                )
                InstructionRow(
                    number: "3",
                    text: "Events are handled via OpenIapStore callbacks"
                )
                InstructionRow(
                    number: "4",
                    text: "Receipt validation should be done server-side"
                )
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    // using shared InstructionRow in Screens/uis/InstructionRow.swift
    
    // MARK: - OpenIapStore Setup
    
    private func setupIapProvider() {
        print("🔷 [PurchaseFlow] Setting up OpenIapStore...")
        
        // Setup callbacks
        iapStore.onPurchaseSuccess = { purchase in
            Task { @MainActor in
                self.handlePurchaseSuccess(purchase)
            }
        }
        
        iapStore.onPurchaseError = { error in
            Task { @MainActor in
                self.handlePurchaseError(error)
            }
        }
        
        Task {
            do {
                try await iapStore.initConnection()
                print("✅ [PurchaseFlow] Connection initialized")
                loadProducts()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to initialize connection: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func teardownConnection() {
        print("🔷 [PurchaseFlow] Tearing down connection...")
        Task {
            try await iapStore.endConnection()
            print("✅ [PurchaseFlow] Connection ended")
        }
    }
    
    // MARK: - Product Loading
    
    private func loadProducts() {
        Task {
            do {
                try await iapStore.fetchProducts(skus: productIds, type: .inApp)
                await MainActor.run {
                    if iapStore.products.isEmpty {
                        errorMessage = "No products found. Please check your App Store Connect configuration."
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load products: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Purchase Flow
    
    private func purchaseProduct(_ product: OpenIapProduct) {
        print("🛒 [PurchaseFlow] Starting purchase for: \(product.id)")
        
        Task {
            do {
                let params = RequestPurchaseProps(
                    sku: product.id,
                    andDangerouslyFinishTransactionAutomatically: false,
                    appAccountToken: nil,
                    quantity: 1
                )
                _ = try await iapStore.requestPurchase(params)
            } catch {
                // Error is already handled by OpenIapStore internally
                print("❌ [PurchaseFlow] Purchase failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handlePurchaseSuccess(_ purchase: OpenIapPurchase) {
        print("✅ [PurchaseFlow] Purchase successful: \(purchase.productId)")
        
        // Update UI state
        let transactionDate = Date(timeIntervalSince1970: purchase.transactionDate / 1000)
        purchaseResultMessage = """
        ✅ Purchase successful
        Product: \(purchase.productId)
        Transaction ID: \(purchase.id)
        Date: \(DateFormatter.localizedString(from: transactionDate, dateStyle: .short, timeStyle: .short))
        """
        showPurchaseResult = true
        
        // In production, validate receipt on your server before finishing
        Task {
            await finishPurchase(purchase)
        }
    }
    
    private func handlePurchaseError(_ error: OpenIapError) {
        print("❌ [PurchaseFlow] Purchase error: \(error.message)")
        
        // Update UI state
        purchaseResultMessage = "❌ Purchase failed: \(error.message)"
        showPurchaseResult = true
        
        // Show error alert for non-cancellation errors
        if error.code != OpenIapError.UserCancelled {
            errorMessage = error.message
            showError = true
        }
    }
    
    private func finishPurchase(_ purchase: OpenIapPurchase) async {
        do {
            _ = try await iapStore.finishTransaction(purchase: purchase)
            print("✅ [PurchaseFlow] Transaction finished: \(purchase.id)")
        } catch {
            print("❌ [PurchaseFlow] Failed to finish transaction: \(error)")
            await MainActor.run {
                errorMessage = "Failed to finish transaction: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

#Preview {
    NavigationView {
        if #available(iOS 15.0, *) {
            PurchaseFlowScreen()
        } else {
            Text("iOS 15.0+ Required")
        }
    }
}
