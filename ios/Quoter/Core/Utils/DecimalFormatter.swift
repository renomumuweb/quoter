import Foundation

enum DecimalFormatter {
    static func currency(_ value: Decimal, code: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = Locale(identifier: AppLanguage.storedOrDefault.localeIdentifier)
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    static func roundedMoney(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .bankers)
        return output
    }
}
