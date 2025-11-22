import Combine
import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var rememberMe = true
    @Published var isLoading = false
    @Published var errorMessage: String?

    var sessionPublisher: AnyPublisher<AuthSession, Never> {
        sessionSubject.eraseToAnyPublisher()
    }

    private let service: Authenticating
    private let sessionSubject = PassthroughSubject<AuthSession, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(service: Authenticating = AuthService()) {
        self.service = service
    }

    var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    func resetError() {
        errorMessage = nil
    }

    func login() {
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
                self.sessionSubject.send(session)
            }
            .store(in: &cancellables)
    }
}
