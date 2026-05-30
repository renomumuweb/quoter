import Foundation

struct Money: Codable, Hashable {
    let amount: Decimal
    let currency: String

    static let zero = Money(amount: 0, currency: "USD")
}
