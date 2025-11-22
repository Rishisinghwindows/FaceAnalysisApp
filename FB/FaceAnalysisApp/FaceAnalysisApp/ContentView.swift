import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    private enum SheetType: Identifiable {
        case library
        case camera

        var id: String {
            switch self {
            case .library: return "library"
            case .camera: return "camera"
            }
        }
    }

    private enum StepStatus {
        case idle
        case inProgress
        case complete

        var icon: String {
            switch self {
            case .idle: return "clock"
            case .inProgress: return "hourglass"
            case .complete: return "checkmark"
            }
        }

        var tint: Color {
            switch self {
            case .idle: return .subtleLight
            case .inProgress: return .primaryPink
            case .complete: return .green
            }
        }
    }

    private struct AnalysisStep: Identifiable {
        let id = UUID()
        let icon: String
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        var status: StepStatus
    }

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var historyStore: AnalysisHistoryStore
    @StateObject private var viewModel = AnalysisViewModel()

    @State private var activeSheet: SheetType?
    @State private var selectedImage: UIImage?
    @State private var isCameraUnavailableAlertPresented = false
    @State private var navigationPath = NavigationPath()
    @State private var animatePulse = false
    @State private var steps = ContentView.defaultSteps
    @State private var isPresentingError = false

    private static let defaultSteps: [AnalysisStep] = [
        AnalysisStep(icon: "face.smiling", title: L10n.Content.stepFaceShapeTitle, subtitle: L10n.Content.stepFaceShapeSubtitle, status: .idle),
        AnalysisStep(icon: "paintpalette", title: L10n.Content.stepSkinToneTitle, subtitle: L10n.Content.stepSkinToneSubtitle, status: .idle),
        AnalysisStep(icon: "sparkles", title: L10n.Content.stepGoldenTitle, subtitle: L10n.Content.stepGoldenSubtitle, status: .idle)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            mainContent
                .navigationDestination(for: AnalysisResult.self) { result in
                    FaceAnalysisResultView(result: result)
                }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .library:
                ImagePicker(image: $selectedImage)
            case .camera:
                CameraPicker(image: $selectedImage)
            }
        }
        .alert(L10n.Content.alertCameraUnavailable, isPresented: $isCameraUnavailableAlertPresented, actions: {
            Button(L10n.General.ok, role: .cancel) {}
        }, message: {
            Text(L10n.Content.alertCameraMessage)
        })
        .alert(L10n.Content.alertAnalysisFailed, isPresented: $isPresentingError, actions: {
            Button(L10n.General.ok, role: .cancel) {
                viewModel.errorMessage = nil
            }
        }, message: {
            Text(viewModel.errorMessage ?? L10n.Content.alertAnalysisMessageFallback)
        })
        .onChange(of: viewModel.errorMessage) { newValue in
            isPresentingError = newValue != nil
            if newValue != nil {
                withAnimation(.easeInOut) {
                    steps = ContentView.defaultSteps
                }
            }
        }
        .onReceive(viewModel.resultPublisher) { result in
            historyStore.add(result)
            withAnimation(.spring()) {
                steps = updateStatuses(for: .complete)
            }
            navigationPath.append(result)
        }
    }

    private var mainContent: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    header
                    analysisList
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 32)
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .onAppear { animatePulse = true }
    }

    private var header: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.primaryPink.opacity(0.18))
                    .scaleEffect(animatePulse ? 1.1 : 0.9)
                    .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: true), value: animatePulse)

                Circle()
                    .stroke(Color.primaryPink.opacity(0.32), lineWidth: 12)
                    .scaleEffect(1.05)

                Group {
                   if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.metering.center.weighted")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(Color.primaryPink.opacity(0.9))
                            Text(L10n.Content.promptTapAdd)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(Circle())
            }
            .frame(width: 240, height: 240)
            .overlay(
                Circle()
                    .stroke(cardBorderColor, lineWidth: 8)
                    .opacity(0.9)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 16, y: 8)
            .contentShape(Circle())
            .onTapGesture {
                activeSheet = .library
            }

            VStack(spacing: 12) {
                Text(L10n.Content.headerTitle)
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(primaryTextColor)

                Text(L10n.Content.headerSubtitle)
                    .font(.system(size: 16, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(secondaryTextColor)
            }
            .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Button(action: presentCamera) {
                    Label(L10n.Content.buttonTakeSelfie, systemImage: "camera.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.primaryPink)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.primaryPink.opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(.plain)

                Button(action: { activeSheet = .library }) {
                    Label(L10n.Content.buttonSelectPhoto, systemImage: "photo.on.rectangle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(secondaryButtonColor.opacity(colorScheme == .dark ? 0.75 : 1.0))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var analysisList: some View {
        VStack(spacing: 16) {
            ForEach(steps) { item in
                HStack(spacing: 16) {
                    Image(systemName: item.icon)
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(Color.primaryPink)
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                        Text(item.subtitle)
                            .font(.system(size: 15))
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: statusIcon(for: item.status))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(statusColor(for: item.status))
                        .frame(width: 28, height: 28)
                }
                .padding(20)
                .background(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 10, y: 4)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08))
                .padding(.bottom, 4)

            Button(action: startAnalysis) {
                Label(buttonTitle, systemImage: viewModel.isAnalyzing ? "hourglass" : "wand.and.stars")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color.primaryPink.opacity(viewModel.isAnalyzing ? 0.6 : 0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isReadyForAnalysis)

           if selectedImage != nil {
                Button(action: resetSelection) {
                    Text(L10n.Content.buttonClearPhoto)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(primaryTextColor)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(secondaryButtonColor)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            backgroundColor
                .opacity(colorScheme == .dark ? 0.95 : 0.98)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func startAnalysis() {
        guard let image = selectedImage, !viewModel.isAnalyzing else { return }

        withAnimation(.easeInOut) {
            steps = updateStatuses(for: .inProgress)
        }

        viewModel.analyze(image: image)
    }

    private func resetSelection() {
        selectedImage = nil
        steps = ContentView.defaultSteps
    }

    private func presentCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            activeSheet = .camera
        } else {
            isCameraUnavailableAlertPresented = true
        }
    }

    private var isReadyForAnalysis: Bool {
        selectedImage != nil && !viewModel.isAnalyzing
    }

    private var buttonTitle: LocalizedStringKey {
        viewModel.isAnalyzing ? L10n.Content.analyzeButtonRunning : L10n.Content.analyzeButtonIdle
    }

    private func updateStatuses(for status: StepStatus) -> [AnalysisStep] {
        ContentView.defaultSteps.enumerated().map { index, step in
            var mutable = step
            switch status {
            case .idle:
                mutable.status = .idle
            case .inProgress:
                mutable.status = index == 0 ? .inProgress : .idle
            case .complete:
                mutable.status = .complete
            }
            return mutable
        }
    }

    private func statusIcon(for status: StepStatus) -> String {
        switch status {
        case .idle:
            return "clock"
        case .inProgress:
            return "hourglass"
        case .complete:
            return "checkmark.circle.fill"
        }
    }

    private func statusColor(for status: StepStatus) -> Color {
        switch status {
        case .idle:
            return colorScheme == .dark ? .subtleDark : .subtleLight
        case .inProgress:
            return .primaryPink
        case .complete:
            return .green
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? .backgroundDark : .backgroundLight
    }

    private var cardColor: Color {
        colorScheme == .dark ? .cardDark : .cardLight
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? .borderDark : .borderLight
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .textDark : .textLight
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .subtleDark : .subtleLight
    }

    private var secondaryButtonColor: Color {
        colorScheme == .dark ? .secondaryButtonDark : .secondaryButtonLight
    }
}
