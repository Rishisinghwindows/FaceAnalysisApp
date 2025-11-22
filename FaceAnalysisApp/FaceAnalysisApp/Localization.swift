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
        static let phoneLabel: LocalizedStringKey = "login.phone_label"
        static let phonePlaceholder: LocalizedStringKey = "login.phone_placeholder"
        static let otpCodeLabel: LocalizedStringKey = "login.otp_label"
        static let otpCodePlaceholder: LocalizedStringKey = "login.otp_placeholder"
        static let requestOTPButton: LocalizedStringKey = "login.request_otp_button"
        static let verifyOTPButton: LocalizedStringKey = "login.verify_otp_button"
        static let methodEmail: LocalizedStringKey = "login.method.email"
        static let methodPhone: LocalizedStringKey = "login.method.phone"
        static let countryLabel: LocalizedStringKey = "login.country_label"
        static let socialDivider: LocalizedStringKey = "login.social.divider"
        static let socialApple: LocalizedStringKey = "login.social.apple"
        static let socialGoogle: LocalizedStringKey = "login.social.google"
        static let socialFacebook: LocalizedStringKey = "login.social.facebook"
        static let socialDisclaimer: LocalizedStringKey = "login.social.disclaimer"
        static let socialGoogleUnavailable: LocalizedStringKey = "login.social.google_unavailable"
        static var socialGoogleConfigMissingMessage: String { String(localized: "login.social.google_config_missing") }
        static var socialGoogleTokenMissingMessage: String { String(localized: "login.social.google_token_missing") }
        static var socialGooglePresenterMissingMessage: String { String(localized: "login.social.google_presenter_missing") }

        static var invalidFormMessage: String {
            String(localized: "login.invalid_form_message")
        }

        static var otpRequestedMessage: String {
            String(localized: "login.otp_requested_message")
        }

        static func otpPreview(_ code: String) -> String {
            String(format: String(localized: "login.otp_preview"), code)
        }

        static func invalidPhoneLength(_ country: String, _ digits: String) -> String {
            String(
                format: String(localized: "login.phone_length_error"),
                country,
                digits
            )
        }
    }

    enum AuthError {
        static var invalidCredentials: String { String(localized: "auth.error.invalid_credentials") }
        static var encodingFailed: String { String(localized: "auth.error.encoding_failed") }
        static var invalidResponse: String { String(localized: "auth.error.invalid_response") }
        static var invalidPhone: String { String(localized: "auth.error.invalid_phone") }
        static var invalidOTP: String { String(localized: "auth.error.invalid_otp") }
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

    enum Tutorial {
        static let title: LocalizedStringKey = "tutorial.title"
        static let subtitle: LocalizedStringKey = "tutorial.subtitle"
        static let skip: LocalizedStringKey = "tutorial.skip"
        static let begin: LocalizedStringKey = "tutorial.begin"
        static let stepCaptureTitle: LocalizedStringKey = "tutorial.step.capture.title"
        static let stepCaptureBody: LocalizedStringKey = "tutorial.step.capture.body"
        static let stepLightingTitle: LocalizedStringKey = "tutorial.step.lighting.title"
        static let stepLightingBody: LocalizedStringKey = "tutorial.step.lighting.body"
        static let stepAnglesTitle: LocalizedStringKey = "tutorial.step.angles.title"
        static let stepAnglesBody: LocalizedStringKey = "tutorial.step.angles.body"
        static let stepPrivacyTitle: LocalizedStringKey = "tutorial.step.privacy.title"
        static let stepPrivacyBody: LocalizedStringKey = "tutorial.step.privacy.body"
    }

    enum Settings {
        static let title: LocalizedStringKey = "settings.title"
        static let profileSection: LocalizedStringKey = "settings.profile.section"
        static let profileTier: LocalizedStringKey = "settings.profile.tier"
        static let viewTutorial: LocalizedStringKey = "settings.profile.view_tutorial"
        static let replayOnboarding: LocalizedStringKey = "settings.profile.replay_onboarding"
        static let signOut: LocalizedStringKey = "settings.profile.sign_out"
        static let preferencesSection: LocalizedStringKey = "settings.preferences.section"
        static let hapticsToggle: LocalizedStringKey = "settings.preferences.haptics"
        static let cellularToggle: LocalizedStringKey = "settings.preferences.cellular"
        static let notificationSettings: LocalizedStringKey = "settings.preferences.notifications"
        static let clearHistory: LocalizedStringKey = "settings.preferences.clear_history"
        static let themeSection: LocalizedStringKey = "settings.theme.section"
        static let themeSystem: LocalizedStringKey = "settings.theme.system"
        static let themeLight: LocalizedStringKey = "settings.theme.light"
        static let themeDark: LocalizedStringKey = "settings.theme.dark"
        static let aboutSection: LocalizedStringKey = "settings.about.section"
        static let aboutApp: LocalizedStringKey = "settings.about.app"
        static let termsConditions: LocalizedStringKey = "settings.about.terms"
        static let supportSection: LocalizedStringKey = "settings.support.section"
        static let contactSupport: LocalizedStringKey = "settings.support.contact"
        static let languageTitle: LocalizedStringKey = "settings.language.title"
        static let languageSubtitle: LocalizedStringKey = "settings.language.subtitle"
        static let openSystemSettings: LocalizedStringKey = "settings.language.open_button"
        static let instructionsTitle: LocalizedStringKey = "settings.language.instructions_title"
        static let instructionsBody: LocalizedStringKey = "settings.language.instructions_body"
        static let profileGuestName: LocalizedStringKey = "settings.profile.guest_name"
        static let profileSourceGuest: LocalizedStringKey = "settings.profile.source.guest"
        static let profileSourceEmail: LocalizedStringKey = "settings.profile.source.email"
        static let profileSourceOTP: LocalizedStringKey = "settings.profile.source.otp"

        static func profileSourceSocial(_ provider: String) -> String {
            String(format: String(localized: "settings.profile.source.social"), provider)
        }
    }

    enum Support {
        static let needHelpTitle: LocalizedStringKey = "support.title"
        static let description: LocalizedStringKey = "support.body"
        static let startChat: LocalizedStringKey = "support.start_chat"
    }

    enum Onboarding {
        static let title: LocalizedStringKey = "onboarding.title"
        static let subtitle: LocalizedStringKey = "onboarding.subtitle"
        static let nextButton: LocalizedStringKey = "onboarding.next"
        static let getStartedButton: LocalizedStringKey = "onboarding.get_started"
        static let captureTitle: LocalizedStringKey = "onboarding.page.capture.title"
        static let captureSubtitle: LocalizedStringKey = "onboarding.page.capture.subtitle"
        static let captureHighlightOneTitle: LocalizedStringKey = "onboarding.page.capture.highlight1.title"
        static let captureHighlightOneBody: LocalizedStringKey = "onboarding.page.capture.highlight1.body"
        static let captureHighlightTwoTitle: LocalizedStringKey = "onboarding.page.capture.highlight2.title"
        static let captureHighlightTwoBody: LocalizedStringKey = "onboarding.page.capture.highlight2.body"
        static let overlayTitle: LocalizedStringKey = "onboarding.page.overlay.title"
        static let overlaySubtitle: LocalizedStringKey = "onboarding.page.overlay.subtitle"
        static let overlayHighlightOneTitle: LocalizedStringKey = "onboarding.page.overlay.highlight1.title"
        static let overlayHighlightOneBody: LocalizedStringKey = "onboarding.page.overlay.highlight1.body"
        static let overlayHighlightTwoTitle: LocalizedStringKey = "onboarding.page.overlay.highlight2.title"
        static let overlayHighlightTwoBody: LocalizedStringKey = "onboarding.page.overlay.highlight2.body"
        static let privacyTitle: LocalizedStringKey = "onboarding.page.privacy.title"
        static let privacySubtitle: LocalizedStringKey = "onboarding.page.privacy.subtitle"
        static let privacyHighlightOneTitle: LocalizedStringKey = "onboarding.page.privacy.highlight1.title"
        static let privacyHighlightOneBody: LocalizedStringKey = "onboarding.page.privacy.highlight1.body"
        static let privacyHighlightTwoTitle: LocalizedStringKey = "onboarding.page.privacy.highlight2.title"
        static let privacyHighlightTwoBody: LocalizedStringKey = "onboarding.page.privacy.highlight2.body"
    }
}

extension L10n {
    enum Toast {
        static let captureTitle: LocalizedStringKey = "content.toast.capture_title"
        static let captureMessage: LocalizedStringKey = "content.toast.capture_message"
    }
}
