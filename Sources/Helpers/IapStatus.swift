import Foundation

/// Standard status management for OpenIAP
/// This is a proposed addition to the OpenIAP specification for tracking operation states
@available(iOS 15.0, macOS 14.0, *)
public struct IapStatus {
    // MARK: - Loading States
    
    /// Structured loading states for different operations
    public var loadings: LoadingStates = LoadingStates()
    
    // MARK: - Data States
    
    /// Latest purchase result data
    public var lastPurchaseResult: PurchaseResultData?
    
    /// Latest error data
    public var lastError: ErrorData?
    
    // MARK: - Operation Tracking
    
    /// Current operation being performed
    public var currentOperation: IapOperation?
    
    /// History of recent operations (limited to last 10)
    public var operationHistory: [IapOperation] = []
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Helper Methods
    
    /// Check if a specific product is being purchased
    public func isPurchasing(_ productId: String) -> Bool {
        return loadings.purchasing.contains(productId)
    }
    
    /// Check if any loading operation is in progress
    public var isLoading: Bool {
        return loadings.initConnection || 
               loadings.fetchProducts || 
               loadings.restorePurchases || 
               !loadings.purchasing.isEmpty
    }
    
    /// Add operation to history (maintains max 10 items)
    public mutating func addToHistory(_ operation: IapOperation) {
        operationHistory.insert(operation, at: 0)
        if operationHistory.count > 10 {
            operationHistory.removeLast()
        }
    }
    
    /// Reset all states to initial values
    public mutating func reset() {
        loadings = LoadingStates()
        lastPurchaseResult = nil
        lastError = nil
        currentOperation = nil
        operationHistory.removeAll()
    }
}

/// Structured loading states for different IAP operations
@available(iOS 15.0, macOS 14.0, *)
public struct LoadingStates {
    /// Connection initialization loading
    public var initConnection: Bool = false
    
    /// Product fetching loading
    public var fetchProducts: Bool = false
    
    /// Purchase restoration loading
    public var restorePurchases: Bool = false
    
    /// Product IDs currently being purchased
    public var purchasing: Set<String> = []
    
    public init() {}
}

/// Purchase result data
@available(iOS 15.0, macOS 14.0, *)
public struct PurchaseResultData {
    public let productId: String
    public let transactionId: String
    public let timestamp: Date
    public let message: String
    
    public init(
        productId: String,
        transactionId: String,
        timestamp: Date = Date(),
        message: String
    ) {
        self.productId = productId
        self.transactionId = transactionId
        self.timestamp = timestamp
        self.message = message
    }
}

/// Error data
@available(iOS 15.0, macOS 14.0, *)
public struct ErrorData {
    public let code: String
    public let message: String
    public let productId: String?
    public let timestamp: Date
    
    public init(
        code: String,
        message: String,
        productId: String? = nil,
        timestamp: Date = Date()
    ) {
        self.code = code
        self.message = message
        self.productId = productId
        self.timestamp = timestamp
    }
}

/// Represents an IAP operation for tracking
@available(iOS 15.0, macOS 14.0, *)
public struct IapOperation: Identifiable, Equatable {
    public let id = UUID()
    public let type: IapOperationType
    public let productId: String?
    public let timestamp: Date
    public let result: IapOperationResult?
    
    public init(
        type: IapOperationType,
        productId: String? = nil,
        result: IapOperationResult? = nil
    ) {
        self.type = type
        self.productId = productId
        self.timestamp = Date()
        self.result = result
    }
}

/// Types of IAP operations
@available(iOS 15.0, macOS 14.0, *)
public enum IapOperationType: String, CaseIterable {
    case initConnection = "init_connection"
    case endConnection = "end_connection"
    case fetchProducts = "fetch_products"
    case requestPurchase = "request_purchase"
    case finishTransaction = "finish_transaction"
    case restorePurchases = "restore_purchases"
    case validateReceipt = "validate_receipt"
}

/// Result of an IAP operation
@available(iOS 15.0, macOS 14.0, *)
public enum IapOperationResult: Equatable {
    case success
    case failure(String)
    case cancelled
}