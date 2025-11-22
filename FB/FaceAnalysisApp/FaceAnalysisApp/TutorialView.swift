import SwiftUI

struct TutorialView: View {
    @ObservedObject var flow: AppFlowController
    @State private var selection = 0
    @Environment(\.colorScheme) private var colorScheme

    private let pages: [TutorialPage] = [
        TutorialPage(
            title: "Capture with Confidence",
            message: "Find soft, even lighting and center your face within the guide circle.",
            icon: "camera.fill"
        ),
        TutorialPage(
            title: "Balanced Proportions",
            message: "We study facial ratios — including the classical 1:1.618 golden ratio — to understand how your features harmonize.",
            icon: "face.smiling"
        ),
        TutorialPage(
            title: "Personalized Playbook",
            message: "Receive shade matches and placement tips that celebrate your undertone, face shape, and distinctive balance.",
            icon: "sparkles"
        )
    ]

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button(action: flow.completeTutorial) {
                        Text("Skip")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.primaryPink)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                TabView(selection: $selection) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        TutorialCard(page: page)
                            .padding(.horizontal, 24)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == selection ? Color.primaryPink : Color.primaryPink.opacity(0.25))
                            .frame(width: index == selection ? 28 : 12, height: 6)
                            .animation(.easeInOut(duration: 0.2), value: selection)
                    }
                }

                Button(action: advance) {
                    Text(selection == pages.count - 1 ? "Get Started" : "Next")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.primaryPink)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 24)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 12)
            }
        }
    }

    private func advance() {
        if selection < pages.count - 1 {
            selection += 1
        } else {
            flow.completeTutorial()
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight
    }
}

private struct TutorialPage {
    let title: String
    let message: String
    let icon: String
}

private struct TutorialCard: View {
    let page: TutorialPage
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(cardBackground)
                    .frame(height: 280)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.1), radius: 20, y: 10)

                VStack(spacing: 24) {
                    Circle()
                        .fill(Color.primaryPink.opacity(colorScheme == .dark ? 0.3 : 0.15))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: page.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 52, height: 52)
                                .foregroundStyle(Color.primaryPink)
                        )

                    VStack(spacing: 12) {
                        Text(page.title)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(primaryTextColor)

                        Text(page.message)
                            .font(.system(size: 15))
                            .foregroundStyle(secondaryTextColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.cardDark : Color.cardLight
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.textDark : Color.textLight
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.subtleDark : Color.subtleLight
    }
}
