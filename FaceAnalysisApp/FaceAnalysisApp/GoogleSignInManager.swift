import Foundation
import GoogleSignIn
import UIKit

struct GoogleSignInPayload {
    let idToken: String
    let email: String?
    let fullName: String?
}

enum GoogleSignInError: LocalizedError {
    case configurationMissing
    case tokenMissing

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return L10n.Login.socialGoogleConfigMissingMessage
        case .tokenMissing:
            return L10n.Login.socialGoogleTokenMissingMessage
        }
    }
}

final class GoogleSignInManager {
    static let shared = GoogleSignInManager()

    private var configuration: GIDConfiguration?

    private init() {
        configuration = Self.loadConfiguration()
    }

    func signIn(presenting controller: UIViewController, completion: @escaping (Result<GoogleSignInPayload, Error>) -> Void) {
        guard let configuration else {
            finish(.failure(GoogleSignInError.configurationMissing), completion: completion)
            return
        }

        GIDSignIn.sharedInstance.configuration = configuration
        GIDSignIn.sharedInstance.signIn(withPresenting: controller) { result, error in
            if let error {
                self.finish(.failure(error), completion: completion)
                return
            }

            guard
                let user = result?.user,
                let token = user.idToken?.tokenString
            else {
                self.finish(.failure(GoogleSignInError.tokenMissing), completion: completion)
                return
            }

            self.finish(
                .success(
                    GoogleSignInPayload(
                        idToken: token,
                        email: user.profile?.email,
                        fullName: user.profile?.name
                    )
                ),
                completion: completion
            )
        }
    }

    private static func loadConfiguration() -> GIDConfiguration? {
        let resourceURL = Bundle.main.url(forResource: "credentials", withExtension: "plist", subdirectory: "Configuration") ??
            Bundle.main.url(forResource: "credentials", withExtension: "plist")
        guard
            let url = resourceURL,
            let dictionary = NSDictionary(contentsOf: url),
            let clientID = dictionary["CLIENT_ID"] as? String
        else {
            return nil
        }

        return GIDConfiguration(clientID: clientID)
    }

    private func finish(
        _ result: Result<GoogleSignInPayload, Error>,
        completion: @escaping (Result<GoogleSignInPayload, Error>) -> Void
    ) {
        if Thread.isMainThread {
            completion(result)
        } else {
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
