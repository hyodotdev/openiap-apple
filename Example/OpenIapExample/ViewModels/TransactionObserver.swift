import SwiftUI
import OpenIAP

@MainActor
@available(iOS 15.0, *)
class TransactionObserver: ObservableObject {
    @Published var latestPurchase: OpenIapPurchase?
    @Published var errorMessage: String?
    @Published var isPending = false
    
    private let iapModule = OpenIapModule.shared
    
    init() {
        setupListeners()
    }
    
    deinit {
        // Clean up listeners
        iapModule.removeAllPurchaseUpdatedListeners()
        iapModule.removeAllPurchaseErrorListeners()
    }
    
    private func setupListeners() {
        // Add purchase updated listener
        iapModule.addPurchaseUpdatedListener { [weak self] purchase in
            Task { @MainActor in
                self?.handlePurchaseUpdated(purchase)
            }
        }
        
        // Add purchase error listener
        iapModule.addPurchaseErrorListener { [weak self] error in
            Task { @MainActor in
                self?.handlePurchaseError(error)
            }
        }
    }
    
    private func handlePurchaseUpdated(_ purchase: OpenIapPurchase) {
        print("✅ Purchase successful: \(purchase.id)")
        latestPurchase = purchase
        isPending = false
        errorMessage = nil
    }
    
    private func handlePurchaseError(_ error: OpenIapError) {
        print("❌ Purchase failed: \(error)")
        errorMessage = error.localizedDescription
        isPending = false
    }
}

// Example usage in SwiftUI View
struct TransactionObserverExampleView: View {
    @StateObject private var observer = TransactionObserver()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Transaction Observer Example")
                .font(.title)
            
            if observer.isPending {
                ProgressView("Transaction pending...")
            }
            
            if let purchase = observer.latestPurchase {
                VStack(alignment: .leading) {
                    Text("Latest Purchase:")
                        .font(.headline)
                    Text("Product: \(purchase.id)")
                    Text("Date: \(Date(timeIntervalSince1970: purchase.purchaseTime / 1000), formatter: dateFormatter)")
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            if let error = observer.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}