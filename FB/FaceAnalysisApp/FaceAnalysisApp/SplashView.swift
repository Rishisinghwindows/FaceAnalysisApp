import SwiftUI

struct SplashView: View {
    @ObservedObject var flow: AppFlowController
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.primaryPink.opacity(0.85), Color.backgroundDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 220, height: 220)
                        .scaleEffect(pulse ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)

                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 160, height: 160)

                    Image(systemName: "face.smiling.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(Color.white.opacity(0.95))
                }

                VStack(spacing: 10) {
                    Text(L10n.Splash.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color.white)

                    Text(L10n.Splash.subtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
        }
        .onAppear {
            pulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                flow.advanceFromSplash()
            }
        }
    }
}
