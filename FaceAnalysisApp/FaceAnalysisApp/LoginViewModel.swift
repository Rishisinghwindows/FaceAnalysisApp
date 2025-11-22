import Combine
import Foundation
import GoogleSignIn
import UIKit

@MainActor
final class LoginViewModel: ObservableObject {
    enum LoginMode: String, CaseIterable, Identifiable {
        case password
        case otp

        var id: String { rawValue }
    }

    @Published var email = ""
    @Published var password = ""
    @Published var rememberMe = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var mode: LoginMode = .password {
        didSet {
            if mode != oldValue {
                resetForMode()
            }
        }
    }
    @Published var phoneNumber = ""
    @Published var otpCode = ""
    @Published var isRequestingOTP = false
    @Published var otpStatusMessage: String?
    @Published var selectedCountry: PhoneCountry
    @Published private(set) var socialInFlight: SocialLoginProvider?
    let countries: [PhoneCountry]

    var sessionPublisher: AnyPublisher<AuthSession, Never> {
        sessionSubject.eraseToAnyPublisher()
    }

    private let service: Authenticating
    private let sessionSubject = PassthroughSubject<AuthSession, Never>()
    private var cancellables = Set<AnyCancellable>()
    private let socialDemoCredentials: [SocialLoginProvider: SocialDemoCredential]
    private let googleSignInManager = GoogleSignInManager.shared
    private(set) var lastCompletionSource: LoginSource = .none

    init(service: Authenticating = AuthService()) {
        self.service = service
        self.countries = PhoneCountry.defaultRegions
        self.selectedCountry = PhoneCountry.defaultRegions.first ?? PhoneCountry(code: "US", name: "United States", dialCode: "+1", flag: "🇺🇸", minDigits: 10, maxDigits: 10)
        self.socialDemoCredentials = [
            .apple: SocialDemoCredential(
                token: SocialLoginProvider.apple.demoToken,
                email: SocialLoginProvider.apple.demoEmail,
                name: SocialLoginProvider.apple.demoDisplayName
            ),
            .google: SocialDemoCredential(
                token: SocialLoginProvider.google.demoToken,
                email: SocialLoginProvider.google.demoEmail,
                name: SocialLoginProvider.google.demoDisplayName
            ),
            .facebook: SocialDemoCredential(
                token: SocialLoginProvider.facebook.demoToken,
                email: SocialLoginProvider.facebook.demoEmail,
                name: SocialLoginProvider.facebook.demoDisplayName
            ),
        ]
    }

    var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    var canSubmit: Bool {
        guard socialInFlight == nil else { return false }
        switch mode {
        case .password:
            return isFormValid && !isLoading
        case .otp:
            return !otpCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
        }
    }

    var canRequestOTP: Bool {
        guard socialInFlight == nil else { return false }
        let digits = digitsOnlyPhone()
        return selectedCountry.isValid(length: digits.count) && !isRequestingOTP && !isLoading
    }

    var shouldSkipTutorialForLastLogin: Bool {
        if case .social = lastCompletionSource {
            return true
        }
        return false
    }

    func resetError() {
        errorMessage = nil
    }

    private func resetForMode() {
        errorMessage = nil
        otpStatusMessage = nil
        otpCode = ""
        if mode == .password {
            isRequestingOTP = false
        }
    }

    func updatePhoneNumber(_ rawValue: String) {
        let digits = rawValue.filter(\.isNumber)
        let limited = String(digits.prefix(selectedCountry.maxDigits))
        phoneNumber = limited
        if !selectedCountry.isValid(length: limited.count) {
            errorMessage = nil
        }
    }

    private func formattedPhoneNumber() -> String {
        let digits = digitsOnlyPhone()
        return selectedCountry.dialCode + digits
    }

    private func digitsOnlyPhone() -> String {
        phoneNumber.filter(\.isNumber)
    }

    private func ensureValidPhoneLength() -> Bool {
        let length = digitsOnlyPhone().count
        guard selectedCountry.isValid(length: length) else {
            errorMessage = L10n.Login.invalidPhoneLength(selectedCountry.name, selectedCountry.digitDescription)
            return false
        }
        return true
    }

