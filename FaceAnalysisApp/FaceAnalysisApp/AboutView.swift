import SwiftUI

struct AboutView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("About FaceMap Beauty")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Text("FaceMap Beauty celebrates every face with guidance grounded in color theory, artistry, and ethical AI. All analysis happens on-device, giving you total control over your imagery and insights.")
                    .font(.system(size: 16))
                    .foregroundStyle(secondaryTextColor)

                Divider()

                VStack(alignment: .leading, spacing: 14) {
                    Label("On-device computation", systemImage: "lock.shield")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(primaryTextColor)

                    Text("Your photos never leave your device. Our algorithms run locally so your data is always private.")
                        .font(.system(size: 15))
                        .foregroundStyle(secondaryTextColor)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label("Inclusive recommendations", systemImage: "hands.sparkles")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(primaryTextColor)

                    Text("We meticulously test our shade ranges and placement advice across undertones, face shapes, and lighting conditions.")
                        .font(.system(size: 15))
                        .foregroundStyle(secondaryTextColor)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label("Artist-designed guidance", systemImage: "paintpalette")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(primaryTextColor)

                    Text("Our makeup artists collaborated with engineers to translate professional techniques into approachable routines.")
                        .font(.system(size: 15))
                        .foregroundStyle(secondaryTextColor)
                }
            }
            .padding(24)
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("About")
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
