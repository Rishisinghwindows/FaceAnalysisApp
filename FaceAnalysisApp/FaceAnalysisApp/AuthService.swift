import Combine
import Foundation

enum SocialLoginProvider: String, CaseIterable, Identifiable, Codable {
    case apple
    case google
    case facebook

    var id: String { rawValue }

    var apiSlug: String { rawValue }

    var demoToken: String {
        switch self {
        case .apple: return "apple-demo-token"
        case .google: return "google-demo-token"
        case .facebook: return "facebook-demo-token"
        }
    }

    var demoEmail: String {
        "demo+\(rawValue)@facemapbeauty.ai"
    }

    var demoDisplayName: String {
        switch self {
        case .apple: return "Apple Guest"
        case .google: return "Google Guest"
        case .facebook: return "Facebook Guest"
        }
    }
}

struct AuthenticatedUser: Equatable, Codable {
    let email: String
    let name: String
}

struct AuthSession: Equatable, Codable {
    let token: String
    let tokenType: String
    let expiresAt: Date
    let user: AuthenticatedUser
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case invalidResponse
    case encodingFailed
    case invalidPhone
    case invalidOTP
    case server(String)
    case network(URLError)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return L10n.AuthError.invalidCredentials
        case .invalidResponse:
            return L10n.AuthError.invalidResponse
        case .encodingFailed:
            return L10n.AuthError.encodingFailed
        case .invalidPhone:
            return L10n.AuthError.invalidPhone
        case .invalidOTP:
            return L10n.AuthError.invalidOTP
        case let .server(message):
            return message
        case let .network(error):
            if error.code == .notConnectedToInternet {
                return L10n.AuthError.offline
            }
            return L10n.AuthError.network
        case .unknown:
            return L10n.AuthError.unknown
        }
    }
}

protocol Authenticating {
    func login(email: String, password: String, rememberMe: Bool) -> AnyPublisher<AuthSession, AuthError>
    func requestOTP(phoneNumber: String) -> AnyPublisher<OTPDispatchResponse, AuthError>
    func verifyOTP(phoneNumber: String, code: String) -> AnyPublisher<AuthSession, AuthError>
    func loginWithSocial(provider: SocialLoginProvider, token: String, email: String?, name: String?) -> AnyPublisher<AuthSession, AuthError>
}

