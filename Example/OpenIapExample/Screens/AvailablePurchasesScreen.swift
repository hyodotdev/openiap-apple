import SwiftUI
import OpenIAP

@available(iOS 15.0, *)
struct AvailablePurchasesScreen: View {
    @StateObject private var store = StoreViewModel()
    
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
                    Task {
                        await store.loadPurchases()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .alert("Error", isPresented: $store.showError) {
            Button("OK") {}
        } message: {
            Text(store.errorMessage)
        }
        .onAppear {
            Task {
                await store.loadPurchases()
            }
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
        let allActivePurchases = store.purchases.filter { purchase in
            // Show active purchases (purchased or restored state)
            purchase.purchaseState == .purchased || purchase.purchaseState == .restored
        }.filter { purchase in
            // Check product type if we can determine it
            let isSubscription = purchase.productId.contains("premium") || 
                                purchase.productId.contains("subscription")
            
            if isSubscription {
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
                ForEach(uniqueActivePurchases, id: \.id) { purchase in
                    ActivePurchaseCard(purchase: purchase) {
                        Task {
                            await store.finishPurchase(purchase)
                        }
                    }
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
        if store.purchases.isEmpty {
            EmptyStateCard(
                icon: "clock",
                title: "No purchase history",
                subtitle: "Your purchase history will appear here"
            )
        } else {
            VStack(spacing: 12) {
                ForEach(store.purchases.sorted { $0.transactionDate > $1.transactionDate }, id: \.id) { purchase in
                    PurchaseHistoryCard(purchase: purchase)
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
                        await store.clearAllTransactions()
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
                        await store.syncSubscriptions()
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
                        await store.finishUnfinishedTransactions()
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
}

// MARK: - Active Purchase Card (For Available Purchases)
struct ActivePurchaseCard: View {
    let purchase: OpenIapPurchase
    let onConsume: () -> Void
    
    private var isSubscription: Bool {
        purchase.productId.contains("premium")
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Status Icon
            Image(systemName: isSubscription ? "crown.fill" : "checkmark.seal.fill")
                .font(.system(size: 24))
                .foregroundColor(isSubscription ? AppColors.warning : AppColors.success)
                .frame(width: 44, height: 44)
                .background((isSubscription ? AppColors.warning : AppColors.success).opacity(0.1))
                .cornerRadius(12)
            
            // Purchase Info
            VStack(alignment: .leading, spacing: 4) {
                Text(purchase.id)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if isSubscription && purchase.isAutoRenewing {
                    Label("Auto-renewable", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(AppColors.primary)
                }
                
                if let expiryTime = purchase.expirationDateIOS != nil ? Date(timeIntervalSince1970: purchase.expirationDateIOS! / 1000) : nil {
                    Text("Expires: \(expiryTime, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action Button
            if !isSubscription && !purchase.purchaseState.isAcknowledged {
                Button(action: onConsume) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 12))
                        Text("Finish")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(AppColors.primary)
                    .cornerRadius(8)
                }
            } else if isSubscription {
                Text("Active")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(AppColors.success.opacity(0.2))
                    .foregroundColor(AppColors.success)
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Purchase History Card
struct PurchaseHistoryCard: View {
    let purchase: OpenIapPurchase
    
    private var statusColor: Color {
        switch purchase.purchaseState {
        case .purchased:
            return AppColors.success
        case .pending:
            return AppColors.warning
        case .failed:
            return AppColors.error
        case .restored:
            return AppColors.primary
        case .deferred:
            return AppColors.secondary
        case .unknown:
            return AppColors.secondary
        }
    }
    
    private var statusText: String {
        switch purchase.purchaseState {
        case .purchased:
            return "Purchased"
        case .pending:
            return "Pending"
        case .failed:
            return "Failed"
        case .restored:
            return "Restored"
        case .deferred:
            return "Deferred"
        case .unknown:
            return "Unknown"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(purchase.id)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Transaction: \(String(purchase.id.prefix(8)))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(statusText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(4)
                    
                    
                    Label(purchase.purchaseState.isAcknowledged ? "Consumed" : "Pending", 
                          systemImage: purchase.purchaseState.isAcknowledged ? "checkmark.circle.fill" : "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                Label("\(Date(timeIntervalSince1970: purchase.transactionDate / 1000), style: .date)", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if purchase.quantity > 1 {
                    Label("Qty: \(purchase.quantity)", systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Original Purchase Card (Deprecated)
struct PurchaseCard: View {
    let purchase: OpenIapPurchase
    let onConsume: () -> Void
    
    private var isSubscription: Bool {
        purchase.id.contains("premium")
    }
    
    private var statusColor: Color {
        switch purchase.purchaseState {
        case .purchased:
            return AppColors.success
        case .pending:
            return AppColors.warning
        case .failed:
            return AppColors.error
        case .restored:
            return AppColors.primary
        case .deferred:
            return AppColors.secondary
        case .unknown:
            return AppColors.secondary
        }
    }
    
    private var statusText: String {
        switch purchase.purchaseState {
        case .purchased:
            return "Purchased"
        case .pending:
            return "Pending"
        case .failed:
            return "Failed"
        case .restored:
            return "Restored"
        case .deferred:
            return "Deferred"
        case .unknown:
            return "Unknown"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(purchase.id)
                        .font(.headline)
                        .font(.system(.body, design: .monospaced))
                    
                    Text("Transaction: \\(purchase.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Purchased:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(Date(timeIntervalSince1970: purchase.transactionDate / 1000), style: .date)
                        .font(.caption)
                }
                
                if let expiryTime = purchase.expirationDateIOS != nil ? Date(timeIntervalSince1970: purchase.expirationDateIOS! / 1000) : nil {
                    HStack {
                        Text("Expires:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(expiryTime, style: .relative)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                
                if isSubscription {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                        Text("Auto-renewable")
                            .font(.caption)
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
            
            if !isSubscription && !purchase.purchaseState.isAcknowledged {
                Button(action: onConsume) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Consume")
                        Spacer()
                    }
                    .padding()
                    .background(AppColors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(AppColors.success)
                    Text("Acknowledged")
                        .font(.caption)
                        .foregroundColor(AppColors.success)
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

// MARK: - Section Header View
struct SectionHeaderView: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppColors.primary)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Product List Card
struct ProductListCard: View {
    let product: OpenIapProduct
    let onPurchase: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Product Icon
            Image(systemName: productIcon)
                .font(.system(size: 28))
                .foregroundColor(AppColors.primary)
                .frame(width: 44, height: 44)
                .background(AppColors.primary.opacity(0.1))
                .cornerRadius(12)
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(productTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Price and Purchase Button
            VStack(spacing: 8) {
                Text(product.displayPrice)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.primary)
                
                Button(action: onPurchase) {
                    Text("Buy")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(AppColors.primary)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var productIcon: String {
        if product.id.contains("10bulbs") {
            return "lightbulb"
        } else if product.id.contains("30bulbs") {
            return "lightbulb.fill"
        } else if product.id.contains("premium") {
            return "crown"
        } else {
            return "bag"
        }
    }
    
    private var productTitle: String {
        if product.id.contains("10bulbs") {
            return "10 Bulbs Pack"
        } else if product.id.contains("30bulbs") {
            return "30 Bulbs Pack"
        } else if product.id.contains("premium") {
            return "Premium Subscription"
        } else {
            return product.title
        }
    }
}

// MARK: - Product Grid Card (Deprecated)
struct ProductGridCard: View {
    let product: OpenIapProduct
    let onPurchase: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Product Icon
            Image(systemName: productIcon)
                .font(.system(size: 32))
                .foregroundColor(AppColors.primary)
                .frame(height: 40)
            
            VStack(spacing: 4) {
                Text(productTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)
                
                Button(action: onPurchase) {
                    Text("Purchase")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppColors.primary)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .frame(height: 180)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal, 4)
    }
    
    private var productIcon: String {
        if product.id.contains("10bulbs") {
            return "lightbulb"
        } else if product.id.contains("30bulbs") {
            return "lightbulb.fill"
        } else if product.id.contains("premium") {
            return "crown"
        } else {
            return "bag"
        }
    }
    
    private var productTitle: String {
        if product.id.contains("10bulbs") {
            return "10 Bulbs"
        } else if product.id.contains("30bulbs") {
            return "30 Bulbs"
        } else if product.id.contains("premium") {
            return "Premium"
        } else {
            return product.title
        }
    }
}