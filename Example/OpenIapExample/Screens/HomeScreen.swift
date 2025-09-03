import SwiftUI
import OpenIAP

@available(iOS 15.0, *)
struct HomeScreen: View {
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 0)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "bag.fill")
                                .font(.largeTitle)
                                .foregroundColor(AppColors.primary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("OpenIAP Example")
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
                        
                        Text("Test in-app purchases and subscription features with StoreKit integration.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                        FeatureCard(
                            title: "Purchase\nFlow",
                            subtitle: "Test product purchases",
                            icon: "cart.fill",
                            color: AppColors.primary,
                            destination: AnyView(PurchaseFlowScreen())
                        )
                        
                        FeatureCard(
                            title: "Subscription\nFlow", 
                            subtitle: "Test subscriptions",
                            icon: "repeat.circle.fill",
                            color: AppColors.secondary,
                            destination: AnyView(SubscriptionFlowScreen())
                        )
                        
                        FeatureCard(
                            title: "My\nPurchases",
                            subtitle: "View your purchases",
                            icon: "list.bullet.rectangle.fill",
                            color: AppColors.success,
                            destination: AnyView(AvailablePurchasesScreen())
                        )
                        
                        FeatureCard(
                            title: "Offer\nCode",
                            subtitle: "Redeem promotional codes",
                            icon: "gift.fill",
                            color: AppColors.warning,
                            destination: AnyView(OfferCodeScreen())
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 0)
                }
                .padding(.vertical)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(AppColors.background)
        .navigationTitle("OpenIAP Features")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct FeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 8) {
                Spacer()
                
                Image(systemName: icon)
                    .font(.system(size: 34))
                    .foregroundColor(color)
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(AppColors.cardBackground)
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}