    func login() {
        guard mode == .password else { return }
        guard socialInFlight == nil else { return }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        let sanitizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitizedEmail.isEmpty, !password.isEmpty else {
            isLoading = false
            errorMessage = L10n.Login.invalidFormMessage
            return
        }

        email = sanitizedEmail

        service.login(email: sanitizedEmail, password: password, rememberMe: rememberMe)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case let .failure(error) = completion {
                    self.errorMessage = error.errorDescription ?? AuthError.unknown.errorDescription
                }
            } receiveValue: { [weak self] session in
                guard let self else { return }
                self.lastCompletionSource = .password
                self.sessionSubject.send(session)
            }
            .store(in: &cancellables)
    }

    func requestOTP() {
        guard mode == .otp, canRequestOTP else { return }
        guard socialInFlight == nil else { return }
        isRequestingOTP = true
        errorMessage = nil
        otpStatusMessage = nil

        guard ensureValidPhoneLength() else {
            isRequestingOTP = false
            return
        }

        let sanitizedPhone = formattedPhoneNumber()
        service.requestOTP(phoneNumber: sanitizedPhone)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isRequestingOTP = false
                if case let .failure(error) = completion {
                    self.errorMessage = error.errorDescription ?? AuthError.unknown.errorDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.otpStatusMessage = {
                    if let preview = response.codePreview {
                        return "\(L10n.Login.otpRequestedMessage)\n\(L10n.Login.otpPreview(preview))"
                    }
                    return L10n.Login.otpRequestedMessage
                }()
            }
            .store(in: &cancellables)
    }

    func verifyOTP() {
        guard mode == .otp, !isLoading else { return }
        guard socialInFlight == nil else { return }

        let localDigits = digitsOnlyPhone()
        let trimmedCode = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !localDigits.isEmpty, !trimmedCode.isEmpty else {
            errorMessage = L10n.Login.invalidFormMessage
            return
        }

        guard ensureValidPhoneLength() else {
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        service.verifyOTP(phoneNumber: formattedPhoneNumber(), code: trimmedCode)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case let .failure(error) = completion {
                    self.errorMessage = error.errorDescription ?? AuthError.unknown.errorDescription
                }
            } receiveValue: { [weak self] session in
                guard let self else { return }
                self.lastCompletionSource = .otp
                self.sessionSubject.send(session)
            }
            .store(in: &cancellables)
    }

    func beginSocialLogin(_ provider: SocialLoginProvider, presentingController: UIViewController? = nil) {
        switch provider {
        case .google:
            guard let controller = presentingController else {
                errorMessage = L10n.Login.socialGooglePresenterMissingMessage
                return
            }
            startGoogleSignIn(presenting: controller)
        case .apple, .facebook:
            startPlaceholderSocialLogin(provider: provider)
        }
    }

    private func startPlaceholderSocialLogin(provider: SocialLoginProvider) {
        guard socialInFlight == nil else { return }
        errorMessage = nil

        let credential = socialDemoCredentials[provider] ?? SocialDemoCredential(
            token: provider.demoToken,
            email: provider.demoEmail,
            name: provider.demoDisplayName
        )

        sendSocialLoginRequest(
            provider: provider,
            token: credential.token,
            email: credential.email,
            name: credential.name
        )
    }

    private func startGoogleSignIn(presenting controller: UIViewController) {
        guard socialInFlight == nil else { return }
        socialInFlight = .google
        errorMessage = nil

        googleSignInManager.signIn(presenting: controller) { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(payload):
                self.sendSocialLoginRequest(
                    provider: .google,
                    token: payload.idToken,
                    email: payload.email,
                    name: payload.fullName
                )
            case let .failure(error):
                self.socialInFlight = nil
                let nsError = error as NSError
                let googleDomain = "com.google.GIDSignIn"
                if nsError.domain == googleDomain,
                   GIDSignInError.Code(rawValue: nsError.code) == .canceled {
                    self.errorMessage = nil
                    return
                }
                if let localized = (error as? LocalizedError)?.errorDescription {
                    self.errorMessage = localized
                } else {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func sendSocialLoginRequest(
        provider: SocialLoginProvider,
        token: String,
        email: String?,
        name: String?
    ) {
        socialInFlight = provider
        service.loginWithSocial(provider: provider, token: token, email: email, name: name)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.socialInFlight = nil
                if case let .failure(error) = completion {
                    self.errorMessage = error.errorDescription ?? AuthError.unknown.errorDescription
                }
            } receiveValue: { [weak self] session in
                guard let self else { return }
                self.lastCompletionSource = .social(provider)
                self.sessionSubject.send(session)
            }
            .store(in: &cancellables)
    }

    func isSocialLoading(_ provider: SocialLoginProvider) -> Bool {
        socialInFlight == provider
    }
}

struct PhoneCountry: Identifiable, Equatable {
    let code: String
    let name: String
    let dialCode: String
    let flag: String
    let minDigits: Int
    let maxDigits: Int

    var id: String { code }

    var displayTitle: String {
        "\(flag) \(name) \(dialCode)"
    }

    var digitDescription: String {
        minDigits == maxDigits ? "\(minDigits)" : "\(minDigits)-\(maxDigits)"
    }

    func isValid(length: Int) -> Bool {
        length >= minDigits && length <= maxDigits
    }

    static let defaultRegions: [PhoneCountry] = [
        PhoneCountry(code: "US", name: "United States", dialCode: "+1", flag: "🇺🇸", minDigits: 10, maxDigits: 10),
        PhoneCountry(code: "IN", name: "India", dialCode: "+91", flag: "🇮🇳", minDigits: 10, maxDigits: 10),
        PhoneCountry(code: "GB", name: "United Kingdom", dialCode: "+44", flag: "🇬🇧", minDigits: 10, maxDigits: 10),
        PhoneCountry(code: "AE", name: "United Arab Emirates", dialCode: "+971", flag: "🇦🇪", minDigits: 9, maxDigits: 9),
        PhoneCountry(code: "ES", name: "Spain", dialCode: "+34", flag: "🇪🇸", minDigits: 9, maxDigits: 9)
    ]
}

private struct SocialDemoCredential {
    let token: String
    let email: String?
    let name: String?
}
