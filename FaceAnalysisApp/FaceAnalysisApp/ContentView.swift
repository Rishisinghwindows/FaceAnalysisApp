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
    private let captureDiameter: CGFloat = 240

    @State private var activeSheet: SheetType?
    @State private var selectedImage: UIImage?
    @State private var isCameraUnavailableAlertPresented = false
    @State private var navigationPath = NavigationPath()
    @State private var animatePulse = false
    @State private var steps = ContentView.defaultSteps
    @State private var isPresentingError = false
    @State private var showCaptureToast = false
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var accumulatedScale: CGFloat = 1.0
    @State private var accumulatedOffset: CGSize = .zero
    @State private var showNotifications = false

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
        .sheet(isPresented: $showNotifications) {
            NavigationStack {
                NotificationsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.General.done) { showNotifications = false }
                        }
                    }
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
        .onChange(of: viewModel.errorMessage) { _, newValue in
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
        .onChange(of: selectedImage) { _, _ in
            resetZoomState()
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
        .overlay(alignment: .top) {
            if showCaptureToast {
                CaptureToastView(
                    title: L10n.Toast.captureTitle,
                    message: L10n.Toast.captureMessage
                )
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topTrailing) {
            notificationButton
                .padding(.top, 24)
                .padding(.trailing, 24)
        }
        .onAppear {
            animatePulse = true
            triggerCaptureToast()
        }
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
                            .scaleEffect(imageScale)
                            .offset(imageOffset)
                            .gesture(zoomableGesture())
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
            .frame(width: captureDiameter, height: captureDiameter)
            .background(
                RoundedRectangle(cornerRadius: captureDiameter / 2, style: .continuous)
                    .fill(
                        colorScheme == .dark
                        ? Color.cardDark.opacity(0.35)
                        : Color.cardLight.opacity(0.7)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: captureDiameter / 2, style: .continuous)
                            .stroke(cardBorderColor.opacity(0.4), lineWidth: 1)
                    )
            )
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
            .overlay(alignment: .bottomTrailing) {
                if selectedImage != nil {
                    HStack(spacing: 0) {
                        zoomButton(systemName: "minus.magnifyingglass") {
                            withAnimation { imageScale = max(1.0, imageScale - 0.1); imageOffset = .zero }
                        }
                        Divider()
                            .frame(height: 24)
                            .background(Color.white.opacity(0.25))
                        zoomButton(systemName: "plus.magnifyingglass") {
                            withAnimation { imageScale = min(2.5, imageScale + 0.1) }
                        }
                    }
                    .background(Color.black.opacity(0.45), in: Capsule())
                    .padding(12)
                }
            }
            .overlay(alignment: .topTrailing) {
                if selectedImage != nil {
                    Button(action: resetSelection) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.4), in: Circle())
                    }
                    .padding(14)
                }
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

            captureGuidanceCard
        }
    }

    private var notificationButton: some View {
        Button(action: { showNotifications = true }) {
            Label("Notifications", systemImage: "bell")
                .labelStyle(.iconOnly)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.primaryPink.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: Color.primaryPink.opacity(0.35), radius: 10, y: 6)
        }
        .buttonStyle(.plain)
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

    private var captureGuidanceCard: some View {
        CaptureGuidanceView()
            .padding(.horizontal, 8)
            .padding(.top, 10)
    }

    private func triggerCaptureToast() {
        showCaptureToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation(.easeInOut(duration: 0.35)) {
                showCaptureToast = false
            }
        }
    }

    private func startAnalysis() {
        guard let image = selectedImage, !viewModel.isAnalyzing else { return }

        withAnimation(.easeInOut) {
            steps = updateStatuses(for: .inProgress)
        }

        let preparedImage: UIImage
        if hasImageTransform, let modified = croppedImageForAnalysis() {
            preparedImage = modified
        } else {
            preparedImage = image
        }
        viewModel.analyze(image: preparedImage)
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

    private var hasImageTransform: Bool {
        abs(imageScale - 1.0) > 0.01 || abs(imageOffset.width) > 0.5 || abs(imageOffset.height) > 0.5
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

private struct CaptureTip: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

private struct CaptureGuidanceView: View {
    @State private var currentTip = 0
    @State private var showTip = true
    @State private var isActive = true

    private let tips: [CaptureTip] = [
        CaptureTip(icon: "face.smiling", title: "Keep your face centered", detail: "Hold the phone at eye level and make sure both eyes and your chin are visible."),
        CaptureTip(icon: "sun.max", title: "Use soft, even lighting", detail: "Stand facing a window or lamp. Avoid harsh shadows or bright backlight."),
        CaptureTip(icon: "eyeglasses", title: "Remove accessories", detail: "Glasses, hats, and masks can confuse the scan. Keep hair tucked behind your ears."),
        CaptureTip(icon: "camera.aperture", title: "Relax your expression", detail: "A neutral face with a gentle gaze produces the most accurate mapping.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
                    .background(Color.primaryPink, in: Circle())

                Text("Capture Tips for Best Results")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.95))

                Spacer()

                Text("\(currentTip + 1)/\(tips.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15), in: Capsule())
            }

            ZStack {
                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                    if index == currentTip {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: tip.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.primaryPink)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(tip.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.white)
                                Text(tip.detail)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .lineLimit(3)
                            }
                        }
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)),
                                                removal: .opacity.combined(with: .move(edge: .top))))
                    }
                }
                .opacity(showTip ? 1 : 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.primaryPink.opacity(0.9), Color.primaryPink.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.primaryPink.opacity(0.25), radius: 14, y: 8)
        .onAppear {
            guard tips.count > 1 else { return }
            cycleTips()
        }
        .onDisappear {
            isActive = false
        }
    }

    private func cycleTips() {
        guard isActive else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            guard isActive else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                showTip = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard isActive else { return }
                currentTip = (currentTip + 1) % tips.count
                withAnimation(.easeInOut(duration: 0.35)) {
                    showTip = true
                }
                cycleTips()
            }
        }
    }
}

