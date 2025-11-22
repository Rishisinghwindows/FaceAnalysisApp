import SwiftUI

struct SettingsView: View {
    @ObservedObject var flow: AppFlowController
    @State private var enableHaptics = true
    @State private var useCellularUploads = false
    @State private var showNotificationSettings = false
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var historyStore: AnalysisHistoryStore

    var body: some View {
        List {
            Section(header: Text("Profile")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aurora Vega")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                    Text("Premium Member")
                        .font(.system(size: 13))
                        .foregroundStyle(secondaryTextColor)
                }
                .padding(.vertical, 4)

                Button(action: flow.revisitTutorial) {
                    Label("View Tutorial Again", systemImage: "play.rectangle")
                }

                Button(action: flow.logout) {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.primary)
                }
            }

            Section(header: Text("Preferences")) {
                Toggle(isOn: $enableHaptics) {
                    Label("Enable haptic feedback", systemImage: "waveform")
                }

                Toggle(isOn: $useCellularUploads) {
                    Label("Allow cellular uploads", systemImage: "antenna.radiowaves.left.and.right")
                }

                Button(action: { showNotificationSettings = true }) {
                    Label("Notification settings", systemImage: "bell.badge")
                }
                .buttonStyle(.plain)

                Button(role: .destructive, action: historyStore.clear) {
                    Label("Clear analysis history", systemImage: "trash")
                }
            }

            Section(header: Text("About")) {
                NavigationLink(destination: AboutView()) {
                    Label("About FaceMap Beauty", systemImage: "info.circle")
                }

                NavigationLink(destination: TermsView()) {
                    Label("Terms & Conditions", systemImage: "doc.text")
                }
            }

            Section(header: Text("Support")) {
                NavigationLink(destination: SupportCardView()) {
                    Label("Contact support", systemImage: "envelope")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile")
        .sheet(isPresented: $showNotificationSettings) {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    NotificationsView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showNotificationSettings = false }
                            }
                        }
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }
}

private struct SupportCardView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Need a hand?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Text("Email us at support@facemapbeauty.app or message us in-app for personalized assistance. We aim to reply within one business day.")
                    .font(.system(size: 15))
                    .foregroundStyle(secondaryTextColor)

                Button(action: {}) {
                    Label("Start a support chat", systemImage: "bubble.right")
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
        .navigationTitle("Support")
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
}
