import SwiftUI

final class AppFlowController: ObservableObject {
    enum Step {
        case splash
        case onboarding
        case login
        case tutorial
        case home
    }

    @Published var step: Step
    @Published var isLoggedIn: Bool
    @Published var hasCompletedOnboarding: Bool
    @Published var hasSeenTutorial: Bool
    @Published var session: AuthSession?
    @Published var lastLoginSource: LoginSource

    private let storage: UserDefaults

    private enum StorageKeys {
        static let isLoggedIn = "appflow.isLoggedIn"
        static let hasCompletedOnboarding = "appflow.hasCompletedOnboarding"
        static let hasSeenTutorial = "appflow.hasSeenTutorial"
        static let session = "appflow.session"
        static let loginSource = "appflow.loginSource"
    }

    init(storage: UserDefaults = .standard) {
        self.storage = storage
        self.step = .splash
        self.isLoggedIn = storage.bool(forKey: StorageKeys.isLoggedIn)
        self.hasCompletedOnboarding = storage.bool(forKey: StorageKeys.hasCompletedOnboarding)
        self.hasSeenTutorial = storage.bool(forKey: StorageKeys.hasSeenTutorial)
        self.lastLoginSource = LoginSource(storedValue: storage.string(forKey: StorageKeys.loginSource))

        if let data = storage.data(forKey: StorageKeys.session),
           let session = try? JSONDecoder().decode(AuthSession.self, from: data) {
            self.session = session
        } else {
            self.session = nil
        }
    }

    func advanceFromSplash() {
        if !hasCompletedOnboarding {
            step = .onboarding
        } else if isLoggedIn {
            step = hasSeenTutorial ? .home : .tutorial
        } else {
            step = .login
        }
    }

    func completeLogin(with session: AuthSession? = nil, skipTutorial: Bool = false, source: LoginSource = .none) {
        if let session {
            self.session = session
            persistSession(session)
        }
        isLoggedIn = true
        storage.set(true, forKey: StorageKeys.isLoggedIn)
        updateLoginSource(source)
        if skipTutorial {
            hasSeenTutorial = true
            storage.set(true, forKey: StorageKeys.hasSeenTutorial)
            step = .home
        } else {
            step = hasSeenTutorial ? .home : .tutorial
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        storage.set(true, forKey: StorageKeys.hasCompletedOnboarding)
        if isLoggedIn {
            step = hasSeenTutorial ? .home : .tutorial
        } else {
            step = .login
        }
    }

    func completeTutorial() {
        hasSeenTutorial = true
        storage.set(true, forKey: StorageKeys.hasSeenTutorial)
        step = .home
    }

    func revisitOnboarding() {
        step = .onboarding
    }

    func revisitTutorial() {
        step = .tutorial
    }

    func logout() {
        session = nil
        isLoggedIn = false
        storage.removeObject(forKey: StorageKeys.session)
        storage.set(false, forKey: StorageKeys.isLoggedIn)
        lastLoginSource = .none
        storage.removeObject(forKey: StorageKeys.loginSource)
        step = .login
    }

    private func persistSession(_ session: AuthSession) {
        if let data = try? JSONEncoder().encode(session) {
            storage.set(data, forKey: StorageKeys.session)
        }
    }

    private func updateLoginSource(_ source: LoginSource) {
        guard source != .none else { return }
        lastLoginSource = source
        storage.set(source.storedValue, forKey: StorageKeys.loginSource)
    }
}

struct RootView: View {
    @StateObject private var flow = AppFlowController()
    @StateObject private var historyStore = AnalysisHistoryStore()

    var body: some View {
        Group {
            switch flow.step {
            case .splash:
                SplashView(flow: flow)
            case .onboarding:
                OnboardingView(flow: flow)
            case .login:
                LoginView(flow: flow)
            case .tutorial:
                TutorialView(flow: flow)
            case .home:
                HomeContainerView(flow: flow)
                    .environmentObject(historyStore)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: flow.step)
        .transition(.opacity)
    }
}
