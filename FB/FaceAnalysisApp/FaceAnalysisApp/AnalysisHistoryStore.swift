import Foundation

@MainActor
final class AnalysisHistoryStore: ObservableObject {
    @Published private(set) var results: [AnalysisResult] = []

    private let fileURL: URL

    init(fileName: String = "analysis-history.json") {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        fileURL = directory.appendingPathComponent(fileName)

        load()
    }

    func add(_ result: AnalysisResult) {
        results.insert(result, at: 0)
        persist()
    }

    func delete(at offsets: IndexSet) {
        results.remove(atOffsets: offsets)
        persist()
    }

    func clear() {
        results.removeAll()
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([AnalysisResult].self, from: data) {
            results = decoded
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(results) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }
}

