import SwiftUI

final class AppFlowController: ObservableObject {
    enum Step {
        case splash
        case login
        case tutorial
        case home
    }

    @Published var step: Step = .splash
    @Published var isLoggedIn = false
    @Published var hasSeenTutorial = false
    @Published var session: AuthSession?

    func advanceFromSplash() {
        if isLoggedIn {
            step = hasSeenTutorial ? .home : .tutorial
        } else {
            step = .login
        }
    }

    func completeLogin(with session: AuthSession? = nil) {
        self.session = session
        isLoggedIn = true
        step = hasSeenTutorial ? .home : .tutorial
    }

    func completeTutorial() {
        hasSeenTutorial = true
        step = .home
    }

    func revisitTutorial() {
        step = .tutorial
    }

    func logout() {
        session = nil
        isLoggedIn = false
        step = .login
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
