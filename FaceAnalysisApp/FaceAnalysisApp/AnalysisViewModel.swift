import Combine
import SwiftUI

@MainActor
final class AnalysisViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var errorMessage: String?

    var resultPublisher: AnyPublisher<AnalysisResult, Never> {
        resultSubject.eraseToAnyPublisher()
    }

    private let service: AnalysisServing
    private let resultSubject = PassthroughSubject<AnalysisResult, Never>()
    private var cancellables = Set<AnyCancellable>()

    init(service: AnalysisServing = AnalysisService()) {
        self.service = service
    }

    func analyze(image: UIImage) {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        errorMessage = nil
        service.analyze(image: image)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isAnalyzing = false
                if case let .failure(error) = completion {
                    self.errorMessage = error.errorDescription ?? AnalysisError.unknown.errorDescription
                }
            } receiveValue: { [weak self] result in
                guard let self else { return }
                self.resultSubject.send(result)
            }
            .store(in: &cancellables)
    }
}
