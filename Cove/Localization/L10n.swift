import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case zhHans = "zh-Hans"
    case en

    static let defaultsKey = "cove.appLanguage"

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .system: L10n.tr("Follow System")
        case .zhHans: "简体中文"
        case .en: "English"
        }
    }
}

@Observable
final class LanguageManager: @unchecked Sendable {
    static let shared = LanguageManager()

    private let lock = NSLock()
    @ObservationIgnored private var _language: AppLanguage

    var language: AppLanguage {
        get {
            access(keyPath: \.language)
            lock.lock()
            defer { lock.unlock() }
            return _language
        }
        set {
            withMutation(keyPath: \.language) {
                lock.lock()
                _language = newValue
                lock.unlock()
                UserDefaults.standard.set(newValue.rawValue, forKey: AppLanguage.defaultsKey)
            }
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: AppLanguage.defaultsKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
        self._language = saved
    }

    var resolvedLanguageCode: String {
        switch language {
        case .zhHans:
            return "zh-Hans"
        case .en:
            return "en"
        case .system:
            if let preferred = Locale.preferredLanguages.first,
               preferred.lowercased().hasPrefix("zh") {
                return "zh-Hans"
            }
            return "en"
        }
    }

    var locale: Locale {
        switch language {
        case .system: .autoupdatingCurrent
        case .zhHans: Locale(identifier: "zh-Hans")
        case .en: Locale(identifier: "en")
        }
    }
}

enum L10n {
    private static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }

    private static var activeBundle: Bundle {
        let code = LanguageManager.shared.resolvedLanguageCode
        if let path = resourceBundle.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return resourceBundle
    }

    static func tr(_ key: String) -> String {
        activeBundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        let pattern = tr(key)
        return String(format: pattern, locale: LanguageManager.shared.locale, arguments: args)
    }

    private static let folderGroupNames: Set<String> = [
        "Aggregates",
        "Collections",
        "Columns",
        "Constraints",
        "Dictionaries",
        "Events",
        "Functions",
        "Hashes",
        "Indexes",
        "Lists",
        "Materialized Views",
        "Packages",
        "Parts",
        "Procedures",
        "Sequences",
        "Sets",
        "Sorted Sets",
        "Streams",
        "Strings",
        "Tables",
        "Triggers",
        "Types",
        "Views",
    ]

    private static let specialNodeIcons: [String: String] = [
        "(no aliases)": "minus.circle",
        "Aliases": "arrow.triangle.branch",
        "Mappings": "list.bullet.rectangle",
        "Settings": "gearshape",
    ]

    static func treeNodeLabel(_ label: String, icon: String) -> String {
        if icon == "folder", folderGroupNames.contains(label) {
            return tr("tree.group.\(label)")
        }
        if specialNodeIcons[label] == icon {
            return tr("tree.group.\(label)")
        }
        return label
    }

    private static let localizableOptions: Set<String> = [
        "No",
        "Yes",
        "Strings",
        "Hashes",
        "Lists",
        "Sets",
        "Sorted Sets",
        "Streams",
    ]

    static func optionLabel(_ option: String) -> String {
        guard localizableOptions.contains(option) else { return option }
        return tr("option.\(option)")
    }

    private static let localizableCompletionDetails: Set<String> = [
        "function",
        "keyword",
        "schema",
        "table",
    ]

    static func completionDetail(_ detail: String) -> String {
        guard localizableCompletionDetails.contains(detail) else { return detail }
        return tr("completion.\(detail)")
    }
}
