import SwiftUI
import OpenIAP

@available(iOS 15.0, *)
struct SubscriptionFlowScreen: View {
    @StateObject private var store = StoreViewModel()
    
    var body: some View {
        ScrollView {
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
                
                if store.isLoading {
                    LoadingCard(text: "Loading subscriptions...")
                } else {
                    let subscriptionProducts = store.products.filter { $0.id.contains("premium") }
                    
                    if subscriptionProducts.isEmpty {
                        EmptyStateCard(
                            icon: "repeat.circle",
                            title: "No subscriptions available",
                            subtitle: "Configure subscription products in App Store Connect"
                        )
                    } else {
                        ForEach(subscriptionProducts, id: \.id) { product in
                            let isSubscribed = store.purchases.contains { purchase in
                                purchase.productId == product.id &&
                                purchase.purchaseState == .purchased &&
                                (purchase.isAutoRenewing || (purchase.expiryTime != nil && purchase.expiryTime! > Date()))
                            }
                            
                            SubscriptionCard(
                                product: product,
                                isSubscribed: isSubscribed,
                                isLoading: store.purchasingProductIds.contains(product.id)
                            ) {
                                if !isSubscribed {
                                    store.purchaseProduct(product)
                                }
                            }
                        }
                    }
                }
                
                Button(action: {
                    Task {
                        await store.restorePurchases()
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await store.loadProducts()
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
                await store.loadProducts()
                await store.loadPurchases()
            }
        }
    }
}

struct SubscriptionCard: View {
    let product: OpenIapProduct
    let isSubscribed: Bool
    let isLoading: Bool
    let onSubscribe: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.localizedTitle)
                            .font(.headline)
                        
                        if isSubscribed {
                            Label("Subscribed", systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(AppColors.success)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(AppColors.success.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(product.productId)
                        .font(.caption)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.localizedPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isSubscribed ? AppColors.success : AppColors.secondary)
                    
                    if product.type == "subs" {
                        Text("per month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text(product.description)
                .font(.body)
                .foregroundColor(AppColors.primaryText)
            
            if product.type == "subs" {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    
                    Text("Auto-renewable subscription")
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 4)
            }
            
            if isSubscribed {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.success)
                    
                    Text("Currently Subscribed")
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.success)
                    
                    Spacer()
                    
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.success.opacity(0.2))
                        .foregroundColor(AppColors.success)
                        .cornerRadius(4)
                }
                .padding()
                .background(AppColors.success.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.success, lineWidth: 1)
                )
                .cornerRadius(8)
            } else {
                Button(action: onSubscribe) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "repeat.circle")
                        }
                        
                        Text(isLoading ? "Processing..." : "Subscribe")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        if !isLoading {
                            Text(product.localizedPrice)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(isLoading ? AppColors.secondary.opacity(0.7) : AppColors.secondary)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isLoading)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}