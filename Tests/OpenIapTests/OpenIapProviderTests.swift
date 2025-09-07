import XCTest
@testable import OpenIAP

@available(iOS 15.0, macOS 14.0, *)
final class OpenIapProviderTests: XCTestCase {
    
    @MainActor
    func testExplicitConnectionManagement() async throws {
        // Test 1: Creating OpenIapProvider does not automatically initialize connection
        let provider1 = OpenIapProvider()
        
        // The provider should NOT be connected yet
        XCTAssertFalse(provider1.isConnected, "OpenIapProvider should not connect automatically")
        
        // Explicitly initialize connection
        try await provider1.initConnection()
        XCTAssertTrue(provider1.isConnected, "OpenIapProvider should be connected after initConnection")
        
        // Test 2: Multiple providers can coexist with explicit connection
        let provider2 = OpenIapProvider()
        XCTAssertFalse(provider2.isConnected, "Second OpenIapProvider should not be connected automatically")
        
        try await provider2.initConnection()
        XCTAssertTrue(provider2.isConnected, "Second OpenIapProvider should be connected after initConnection")
        
        // Clean up connections
        try await provider1.endConnection()
        try await provider2.endConnection()
        
        XCTAssertFalse(provider1.isConnected, "Provider1 should be disconnected after endConnection")
        XCTAssertFalse(provider2.isConnected, "Provider2 should be disconnected after endConnection")
    }
    
    @MainActor
    func testListenerManagement() async throws {
        let module = OpenIapModule.shared
        
        // Initialize connection first
        _ = try await module.initConnection()
        
        // Add a listener
        var purchaseSubscription: Subscription? = module.purchaseUpdatedListener { _ in
            print("Purchase updated")
        }
        
        // Listener should work with the connection established
        
        // Remove the listener
        if let subscription = purchaseSubscription {
            module.removeListener(subscription)
        }
        purchaseSubscription = nil
        
        // End connection explicitly
        _ = try await module.endConnection()
    }
    
    @MainActor
    func testMultipleListeners() async throws {
        let module = OpenIapModule.shared
        
        // Initialize connection first
        _ = try await module.initConnection()
        
        // Add multiple listeners
        let sub1 = module.purchaseUpdatedListener { _ in }
        let sub2 = module.purchaseErrorListener { _ in }
        let sub3 = module.promotedProductListenerIOS { _ in }
        
        // All listeners should work with the established connection
        
        // Remove listeners one by one
        module.removeListener(sub1)
        module.removeListener(sub2)
        module.removeListener(sub3)
        
        // End connection explicitly
        _ = try await module.endConnection()
        // Listeners should be cleaned up automatically on endConnection
    }
    
    @MainActor
    func testListenerCleanupOnEndConnection() async throws {
        let module = OpenIapModule.shared
        
        // Initialize connection
        _ = try await module.initConnection()
        
        // Create subscriptions
        autoreleasepool {
            _ = module.purchaseUpdatedListener { _ in
                print("This will be cleaned up on endConnection")
            }
            _ = module.purchaseErrorListener { _ in
                print("This will also be cleaned up")
            }
        }
        
        // End connection - should clean up all listeners
        _ = try await module.endConnection()
        
        // All listeners should have been cleaned up automatically
    }
}