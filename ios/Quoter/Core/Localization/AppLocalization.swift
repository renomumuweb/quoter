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
