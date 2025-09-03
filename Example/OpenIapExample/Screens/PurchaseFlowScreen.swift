import SwiftUI
import OpenIAP

@available(iOS 15.0, *)
struct PurchaseFlowScreen: View {
    @StateObject private var store = StoreViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeaderCardView()
                
                ProductsContentView(store: store)
                
                if !store.purchases.isEmpty {
                    RecentPurchasesSection(purchases: store.purchases)
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
                Button(action: {
                    Task {
                        await store.loadProducts()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
        }
        .alert("Purchase Successful", isPresented: $store.showPurchaseSuccess) {
            Button("OK") {
                store.showPurchaseSuccess = false
                store.lastPurchasedProduct = nil
            }
        } message: {
            if let product = store.lastPurchasedProduct {
                Text("Successfully purchased \(product.title)")
            }
        }
        .alert("Error", isPresented: $store.showError) {
            Button("OK") {}
        } message: {
            Text(store.errorMessage)
        }
        .onAppear {
            Task {
                await store.loadProducts()
                await store.loadPurchases()
            }
        }
    }
}

struct ProductCard: View {
    let product: IapProductData
    let isLoading: Bool
    let onPurchase: () -> Void
    
    private var productIcon: String {
        switch product.type {
        case "inapp":
            return "bag.fill"
        case "subs":
            return "repeat.circle.fill"
        default:
            return "star.fill"
        }
    }
    
    private var productTypeText: String {
        switch product.type {
        case "inapp":
            return "In-App Purchase"
        case "subs":
            return "Subscription"
        default:
            return "Non-Renewing"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Product header
            HStack {
                Image(systemName: productIcon)
                    .font(.title2)
                    .foregroundColor(AppColors.primary)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text(productTypeText)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.primary.opacity(0.1))
                            .foregroundColor(AppColors.primary)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text(product.displayPrice)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            
            // Product description
            Text(product.description)
                .font(.subheadline)
                .foregroundColor(AppColors.secondaryText)
                .lineLimit(nil)
            
            // Product ID (for testing)
            Text("ID: \(product.id)")
                .font(.caption)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(AppColors.secondaryText)
                .opacity(0.7)
            
            // Purchase button
            Button(action: onPurchase) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "cart")
                    }
                    
                    Text(isLoading ? "Processing..." : "Purchase")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if !isLoading {
                        Text(product.displayPrice)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(isLoading ? AppColors.primary.opacity(0.7) : AppColors.primary)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isLoading)
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct RecentPurchasesSection: View {
    let purchases: [IapPurchase]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                Text("Recent Purchases")
                    .font(.headline)
                Spacer()
                
                Text("\(purchases.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppColors.success.opacity(0.2))
                    .foregroundColor(AppColors.success)
                    .cornerRadius(12)
            }
            
            VStack(spacing: 12) {
                ForEach(purchases.prefix(3), id: \.transactionId) { purchase in
                    RecentPurchaseRow(purchase: purchase)
                }
                
                if purchases.count > 3 {
                    NavigationLink(destination: AvailablePurchasesScreen()) {
                        HStack {
                            Text("View all \(purchases.count) purchases")
                                .font(.subheadline)
                                .foregroundColor(AppColors.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AppColors.primary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.success.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct RecentPurchaseRow: View {
    let purchase: IapPurchase
    
    var body: some View {
        HStack {
            Image(systemName: "bag.fill")
                .font(.caption)
                .foregroundColor(AppColors.success)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(purchase.productId)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(purchase.purchaseTime, style: .relative)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
            
            Text("Qty: \(purchase.quantity)")
                .font(.caption)
                .foregroundColor(AppColors.secondaryText)
        }
        .padding(.vertical, 4)
    }
}

struct InstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(AppColors.primary)
                Text("Testing Instructions")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                PurchaseInstructionRow(
                    number: "1",
                    text: "Make sure you're signed in with a sandbox Apple ID"
                )
                
                PurchaseInstructionRow(
                    number: "2",
                    text: "Tap 'Purchase' on any product above to test the flow"
                )
                
                PurchaseInstructionRow(
                    number: "3",
                    text: "Use test card 4242 4242 4242 4242 in sandbox"
                )
                
                PurchaseInstructionRow(
                    number: "4",
                    text: "Check Available Purchases screen for purchase history"
                )
            }
        }
        .padding()
        .background(AppColors.primary.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct PurchaseInstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(AppColors.primary)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.primaryText)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

struct LoadingCard: View {
    let text: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(text)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(AppColors.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

struct HeaderCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cart.fill")
                    .font(.largeTitle)
                    .foregroundColor(AppColors.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Purchase Flow")
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
            
            Text("Test consumable in-app purchases with StoreKit integration.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

struct ProductsContentView: View {
    @ObservedObject var store: StoreViewModel
    
    var consumableProducts: [IapProductData] {
        store.products.filter { product in
            // Filter out premium subscription products
            !product.id.contains("premium") && product.type == "inapp"
        }
    }
    
    var body: some View {
        if store.isLoading {
            LoadingCard(text: "Loading products...")
        } else if consumableProducts.isEmpty {
            EmptyStateCard(
                icon: "bag",
                title: "No consumable products available",
                subtitle: "Check your App Store Connect configuration"
            )
        } else {
            ForEach(consumableProducts, id: \.id) { product in
                ProductCard(
                    product: product,
                    isLoading: store.purchasingProductIds.contains(product.id)
                ) {
                    store.purchaseProduct(product)
                }
            }
        }
    }
}