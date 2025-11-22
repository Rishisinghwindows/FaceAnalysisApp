import SwiftUI

struct HomeContainerView: View {
    @ObservedObject var flow: AppFlowController
    @EnvironmentObject private var historyStore: AnalysisHistoryStore

    var body: some View {
        TabView {
            NavigationStack {
                ContentView()
            }
            .environmentObject(historyStore)
            .tabItem {
                Label(L10n.Home.tabAnalyze, systemImage: "wand.and.stars")
            }

            NavigationStack {
                HistoryView()
            }
            .environmentObject(historyStore)
            .tabItem {
                Label(L10n.Home.tabHistory, systemImage: "clock")
            }

            NavigationStack {
                SettingsView(flow: flow)
            }
            .environmentObject(historyStore)
            .tabItem {
                Label(L10n.Home.tabProfile, systemImage: "person.crop.circle")
            }
        }
        .accentColor(Color.primaryPink)
    }
}
