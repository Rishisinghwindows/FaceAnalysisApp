import Foundation
import SwiftUI

enum L10n {
    enum General {
        static let ok: LocalizedStringKey = "general.ok"
        static let done: LocalizedStringKey = "general.done"
    }

    enum Login {
        static let welcomeTitle: LocalizedStringKey = "login.welcome_title"
        static let welcomeSubtitle: LocalizedStringKey = "login.welcome_subtitle"
        static let emailLabel: LocalizedStringKey = "login.email_label"
        static let emailPlaceholder: LocalizedStringKey = "login.email_placeholder"
        static let passwordLabel: LocalizedStringKey = "login.password_label"
        static let passwordPlaceholder: LocalizedStringKey = "login.password_placeholder"
        static let rememberMe: LocalizedStringKey = "login.remember_me"
        static let signInButton: LocalizedStringKey = "login.sign_in_button"
        static let skipButton: LocalizedStringKey = "login.skip_button"
        static let termsText: LocalizedStringKey = "login.terms_text"
        static let supportText: LocalizedStringKey = "login.support_text"

        static var invalidFormMessage: String {
            String(localized: "login.invalid_form_message")
        }
    }

    enum AuthError {
        static var invalidCredentials: String { String(localized: "auth.error.invalid_credentials") }
        static var encodingFailed: String { String(localized: "auth.error.encoding_failed") }
        static var invalidResponse: String { String(localized: "auth.error.invalid_response") }
        static var genericServer: String { String(localized: "auth.error.generic_server") }
        static var offline: String { String(localized: "auth.error.offline") }
        static var network: String { String(localized: "auth.error.network") }
        static var unknown: String { String(localized: "auth.error.unknown") }

        static func statusCode(_ code: Int) -> String {
            String(format: String(localized: "auth.error.server_status"), code)
        }
    }

    enum Home {
        static let tabAnalyze: LocalizedStringKey = "home.tab.analyze"
        static let tabHistory: LocalizedStringKey = "home.tab.history"
        static let tabProfile: LocalizedStringKey = "home.tab.profile"
    }

    enum Splash {
        static let title: LocalizedStringKey = "splash.title"
        static let subtitle: LocalizedStringKey = "splash.subtitle"
    }

    enum History {
        static let title: LocalizedStringKey = "history.title"
        static let subtitle: LocalizedStringKey = "history.subtitle"
        static let emptyTitle: LocalizedStringKey = "history.empty.title"
        static let emptySubtitle: LocalizedStringKey = "history.empty.subtitle"
        static let sectionRecent: LocalizedStringKey = "history.section.recent"
        static let clearAll: LocalizedStringKey = "history.clear_all"

        static func undertoneTag(_ value: String) -> String {
            String(
                format: String(localized: "history.tag.undertone"),
                locale: Locale.current,
                value
            )
        }

        static func skinToneTag(_ value: String) -> String {
            String(
                format: String(localized: "history.tag.skin_tone"),
                locale: Locale.current,
                value
            )
        }
    }

    enum Content {
        static let headerTitle: LocalizedStringKey = "content.header.title"
        static let headerSubtitle: LocalizedStringKey = "content.header.subtitle"
        static let promptTapAdd: LocalizedStringKey = "content.prompt.tap_add"
        static let buttonTakeSelfie: LocalizedStringKey = "content.button.take_selfie"
        static let buttonSelectPhoto: LocalizedStringKey = "content.button.select_photo"
        static let buttonClearPhoto: LocalizedStringKey = "content.button.clear_photo"
        static let alertCameraUnavailable: LocalizedStringKey = "content.alert.camera_unavailable.title"
        static let alertCameraMessage: LocalizedStringKey = "content.alert.camera_unavailable.message"
        static let alertAnalysisFailed: LocalizedStringKey = "content.alert.analysis_failed.title"
        static var alertAnalysisMessageFallback: String { String(localized: "content.alert.analysis_failed.message") }
        static let analyzeButtonIdle: LocalizedStringKey = "content.button.analyze.idle"
        static let analyzeButtonRunning: LocalizedStringKey = "content.button.analyze.running"
        static let stepFaceShapeTitle: LocalizedStringKey = "content.step.face_shape.title"
        static let stepFaceShapeSubtitle: LocalizedStringKey = "content.step.face_shape.subtitle"
        static let stepSkinToneTitle: LocalizedStringKey = "content.step.skin_tone.title"
        static let stepSkinToneSubtitle: LocalizedStringKey = "content.step.skin_tone.subtitle"
        static let stepGoldenTitle: LocalizedStringKey = "content.step.golden.title"
        static let stepGoldenSubtitle: LocalizedStringKey = "content.step.golden.subtitle"
    }
}
