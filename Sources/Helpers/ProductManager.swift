import Foundation
import StoreKit

/// Thread-safe product manager backed by Swift actor
@available(iOS 15.0, macOS 12.0, *)
actor ProductManager {
    private var products: [String: Product] = [:]
    
    func addProduct(_ product: Product) {
        products[product.id] = product
    }
    
    func getProduct(productID: String) -> Product? {
        return products[productID]
    }
    
    func getAllProducts() -> [Product] {
        return Array(products.values)
    }
    
    func removeAll() {
        products.removeAll()
    }
    
    func remove(productID: String) {
        products.removeValue(forKey: productID)
    }
}
