import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case french = "fr"
    case italian = "it"

    static let storageKey = "appLanguageCode"

    var id: String { rawValue }

    var localeIdentifier: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .french:
            return "Français (reserved)"
        case .italian:
            return "Italiano (reserved)"
        }
    }

    func displayName(in language: AppLanguage) -> String {
        guard language == .simplifiedChinese else { return displayName }
        switch self {
        case .english:
            return "英文"
        case .simplifiedChinese:
            return "简体中文"
        case .french:
            return "法语（预留）"
        case .italian:
            return "意大利语（预留）"
        }
    }

    var isSelectable: Bool {
        switch self {
        case .english, .simplifiedChinese:
            return true
        case .french, .italian:
            return false
        }
    }

    static var storedOrDefault: AppLanguage {
        if let code = UserDefaults.standard.string(forKey: storageKey),
           let language = AppLanguage(rawValue: code) {
            return language
        }

        let prefersChinese = Locale.preferredLanguages.contains { language in
            language.lowercased().hasPrefix("zh")
        }
        return prefersChinese ? .simplifiedChinese : .english
    }

    static func localizedString(_ key: String, language: AppLanguage = storedOrDefault) -> String {
        if let value = localizedValue(for: key, language: language) {
            return value
        }
        if language != .english, let value = localizedValue(for: key, language: .english) {
            return value
        }
        return key
    }

    static func localizedFormat(_ key: String, language: AppLanguage = storedOrDefault, _ arguments: CVarArg...) -> String {
        String(
            format: localizedString(key, language: language),
            locale: Locale(identifier: language.localeIdentifier),
            arguments: arguments
        )
    }

    static func localizedKnownSystemString(_ value: String, language: AppLanguage = storedOrDefault) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return value }

        if let key = systemValueKeys[normalizedSystemKey(trimmed)] {
            return localizedString(key, language: language)
        }
        if hasLocalizedValue(for: trimmed, language: language) || hasLocalizedValue(for: trimmed, language: .english) {
            return localizedString(trimmed, language: language)
        }
        return value
    }

    static func localizedStatus(_ value: String, language: AppLanguage = storedOrDefault) -> String {
        localizedKnownSystemString(value, language: language)
    }

    static func localizedServerMessage(_ message: String, language: AppLanguage = storedOrDefault) -> String {
        let localized = localizedKnownSystemString(message, language: language)
        if localized != message || language == .english {
            return localized
        }
        let containsEnglish = message.range(of: "[A-Za-z]", options: .regularExpression) != nil
        return containsEnglish ? localizedString("Request failed", language: language) : message
    }

    static func localizedErrorDescription(_ error: Error, language: AppLanguage = storedOrDefault) -> String {
        let description = error.localizedDescription
        guard language != .english else { return description }
        let containsEnglish = description.range(of: "[A-Za-z]", options: .regularExpression) != nil
        return containsEnglish ? localizedString("Operation failed", language: language) : description
    }

    private static func localizedValue(for key: String, language: AppLanguage) -> String? {
        guard let bundle = bundle(for: language) else { return nil }
        let missing = "__MISSING_LOCALIZATION__\(key)"
        let value = bundle.localizedString(forKey: key, value: missing, table: nil)
        return value == missing ? nil : value
    }

    private static func hasLocalizedValue(for key: String, language: AppLanguage) -> Bool {
        localizedValue(for: key, language: language) != nil
    }

    private static func bundle(for language: AppLanguage) -> Bundle? {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }

    private static func normalizedSystemKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .lowercased()
    }

    private static let systemValueKeys: [String: String] = [
        "active": "Active",
        "approved": "Approved",
        "area": "Area",
        "confirmed": "Confirmed",
        "completed": "Completed",
        "day": "Day",
        "dimension": "Dimension",
        "door": "Door",
        "draft": "Draft",
        "ea": "Each",
        "each": "Each",
        "fixture": "Fixture",
        "hr": "Hour",
        "hour": "Hour",
        "inactive": "Inactive",
        "issued": "Issued",
        "issue": "Issue",
        "job": "Job",
        "light": "Light",
        "ln ft": "Linear Foot",
        "lot": "Lot",
        "note": "Note",
        "opening": "Opening",
        "outlet": "Outlet",
        "pending": "Pending",
        "priced": "Priced",
        "product": "Product",
        "quoted": "Quoted",
        "room": "Room",
        "service": "Service",
        "sq ft": "Square Foot",
        "sqft": "Square Foot",
        "tbd": "TBD",
        "client": "Client",
        "company": "Company",
        "allowance": "Allowance",
        "admin": "Admin",
        "black": "Black",
        "brushed nickel": "Brushed Nickel",
        "chrome": "Chrome",
        "member": "Member",
        "matte black": "Matte Black",
        "owner": "Owner",
        "vanity": "Vanity",
        "toilet": "Toilet",
        "shower": "Shower",
        "tile": "Tile",
        "install service": "Install Service",
        "demo service": "Demo Service",
        "white": "White"
    ]
}

extension AppLanguage {
    var isChinese: Bool {
        self == .simplifiedChinese
    }
}

@MainActor
final class AppLocalization: ObservableObject {
    @Published private(set) var language: AppLanguage

    init() {
        language = AppLanguage.storedOrDefault
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
    }

    func setLanguage(_ language: AppLanguage) {
        guard language.isSelectable else { return }
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
        self.language = language
    }
}
