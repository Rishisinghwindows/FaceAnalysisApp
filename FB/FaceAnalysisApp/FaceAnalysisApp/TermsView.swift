import SwiftUI

struct TermsView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Terms & Conditions")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Text("Last updated: January 2024")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(secondaryTextColor)

                Divider()

                Group {
                    section(title: "Privacy") {
                        Text("FaceMap Beauty performs all processing on-device. Photos and derived data are never uploaded, stored on remote servers, or shared without your explicit action.")
                    }

                    section(title: "Usage") {
                        Text("You may use the app for personal, non-commercial purposes. Reverse engineering or attempting to extract proprietary models is prohibited.")
                    }

                    section(title: "Health disclaimer") {
                        Text("FaceMap Beauty offers cosmetic guidance only. It does not diagnose, treat, or provide medical advice. Consult licensed professionals for dermatological care.")
                    }

                    section(title: "Content") {
                        Text("Generated mappings and recommendations are suggestions. You retain responsibility for any looks shared or saved from the app.")
                    }

                    section(title: "Changes") {
                        Text("We may update these terms as features evolve. We’ll notify you in-app before material changes take effect.")
                    }
                }
                .font(.system(size: 15))
                .foregroundStyle(Color.subtleLight)
            }
            .padding(24)
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("Terms")
    }

    private func section(title: String, content: () -> Text) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primaryPink)

            content()
                .foregroundStyle(secondaryTextColor)
        }
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
