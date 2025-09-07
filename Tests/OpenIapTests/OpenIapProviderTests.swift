import XCTest
@testable import OpenIAP

@available(iOS 15.0, macOS 14.0, *)
final class OpenIapProviderTests: XCTestCase {
    
    @MainActor
    func testExplicitConnectionManagement() async throws {
        // Test 1: Creating OpenIapStore does not automatically initialize connection
        let store1 = OpenIapStore()
        
        // The store should NOT be connected yet
        XCTAssertFalse(store1.isConnected, "OpenIapStore should not connect automatically")
        
        // Explicitly initialize connection
        try await store1.initConnection()
        XCTAssertTrue(store1.isConnected, "OpenIapStore should be connected after initConnection")
        
        // Test 2: Multiple stores can coexist with explicit connection
        let store2 = OpenIapStore()
        XCTAssertFalse(store2.isConnected, "Second OpenIapStore should not be connected automatically")
        
        try await store2.initConnection()
        XCTAssertTrue(store2.isConnected, "Second OpenIapStore should be connected after initConnection")
        
        // Clean up connections
        try await store1.endConnection()
        try await store2.endConnection()
        
        XCTAssertFalse(store1.isConnected, "Store1 should be disconnected after endConnection")
        XCTAssertFalse(store2.isConnected, "Store2 should be disconnected after endConnection")
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