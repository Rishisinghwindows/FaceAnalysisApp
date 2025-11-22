import SwiftUI
import UIKit

struct NotificationsView: View {
    @State private var tipsEnabled = true
    @State private var remindersEnabled = false
    @State private var newLooksEnabled = true
    @State private var backstageEnabled = true
    private let notifications = NotificationItem.mock

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                notificationList
                preferencePanel
                systemSettingsLink
            }
            .padding(24)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("Notifications")
        .toolbarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stay in the loop")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.textLight)
            Text("Fresh looks, reminders, and pro tips land here. Manage what you want to hear from us.")
                .font(.system(size: 14))
                .foregroundStyle(Color.textLight.opacity(0.85))
            HStack(spacing: 16) {
                summaryChip(title: "Unread", value: "2")
                summaryChip(title: "Scheduled", value: "3 this week")
            }
        }
        .padding()
        .background(
            LinearGradient(colors: [Color.primaryPink.opacity(0.25), Color.resultPrimary.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func summaryChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var notificationList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent alerts")
                .font(.system(size: 16, weight: .semibold))
            ForEach(notifications) { item in
                NotificationRow(item: item)
            }
        }
    }

    private var preferencePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.system(size: 16, weight: .semibold))
            toggleRow(title: "Weekly tips", subtitle: "Trend drops + skincare rituals", systemImage: "sparkles", isOn: $tipsEnabled)
            toggleRow(title: "Selfie reminders", subtitle: "Ping me every 30 days", systemImage: "timer", isOn: $remindersEnabled)
            toggleRow(title: "New looks", subtitle: "Instant alert for curated drops", systemImage: "wand.and.rays", isOn: $newLooksEnabled)
            toggleRow(title: "Early backstage", subtitle: "Beta features + events", systemImage: "bolt.fill", isOn: $backstageEnabled)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.secondaryButtonLight.opacity(0.6)))
    }

    private func toggleRow(title: String, subtitle: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.primaryPink)
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: Color.primaryPink))
    }

    private var systemSettingsLink: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Need finer control?")
                .font(.system(size: 14, weight: .semibold))
            Button(action: openSystemSettings) {
                Label("Open iOS Settings", systemImage: "gear")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.primaryPink.opacity(0.15)))
            }
            .buttonStyle(.plain)
            Text("We only send a few helpful alerts. You can disable them at any time.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct NotificationItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let timeAgo: String
    let isUnread: Bool

    static let mock: [NotificationItem] = [
        NotificationItem(title: "Creative Remix ready", message: "Your pastel neon mix is finished—tap to review and share.", icon: "paintpalette", timeAgo: "2m", isUnread: true),
        NotificationItem(title: "New wedding playbook", message: "See three bridal looks optimized for oval faces.", icon: "heart.fill", timeAgo: "3h", isUnread: true),
        NotificationItem(title: "Reminder", message: "It's been 30 days since your last scan—capture an updated selfie.", icon: "timer", timeAgo: "Yesterday", isUnread: false)
    ]
}

private struct NotificationRow: View {
    let item: NotificationItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primaryPink)
                .frame(width: 40, height: 40)
                .background(Color.primaryPink.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                    if item.isUnread {
                        Circle()
                            .fill(Color.primaryPink)
                            .frame(width: 8, height: 8)
                    }
                    Spacer()
                    Text(item.timeAgo)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Text(item.message)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.cardLight.opacity(0.95))
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 5)
        )
    }
}
