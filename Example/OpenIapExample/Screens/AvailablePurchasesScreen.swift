import SwiftUI
import OpenIAP

@available(iOS 15.0, *)
struct AvailablePurchasesScreen: View {
    @StateObject private var iapStore = OpenIapStore()
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedPurchase: OpenIapPurchase?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                availablePurchasesSection
                purchaseHistorySection
                
                // Debug section for Sandbox testing
                #if DEBUG
                sandboxToolsSection
                #endif
            }
            .padding(.vertical)
        }
        .background(AppColors.background)
        .navigationTitle("Purchases")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    loadPurchases()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(iapStore.status.loadings.restorePurchases)
            }
        }
        .sheet(item: $selectedPurchase) { purchase in
            PurchaseDetailSheet(purchase: purchase)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            setupIapProvider()
        }
        .onDisappear {
            teardownConnection()
        }
    }
    
    // MARK: - Available Purchases Section (Currently Owned/Active)
    private var availablePurchasesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                title: "Available Purchases",
                subtitle: "Your active subscriptions and unconsumed items",
                icon: "checkmark.seal.fill"
            )
            
            availablePurchasesContent
        }
    }
    
    private var uniqueActivePurchases: [OpenIapPurchase] {
        let allActivePurchases = iapStore.iosAvailablePurchases.filter { purchase in
            // Show active purchases (purchased or restored state)
            purchase.purchaseState == .purchased || purchase.purchaseState == .restored
        }.filter { purchase in
            if purchase.isSubscription {
                // Active subscriptions: check auto-renewing or expiry time
                if purchase.isAutoRenewing {
                    return true  // Always show auto-renewing subscriptions
                }
                // For non-auto-renewing, check expiry time
                if let expiryTime = purchase.expirationDateIOS {
                    let expiryDate = Date(timeIntervalSince1970: expiryTime / 1000)
                    return expiryDate > Date()  // Only show if not expired
                }
                return true  // Show if no expiry info
            } else {
                // Consumables: show if not acknowledged
                return !purchase.purchaseState.isAcknowledged
            }
        }
        
        // Return sorted by date
        return allActivePurchases.sorted(by: { $0.transactionDate > $1.transactionDate })
    }
    
    @ViewBuilder
    private var availablePurchasesContent: some View {
        if uniqueActivePurchases.isEmpty {
            EmptyStateCard(
                icon: "bag.circle",
                title: "No active purchases",
                subtitle: "Your active subscriptions and items will appear here"
            )
        } else {
            VStack(spacing: 12) {
                ForEach(uniqueActivePurchases, id: \.transactionId) { purchase in
                    ActivePurchaseCard(purchase: purchase, onConsume: {
                        Task {
                            await finishPurchase(purchase)
                        }
                    }, onShowDetails: {
                        selectedPurchase = purchase
                    })
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Purchase History Section (All Past Purchases)
    private var purchaseHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                title: "Purchase History",
                subtitle: "All your past purchases",
                icon: "clock.arrow.circlepath"
            )
            
            purchaseHistoryContent
        }
    }
    
    @ViewBuilder
    private var purchaseHistoryContent: some View {
        if iapStore.iosAvailablePurchases.isEmpty {
            EmptyStateCard(
                icon: "clock",
                title: "No purchase history",
                subtitle: "Your purchase history will appear here"
            )
        } else {
            VStack(spacing: 12) {
                ForEach(iapStore.iosAvailablePurchases.sorted { $0.transactionDate > $1.transactionDate }, id: \.transactionId) { purchase in
                    PurchaseHistoryCard(purchase: purchase) {
                        selectedPurchase = purchase
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Sandbox Tools Section (Debug Only)
    #if DEBUG
    private var sandboxToolsSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(AppColors.warning)
                    Text("🧪 Sandbox Testing Tools")
                        .font(.headline)
                    Spacer()
                }
                
                Text("Debug tools for testing in-app purchases in Sandbox environment")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(AppColors.warning.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                // Clear All Transactions
                Button(action: {
                    Task {
                        await clearAllTransactions()
                    }
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Transactions")
                        Spacer()
                        Text("Reset")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Sync Subscription Status
                Button(action: {
                    Task {
                        await syncSubscriptions()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Subscription Status")
                        Spacer()
                        Text("Refresh")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Finish Pending Transactions
                Button(action: {
                    Task {
                        await finishUnfinishedTransactions()
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Finish Pending Transactions")
                        Spacer()
                        Text("Complete")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(Color.orange.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            
            // Testing Tips
            VStack(alignment: .leading, spacing: 8) {
                Label("Testing Tips", systemImage: "lightbulb.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.warning)
                    .padding(.bottom, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text("Use real device for best results")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text("Sign in with Sandbox account in Settings > App Store")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text("Clear transactions resets local cache")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text("Subscriptions expire quickly (5 min = 1 month)")
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(AppColors.warning.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal)
            
            Spacer(minLength: 20)
        }
    }
    #endif
    
    // MARK: - OpenIapStore Setup
    
    private func setupIapProvider() {
        print("🔷 [AvailablePurchases] Setting up OpenIapStore...")
        
        iapStore.onPurchaseSuccess = { purchase in
            if purchase.asIOS() != nil {
                Task { @MainActor in
                    loadPurchases()
                }
            }
        }
        
        iapStore.onPurchaseError = { error in
            Task { @MainActor in
                errorMessage = error.message
                showError = true
            }
        }
        
        Task {
            do {
                try await iapStore.initConnection()
                print("✅ [AvailablePurchases] Connection initialized")
                loadPurchases()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to initialize connection: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func teardownConnection() {
        print("🔷 [AvailablePurchases] Tearing down connection...")
        Task {
            try await iapStore.endConnection()
            print("✅ [AvailablePurchases] Connection ended")
        }
    }
    
    // MARK: - Purchase Loading
    
    private func loadPurchases() {
        Task {
            do {
                try await iapStore.getAvailablePurchases()
                print("✅ [AvailablePurchases] Loaded \(iapStore.iosAvailablePurchases.count) purchases")
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load purchases: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Purchase Actions
    
    private func finishPurchase(_ purchase: OpenIapPurchase) async {
        do {
            try await iapStore.finishTransaction(purchase: purchase)
            print("✅ [AvailablePurchases] Transaction finished: \(purchase.id)")
            // Reload purchases to update UI
            loadPurchases()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to finish transaction: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Debug Methods
    
    private func clearAllTransactions() async {
        // Note: This would require additional API in OpenIapStore
        // For now, just reload purchases
        loadPurchases()
        print("🧪 [AvailablePurchases] Clear transactions requested (reloaded purchases)")
    }
    
    private func syncSubscriptions() async {
        // Reload purchases to sync subscription status
        loadPurchases()
        print("🧪 [AvailablePurchases] Subscription sync requested (reloaded purchases)")
    }
    
    private func finishUnfinishedTransactions() async {
        let unfinishedPurchases = iapStore.iosAvailablePurchases.filter { !$0.purchaseState.isAcknowledged }
        
        for purchase in unfinishedPurchases {
            do {
                try await iapStore.finishTransaction(purchase: purchase)
                print("✅ [AvailablePurchases] Finished unfinished transaction: \(purchase.transactionId)")
            } catch {
                print("❌ [AvailablePurchases] Failed to finish transaction \(purchase.transactionId): \(error)")
            }
        }
        
        // Reload after finishing transactions
        loadPurchases()
    }
}

// ActivePurchaseCard moved to Screens/uis/ActivePurchaseCard.swift

// PurchaseHistoryCard moved to Screens/uis/PurchaseHistoryCard.swift

// PurchaseCard moved to Screens/uis/PurchaseCard.swift

// SectionHeaderView moved to Screens/uis/SectionHeaderView.swift

// ProductListCard moved to Screens/uis/ProductListCard.swift

// ProductGridCard moved to Screens/uis/ProductGridCard.swift

// EmptyStateCard and LoadingCard moved to Screens/uis/
