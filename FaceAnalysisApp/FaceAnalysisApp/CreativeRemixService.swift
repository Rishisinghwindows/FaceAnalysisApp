import Foundation
import UIKit

enum CreativeRemixError: LocalizedError {
    case invalidPrompt
    case invalidResponse
    case server(String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidPrompt:
            return "Enter a few words describing the vibe you want."
        case .invalidResponse:
            return "We couldn't reach the creative service."
        case let .server(message):
            return message
        case .decodingFailed:
            return "The generated image couldn't be decoded."
        }
    }
}

protocol CreativeRemixing {
    func generateImage(from imageData: Data, prompt: String) async throws -> UIImage
}

struct CreativeRemixService: CreativeRemixing {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://localhost:8000")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func generateImage(from imageData: Data, prompt: String) async throws -> UIImage {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CreativeRemixError.invalidPrompt
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/creative/chatgpt"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Payload: Encodable {
            let prompt: String
            let image_base64: String
        }

        let payload = Payload(prompt: trimmed, image_base64: imageData.base64EncodedString())
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CreativeRemixError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            let decoder = JSONDecoder()
            let result = try decoder.decode(CreativeRemixResponse.self, from: data)
            guard let remixData = Data(base64Encoded: result.imageBase64), let image = UIImage(data: remixData) else {
                throw CreativeRemixError.decodingFailed
            }
            return image
        default:
            if let server = try? JSONDecoder().decode(ServerErrorResponse.self, from: data) {
                throw CreativeRemixError.server(server.detail)
            }
            throw CreativeRemixError.server("Creative service returned \(httpResponse.statusCode).")
        }
    }
}

private struct CreativeRemixResponse: Decodable {
    let imageBase64: String
}

private struct ServerErrorResponse: Decodable {
    let detail: String
}
