import SwiftUI
import OpenIAP

@available(iOS 15.0, *)
struct OfferCodeScreen: View {
    @StateObject private var store = StoreViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "gift.fill")
                            .font(.largeTitle)
                            .foregroundColor(AppColors.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Offer Code Redemption")
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
                    
                    Text("Redeem promotional offer codes for in-app purchases and subscriptions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding(.horizontal)
                
                Button(action: {
                    Task {
                        await store.presentOfferCodeRedemption()
                    }
                }) {
                    HStack {
                        Image(systemName: "gift")
                        Text("Redeem Offer Code")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .padding()
                    .background(AppColors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                
                InstructionCard()
                
                TestingNotesCard()
                
                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
        .background(AppColors.background)
        .navigationTitle("Offer Code")
        .navigationBarTitleDisplayMode(.large)
        .alert("Error", isPresented: $store.showError) {
            Button("OK") {}
        } message: {
            Text(store.errorMessage)
        }
    }
}

struct InstructionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(AppColors.primary)
                Text("How it works")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(
                    number: "1",
                    text: "Tap the 'Redeem Offer Code' button above"
                )
                
                InstructionRow(
                    number: "2", 
                    text: "Enter your offer code in the native iOS sheet"
                )
                
                InstructionRow(
                    number: "3",
                    text: "Follow the prompts to complete redemption"
                )
                
                InstructionRow(
                    number: "4",
                    text: "Your purchase will be automatically applied"
                )
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

struct TestingNotesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "testtube.2")
                    .foregroundColor(AppColors.warning)
                Text("Testing Notes")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                TestingNote(
                    icon: "checkmark.circle",
                    text: "Requires iOS 14.0+ for offer code redemption",
                    color: AppColors.success
                )
                
                TestingNote(
                    icon: "gear",
                    text: "Configure offer codes in App Store Connect",
                    color: AppColors.primary
                )
                
                TestingNote(
                    icon: "person.2",
                    text: "Test with sandbox account for development",
                    color: AppColors.secondary
                )
                
                TestingNote(
                    icon: "exclamationmark.triangle",
                    text: "Production codes only work in live app",
                    color: AppColors.warning
                )
            }
        }
        .padding()
        .background(AppColors.warning.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.warning, lineWidth: 1)
        )
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(AppColors.primary)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
        }
    }
}

struct TestingNote: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(text)
                .font(.caption)
                .foregroundColor(AppColors.primaryText)
            
            Spacer()
        }
    }
}