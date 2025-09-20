import SwiftUI
import OpenIAP

@available(iOS 15.0, *)
struct SubscriptionFlowScreen: View {
    @StateObject private var iapStore = OpenIapStore()
    
    // UI State
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var recentPurchase: OpenIapPurchase?
    @State private var selectedPurchase: OpenIapPurchase?
    
    // Product IDs for subscription testing
    private let subscriptionIds: [String] = [
        "dev.hyo.martie.premium",
        "dev.hyo.martie.premium_year"
    ]
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "repeat.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(AppColors.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subscription Management")
                                .font(.headline)
                            
                            Text("iOS")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(AppColors.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                    
                    Text("Manage your premium subscriptions and auto-renewable purchases.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding(.horizontal)
                
                if iapStore.status.isLoading {
                    LoadingCard(text: "Loading subscriptions...")
                } else {
                    if let purchase = recentPurchase {
                        purchaseResultCard(for: purchase)
                    }

                    let productIds = subscriptionProductIds
                    
                    if productIds.isEmpty {
                        EmptyStateCard(
                            icon: "repeat.circle",
                            title: "No subscriptions available",
                            subtitle: "Configure subscription products in App Store Connect"
                        )
                    } else {
                        ForEach(productIds, id: \.self) { productId in
                            let product = product(for: productId)
                            SubscriptionCard(
                                productId: productId,
                                product: product,
                                purchase: purchase(for: productId),
                                isSubscribed: isSubscribed(productId: productId),
                                isCancelled: isCancelled(productId: productId),
                                isLoading: iapStore.status.isPurchasing(productId),
                                onSubscribe: {
                                    let subscribed = isSubscribed(productId: productId)

                                    if subscribed {
                                        Task {
                                            await manageSubscriptions()
                                        }
                                    } else {
                                        if let product = product {
                                            purchaseProduct(product)
                                        }
                                    }
                                },
                                onManage: {
                                    Task {
                                        await manageSubscriptions()
                                    }
                                }
                            )
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Subscriptions may take a moment to reflect")
                        Text("• Use Sandbox account for testing")
                        Text("• Restore purchases to sync status")
                    }
                    .font(.caption)
                }
                .padding()
                .background(AppColors.secondary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(8)
                .padding(.horizontal)
                
                Button(action: {
                    Task {
                        await restorePurchases()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle")
                        Text("Restore Purchases")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .padding()
                    .background(AppColors.secondary)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
        .background(AppColors.background)
        .navigationTitle("Subscriptions")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarItems(trailing: 
            Button {
                loadProducts()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(iapStore.status.isLoading)
        )
        .sheet(isPresented: Binding(
            get: { selectedPurchase != nil },
            set: { if !$0 { selectedPurchase = nil } }
        )) {
            if let purchase = selectedPurchase {
                PurchaseDetailSheet(purchase: purchase)
            }
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
    
    // MARK: - OpenIapStore Setup
    
    private func setupIapProvider() {
        print("🔷 [SubscriptionFlow] Setting up OpenIapStore...")
        
        // Setup callbacks
        iapStore.onPurchaseSuccess = { purchase in
            if let iosPurchase = purchase.asIOS() {
                Task { @MainActor in
                    self.handlePurchaseSuccess(iosPurchase)
                }
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
                print("✅ [SubscriptionFlow] Connection initialized")
                loadProducts()
                await loadPurchases()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to initialize connection: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func teardownConnection() {
        print("🔷 [SubscriptionFlow] Tearing down connection...")
        Task {
            try await iapStore.endConnection()
            print("✅ [SubscriptionFlow] Connection ended")
        }
    }
    
    // MARK: - Product and Purchase Loading
    
    private func loadProducts() {
        Task {
            await MainActor.run {
                // Loading state is managed internally
            }
            defer { 
                Task { @MainActor in
                    // Loading state is managed internally
                }
            }
            
            do {
                try await iapStore.fetchProducts(skus: subscriptionIds, type: .all)
                await MainActor.run {
                    let ids = subscriptionProductIds
                    if ids.isEmpty {
                        errorMessage = "No subscription products found. Please check your App Store Connect configuration."
                        showError = true
                    }
                    print("✅ [SubscriptionFlow] Loaded subscriptions: \(ids.joined(separator: ", "))")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load products: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func loadPurchases() async {
        do {
            try await iapStore.getAvailablePurchases()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load purchases: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Purchase Flow
    
    private func purchaseProduct(_ product: OpenIapProduct) {
        print("🔄 [SubscriptionFlow] Starting subscription purchase for: \(product.id)")
        Task {
            do {
                _ = try await iapStore.requestPurchase(sku: product.id, type: .subs, autoFinish: true)
            } catch {
                // Error is already handled by OpenIapStore internally
                print("❌ [SubscriptionFlow] Purchase failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func restorePurchases() async {
        do {
            try await iapStore.refreshPurchases(forceSync: true)
            await MainActor.run {
                print("✅ [SubscriptionFlow] Restored \(iapStore.iosAvailablePurchases.count) purchases")
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func manageSubscriptions() async {
        do {
            _ = try await iapStore.showManageSubscriptionsIOS()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to open subscription management: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handlePurchaseSuccess(_ purchase: OpenIapPurchase) {
        print("✅ [SubscriptionFlow] Subscription successful: \(purchase.productId)")
        
        // Reload purchases to update UI
        Task {
            await loadPurchases()
        }
        recentPurchase = purchase
    }
    
    private func handlePurchaseError(_ error: OpenIapError) {
        print("❌ [SubscriptionFlow] Subscription error: \(error.message)")
        // Error status is already handled internally by OpenIapStore
    }
}

@available(iOS 15.0, *)
@MainActor
private extension SubscriptionFlowScreen {
    var subscriptionProductIds: [String] {
        var orderedIds: [String] = []
        func appendIfNeeded(_ id: String) {
            guard orderedIds.contains(id) == false else { return }
            orderedIds.append(id)
        }

        subscriptionIds.forEach { appendIfNeeded($0) }
        iapStore.iosProducts.filter { $0.type == .subs }.forEach { appendIfNeeded($0.id) }
        iapStore.iosAvailablePurchases.filter { $0.isSubscription }.forEach { appendIfNeeded($0.productId) }
        return orderedIds
    }

    func product(for id: String) -> OpenIapProduct? {
        iapStore.iosProducts.first { $0.id == id }
    }

    func purchase(for productId: String) -> OpenIapPurchase? {
        iapStore.iosAvailablePurchases.first { $0.productId == productId }
    }

    func isSubscribed(productId: String) -> Bool {
        guard let purchase = purchase(for: productId) else { return false }
        if let expirationTime = purchase.expirationDateIOS {
            let expirationDate = Date(timeIntervalSince1970: expirationTime / 1000)
            if expirationDate > Date() { return true }
        }
        if purchase.isAutoRenewing { return true }
        if purchase.purchaseState == .purchased || purchase.purchaseState == .restored { return true }
        return purchase.isSubscription
    }

    func isCancelled(productId: String) -> Bool {
        guard let purchase = purchase(for: productId) else { return false }
        let active = isSubscribed(productId: productId)
        return purchase.isAutoRenewing == false && active
    }
}

@available(iOS 15.0, *)
@MainActor
private extension SubscriptionFlowScreen {
    func purchaseResultCard(for purchase: OpenIapPurchase) -> some View {
        let transactionDate = Date(timeIntervalSince1970: purchase.transactionDate / 1000)
        let formattedDate = DateFormatter.localizedString(from: transactionDate, dateStyle: .short, timeStyle: .short)
        let message = """
        ✅ Subscription successful
        Product: \(purchase.productId)
        Transaction ID: \(purchase.id)
        Date: \(formattedDate)
        """

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                Text("Latest Subscription")
                    .font(.headline)

                Spacer()

                Button("Dismiss") {
                    recentPurchase = nil
                }
                .font(.caption)
                .foregroundColor(AppColors.primary)
            }

            Button {
                selectedPurchase = purchase
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundColor(AppColors.primary)
                    Text(message)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}
