import SwiftUI

struct LoginView: View {
    @ObservedObject var flow: AppFlowController
    @StateObject private var viewModel = LoginViewModel()
    @State private var isShowingTerms = false
    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) private var colorScheme

    private enum Field {
        case email
        case password
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 32) {
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

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.Login.emailLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(primaryTextColor)

                        TextField(L10n.Login.emailPlaceholder, text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(borderColor, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .onChange(of: viewModel.email) { _ in viewModel.resetError() }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.Login.passwordLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(primaryTextColor)

                        SecureField(L10n.Login.passwordPlaceholder, text: $viewModel.password)
                            .textContentType(.password)
                            .padding()
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(borderColor, lineWidth: 1)
                            )
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { signIn() }
                            .onChange(of: viewModel.password) { _ in viewModel.resetError() }
                    }

                    Toggle(isOn: $viewModel.rememberMe) {
                        Text(L10n.Login.rememberMe)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(secondaryTextColor)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Color.primaryPink))
                }
                .padding(24)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 12, y: 4)
                .padding(.horizontal, 20)

                VStack(spacing: 16) {
                    Button(action: signIn) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.primaryPink)

                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text(L10n.Login.signInButton)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .disabled(!viewModel.isFormValid || viewModel.isLoading)

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
                }

                VStack(spacing: 8) {
                    Button(action: { isShowingTerms = true }) {
                        Text(L10n.Login.termsText)
                            .font(.system(size: 12))
                            .foregroundStyle(secondaryTextColor)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(.plain)

                    Button(action: { focusedField = .email }) {
                        Text(L10n.Login.supportText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.primaryPink)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onTapGesture {
            focusedField = nil
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
            flow.completeLogin(with: session)
        }
    }

    private func signIn() {
        focusedField = nil

        viewModel.login()
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.cardDark : Color.cardLight
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.borderDark : Color.borderLight
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
