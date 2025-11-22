import SwiftUI
import UIKit

struct LanguageSettingsView: View {
    private let languages = AppLanguage.supported
    private let currentLanguageCode = Locale.preferredLanguages.first ?? Locale.current.identifier
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        List {
            Section(
                header: Text(L10n.Settings.languageTitle),
                footer: Text(L10n.Settings.languageSubtitle)
                    .font(.footnote)
                    .foregroundStyle(secondaryTextColor)
            ) {
                ForEach(languages) { language in
                    HStack {
                        Text(language.displayName)
                        Spacer()
                        if language.matches(code: currentLanguageCode) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.primaryPink)
                        }
                    }
                }
            }

            Section(header: Text(L10n.Settings.instructionsTitle)) {
                Text(L10n.Settings.instructionsBody)
                    .font(.system(size: 14))
                    .foregroundStyle(secondaryTextColor)
                    .padding(.vertical, 4)

                Button(action: openSystemSettings) {
                    Label(L10n.Settings.openSystemSettings, systemImage: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.primaryPink)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(L10n.Settings.languageTitle)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.subtleDark : Color.subtleLight
    }
}

private struct AppLanguage: Identifiable {
    let code: String
    let name: String
    let flag: String

    var id: String { code }

    var displayName: String {
        "\(flag) \(name)"
    }

    func matches(code localeIdentifier: String) -> Bool {
        localeIdentifier.hasPrefix(code)
    }

    static let supported: [AppLanguage] = [
        AppLanguage(code: "en", name: "English", flag: "🇺🇸"),
        AppLanguage(code: "es", name: "Español", flag: "🇪🇸"),
        AppLanguage(code: "ar", name: "العربية", flag: "🇦🇪"),
        AppLanguage(code: "hi", name: "हिन्दी", flag: "🇮🇳")
    ]
}
