import SwiftUI

struct SettingsView: View {
    @ObservedObject var flow: AppFlowController
    @State private var enableHaptics = true
    @State private var useCellularUploads = false
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var historyStore: AnalysisHistoryStore
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        List {
            Section(header: Text(L10n.Settings.profileSection)) {
                VStack(alignment: .leading, spacing: 6) {
                    profileDisplayName
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                    profileSubtitleText
                        .font(.system(size: 13))
                        .foregroundStyle(secondaryTextColor)
                }
                .padding(.vertical, 4)

                Button(action: flow.revisitTutorial) {
                    Label(L10n.Settings.viewTutorial, systemImage: "play.rectangle")
                }

                Button(action: flow.revisitOnboarding) {
                    Label(L10n.Settings.replayOnboarding, systemImage: "sparkles.tv")
                }

                Button(action: flow.logout) {
                    Label(L10n.Settings.signOut, systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.primary)
                }
            }

            Section(header: Text(L10n.Settings.preferencesSection)) {
                Toggle(isOn: $enableHaptics) {
                    Label(L10n.Settings.hapticsToggle, systemImage: "waveform")
                }

                Toggle(isOn: $useCellularUploads) {
                    Label(L10n.Settings.cellularToggle, systemImage: "antenna.radiowaves.left.and.right")
                }

                NavigationLink(destination: NotificationsView()) {
                    Label(L10n.Settings.notificationSettings, systemImage: "bell.badge")
                }

                NavigationLink(destination: LanguageSettingsView()) {
                    Label(L10n.Settings.languageTitle, systemImage: "character.book.closed")
                }

                Button(role: .destructive, action: historyStore.clear) {
                    Label(L10n.Settings.clearHistory, systemImage: "trash")
                }
            }

            Section(header: Text(L10n.Settings.themeSection)) {
                Picker(L10n.Settings.themeSection, selection: $themeManager.selectedTheme) {
                    ForEach(ThemeManager.Theme.allCases) { theme in
                        Text(theme.label)
                            .tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text(L10n.Settings.aboutSection)) {
                NavigationLink(destination: AboutView()) {
                    Label(L10n.Settings.aboutApp, systemImage: "info.circle")
                }

                NavigationLink(destination: TermsView()) {
                    Label(L10n.Settings.termsConditions, systemImage: "doc.text")
                }
            }

            Section(header: Text(L10n.Settings.supportSection)) {
                NavigationLink(destination: SupportCardView()) {
                    Label(L10n.Settings.contactSupport, systemImage: "envelope")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.Settings.title)
    }
}

private struct SupportCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.Support.needHelpTitle)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Text(L10n.Support.description)
                    .font(.system(size: 15))
                    .foregroundStyle(secondaryTextColor)

                Button(action: {}) {
                    Label(L10n.Support.startChat, systemImage: "bubble.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.primaryPink)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle(L10n.Settings.supportSection)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.textDark : Color.textLight
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.subtleDark : Color.subtleLight
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight
    }
}

private extension SettingsView {
    var primaryTextColor: Color {
        colorScheme == .dark ? Color.textDark : Color.textLight
    }

    var secondaryTextColor: Color {
        colorScheme == .dark ? Color.subtleDark : Color.subtleLight
    }

    var profileDisplayName: Text {
        guard let name = flow.session?.user.name.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return Text(L10n.Settings.profileGuestName)
        }
        return Text(name)
    }

    var profileSubtitleText: Text {
        switch flow.lastLoginSource {
        case .none:
            return Text(L10n.Settings.profileSourceGuest)
        case .password:
            return Text(L10n.Settings.profileSourceEmail)
        case .otp:
            return Text(L10n.Settings.profileSourceOTP)
        case let .social(provider):
            return Text(L10n.Settings.profileSourceSocial(provider.displayName))
        }
    }
}
