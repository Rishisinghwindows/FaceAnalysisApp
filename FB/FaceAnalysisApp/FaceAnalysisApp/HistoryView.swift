import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: AnalysisHistoryStore
    @Environment(\.colorScheme) private var colorScheme

    private var results: [AnalysisResult] {
        historyStore.results
    }

    private let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.History.title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(primaryTextColor)
                .padding(.top, 32)
                .padding(.horizontal, 20)

            Text(L10n.History.subtitle)
                .font(.system(size: 15))
                .foregroundStyle(secondaryTextColor)
                .padding(.horizontal, 20)
                .padding(.top, 4)

            if results.isEmpty {
                emptyState
            } else {
                List {
                    Section(header: Text(L10n.History.sectionRecent)) {
                        ForEach(results) { result in
                            NavigationLink(value: result) {
                                HistoryCell(result: result, relativeString: relativeDate(for: result))
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationDestination(for: AnalysisResult.self) { result in
                    FaceAnalysisResultView(result: result)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if !historyStore.results.isEmpty {
                            Button(L10n.History.clearAll) {
                                historyStore.clear()
                            }
                        }
                    }
                }
            }
        }
        .background(backgroundColor.ignoresSafeArea())
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(Color.primaryPink.opacity(0.6))

            Text(L10n.History.emptyTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(primaryTextColor)

            Text(L10n.History.emptySubtitle)
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(secondaryTextColor)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func delete(at offsets: IndexSet) {
        historyStore.delete(at: offsets)
    }

    private func relativeDate(for result: AnalysisResult) -> String {
        dateFormatter.localizedString(for: result.createdAt, relativeTo: Date())
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.textDark : Color.textLight
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.subtleDark : Color.subtleLight
    }
}

private struct HistoryCell: View {
    let result: AnalysisResult
    let relativeString: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.faceShape.capitalized)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(relativeString)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.subtleLight)
            }

            HStack(spacing: 8) {
                TagView(text: L10n.History.undertoneTag(result.undertone.capitalized))
                TagView(text: L10n.History.skinToneTag(result.skinTone.replacingOccurrences(of: "_", with: " ").capitalized))
            }
            .lineLimit(1)
        }
        .padding(.vertical, 10)
    }
}

private struct TagView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.primaryPink)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.primaryPink.opacity(0.12))
            .clipShape(Capsule())
    }
}
