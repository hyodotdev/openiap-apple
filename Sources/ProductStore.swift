import Foundation
import StoreKit

/// Thread-safe product cache
@available(iOS 15.0, macOS 12.0, *)
class ProductStore {
    private var products: [String: Product] = [:]
    private let queue = DispatchQueue(label: "ProductStore", attributes: .concurrent)
    
    func addProduct(_ product: Product) {
        queue.async(flags: .barrier) {
            self.products[product.id] = product
        }
    }
    
    func getProduct(productID: String) -> Product? {
        return queue.sync {
            return products[productID]
        }
    }
    
    func getAllProducts() -> [Product] {
        return queue.sync {
            return Array(products.values)
        }
    }
    
    func removeAll() {
        queue.async(flags: .barrier) {
            self.products.removeAll()
        }
    }
    
    func remove(productID: String) {
        queue.async(flags: .barrier) {
            self.products.removeValue(forKey: productID)
        }
    }
}