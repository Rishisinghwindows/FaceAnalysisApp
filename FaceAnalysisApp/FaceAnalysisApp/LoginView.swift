import SwiftUI
import UIKit

struct LoginView: View {
    @ObservedObject var flow: AppFlowController
    @StateObject private var viewModel = LoginViewModel()
    @State private var isShowingTerms = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer().frame(height: 12)

                VStack(spacing: 10) {
                    Text(L10n.Login.welcomeTitle)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(primaryTextColor)

                    Text(L10n.Login.welcomeSubtitle)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(secondaryTextColor)
                        .padding(.horizontal, 28)
                }

                socialLoginSection

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Button(action: { flow.completeLogin() }) {
                    Text(L10n.Login.skipButton)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.primaryPink)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)

                VStack(spacing: 8) {
                    Button(action: { isShowingTerms = true }) {
                        Text(L10n.Login.termsText)
                            .font(.system(size: 12))
                            .foregroundStyle(secondaryTextColor)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 12)
            }
        }
        .sheet(isPresented: $isShowingTerms) {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    TermsView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { isShowingTerms = false }
                            }
                        }
                }
            } else {
                // Fallback on earlier versions
            }
        }
        .onReceive(viewModel.sessionPublisher) { session in
            flow.completeLogin(
                with: session,
                skipTutorial: viewModel.shouldSkipTutorialForLastLogin,
                source: viewModel.lastCompletionSource
            )
        }
    }

    private func handleGoogleSignInTap() {
        guard let controller = UIApplication.shared.topViewController() else {
            viewModel.errorMessage = L10n.Login.socialGooglePresenterMissingMessage
            return
        }
        viewModel.beginSocialLogin(.google, presentingController: controller)
    }

    private var socialLoginSection: some View {
        VStack(spacing: 14) {
            socialDivider

            VStack(spacing: 12) {
                SocialLoginButton(
                    title: L10n.Login.socialApple,
                    iconSystemName: "apple.logo",
                    background: Color.black,
                    foreground: Color.white,
                    borderColor: .black.opacity(0.8),
                    isLoading: viewModel.isSocialLoading(.apple),
                    isDisabled: isSocialActionsDisabled(excluding: .apple),
                    action: { viewModel.beginSocialLogin(.apple) }
                )

                SocialLoginButton(
                    title: L10n.Login.socialGoogle,
                    iconSystemName: "globe",
                    background: colorScheme == .dark ? Color.cardDark : Color.cardLight,
                    foreground: colorScheme == .dark ? Color.white : Color.black,
                    borderColor: borderColor,
                    isLoading: viewModel.isSocialLoading(.google),
                    isDisabled: isSocialActionsDisabled(excluding: .google),
                    action: handleGoogleSignInTap
                )

                SocialLoginButton(
                    title: L10n.Login.socialFacebook,
                    iconSystemName: "f.cursive.circle.fill",
                    background: Color(hex: 0x1877F2),
                    foreground: Color.white,
                    borderColor: Color(hex: 0x1877F2),
                    isLoading: viewModel.isSocialLoading(.facebook),
                    isDisabled: isSocialActionsDisabled(excluding: .facebook),
                    action: { viewModel.beginSocialLogin(.facebook) }
                )
            }

            Text(L10n.Login.socialDisclaimer)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(secondaryTextColor)
        }
        .padding(.horizontal, 20)
    }

    private var socialDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(borderColor.opacity(0.7))
                .frame(height: 1)
            Text(L10n.Login.socialDivider)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(secondaryTextColor)
            Rectangle()
                .fill(borderColor.opacity(0.7))
                .frame(height: 1)
        }
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.borderDark : Color.borderLight
    }

    private func isSocialActionsDisabled(excluding provider: SocialLoginProvider) -> Bool {
        if let active = viewModel.socialInFlight {
            return active != provider
        }
        return viewModel.isLoading
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.textDark : Color.textLight
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.subtleDark : Color.subtleLight
    }
}

private struct SocialLoginButton: View {
    let title: LocalizedStringKey
    let iconSystemName: String
    let background: Color
    let foreground: Color
    let borderColor: Color
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(foreground)
                    } else {
                        Image(systemName: iconSystemName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(foreground)
                    }
                    Spacer()
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(foreground)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: colorScheme == .dark ? 1.2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity((isDisabled && !isLoading) ? 0.6 : 1)
    }
}
