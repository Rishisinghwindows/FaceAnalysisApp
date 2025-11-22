import SwiftUI

final class ThemeManager: ObservableObject {
    enum Theme: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var colorScheme: ColorScheme? {
            switch self {
            case .system:
                return nil
            case .light:
                return .light
            case .dark:
                return .dark
            }
        }

        var label: LocalizedStringKey {
            switch self {
            case .system:
                return L10n.Settings.themeSystem
            case .light:
                return L10n.Settings.themeLight
            case .dark:
                return L10n.Settings.themeDark
            }
        }
    }

    @Published var selectedTheme: Theme {
        didSet {
            storage.set(selectedTheme.rawValue, forKey: storageKey)
        }
    }

    private let storage: UserDefaults
    private let storageKey = "appearance.selectedTheme"

    init(storage: UserDefaults = .standard) {
        self.storage = storage
        if let storedValue = storage.string(forKey: storageKey),
           let theme = Theme(rawValue: storedValue) {
            selectedTheme = theme
        } else {
            selectedTheme = .system
        }
    }

    var colorScheme: ColorScheme? {
        selectedTheme.colorScheme
    }
}

@main
struct FaceAnalysisApp: App {
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
