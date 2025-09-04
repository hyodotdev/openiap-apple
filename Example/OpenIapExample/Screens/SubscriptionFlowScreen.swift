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
                    let subscriptionProducts = store.products.filter { $0.typeIOS.isSubs }
                    
                    if subscriptionProducts.isEmpty {
                        EmptyStateCard(
                            icon: "repeat.circle",
                            title: "No subscriptions available",
                            subtitle: "Configure subscription products in App Store Connect"
                        )
                    } else {
                        ForEach(subscriptionProducts, id: \.id) { product in
                            let activePurchase = store.purchases.first { purchase in
                                purchase.productId == product.id
                            }
                            let isSubscribed = activePurchase != nil
                            let isCancelled = activePurchase?.isAutoRenewing == false
                            
                            SubscriptionCard(
                                product: product,
                                isSubscribed: isSubscribed,
                                isCancelled: isCancelled,
                                isLoading: store.purchasingProductIds.contains(product.id),
                                onSubscribe: {
                                    if !isSubscribed || isCancelled {
                                        store.purchaseProduct(product)
                                    }
                                },
                                onManage: {
                                    Task {
                                        await store.manageSubscriptions()
                                    }
                                }
                            )
                        }
                    }
                }
                
                // Instructions Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppColors.secondary)
                        Text("Subscription Flow")
                            .font(.headline)
                    }
                    .padding(.bottom, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Purchase → Auto receipt validation", systemImage: "1.circle.fill")
                            .font(.subheadline)
                        Label("Server validates receipt (see StoreViewModel)", systemImage: "2.circle.fill")
                            .font(.subheadline)
                        Label("Subscriptions auto-finish (no manual finish needed)", systemImage: "3.circle.fill")
                            .font(.subheadline)
                        Label("Re-subscriptions may take 10-30 seconds in Sandbox", systemImage: "4.circle.fill")
                            .font(.subheadline)
                    }
                    .foregroundColor(AppColors.primaryText)
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
    let isCancelled: Bool
    let isLoading: Bool
    let onSubscribe: () -> Void
    let onManage: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.title)
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
                    
                    Text(product.id)
                        .font(.caption)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isSubscribed ? AppColors.success : AppColors.secondary)
                    
                    if product.typeIOS.isSubs {
                        Text("per month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text(product.description)
                .font(.body)
                .foregroundColor(AppColors.primaryText)
            
            if product.typeIOS.isSubs {
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
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: isCancelled ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundColor(isCancelled ? AppColors.warning : AppColors.success)
                        
                        Text(isCancelled ? "Subscription Cancelled" : "Currently Subscribed")
                            .fontWeight(.medium)
                            .foregroundColor(isCancelled ? AppColors.warning : AppColors.success)
                        
                        Spacer()
                        
                        Text(isCancelled ? "Expires Soon" : "Active")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((isCancelled ? AppColors.warning : AppColors.success).opacity(0.2))
                            .foregroundColor(isCancelled ? AppColors.warning : AppColors.success)
                            .cornerRadius(4)
                    }
                    .padding()
                    .background((isCancelled ? AppColors.warning : AppColors.success).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isCancelled ? AppColors.warning : AppColors.success, lineWidth: 1)
                    )
                    .cornerRadius(8)
                    
                    if isCancelled {
                        // Re-subscribe button for cancelled subscriptions
                        Button(action: onSubscribe) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.clockwise.circle")
                                }
                                Text(isLoading ? "Reactivating..." : "Reactivate Subscription")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(product.displayPrice)
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .background(isLoading ? AppColors.secondary.opacity(0.7) : AppColors.secondary)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isLoading)
                        
                        Text("Subscription will remain active until expiry")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        // Manage/Cancel Subscription Button
                        Button(action: onManage) {
                            HStack {
                                Image(systemName: "gear")
                                    .font(.system(size: 14))
                                Text("Manage Subscription")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.15))
                            .foregroundColor(AppColors.primaryText)
                            .cornerRadius(8)
                        }
                        
                        Text("Cancel anytime in Settings")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
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
                            Text(product.displayPrice)
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