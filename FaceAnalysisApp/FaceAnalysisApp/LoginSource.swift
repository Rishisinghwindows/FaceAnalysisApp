import Foundation

enum LoginSource: Equatable {
    case none
    case password
    case otp
    case social(SocialLoginProvider)

    init(storedValue: String?) {
        guard let storedValue else {
            self = .none
            return
        }

        switch storedValue {
        case "password":
            self = .password
        case "otp":
            self = .otp
        case "none":
            self = .none
        default:
            if storedValue.hasPrefix("social:"),
               let raw = storedValue.split(separator: ":", maxSplits: 1).last,
               let provider = SocialLoginProvider(rawValue: String(raw)) {
                self = .social(provider)
            } else {
                self = .none
            }
        }
    }

    var storedValue: String {
        switch self {
        case .none:
            return "none"
        case .password:
            return "password"
        case .otp:
            return "otp"
        case let .social(provider):
            return "social:\(provider.rawValue)"
        }
    }

    var providerDisplayName: String {
        switch self {
        case .none:
            return ""
        case .password:
            return "Email & Password"
        case .otp:
            return "Mobile OTP"
        case let .social(provider):
            return provider.displayName
        }
    }
}

extension SocialLoginProvider {
    var displayName: String {
        switch self {
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        case .facebook:
            return "Facebook"
        }
    }
}