private struct CaptureToastView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.max")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primaryPink)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.2), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.9))
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.top, 8)
    }
}

private extension ContentView {
    func resetZoomState() {
        imageScale = 1.0
        accumulatedScale = 1.0
        imageOffset = .zero
        accumulatedOffset = .zero
    }

    func zoomableGesture() -> some Gesture {
        let magnification = MagnificationGesture()
            .onChanged { value in
                let proposed = accumulatedScale * value
                imageScale = proposed.clamped(to: 1.0...2.5)
                imageOffset = limitedOffset(accumulatedOffset, imageScale: imageScale)
            }
            .onEnded { value in
                accumulatedScale = (accumulatedScale * value).clamped(to: 1.0...2.5)
                imageScale = accumulatedScale
                imageOffset = limitedOffset(accumulatedOffset, imageScale: imageScale)
            }

        let drag = DragGesture()
            .onChanged { gesture in
                let proposed = CGSize(
                    width: accumulatedOffset.width + gesture.translation.width,
                    height: accumulatedOffset.height + gesture.translation.height
                )
                imageOffset = limitedOffset(proposed, imageScale: imageScale)
            }
            .onEnded { _ in
                accumulatedOffset = imageOffset
            }

        return magnification.simultaneously(with: drag)
    }

    func limitedOffset(_ proposed: CGSize, imageScale: CGFloat) -> CGSize {
        guard let source = selectedImage else { return .zero }
        let baseScale = max(captureDiameter / source.size.width, captureDiameter / source.size.height)
        let displayWidth = source.size.width * baseScale * imageScale
        let displayHeight = source.size.height * baseScale * imageScale
        let extraX = max((displayWidth - captureDiameter) / 2, 0)
        let extraY = max((displayHeight - captureDiameter) / 2, 0)
        let limitedX = Swift.min(Swift.max(proposed.width, -extraX), extraX)
        let limitedY = Swift.min(Swift.max(proposed.height, -extraY), extraY)
        return CGSize(width: limitedX, height: limitedY)
    }

    func zoomButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(Color.black.opacity(0.35), in: Circle())
        }
        .buttonStyle(.plain)
    }

    func croppedImageForAnalysis() -> UIImage? {
        guard hasImageTransform, let source = selectedImage else { return nil }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: captureDiameter, height: captureDiameter))
        let rendered = renderer.image { ctx in
            ctx.cgContext.saveGState()
            ctx.cgContext.addEllipse(in: CGRect(origin: .zero, size: CGSize(width: captureDiameter, height: captureDiameter)))
            ctx.cgContext.clip()

            let baseScale = max(captureDiameter / source.size.width, captureDiameter / source.size.height)
            let totalScale = baseScale * imageScale
            let displayedSize = CGSize(width: source.size.width * totalScale, height: source.size.height * totalScale)
            let origin = CGPoint(
                x: (captureDiameter - displayedSize.width) / 2 + imageOffset.width,
                y: (captureDiameter - displayedSize.height) / 2 + imageOffset.height
            )
            source.draw(in: CGRect(origin: origin, size: displayedSize))
            ctx.cgContext.restoreGState()
        }
        return rendered
    }
}


private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
