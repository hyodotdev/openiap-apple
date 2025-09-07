import Foundation
#if canImport(os)
import os
#endif

public enum OpenIapLog {
    public enum Level: String { case debug, info, warn, error }

    // Toggle to enable/disable logging from host app.
    public static var isEnabled: Bool = false

    // Optional external handler to integrate with app logging frameworks.
    public static var handler: ((Level, String) -> Void)? = nil

    #if canImport(os)
    static let osLogger = Logger(subsystem: "openiap", category: "OpenIap")
    #endif

    @inline(__always)
    public static func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    @inline(__always)
    public static func setHandler(_ custom: @escaping (Level, String) -> Void) {
        handler = custom
    }

    @inline(__always)
    public static func debug(_ message: String) { log(.debug, message) }

    @inline(__always)
    public static func info(_ message: String) { log(.info, message) }

    @inline(__always)
    public static func warn(_ message: String) { log(.warn, message) }

    @inline(__always)
    public static func error(_ message: String) { log(.error, message) }

    @inline(__always)
    static func log(_ level: Level, _ message: String) {
        guard isEnabled else { return }

        if let h = handler {
            h(level, message)
            return
        }

        #if canImport(os)
        switch level {
        case .debug:
            osLogger.debug("\(message, privacy: .public)")
        case .info:
            osLogger.info("\(message, privacy: .public)")
        case .warn:
            osLogger.warning("\(message, privacy: .public)")
        case .error:
            osLogger.error("\(message, privacy: .public)")
        }
        #else
        // Fallback to stdout if os Logger is unavailable
        print("[OpenIap][\(level.rawValue.uppercased())] \(message)")
        #endif
    }
}

