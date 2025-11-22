import SwiftUI

struct OnboardingView: View {
    @ObservedObject var flow: AppFlowController
    @State private var selection = 0
    @State private var animateBackground = false
    private let autoAdvance = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()

    private let pages = OnboardingPage.pages

    var body: some View {
        ZStack {
            AnimatedGradientBackground(colors: currentPage.gradient, animate: animateBackground)
            VStack(spacing: 24) {
                header
                OnboardingPageView(page: currentPage)
                pageIndicator
                actionArea
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
            .overlay(alignment: .topTrailing) {
                SkipButton {
                    flow.completeOnboarding()
                }
                .padding(.trailing, 24)
            }
        }
        .onAppear {
            animateBackground = true
        }
        .onReceive(autoAdvance) { _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                selection = (selection + 1) % pages.count
            }
        }
        .animation(.easeInOut(duration: 0.4), value: selection)
    }

    private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(L10n.Onboarding.title)
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(.white.opacity(0.95))
            .frame(maxWidth: .infinity, alignment: .leading)
        Text(L10n.Onboarding.subtitle)
            .font(.system(size: 15))
            .foregroundColor(.white.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

    private var pageIndicator: some View {
        HStack(spacing: 10) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(index == selection ? 0.9 : 0.25))
                    .frame(width: index == selection ? 32 : 12, height: 6)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selection)
            }
        }
        .accessibilityHidden(true)
    }

    private var actionArea: some View {
        VStack(spacing: 12) {
            Button(action: flow.completeOnboarding) {
                Text(L10n.Onboarding.getStartedButton)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button(action: flow.completeOnboarding) {
                Text(L10n.Login.skipButton)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
    }

    private var currentPage: OnboardingPage {
        pages[selection]
    }
}

private struct OnboardingPageView: View {
    @Environment(\.colorScheme) private var colorScheme
    let page: OnboardingPage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeroScene(style: page.style, colors: page.gradient)
                .frame(height: 240)
            Text(page.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            Text(page.subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary.opacity(0.75))
                .padding(.horizontal, 4)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView(.horizontal, showsIndicators: false) {
                let chipColor = page.gradient.first ?? Color.primaryPink
                HStack(spacing: 10) {
                    ForEach(page.keywords.indices, id: \.self) { index in
                        Text(page.keywords[index])
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(chipColor)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .stroke(chipColor, lineWidth: colorScheme == .dark ? 1.2 : 1)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.25))
                                    )
                            )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(colorScheme == .dark ? Color.black.opacity(0.45) : Color.white.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

private struct OnboardingHeroScene: View {
    let style: OnboardingHeroStyle
    let colors: [Color]

    @State private var scanOffset: CGFloat = -0.45
    @State private var breathing = false
    @State private var overlayOrbit: Double = 0
    @State private var sparkleRotation: Double = 0
    @State private var auraRotation: Double = 0
    @State private var particlePhase: Double = 0
    @State private var sparkPulse: Bool = false

    private var accentColors: [Color] {
        colors.isEmpty ? [Color.primaryPink, Color.resultPrimary] : colors
    }

    private var accentGradient: LinearGradient {
        LinearGradient(colors: accentColors, startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                auraLayer(in: size)
                particleHalo(in: size)
                heroContent(in: size)
            }
            .frame(width: size.width, height: size.height)
        }
        .onAppear(perform: startAnimations)
    }

    @ViewBuilder
    private func heroContent(in size: CGSize) -> some View {
        switch style {
        case .capture:
            captureScene(in: size)
        case .overlay:
            overlayScene(in: size)
        case .privacy:
            privacyScene(in: size)
        }
    }

    private func captureScene(in size: CGSize) -> some View {
        let outlineWidth = size.width * 0.6
        let outlineHeight = size.height * 0.75
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        return ZStack {
            ForEach(0..<4) { idx in
                Path { path in
                    let y = size.height * (0.25 + CGFloat(idx) * 0.15)
                    path.move(to: CGPoint(x: size.width * 0.15, y: y))
                    path.addLine(to: CGPoint(x: size.width * 0.85, y: y))
                }
                .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
            }

            RoundedRectangle(cornerRadius: outlineWidth / 2.2, style: .continuous)
                .fill(accentGradient)
                .opacity(0.35)
                .frame(width: outlineWidth, height: outlineHeight)
                .blendMode(.screen)

            RoundedRectangle(cornerRadius: outlineWidth / 2.2, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                .frame(width: outlineWidth, height: outlineHeight)

            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColors.first?.opacity(0.05) ?? Color.white.opacity(0.05),
                            Color.white.opacity(0.65),
                            accentColors.last?.opacity(0.05) ?? Color.white.opacity(0.05),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: outlineWidth * 1.05, height: outlineHeight * 0.35)
                .offset(y: scanOffset * outlineHeight)
                .blur(radius: 10)
                .blendMode(.screen)

            let anchorPoints: [CGPoint] = [
                CGPoint(x: -0.35, y: -0.15),
                CGPoint(x: 0.35, y: -0.15),
                CGPoint(x: -0.25, y: 0.2),
                CGPoint(x: 0.25, y: 0.2),
                CGPoint(x: 0, y: 0.5),
            ]
            ForEach(Array(anchorPoints.enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: Color.white.opacity(0.5), radius: 8, y: 2)
                    .position(
                        x: center.x + point.x * outlineWidth * 0.45,
                        y: center.y + point.y * outlineHeight * 0.6
                    )
                    .scaleEffect(breathing ? 1.08 : 0.95)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: breathing)
            }
        }
    }

    private func overlayScene(in size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.55)
        let baseRadius = size.width * 0.35

        return ZStack {
            Circle()
                .fill(accentGradient.opacity(0.4))
                .frame(width: size.width * 0.7, height: size.width * 0.7)

            ForEach(0..<3) { idx in
                Path { path in
                    let radius = baseRadius - CGFloat(idx) * 15
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(-20),
                        endAngle: .degrees(200),
                        clockwise: true
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: accentColors.reversed(),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: CGFloat(10 - idx * 2), lineCap: .round)
                )
                .opacity(Double(3 - idx) / 3.5)
            }

            Ellipse()
                .stroke(Color.white.opacity(0.45), lineWidth: 2)
                .frame(width: size.width * 0.6, height: size.height * 0.35)

            let orbitAngle = overlayOrbit * 360
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
                .position(
                    x: center.x + CGFloat(cos(orbitAngle * .pi / 180)) * baseRadius * 0.85,
                    y: center.y + CGFloat(sin(orbitAngle * .pi / 180)) * baseRadius * 0.55
                )
                .shadow(color: Color.white.opacity(0.7), radius: 12)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: breathing)

            ForEach(0..<3) { index in
                let offset = Double(index) * 120
                Capsule()
                    .fill(accentGradient)
                    .frame(width: 14, height: 70)
                    .opacity(0.35)
                    .rotationEffect(.degrees(offset + overlayOrbit * 360))
                    .position(center)
            }
        }
    }

    private func privacyScene(in size: CGSize) -> some View {
        let shieldWidth = size.width * 0.55

        return ZStack {
            ShieldShape()
                .fill(accentGradient)
                .frame(width: shieldWidth, height: size.height * 0.75)
                .shadow(color: accentColors.first?.opacity(0.4) ?? Color.black.opacity(0.2), radius: 20, y: 10)

            ShieldShape()
                .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                .frame(width: shieldWidth * 1.05, height: size.height * 0.78)

            Image(systemName: "lock.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                .offset(y: -6)

            Circle()
                .trim(from: 0.2, to: 0.95)
                .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: size.width * 0.9, height: size.width * 0.9)
                .rotationEffect(.degrees(sparkleRotation))

            ForEach(0..<5) { index in
                let angle = Double(index) / 5.0 * 360 + sparkleRotation
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 10, height: 10)
                    .position(
                        x: size.width / 2 + CGFloat(cos(angle * .pi / 180)) * size.width * 0.4,
                        y: size.height / 2 + CGFloat(sin(angle * .pi / 180)) * size.width * 0.4
                    )
                    .shadow(color: Color.white.opacity(0.5), radius: 8)
            }
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            scanOffset = 0.45
        }
        withAnimation {
            breathing = true
        }
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            overlayOrbit = 1
        }
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            sparkleRotation = 360
        }
        withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
            auraRotation = 360
        }
        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
            particlePhase = 360
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            sparkPulse = true
        }
    }

    private func auraLayer(in size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        accentColors.first?.opacity(0.9) ?? Color.primaryPink,
                        accentColors.last?.opacity(0.25) ?? Color.resultPrimary.opacity(0.25),
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: size.width * 0.8
                ))
                .scaleEffect(breathing ? 1.05 : 0.92)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: breathing)
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                .frame(width: size.width * 0.9, height: size.width * 0.9)
                .rotationEffect(.degrees(auraRotation))
                .blur(radius: 1)
            Circle()
                .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 12, lineCap: .round, dash: [80, 40]))
                .frame(width: size.width * 1.1, height: size.width * 1.1)
                .rotationEffect(.degrees(-auraRotation * 0.8))
        }
    }

    private func particleHalo(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<12) { index in
                let angle = (Double(index) / 12.0 * 360) + particlePhase
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 6, height: 6)
                    .scaleEffect(sparkPulse ? 1.3 : 0.8)
                    .position(
                        x: size.width / 2 + CGFloat(cos(angle * .pi / 180)) * size.width * 0.4,
                        y: size.height / 2 + CGFloat(sin(angle * .pi / 180)) * size.width * 0.28
                    )
                    .shadow(color: Color.white.opacity(0.4), radius: 6)
            }
        }
    }
}

