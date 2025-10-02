import SwiftUI
import OpenIAP

@available(iOS 16.0, *)
struct AlternativeBillingScreen: View {
    @StateObject private var iapStore = OpenIapStore()

    // UI State
    @State private var showPurchaseResult = false
    @State private var purchaseResultMessage = ""
    @State private var latestPurchase: OpenIapPurchase?
    @State private var selectedPurchase: OpenIapPurchase?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isInitialLoading = true
    @State private var externalUrl = "https://openiap.dev"

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

                if isInitialLoading {
                    LoadingCard(text: "Loading products...")
                } else {
                    ExternalUrlSection()

                    ProductsSection()

                    if showPurchaseResult {
                        PurchaseResultSection()
                    }
                }

                InstructionsCard()

                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
        .background(AppColors.background)
        .navigationTitle("Alternative Billing")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await loadProducts() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isInitialLoading || iapStore.status.isLoading)
            }
        }
        .onAppear {
            isInitialLoading = true
            setupIapProvider()
        }
        .onDisappear {
            iapStore.resetEphemeralState()
            teardownConnection()
            selectedPurchase = nil
            latestPurchase = nil
            showPurchaseResult = false
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: Binding(
            get: { selectedPurchase != nil },
            set: { if !$0 { selectedPurchase = nil } }
        )) {
            if let purchase = selectedPurchase {
                PurchaseDetailSheet(purchase: purchase)
            }
        }
    }

    @ViewBuilder
    private func HeaderCardView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(AppColors.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Alternative Billing")
                        .font(.headline)

                    Text("External purchase links")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Text("Test alternative billing flow using external purchase URLs. When tapping Purchase, users will be redirected to the external website.")
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
    private func ExternalUrlSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(AppColors.primary)
                Text("External Purchase URL")
                    .font(.headline)
                Spacer()
            }

            TextField("https://your-payment-site.com/checkout", text: $externalUrl)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .keyboardType(.URL)

            Text("This URL will be opened when a user taps Purchase. Make sure the URL is valid and accessible.")
                .font(.caption)
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
            ForEach(iapStore.iosProducts, id: \.id) { product in
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
                    latestPurchase = nil
                }
                .font(.caption)
                .foregroundColor(AppColors.primary)
            }

            Button {
                if let purchase = latestPurchase {
                    selectedPurchase = purchase
                }
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundColor(AppColors.primary)
                    Text(purchaseResultMessage)
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

    @ViewBuilder
    private func InstructionsCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppColors.primary)
                Text("How It Works")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                InstructionRow(
                    number: "1",
                    text: "Enter your external purchase URL above"
                )
                InstructionRow(
                    number: "2",
                    text: "Tap Purchase on any product"
                )
                InstructionRow(
                    number: "3",
                    text: "User will be redirected to the external URL"
                )
                InstructionRow(
                    number: "4",
                    text: "Complete purchase on your website"
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("⚠️ Important Notes")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.warning)

                Text("• iOS 16.0 or later required\n• Valid external URL needed\n• useAlternativeBilling: true is set\n• onPurchaseUpdated will NOT fire\n• Implement deep link to return to app")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }

    // MARK: - OpenIapStore Setup

    private func setupIapProvider() {
        print("🔷 [AlternativeBilling] Setting up OpenIapStore...")

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
                print("✅ [AlternativeBilling] Connection initialized")
                await loadProducts()
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to initialize connection: \(error.localizedDescription)"
                    showError = true
                }
            }

            await MainActor.run { isInitialLoading = false }
        }
    }

    private func teardownConnection() {
        print("🔷 [AlternativeBilling] Tearing down connection...")
        Task {
            try await iapStore.endConnection()
            print("✅ [AlternativeBilling] Connection ended")
        }
    }

    // MARK: - Product Loading

    private func loadProducts() async {
        do {
            try await iapStore.fetchProducts(skus: productIds, type: .inApp)
            await MainActor.run {
                if iapStore.iosProducts.isEmpty {
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

    // MARK: - Purchase Flow with Alternative Billing

    private func purchaseProduct(_ product: OpenIapProduct) {
        print("🛒 [AlternativeBilling] Starting alternative billing purchase for: \(product.id)")
        print("🌐 [AlternativeBilling] External URL: \(externalUrl)")

        Task {
            do {
                let requestType: ProductQueryType = product.type == .subs ? .subs : .inApp

                // Create request based on product type
                let request: RequestPurchaseProps.Request
                if requestType == .subs {
                    let subscriptionProps = RequestSubscriptionIosProps(
                        externalPurchaseUrlOnIOS: externalUrl,
                        sku: product.id
                    )

                    request = .subscription(RequestSubscriptionPropsByPlatforms(
                        android: nil,
                        ios: subscriptionProps
                    ))
                } else {
                    let iosProps = RequestPurchaseIosProps(
                        externalPurchaseUrlOnIOS: externalUrl,
                        sku: product.id
                    )

                    request = .purchase(RequestPurchasePropsByPlatforms(
                        android: nil,
                        ios: iosProps
                    ))
                }

                let params = RequestPurchaseProps(
                    request: request,
                    type: requestType,
                    useAlternativeBilling: true
                )

                _ = try await OpenIapModule.shared.requestPurchase(params)

                // When using external URL, the purchase is handled externally
                await MainActor.run {
                    purchaseResultMessage = """
                    🌐 Redirected to external URL
                    Product: \(product.id)
                    URL: \(externalUrl)

                    Complete the purchase on the external website.
                    Note: onPurchaseUpdated will NOT be called.
                    """
                    showPurchaseResult = true
                }

            } catch {
                print("❌ [AlternativeBilling] Purchase failed: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Alternative billing error: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    // MARK: - Event Handlers

    private func handlePurchaseSuccess(_ purchase: OpenIapPurchase) {
        print("✅ [AlternativeBilling] Purchase successful: \(purchase.productId)")

        // Update UI state
        let transactionDate = Date(timeIntervalSince1970: purchase.transactionDate / 1000)
        purchaseResultMessage = """
        ✅ Purchase successful
        Product: \(purchase.productId)
        Transaction ID: \(purchase.id)
        Date: \(DateFormatter.localizedString(from: transactionDate, dateStyle: .short, timeStyle: .short))
        """
        showPurchaseResult = true
        latestPurchase = purchase

        // In production, validate receipt on your server before finishing
        Task {
            await finishPurchase(purchase)
        }
    }

    private func handlePurchaseError(_ error: OpenIapError) {
        print("❌ [AlternativeBilling] Purchase error: \(error.message)")

        // Update UI state
        purchaseResultMessage = "❌ Purchase failed: \(error.message)"
        showPurchaseResult = true

        // Show error alert for non-cancellation errors
        if error.code != .userCancelled {
            errorMessage = error.message
            showError = true
        }
    }

    private func finishPurchase(_ purchase: OpenIapPurchase) async {
        do {
            try await iapStore.finishTransaction(purchase: purchase)
            print("✅ [AlternativeBilling] Transaction finished: \(purchase.id)")
        } catch {
            print("❌ [AlternativeBilling] Failed to finish transaction: \(error)")
            await MainActor.run {
                errorMessage = "Failed to finish transaction: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

#Preview {
    NavigationView {
        if #available(iOS 16.0, *) {
            AlternativeBillingScreen()
        } else {
            Text("iOS 16.0+ Required")
        }
    }
}