final class AuthService: Authenticating {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://localhost:8000")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func login(email: String, password: String, rememberMe: Bool) -> AnyPublisher<AuthSession, AuthError> {
        let payload = LoginRequestPayload(email: email, password: password, rememberMe: rememberMe)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/login"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try encoder.encode(payload)
        } catch {
            return Fail(error: AuthError.encodingFailed).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: request)
            .mapError { AuthError.network($0) }
            .tryMap { data, response -> AuthSession in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AuthError.invalidResponse
                }

                guard 200 ..< 300 ~= httpResponse.statusCode else {
                    if httpResponse.statusCode == 401 {
                        throw AuthError.invalidCredentials
                    }

                    if let serverMessage = try? JSONDecoder().decode(ServerErrorMessage.self, from: data) {
                        let detail = serverMessage.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                        throw AuthError.server(detail.isEmpty ? L10n.AuthError.genericServer : detail)
                    }

                    throw AuthError.server(L10n.AuthError.statusCode(httpResponse.statusCode))
                }

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let payload = try decoder.decode(LoginResponsePayload.self, from: data)

                let expiresAt = Date().addingTimeInterval(TimeInterval(payload.expiresIn))
                let user = AuthenticatedUser(email: payload.user.email, name: payload.user.name)

                return AuthSession(
                    token: payload.accessToken,
                    tokenType: payload.tokenType,
                    expiresAt: expiresAt,
                    user: user
                )
            }
            .mapError { error -> AuthError in
                if let authError = error as? AuthError {
                    return authError
                }
                if let urlError = error as? URLError {
                    return .network(urlError)
                }
                return .unknown
            }
            .eraseToAnyPublisher()
    }

    func requestOTP(phoneNumber: String) -> AnyPublisher<OTPDispatchResponse, AuthError> {
        let payload = OTPRequestPayload(phoneNumber: phoneNumber)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/otp/request"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try encoder.encode(payload)
        } catch {
            return Fail(error: AuthError.encodingFailed).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: request)
            .mapError { AuthError.network($0) }
            .tryMap { data, response -> OTPDispatchResponse in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AuthError.invalidResponse
                }

                guard 200 ..< 300 ~= httpResponse.statusCode else {
                    if httpResponse.statusCode == 404 {
                        throw AuthError.invalidPhone
                    }

                    if let serverMessage = try? JSONDecoder().decode(ServerErrorMessage.self, from: data) {
                        let detail = serverMessage.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                        throw AuthError.server(detail.isEmpty ? L10n.AuthError.genericServer : detail)
                    }

                    throw AuthError.server(L10n.AuthError.statusCode(httpResponse.statusCode))
                }

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(OTPDispatchResponse.self, from: data)
            }
            .mapError { error -> AuthError in
                if let authError = error as? AuthError {
                    return authError
                }
                if let urlError = error as? URLError {
                    return .network(urlError)
                }
                return .unknown
            }
            .eraseToAnyPublisher()
    }

    func verifyOTP(phoneNumber: String, code: String) -> AnyPublisher<AuthSession, AuthError> {
        let payload = OTPVerifyPayload(phoneNumber: phoneNumber, code: code)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/otp/verify"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try encoder.encode(payload)
        } catch {
            return Fail(error: AuthError.encodingFailed).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: request)
            .mapError { AuthError.network($0) }
            .tryMap { data, response -> AuthSession in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AuthError.invalidResponse
                }

                guard 200 ..< 300 ~= httpResponse.statusCode else {
                    if httpResponse.statusCode == 400 {
                        throw AuthError.invalidOTP
                    }
                    if httpResponse.statusCode == 404 {
                        throw AuthError.invalidPhone
                    }

                    if let serverMessage = try? JSONDecoder().decode(ServerErrorMessage.self, from: data) {
                        let detail = serverMessage.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                        throw AuthError.server(detail.isEmpty ? L10n.AuthError.genericServer : detail)
                    }

                    throw AuthError.server(L10n.AuthError.statusCode(httpResponse.statusCode))
                }

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let payload = try decoder.decode(LoginResponsePayload.self, from: data)

                let expiresAt = Date().addingTimeInterval(TimeInterval(payload.expiresIn))
                let user = AuthenticatedUser(email: payload.user.email, name: payload.user.name)

                return AuthSession(
                    token: payload.accessToken,
                    tokenType: payload.tokenType,
                    expiresAt: expiresAt,
                    user: user
                )
            }
            .mapError { error -> AuthError in
                if let authError = error as? AuthError {
                    return authError
                }
                if let urlError = error as? URLError {
                    return .network(urlError)
                }
                return .unknown
            }
            .eraseToAnyPublisher()
    }

    func loginWithSocial(provider: SocialLoginProvider, token: String, email: String?, name: String?) -> AnyPublisher<AuthSession, AuthError> {
        let payload = SocialLoginRequestPayload(token: token, email: email, name: name)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        var request = URLRequest(
            url: baseURL.appendingPathComponent("/api/login/social/\(provider.apiSlug)")
        )
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try encoder.encode(payload)
        } catch {
            return Fail(error: AuthError.encodingFailed).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: request)
            .mapError { AuthError.network($0) }
            .tryMap { data, response -> AuthSession in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AuthError.invalidResponse
                }

                guard 200 ..< 300 ~= httpResponse.statusCode else {
                    if httpResponse.statusCode == 401 {
                        throw AuthError.invalidCredentials
                    }

                    if let serverMessage = try? JSONDecoder().decode(ServerErrorMessage.self, from: data) {
                        let detail = serverMessage.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                        throw AuthError.server(detail.isEmpty ? L10n.AuthError.genericServer : detail)
                    }

                    throw AuthError.server(L10n.AuthError.statusCode(httpResponse.statusCode))
                }

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let payload = try decoder.decode(LoginResponsePayload.self, from: data)
                let expiresAt = Date().addingTimeInterval(TimeInterval(payload.expiresIn))
                let user = AuthenticatedUser(email: payload.user.email, name: payload.user.name)

                return AuthSession(
                    token: payload.accessToken,
                    tokenType: payload.tokenType,
                    expiresAt: expiresAt,
                    user: user
                )
            }
            .mapError { error -> AuthError in
                if let authError = error as? AuthError {
                    return authError
                }
                if let urlError = error as? URLError {
                    return .network(urlError)
                }
                return .unknown
            }
            .eraseToAnyPublisher()
    }
}

private struct LoginRequestPayload: Encodable {
    let email: String
    let password: String
    let rememberMe: Bool
}

private struct LoginResponsePayload: Decodable {
    struct User: Decodable {
        let email: String
        let name: String
    }

    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let user: User
}

private struct ServerErrorMessage: Decodable {
    let detail: String
}

private struct OTPRequestPayload: Encodable {
    let phoneNumber: String
}

private struct OTPVerifyPayload: Encodable {
    let phoneNumber: String
    let code: String
}

private struct SocialLoginRequestPayload: Encodable {
    let token: String
    let email: String?
    let name: String?
}

struct OTPDispatchResponse: Decodable {
    let expiresIn: Int
    let message: String
    let codePreview: String?
}