private struct AnimatedGradientBackground: View {
    let colors: [Color]
    let animate: Bool
    @State private var rotation: Double = 0
    @State private var scalePulse = false

    var body: some View {
        let fallback = colors.isEmpty ? [Color.primaryPink, Color.resultPrimary] : colors
        ZStack {
            LinearGradient(
                colors: fallback,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.55)
            .blur(radius: 40)
            AngularGradient(
                gradient: Gradient(colors: fallback + fallback.reversed()),
                center: .center
            )
            .rotationEffect(.degrees(rotation))
            .opacity(0.35)
            Circle()
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 2)
                .scaleEffect(scalePulse ? 1.35 : 0.95)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: scalePulse)
                .offset(x: -80, y: -120)
            Circle()
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1.5)
                .scaleEffect(scalePulse ? 1.15 : 0.85)
                .offset(x: 120, y: 160)
        }
        .ignoresSafeArea()
        .onAppear {
            guard animate else { return }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            scalePulse = true
        }
    }
}

private struct SkipButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(L10n.Login.skipButton)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.95))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.25))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let icon: String
    let gradient: [Color]
    let keywords: [LocalizedStringKey]
    let style: OnboardingHeroStyle

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            title: L10n.Onboarding.captureTitle,
            subtitle: L10n.Onboarding.captureSubtitle,
            icon: "camera.metering.center.weighted",
            gradient: [Color.primaryPink, Color.resultPrimary],
            keywords: [
                L10n.Onboarding.captureHighlightOneTitle,
                L10n.Onboarding.captureHighlightTwoTitle
            ],
            style: .capture
        ),
        OnboardingPage(
            title: L10n.Onboarding.overlayTitle,
            subtitle: L10n.Onboarding.overlaySubtitle,
            icon: "wand.and.rays",
            gradient: [Color.resultPrimary, Color.blue.opacity(0.8)],
            keywords: [
                L10n.Onboarding.overlayHighlightOneTitle,
                L10n.Onboarding.overlayHighlightTwoTitle
            ],
            style: .overlay
        ),
        OnboardingPage(
            title: L10n.Onboarding.privacyTitle,
            subtitle: L10n.Onboarding.privacySubtitle,
            icon: "lock.shield",
            gradient: [Color.green.opacity(0.9), Color.primaryPink],
            keywords: [
                L10n.Onboarding.privacyHighlightOneTitle,
                L10n.Onboarding.privacyHighlightTwoTitle
            ],
            style: .privacy
        ),
    ]
}

private enum OnboardingHeroStyle {
    case capture
    case overlay
    case privacy
}

private struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let left = CGPoint(x: rect.minX, y: rect.midY * 0.9)
        let right = CGPoint(x: rect.maxX, y: rect.midY * 0.9)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)

        return Path { path in
            path.move(to: top)
            path.addQuadCurve(to: left, control: CGPoint(x: rect.minX, y: rect.minY + 10))
            path.addLine(to: bottom)
            path.addLine(to: right)
            path.addQuadCurve(to: top, control: CGPoint(x: rect.maxX, y: rect.minY + 10))
            path.closeSubpath()
        }
    }
}
