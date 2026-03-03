import Foundation

enum Weight {
    /// Formatted with unit: "135 lb" or "135.5 lb"
    static func formatted(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value)) lb" : String(format: "%.1f lb", value)
    }

    /// Raw numeric string: "135" or "135.5"
    static func rawValue(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }
}
