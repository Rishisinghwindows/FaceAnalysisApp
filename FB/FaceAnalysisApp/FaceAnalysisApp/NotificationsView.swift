import SwiftUI

struct NotificationsView: View {
    @State private var tipsEnabled = true
    @State private var remindersEnabled = false
    @State private var newLooksEnabled = true

    var body: some View {
        Form {
            Section(header: Text("Push notifications")) {
                Toggle(isOn: $tipsEnabled) {
                    Label("Weekly skincare + makeup tips", systemImage: "sparkles")
                }

                Toggle(isOn: $remindersEnabled) {
                    Label("Retake reminders", systemImage: "timer")
                }

                Toggle(isOn: $newLooksEnabled) {
                    Label("New curated looks", systemImage: "wand.and.rays")
                }
            }

            Section(footer: Text("Notifications are respectful and limited. You can disable them anytime in system settings.")) {
                EmptyView()
            }
        }
        .navigationTitle("Notifications")
    }
}

