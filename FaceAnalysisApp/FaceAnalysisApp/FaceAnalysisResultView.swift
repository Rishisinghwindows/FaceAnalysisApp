import SwiftUI
import UIKit
import Vision

struct FaceAnalysisResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let result: AnalysisResult
    private let remixService: CreativeRemixing

    private let recommendationOrder = ["contour", "blush", "highlight", "eyes", "lips"]
    @State private var fullScreenContent: FullscreenContent?
    @State private var remixPrompt: String = ""
    @State private var remixImage: UIImage?
    @State private var isGeneratingRemix = false
    @State private var remixError: String?
    @State private var showRemixPrompt = false
    @State private var remixSourceImage: UIImage?
    @State private var pendingRemixImage: UIImage?
    @State private var inlineRemixIsLoading = false
    @State private var showingOriginal = true
    @State private var showMakeupStudio = false
    @State private var makeupSourceImage: UIImage?
    private let remixSuggestions: [RemixSuggestion] = [
        .init(
            title: "Wedding glow",
            prompt: "elevated bridal glam with soft rose gold eyes and luminous skin",
            icon: "sparkles",
            colors: (Color(hex: 0xF9D4E4), Color(hex: 0xF275AE))
        ),
        .init(
            title: "College fest",
            prompt: "playful holographic festival makeup with pastel liner and glitter",
            icon: "party.popper",
            colors: (Color(hex: 0x99DAFF), Color(hex: 0x7B5BFF))
        ),
        .init(
            title: "Professional",
            prompt: "clean executive-ready makeup with soft contour and muted lip",
            icon: "briefcase.fill",
            colors: (Color(hex: 0xF2E7DC), Color(hex: 0xC8B6A6))
        )
    ]

    init(result: AnalysisResult, remixService: CreativeRemixing = CreativeRemixService()) {
        self.result = result
        self.remixService = remixService
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    AnimatedSection(delay: 0.05) { titleSection }
                    AnimatedSection(delay: 0.15) { imageGrid }
                    AnimatedSection(delay: 0.25) { featureSummary }
                    AnimatedSection(delay: 0.32) { observationHighlightsCard }
                    AnimatedSection(delay: 0.4) { insightsCard }
                    AnimatedSection(delay: 0.5) { ratiosCard }
                    AnimatedSection(delay: 0.6) { toneSummaryCard }
                    AnimatedSection(delay: 0.7) { goldenRatioCard }
                    AnimatedSection(delay: 0.78) { styleGuidanceCard }
                    AnimatedSection(delay: 0.85) { recommendationsSection }
                    AnimatedSection(delay: 0.95) { creativeRemixSection }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .bottom) { bottomCallToAction }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Face Analysis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(primaryTextColor)
            }
        }
        .fullScreenCover(item: $fullScreenContent) { item in
            FullScreenGallery(
                content: item,
                result: result,
                suggestions: remixSuggestions,
                isLoading: inlineRemixIsLoading,
                dismiss: { fullScreenContent = nil },
                onRequestRemix: { image in
                    pendingRemixImage = image
                    fullScreenContent = nil
                },
                onSuggestionRemix: { image, suggestion in
                    generateInlineRemix(from: image, prompt: suggestion.prompt)
                },
                onShowMakeupStudio: { image in
                    makeupSourceImage = image
                    showMakeupStudio = true
                }
            )
        }
        .sheet(isPresented: $showRemixPrompt) {
            CreativeRemixPromptSheet(
                prompt: $remixPrompt,
                isGenerating: isGeneratingRemix,
                errorMessage: remixError,
                onGenerate: { generateRemix(using: remixSourceImage) }
            )
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showMakeupStudio) {
            NavigationStack {
                MakeupEffectsView(image: makeupSourceImage ?? result.primaryImage ?? UIImage())
            }
        }
        .onChange(of: fullScreenContent?.id) { _, _ in
            guard fullScreenContent == nil else { return }
            if let pending = pendingRemixImage {
                remixSourceImage = pending
                pendingRemixImage = nil
                showRemixPrompt = true
            }
        }
    }

    private var header: some View {
        EmptyView()
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Personalized Makeup Map")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(primaryTextColor)
            Text("Captured \(formattedDate). Tap any card for at-home application tips.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(secondaryTextColor)
        }
    }

    private var imageGrid: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                let displayImage = showingOriginal ? result.primaryImage : (remixImage ?? result.primaryImage)
                if let image = displayImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .overlay(
                            Group {
                                if showingOriginal {
                                    FaceScanAnimation()
                                }
                            }
                        )
                } else {
                    placeholder
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(cardColor.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(borderColor.opacity(0.4), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .modifier(SpectrumAuraEffect())

            Button(action: {
                guard remixImage != nil else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    showingOriginal.toggle()
                }
            }) {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(primaryTextColor)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardColor.opacity(0.95))
                            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                    )
            }
            .buttonStyle(.plain)
            .padding(12)
            .opacity(remixImage == nil ? 0.35 : 1)
            .disabled(remixImage == nil)
        }
        .onTapGesture {
            if showingOriginal, let image = result.primaryImage {
                fullScreenContent = .photo(image)
            } else if let remix = remixImage {
                fullScreenContent = .remix(remix)
            } else if let image = result.primaryImage {
                fullScreenContent = .photo(image)
            }
        }
    }

    private var featureSummary: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                iconTile("square.on.circle")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Feature Summary")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                    Text("Dimensions and tones derived from your captured selfie.")
                        .font(.system(size: 14))
                        .foregroundStyle(secondaryTextColor)
                }
            }

            VStack(spacing: 16) {
                metricRow(title: "Forehead width", value: formatted(result.dimensions.foreheadWidth) + " px")
                metricRow(title: "Cheekbone width", value: formatted(result.dimensions.cheekboneWidth) + " px")
                metricRow(title: "Face length", value: formatted(result.dimensions.faceLength) + " px")
                metricRow(title: "Jaw angle", value: angleDegrees(result.dimensions.jawAngle))
            }
        }
        .padding(20)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(borderColor.opacity(0.35), lineWidth: 1)
        )
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Tailored Recommendations")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(primaryTextColor)

            VStack(spacing: 16) {
                ForEach(visibleRecommendations, id: \.key) { key, recommendation in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(key.capitalized)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(primaryTextColor)

                        if let details = recommendation.details {
                            Text(details)
                                .font(.system(size: 14))
                                .foregroundStyle(secondaryTextColor)
                        }

                        if let shades = recommendation.suggestedShades, !shades.isEmpty {
                            chipGrid(title: "Shades", values: shades)
                        }

                        if let finishes = recommendation.suggestedFinishes, !finishes.isEmpty {
                            chipGrid(title: "Finishes", values: finishes)
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(recommendationGradient(for: key))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 20, x: 0, y: 12)
                }
            }
        }
    }

    private var creativeRemixSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.primaryPink)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Creative Remix")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                    Text("Describe a new mood and reimagine this capture with Nano Banana.")
                        .font(.system(size: 14))
                        .foregroundStyle(secondaryTextColor)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(remixSuggestions) { suggestion in
                        Button {
                            remixPrompt = suggestion.prompt
                            generateRemix(using: nil)
                        } label: {
                            RemixSuggestionTile(suggestion: suggestion)
                        }
                        .buttonStyle(.plain)
                        .disabled(isGeneratingRemix)
                    }
                }
                .frame(height: 135)
            }

            VStack(spacing: 12) {
                TextField("e.g. ethereal holographic editorial", text: $remixPrompt)
                    .textFieldStyle(.roundedBorder)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.08))
                    )

                Button(action: { generateRemix(using: nil) }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.primaryPink)
                        if isGeneratingRemix {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Generate look")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white)
                        }
                    }
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                .disabled(isGeneratingRemix)

                Button {
                    makeupSourceImage = result.primaryImage
                    showMakeupStudio = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                            Text("Try makeup studio")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    }
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
            }

            if let error = remixError {
                Text(error)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.red)
            }

            if let remixImage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                    Button {
                        fullScreenContent = .remix(remixImage)
                    } label: {
                        Image(uiImage: remixImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(borderColor.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

        }
        .padding(20)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(borderColor.opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var observationHighlightsCard: some View {
        if let insights = result.insights, insights.hasDetailedObservations {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    iconTile("text.magnifyingglass")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Detailed observations")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                        Text("Face shape findings, confidence, and notable facial markers from your scan.")
                            .font(.system(size: 14))
                            .foregroundStyle(secondaryTextColor)
                    }
                }

                if let confidence = insights.confidence, !confidence.isEmpty {
                    Text("Confidence \(confidence)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.primaryPink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.primaryPink.opacity(0.12))
                        .clipShape(Capsule())
                }

                if let summary = insights.analysisSummary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Summary")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                        Text(summary)
                            .font(.system(size: 14))
                            .foregroundStyle(secondaryTextColor)
                    }
                }

                if !insights.cleanedKeyFeatures.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key features")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                        ForEach(insights.cleanedKeyFeatures) { feature in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.primaryPink.opacity(0.6))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feature.feature.capitalized)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(primaryTextColor)
                                    Text(feature.observation)
                                        .font(.system(size: 13))
                                        .foregroundStyle(secondaryTextColor)
                                }
                            }
                        }
                    }
                }

                if let skin = insights.skinObservations, !skin.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Skin observations")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                        Text(skin)
                            .font(.system(size: 14))
                            .foregroundStyle(secondaryTextColor)
                    }
                }

                if !insights.hairFeatures.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hair details")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                        ForEach(insights.hairFeatures) { hair in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.primaryPink.opacity(0.9))
                                    .padding(.top, 4)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hair.feature.capitalized)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(primaryTextColor)
                                    Text(hair.observation)
                                        .font(.system(size: 13))
                                        .foregroundStyle(secondaryTextColor)
                                }
                            }
                        }
                    }
                }

                if !insights.cleanedCautions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cautions")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                        ForEach(insights.cleanedCautions, id: \.self) { caution in
                            Label(caution, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.orange)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }

                if let notes = insights.additionalNotes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                        Text(notes)
                            .font(.system(size: 13))
                            .foregroundStyle(secondaryTextColor)
                    }
                }
            }
            .padding(20)
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(borderColor.opacity(0.35), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var insightsCard: some View {
        if let insights = result.insights {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    iconTile("sparkle.magnifyingglass")

                    VStack(alignment: .leading, spacing: 6) {
                Text("Feature Focus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                        Text("Symmetry, balance, and alignment insights from your capture.")
                            .font(.system(size: 14))
                            .foregroundStyle(secondaryTextColor)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Symmetry Score")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(primaryTextColor)

                    HStack(spacing: 12) {
                        ProgressView(value: insights.symmetryScore, total: 1.0)
                            .tint(Color.resultPrimary)
                            .scaleEffect(x: 1, y: 1.2, anchor: .center)
                        Text(insights.formattedSymmetryPercentage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                    }

                    Text(insights.symmetryDescription)
                        .font(.system(size: 14))
                        .foregroundStyle(secondaryTextColor)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Eye Alignment")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                    Text("Vertical difference: \(insights.formattedEyeAlignment)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(primaryTextColor)
                    Text(insights.guidance)
                        .font(.system(size: 13))
                        .foregroundStyle(secondaryTextColor)
                        .padding(.top, 4)
                }

                Divider().background(borderColor.opacity(0.25))

                VStack(alignment: .leading, spacing: 12) {
                    InsightMetricRow(
                        title: "Brow balance",
                        value: insights.formattedBrowBalance,
                        progress: insights.browBalanceScore
                    )

                    InsightMetricRow(
                        title: "Jaw definition",
                        value: insights.formattedJawDefinition,
                        progress: insights.jawDefinitionScore
                    )
                }
            }
            .padding(20)
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(borderColor.opacity(0.35), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var styleGuidanceCard: some View {
        if let insights = result.insights,
           let style = insights.styleRecommendations,
           insights.hasStyleGuidance {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    iconTile("person.text.rectangle")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Style suggestions")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                        Text("Hair, accessory, and makeup cues tailored to your mapped proportions.")
                            .font(.system(size: 14))
                            .foregroundStyle(secondaryTextColor)
                    }
                }

                if let hair = style.hairstyles, !hair.isEmpty {
                    styleTagGroup(title: "Hairstyles", systemImage: "scissors", items: hair)
                }

                if let glasses = style.glasses, !glasses.isEmpty {
                    styleTagGroup(title: "Frames", systemImage: "eyeglasses", items: glasses)
                }

                if let makeup = style.makeup, !makeup.isEmpty {
                    styleTagGroup(title: "Makeup", systemImage: "sparkles", items: makeup)
                }

                if let beard = style.beardGrooming?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !beard.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Grooming", systemImage: "mustache")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                        Text(beard)
                            .font(.system(size: 13))
                            .foregroundStyle(secondaryTextColor)
                    }
                }
            }
            .padding(20)
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(borderColor.opacity(0.35), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var goldenRatioCard: some View {
        if let summary = result.goldenRatioSummary {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    iconTile("ruler")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Golden Ratio Perspective")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                        Text("A look at how your face length compares to the classical 1:1.618 harmony.")
                            .font(.system(size: 14))
                            .foregroundStyle(secondaryTextColor)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Length to width ratio")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(primaryTextColor)
                        Spacer()
                        Text(summary.formattedRatio)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                    }

                    Text(summary.interpretation)
                        .font(.system(size: 14))
                        .foregroundStyle(secondaryTextColor)

                    Text(summary.guidance)
                        .font(.system(size: 13))
                        .foregroundStyle(secondaryTextColor)
                        .padding(.top, 4)

                    Text("The golden ratio is a guide, not a rulebook — unique proportions are what make features memorable.")
                        .font(.system(size: 12))
                        .foregroundStyle(secondaryTextColor)
                        .padding(.top, 6)
                }
            }
            .padding(20)
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(borderColor.opacity(0.35), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var ratiosCard: some View {
        if let ratios = result.insights?.featureRatios, !ratios.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Facial Ratios")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(primaryTextColor)

                ratioList(ratios: ratios)
            }
            .padding(20)
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(borderColor.opacity(0.35), lineWidth: 1)
            )
        }
    }

    private func ratioList(ratios: [FeatureInsights.FeatureRatio]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(ratios.enumerated()), id: \.element.id) { index, ratio in
                ratioRow(ratio: ratio)
                    .padding(.vertical, 6)
                if index != ratios.count - 1 {
                    Divider().background(borderColor.opacity(0.2))
                }
            }
        }
    }

    private func ratioRow(ratio: FeatureInsights.FeatureRatio) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ratio.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(primaryTextColor)
                Spacer()
                Text("\(ratio.formattedValue) • Ideal \(ratio.formattedIdeal)")
                    .font(.system(size: 13))
                    .foregroundStyle(secondaryTextColor)
            }

            let normalized = min(max(ratio.value / max(ratio.ideal, 0.1), 0), 2)
            ProgressView(value: normalized, total: 2)
                .tint(Color.resultPrimary)

            Text(ratio.message)
                .font(.system(size: 13))
                .foregroundStyle(secondaryTextColor)
        }
    }

    @ViewBuilder
    private var toneSummaryCard: some View {
        if let toneSummary = result.insights?.toneSummary {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tone & Finish Highlights")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(primaryTextColor)

                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(color(from: toneSummary.hex))
                        .frame(width: 70, height: 70)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(borderColor.opacity(0.4), lineWidth: 1)
                        )
                        .overlay(
                            Text(toneSummary.hex.uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keywords")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(primaryTextColor)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                            ForEach(toneSummary.keywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primaryPink.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Finish tips")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                    ForEach(toneSummary.finishTips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.primaryPink.opacity(0.7))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(tip)
                                .font(.system(size: 13))
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                }
            }
            .padding(20)
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(borderColor.opacity(0.35), lineWidth: 1)
            )
        }
    }

    private var bottomCallToAction: some View {
        VStack(spacing: 12) {
            Divider()
                .background(borderColor.opacity(0.3))

            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(resultButtonTextColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.resultPrimary)
                    .clipShape(Capsule())
                    .shadow(color: Color.resultPrimary.opacity(0.35), radius: 16, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(backgroundColor.opacity(0.92))
    }

    private func iconTile(_ systemName: String) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.resultPrimary.opacity(0.18))
            .frame(width: 52, height: 52)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.resultPrimary)
            )
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(primaryTextColor)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(primaryTextColor)
        }
    }

    private func chipGrid(title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(chipLabelColor)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(chipTextColor)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(chipBackgroundColor)
                        )
                        .overlay(
                            Capsule()
                                .stroke(chipBorderColor, lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 6, x: 0, y: 3)
                }
            }
        }
    }

    private func styleTagGroup(title: String, systemImage: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(primaryTextColor)
            let tagFill = colorScheme == .dark ? Color.secondaryButtonDark : Color.secondaryButtonLight
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(items, id: \.self) { value in
                    Text(value)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(primaryTextColor)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(tagFill.opacity(colorScheme == .dark ? 0.35 : 0.9))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(borderColor.opacity(0.25), lineWidth: 0.8)
                        )
                }
            }
        }
    }

    private var visibleRecommendations: [(key: String, value: Recommendation)] {
        let excluded = Set(["contour", "blush", "highlight"])
        let filtered = result.recommendations.filter { !excluded.contains($0.key.lowercased()) }

        return filtered.sorted { lhs, rhs in
            let lhsIndex = recommendationOrder.firstIndex(of: lhs.key) ?? Int.max
            let rhsIndex = recommendationOrder.firstIndex(of: rhs.key) ?? Int.max
            if lhsIndex == rhsIndex {
                return lhs.key < rhs.key
            }
            return lhsIndex < rhsIndex
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: result.createdAt)
    }

    private func angleDegrees(_ radians: Double) -> String {
        let degrees = radians * 180 / .pi
        return String(format: "%.0f°", degrees)
    }

    private func generateRemix(using sourceImage: UIImage?) {
        guard !isGeneratingRemix else { return }
        let trimmed = remixPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            remixError = CreativeRemixError.invalidPrompt.errorDescription
            return
        }
        guard let data = imageData(for: sourceImage ?? remixSourceImage) else {
            remixError = "Original capture missing. Try rerunning the analysis."
            return
        }

        isGeneratingRemix = true
        remixError = nil

        Task {
            do {
                let image = try await remixService.generateImage(from: data, prompt: trimmed)
                await MainActor.run {
                    self.isGeneratingRemix = false
                    self.presentRemixResult(image)
                }
            } catch {
                await MainActor.run {
                    self.isGeneratingRemix = false
                    self.handleRemixFailure(fallbackSource: sourceImage ?? remixSourceImage)
                }
            }
        }
    }

    private func generateInlineRemix(from image: UIImage, prompt: String) {
        guard !inlineRemixIsLoading else { return }
        inlineRemixIsLoading = true
        remixError = nil

        Task {
            do {
                guard let data = image.jpegData(compressionQuality: 0.95) else {
                    throw CreativeRemixError.decodingFailed
                }
                let generated = try await remixService.generateImage(from: data, prompt: prompt)
                await MainActor.run {
                    self.inlineRemixIsLoading = false
                    self.remixImage = generated
                    self.fullScreenContent = .remix(generated)
                }
            } catch {
                await MainActor.run {
                    self.inlineRemixIsLoading = false
                    self.handleRemixFailure(fallbackSource: image)
                }
            }
        }
    }

    private func presentRemixResult(_ image: UIImage) {
        remixImage = image
        showingOriginal = false
        fullScreenContent = .remix(image)
    }

    private func handleRemixFailure(fallbackSource: UIImage?) {
        if let source = fallbackSource {
            let mock = placeholderRemix(from: source)
            remixImage = mock
            showingOriginal = false
            fullScreenContent = .remix(mock)
        } else {
            remixError = CreativeRemixError.server("Unable to generate the creative remix.").errorDescription
        }
    }

    private func placeholderRemix(from source: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: source.size)
        return renderer.image { context in
            source.draw(in: CGRect(origin: .zero, size: source.size))

            let gradientColors = [UIColor.systemPink.withAlphaComponent(0.25), UIColor.systemBlue.withAlphaComponent(0.25)]
            let gradient = CAGradientLayer()
            gradient.frame = CGRect(origin: .zero, size: source.size)
            gradient.colors = gradientColors.map { $0.cgColor }
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 1, y: 1)
            gradient.render(in: context.cgContext)
        }
    }

    private func imageData(for sourceImage: UIImage?) -> Data? {
        if let sourceImage, let data = sourceImage.jpegData(compressionQuality: 0.95) {
            return data
        }
        return result.imageData
    }

    private var placeholder: some View {
        ZStack {
            cardColor
            Image(systemName: "person.crop.circle")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Color.resultPrimary.opacity(0.8))
        }
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .resultTextDark : .resultTextLight
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .resultTextSecondaryDark : .resultTextSecondaryLight
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? .resultBackgroundDark : .resultBackgroundLight
    }

    private var cardColor: Color {
        colorScheme == .dark ? .resultCardDark : .resultCardLight
    }

    private var borderColor: Color {
        colorScheme == .dark ? .resultBorderDark : .resultBorderLight
    }

    private var resultButtonTextColor: Color {
        Color.resultBackgroundDark
    }

    private func color(from hex: String) -> Color {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        guard hexString.count == 6, let value = Int(hexString, radix: 16) else {
            return Color.primaryPink
        }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        return Color(red: red, green: green, blue: blue)
    }

    private func recommendationGradient(for key: String) -> LinearGradient {
        let baseOpacity: Double = colorScheme == .dark ? 0.45 : 0.75
        let colors: [Color]
        switch key.lowercased() {
        case "blush":
            colors = [
                Color.primaryPink.opacity(baseOpacity),
                Color.primaryPink.opacity(baseOpacity * 0.65)
            ]
        case "contour":
            colors = [
                Color.resultPrimary.opacity(baseOpacity),
                Color.resultPrimary.opacity(baseOpacity * 0.6)
            ]
        case "highlight":
            colors = [
                Color.white.opacity(baseOpacity),
                Color.accentColor.opacity(baseOpacity * 0.5)
            ]
        case "eyes":
            colors = [
                Color.blue.opacity(baseOpacity * 0.8),
                Color.purple.opacity(baseOpacity * 0.6)
            ]
        case "lips":
            colors = [
                Color.red.opacity(baseOpacity * 0.75),
                Color.pink.opacity(baseOpacity * 0.55)
            ]
        default:
            colors = [
                cardColor.opacity(baseOpacity),
                cardColor.opacity(baseOpacity * 0.7)
            ]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var chipBackgroundColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.18)
        }
        return Color.white.opacity(0.96)
    }

    private var chipTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : Color.resultTextLight
    }

    private var chipLabelColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.75) : Color.resultTextLight.opacity(0.65)
    }

    private var chipBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.1)
    }
}

private struct AnalysisOverlayView: View {
    let result: AnalysisResult

    private let zoneColors: [String: Color] = [
        "contour": Color.resultPrimary.opacity(0.45),
        "blush": Color.primaryPink.opacity(0.45),
        "highlight": Color.white.opacity(0.45)
    ]

    var body: some View {
        GeometryReader { proxy in
            let containerSize = proxy.size
            let imageAspect = CGFloat(result.imageWidth) / CGFloat(result.imageHeight)
            let containerAspect = containerSize.width / containerSize.height

            let drawSize: CGSize = {
                if containerAspect > imageAspect {
                    let height = containerSize.height
                    return CGSize(width: height * imageAspect, height: height)
                } else {
                    let width = containerSize.width
                    return CGSize(width: width, height: width / imageAspect)
                }
            }()

            let offsetX = (containerSize.width - drawSize.width) / 2
            let offsetY = (containerSize.height - drawSize.height) / 2

            let zones = result.overlay.normalizedZones(imageWidth: result.imageWidth, imageHeight: result.imageHeight)
            let polygons: [(key: String, points: [CGPoint])] = zones.compactMap { element in
                let (key, points) = element
                guard points.count > 2 else { return nil }
                let converted = points.map { convert(point: $0, drawSize: drawSize, offsetX: offsetX, offsetY: offsetY) }
                return (key: key, points: converted)
            }

            ZStack {
                ForEach(polygons, id: \.key) { polygon in
                    OverlayPolygonView(
                        points: polygon.points,
                        fillColor: zoneColors[polygon.key, default: Color.primaryPink.opacity(0.3)]
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func convert(point: CGPoint, drawSize: CGSize, offsetX: CGFloat, offsetY: CGFloat) -> CGPoint {
        CGPoint(
            x: offsetX + point.x * drawSize.width,
            y: offsetY + point.y * drawSize.height
        )
    }
}

private struct InsightMetricRow: View {
    let title: String
    let value: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Color.primary)

            ProgressView(value: progress, total: 1.0)
                .tint(Color.resultPrimary)
        }
    }
}


private struct OverlayPolygonView: View {
    let points: [CGPoint]
    let fillColor: Color

    var body: some View {
        let polygonPath = path(for: points)
        polygonPath
            .fill(fillColor)
            .overlay(
                polygonPath
                    .stroke(Color.primaryPink.opacity(0.65), lineWidth: 1.4)
            )
    }

    private func path(for points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

private struct RemixSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let prompt: String
    let icon: String
    let colors: (Color, Color)

    var gradient: LinearGradient {
        LinearGradient(colors: [colors.0, colors.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct RemixSuggestionTile: View {
    let suggestion: RemixSuggestion
    var size: CGFloat = 120
    var showsTitle: Bool = true

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(suggestion.gradient)
                .overlay(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .clear, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        .blur(radius: 0.1)
                )
                .shadow(color: .black.opacity(0.3), radius: 18, x: 0, y: 12)
                .frame(width: size, height: size)

            Image(systemName: suggestion.icon)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 4)
                .offset(y: showsTitle ? -size * 0.18 : 0)

            if showsTitle {
                Text(suggestion.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .frame(width: size, height: size)
    }
}


private struct RemixResultView: View {
    let image: UIImage
    @State private var saveStatus: String?
    @State private var isSharing = false

    var body: some View {
        VStack(spacing: 18) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 10)

            if let saveStatus {
                Text(saveStatus)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primaryPink)
            }

            HStack(spacing: 16) {
                Button(action: { isSharing = true }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.primaryPink.opacity(0.18))
                        .foregroundStyle(Color.primaryPink)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $isSharing) {
                    ShareSheet(activityItems: [image])
                }

                Button(action: saveToPhotos) {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.primaryPink)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .padding()
    }

    private func saveToPhotos() {
        ImageSaver().write(image: image) { error in
            if let error {
                saveStatus = "Save failed: \(error.localizedDescription)"
            } else {
                saveStatus = "Saved to Photos"
            }
        }
    }
}

private final class ImageSaver: NSObject {
    private var completion: ((Error?) -> Void)?

    func write(image: UIImage, completion: @escaping (Error?) -> Void) {
        self.completion = completion
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc private func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer?) {
        completion?(error)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum FullscreenContent: Identifiable {
    case photo(UIImage)
    case map
    case remix(UIImage)

    var id: String {
        switch self {
        case .photo: return "photo"
        case .map: return "map"
        case .remix: return "remix"
        }
    }
}

private struct PersonalizedMapThumbnail: View {
    let result: AnalysisResult
    let cardColor: Color
    let borderColor: Color

    var body: some View {
        ZStack {
            if let image = result.primaryImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    cardColor
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(Color.resultPrimary.opacity(0.8))
                }
            }

            AnalysisOverlayView(result: result)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderColor.opacity(0.4), lineWidth: 1)
        )
    }
}

private enum OverlayPhase {
    case scan, vertical, horizontal, details
}

private struct PhotoDetailView: View {
    let image: UIImage?
    let result: AnalysisResult
    let showAnalysisOverlay: Bool
    let deferBubbles: Bool

    @State private var overlayPhase: OverlayPhase
    @State private var cycleActive: Bool

    init(image: UIImage?, result: AnalysisResult, showAnalysisOverlay: Bool = false, deferBubbles: Bool = false) {
        self.image = image
        self.result = result
        self.showAnalysisOverlay = showAnalysisOverlay
        self.deferBubbles = deferBubbles
        _overlayPhase = State(initialValue: deferBubbles ? .scan : .details)
        _cycleActive = State(initialValue: deferBubbles)
    }

    var body: some View {
        GeometryReader { proxy in
            let containerSize = proxy.size
            let imageAspect = (image?.size.width ?? 1) / max(image?.size.height ?? 1, 1)
            let containerAspect = containerSize.width / max(containerSize.height, 1)
            let normalizedFaceRect = result.overlay.normalizedBoundingRect(
                imageWidth: result.imageWidth,
                imageHeight: result.imageHeight
            )
            let drawSize: CGSize = {
                if containerAspect > imageAspect {
                    let height = containerSize.height
                    return CGSize(width: height * imageAspect, height: height)
                } else {
                    let width = containerSize.width
                    return CGSize(width: width, height: width / imageAspect)
                }
            }()

            let offsetX = (containerSize.width - drawSize.width) / 2
            let offsetY = (containerSize.height - drawSize.height) / 2

            ZStack(alignment: .topLeading) {
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: drawSize.width, height: drawSize.height)
                        .position(x: containerSize.width / 2, y: containerSize.height / 2)
                } else {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: drawSize.width, height: drawSize.height)
                        .position(x: containerSize.width / 2, y: containerSize.height / 2)
                        .foregroundStyle(Color.primaryPink.opacity(0.8))
                }

                if showAnalysisOverlay {
                    AnalysisOverlayView(result: result)
                        .frame(width: drawSize.width, height: drawSize.height)
                        .offset(x: offsetX, y: offsetY)
                }

                if deferBubbles {
                    if overlayPhase == .scan {
                        FaceScanAnimation {
                            advancePhase(.vertical)
                        }
                        .frame(width: drawSize.width, height: drawSize.height)
                        .offset(x: offsetX, y: offsetY)
                    }

                    if overlayPhase == .vertical {
                        FaceVerticalRatioOverlay(
                            percentages: result.verticalRatioPercentages,
                            normalizedFaceRect: normalizedFaceRect
                        )
                            .frame(width: drawSize.width, height: drawSize.height)
                            .offset(x: offsetX, y: offsetY)
                    }

                    if overlayPhase == .horizontal {
                        FaceHorizontalRatioOverlay(
                            percentages: result.horizontalRatioPercentages,
                            normalizedFaceRect: normalizedFaceRect
                        )
                            .frame(width: drawSize.width, height: drawSize.height)
                            .offset(x: offsetX, y: offsetY)
                    }
                } else {
                    FaceVerticalRatioOverlay(
                        percentages: result.verticalRatioPercentages,
                        normalizedFaceRect: normalizedFaceRect
                    )
                        .frame(width: drawSize.width, height: drawSize.height)
                        .offset(x: offsetX, y: offsetY)

                    FaceHorizontalRatioOverlay(
                        percentages: result.horizontalRatioPercentages,
                        normalizedFaceRect: normalizedFaceRect
                    )
                        .frame(width: drawSize.width, height: drawSize.height)
                        .offset(x: offsetX, y: offsetY)
                }

                if !deferBubbles || overlayPhase == .details {
                    FaceDetailDotsOverlay(
                        result: result,
                        imageFrame: CGRect(origin: CGPoint(x: offsetX, y: offsetY), size: drawSize),
                        containerSize: containerSize
                    )

                    MeasurementTagOverlay(
                        result: result,
                        imageFrame: CGRect(origin: CGPoint(x: offsetX, y: offsetY), size: drawSize),
                        containerSize: containerSize
                    )
                }
            }
            .frame(width: containerSize.width, height: containerSize.height)
        }
        .padding()
        .onAppear {
            if !deferBubbles {
                cycleActive = false
            }
        }
        .onDisappear { cycleActive = false }
        .onChange(of: overlayPhase) { _, newPhase in
            guard deferBubbles else { return }
            switch newPhase {
            case .vertical:
                schedulePhaseChange(to: .horizontal, after: 2.6)
            case .horizontal:
                schedulePhaseChange(to: .details, after: 2.6)
            case .details:
                schedulePhaseChange(to: .scan, after: 6.0)
            case .scan:
                break
            }
        }
    }

    private func advancePhase(_ phase: OverlayPhase) {
        guard cycleActive else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            overlayPhase = phase
        }
    }

    private func schedulePhaseChange(to phase: OverlayPhase, after delay: Double) {
        guard cycleActive else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard cycleActive else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                overlayPhase = phase
            }
        }
    }
}

private struct FaceDetailDotsOverlay: View {
    let result: AnalysisResult
    let imageFrame: CGRect
    let containerSize: CGSize

    var body: some View {
        let zones = result.overlay
            .normalizedZones(imageWidth: result.imageWidth, imageHeight: result.imageHeight)
            .filter { !["highlight", "contour", "blush"].contains($0.key.lowercased()) }
        let callouts = makeResolvedCallouts(from: zones)

        ZStack {
            ForEach(callouts) { callout in
                DetailCalloutView(callout: callout)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .allowsHitTesting(false)
    }

    private func makeResolvedCallouts(from zones: [String: [CGPoint]]) -> [ResolvedCallout] {
        let excludedKeys: Set<String> = ["highlight", "contour", "blush"]

        let base: [DetailCallout] = zones
            .filter { !excludedKeys.contains($0.key.lowercased()) }
            .sorted(by: { $0.key < $1.key })
            .compactMap { key, points in
            guard !points.isEmpty else { return nil }
            let centroid = points.reduce(CGPoint.zero) { partial, point in
                CGPoint(x: partial.x + point.x, y: partial.y + point.y)
            }
            let normalized = CGPoint(x: centroid.x / CGFloat(points.count), y: centroid.y / CGFloat(points.count))
            let converted = CGPoint(
                x: imageFrame.origin.x + normalized.x * imageFrame.width,
                y: imageFrame.origin.y + normalized.y * imageFrame.height
            )

            let detailText = result.recommendations[key]?.details ?? defaultDetail(for: key)
            let orientation: DetailCallout.Orientation = converted.x > imageFrame.midX ? .right : .left

            return DetailCallout(
                id: key,
                title: key.capitalized,
                detail: detailText,
                point: converted,
                orientation: orientation
            )
        }

        let bubbleWidth = min(containerSize.width * 0.38, 220)
        let bubbleHeight: CGFloat = 78
        let margin: CGFloat = 18
        let spacing = bubbleHeight + 16

        func horizontalOrigin(for orientation: DetailCallout.Orientation) -> CGFloat {
            switch orientation {
            case .left:
                return max(margin, imageFrame.minX - bubbleWidth - margin)
            case .right:
                return min(containerSize.width - bubbleWidth - margin, imageFrame.maxX + margin)
            }
        }

        func distributeCenters(for orientation: DetailCallout.Orientation) -> [String: CGFloat] {
            let filtered = base.filter { $0.orientation == orientation }.sorted { $0.point.y < $1.point.y }
            guard !filtered.isEmpty else { return [:] }

            let minCenter = bubbleHeight / 2 + margin
            let maxCenter = containerSize.height - bubbleHeight / 2 - margin

            var centers = filtered.map { min(max($0.point.y, minCenter), maxCenter) }

            for idx in 1..<centers.count {
                centers[idx] = max(centers[idx], centers[idx - 1] + spacing)
            }

            if let last = centers.last, last > maxCenter {
                centers[centers.count - 1] = maxCenter
                if centers.count > 1 {
                    for idx in stride(from: centers.count - 2, through: 0, by: -1) {
                        centers[idx] = min(centers[idx], centers[idx + 1] - spacing)
                    }
                }
            }

            return Dictionary(uniqueKeysWithValues: zip(filtered.map { $0.id }, centers))
        }

        let leftCenters = distributeCenters(for: .left)
        let rightCenters = distributeCenters(for: .right)

        return base.map { callout in
            let centerY = (callout.orientation == .left ? leftCenters[callout.id] : rightCenters[callout.id]) ?? callout.point.y
            let originY = min(
                max(centerY - bubbleHeight / 2, margin),
                containerSize.height - bubbleHeight - margin
            )
            let frame = CGRect(
                x: horizontalOrigin(for: callout.orientation),
                y: originY,
                width: bubbleWidth,
                height: bubbleHeight
            )
            let anchorX = callout.orientation == .left ? frame.maxX : frame.minX
            let bubbleAnchor = CGPoint(x: anchorX, y: frame.midY)
            let lineMid = CGPoint(
                x: (bubbleAnchor.x + callout.point.x) / 2,
                y: (bubbleAnchor.y + callout.point.y) / 2
            )

            return ResolvedCallout(
                id: callout.id,
                base: callout,
                bubbleFrame: frame,
                bubbleAnchor: bubbleAnchor,
                lineMidPoint: lineMid
            )
        }
    }

    private func defaultDetail(for key: String) -> String {
        switch key.lowercased() {
        case "blush":
            return "Blend blush along this arc to add lift."
        case "contour":
            return "Shade just under this contour line to sculpt."
        case "highlight":
            return "Tap highlight where light naturally hits."
        case "eyes":
            return "Layer shadows moving outward from this baseline."
        case "lips":
            return "Align lip color with your undertone here."
        default:
            return "Focus product placement along this region."
        }
    }
}

private struct MeasurementTagOverlay: View {
    let result: AnalysisResult
    let imageFrame: CGRect
    let containerSize: CGSize
    @State private var visibleTagIDs: Set<String> = []

    var body: some View {
        let tags = resolveTags()
        return ZStack {
            ForEach(Array(tags.enumerated()), id: \.element.id) { index, tag in
                MeasurementTagView(tag: tag)
                    .opacity(visibleTagIDs.contains(tag.id) ? 1 : 0)
                    .offset(y: visibleTagIDs.contains(tag.id) ? 0 : 12)
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.85)
                            .delay(Double(index) * 0.1),
                        value: visibleTagIDs
                    )
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .onAppear {
            let ids = tags.map(\.id)
            visibleTagIDs = []
            for (offset, id) in ids.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(offset) * 0.1) {
                    visibleTagIDs.insert(id)
                }
            }
        }
    }

    private func resolveTags() -> [ResolvedMeasurementTag] {
        let baseTags = measurementTags()
        guard !baseTags.isEmpty else { return [] }

        let bubbleWidth = min(containerSize.width * 0.32, 150)
        let bubbleHeight: CGFloat = 44
        let margin: CGFloat = 10
        let spacing = bubbleHeight + 8

        func originX(for orientation: DetailCallout.Orientation) -> CGFloat {
            switch orientation {
            case .left:
                return max(margin, imageFrame.minX - bubbleWidth - 10)
            case .right:
                return min(containerSize.width - bubbleWidth - margin, imageFrame.maxX + 10)
            }
        }

        func distributeCenters(for orientation: DetailCallout.Orientation) -> [String: CGFloat] {
            let filtered = baseTags.filter { $0.orientation == orientation }.sorted { $0.anchor.y < $1.anchor.y }
            guard !filtered.isEmpty else { return [:] }

            let minCenter = bubbleHeight / 2 + margin
            let maxCenter = containerSize.height - bubbleHeight / 2 - margin

            var centers = filtered.map { min(max($0.anchor.y, minCenter), maxCenter) }
            for idx in 1..<centers.count {
                centers[idx] = max(centers[idx], centers[idx - 1] + spacing)
            }
            if let last = centers.last, last > maxCenter {
                centers[centers.count - 1] = maxCenter
                if centers.count > 1 {
                    for idx in stride(from: centers.count - 2, through: 0, by: -1) {
                        centers[idx] = min(centers[idx], centers[idx + 1] - spacing)
                    }
                }
            }
            return Dictionary(uniqueKeysWithValues: zip(filtered.map { $0.id }, centers))
        }

        let leftCenters = distributeCenters(for: .left)
        let rightCenters = distributeCenters(for: .right)

        return baseTags.map { tag in
            let centerY = (tag.orientation == .left ? leftCenters[tag.id] : rightCenters[tag.id]) ?? tag.anchor.y
            let originY = min(max(centerY - bubbleHeight / 2, margin), containerSize.height - bubbleHeight - margin)
            let frame = CGRect(
                x: originX(for: tag.orientation),
                y: originY,
                width: bubbleWidth,
                height: bubbleHeight
            )
            let anchorX = tag.orientation == .left ? frame.maxX : frame.minX
            let bubbleAnchor = CGPoint(x: anchorX, y: frame.midY)
            let midPoint = CGPoint(
                x: (bubbleAnchor.x + tag.anchor.x) / 2,
                y: (bubbleAnchor.y + tag.anchor.y) / 2
            )

            return ResolvedMeasurementTag(
                id: tag.id,
                base: tag,
                bubbleFrame: frame,
                bubbleAnchor: bubbleAnchor,
                lineMidPoint: midPoint
            )
        }
    }

    private func measurementTags() -> [MeasurementTag] {
        let faceRectNormalized = result.overlay
            .normalizedBoundingRect(imageWidth: result.imageWidth, imageHeight: result.imageHeight)
            ?? CGRect(x: 0.2, y: 0.15, width: 0.6, height: 0.7)

        func anchor(for relative: CGPoint) -> CGPoint {
            let normalizedX = faceRectNormalized.origin.x + relative.x * faceRectNormalized.width
            let normalizedY = faceRectNormalized.origin.y + relative.y * faceRectNormalized.height
            return CGPoint(
                x: imageFrame.origin.x + normalizedX * imageFrame.width,
                y: imageFrame.origin.y + normalizedY * imageFrame.height
            )
        }

        let specs: [(id: String, title: String, value: String, point: CGPoint, orientation: DetailCallout.Orientation)] = [
            ("face_shape", "Face Shape", readable(result.faceShape), CGPoint(x: 0.5, y: 0.0), .left),
            ("skin_tone", "Skin Tone", readable(result.skinTone), CGPoint(x: 0.55, y: 0.12), .right),
            ("undertone", "Undertone", readable(result.undertone), CGPoint(x: 0.45, y: 0.22), .right),
            ("forehead_width", "Forehead Width", px(result.dimensions.foreheadWidth), CGPoint(x: 0.2, y: 0.15), .left),
            ("cheekbone_width", "Cheekbone Width", px(result.dimensions.cheekboneWidth), CGPoint(x: 0.8, y: 0.45), .right),
            ("jaw_width", "Jaw Width", px(result.dimensions.jawWidth), CGPoint(x: 0.2, y: 0.7), .left),
            ("face_length", "Face Length", px(result.dimensions.faceLength), CGPoint(x: 0.8, y: 0.8), .right),
            ("jaw_angle", "Jaw Angle", angle(result.dimensions.jawAngle), CGPoint(x: 0.35, y: 0.95), .left)
        ]

        return specs.map { spec in
            MeasurementTag(
                id: spec.id,
                title: spec.title,
                value: spec.value,
                anchor: anchor(for: spec.point),
                orientation: spec.orientation
            )
        }
    }

    private func px(_ value: Double) -> String {
        "\(Int(value.rounded())) px"
    }

    private func angle(_ radians: Double) -> String {
        let degrees = radians * 180 / .pi
        return String(format: "%.0f°", degrees)
    }

}

private struct MeasurementTag: Identifiable {
    let id: String
    let title: String
    let value: String
    let anchor: CGPoint
    let orientation: DetailCallout.Orientation
}

private struct ResolvedMeasurementTag: Identifiable {
    let id: String
    let base: MeasurementTag
    let bubbleFrame: CGRect
    let bubbleAnchor: CGPoint
    let lineMidPoint: CGPoint
}

private struct MeasurementTagView: View {
    let tag: ResolvedMeasurementTag
    @State private var accumulatedOffset: CGSize = .zero
    @State private var draggingOffset: CGSize = .zero

    private var totalOffset: CGSize {
        CGSize(width: accumulatedOffset.width + draggingOffset.width,
               height: accumulatedOffset.height + draggingOffset.height)
    }

    var body: some View {
        let bubbleCenter = CGPoint(
            x: tag.bubbleFrame.midX + totalOffset.width,
            y: tag.bubbleFrame.midY + totalOffset.height
        )
        let halfWidth = tag.bubbleFrame.width / 2
        let anchorDistance = max(halfWidth - 6, halfWidth * 0.85)
        let anchorX = bubbleCenter.x + (tag.base.orientation == .left ? anchorDistance : -anchorDistance)
        let bubbleAnchor = CGPoint(x: anchorX, y: bubbleCenter.y)
        let lineMid = CGPoint(
            x: (bubbleAnchor.x + tag.base.anchor.x) / 2,
            y: (bubbleAnchor.y + tag.base.anchor.y) / 2
        )

        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: tag.base.anchor)
                path.addLine(to: lineMid)
                path.addLine(to: bubbleAnchor)
            }
            .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 3)

            Circle()
                .fill(Color.primaryPink)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1.5)
                )
                .position(tag.base.anchor)

            MeasurementBubble(title: tag.base.title, value: tag.base.value, orientation: tag.base.orientation)
                .frame(width: tag.bubbleFrame.width, height: tag.bubbleFrame.height)
                .position(x: bubbleCenter.x, y: bubbleCenter.y)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    draggingOffset = value.translation
                }
                .onEnded { value in
                    accumulatedOffset.width += value.translation.width
                    accumulatedOffset.height += value.translation.height
                    draggingOffset = .zero
                }
        )
    }
}

private struct MeasurementBubble: View {
    let title: String
    let value: String
    let orientation: DetailCallout.Orientation

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.9))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primaryPink.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 0.9)
        )
        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
    }
}

private struct FaceScanAnimation: View {
    @State private var rotate = false
    @State private var scan = false
    @State private var fadeOut = false
    var onComplete: (() -> Void)? = nil

    var body: some View {
        let autoCycle = onComplete != nil

        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                FaceScanGrid()
                    .frame(width: size * 0.95, height: size * 0.95)
                    .opacity(0.9)
                    .blendMode(.screen)

                RoundedRectangle(cornerRadius: size / 2)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                    .frame(width: size * 0.9, height: size * 0.9)
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(.linear(duration: 14).repeatForever(autoreverses: false), value: rotate)

                RoundedRectangle(cornerRadius: size / 2)
                    .trim(from: 0, to: 0.5)
                    .stroke(Color.primaryPink.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [6, 8]))
                    .frame(width: size * 0.8, height: size * 0.8)
                    .rotationEffect(.degrees(rotate ? -360 : 0))
                    .animation(.linear(duration: 10).repeatForever(autoreverses: false), value: rotate)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.primaryPink.opacity(0.4),
                                Color.white.opacity(0.25),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: size * 0.55)
                    .frame(width: size * 0.9)
                    .offset(y: scan ? size * 0.35 : -size * 0.35)
                    .blendMode(.screen)
                    .animation(.linear(duration: 3.2).repeatForever(autoreverses: false), value: scan)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .opacity(autoCycle ? (fadeOut ? 0 : 1) : 1)
            .animation(autoCycle ? .easeOut(duration: 0.5).delay(3.0) : .default, value: fadeOut)
            .onAppear {
                rotate = true
                scan.toggle()
                guard autoCycle else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    fadeOut = true
                    onComplete?()
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct FaceScanGrid: View {
    let rows = 12
    let columns = 10

    var body: some View {
        GeometryReader { geo in
            let spacingX = geo.size.width / CGFloat(columns - 1)
            let spacingY = geo.size.height / CGFloat(rows - 1)
            ForEach(0..<rows, id: \.self) { row in
                ForEach(0..<columns, id: \.self) { column in
                    Circle()
                        .fill(Color.white.opacity(0.65))
                        .frame(width: 3, height: 3)
                        .position(
                            x: CGFloat(column) * spacingX,
                            y: CGFloat(row) * spacingY
                        )
                        .opacity(0.3 + Double(row + column).truncatingRemainder(dividingBy: 3) * 0.2)
                }
            }
        }
    }
}

private struct FaceVerticalRatioOverlay: View {
    let percentages: [Int]
    let normalizedFaceRect: CGRect?

    init(percentages: [Int], normalizedFaceRect: CGRect? = nil) {
        self.percentages = percentages.isEmpty ? [20, 20, 20, 20, 20] : percentages
        self.normalizedFaceRect = normalizedFaceRect
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            let faceRect = normalizedFaceRect.map { rect -> CGRect in
                CGRect(
                    x: rect.origin.x * width,
                    y: rect.origin.y * height,
                    width: rect.width * width,
                    height: rect.height * height
                )
            } ?? CGRect(x: width * 0.08, y: height * 0.08, width: width * 0.84, height: height * 0.8)

            let left = faceRect.minX
            let right = faceRect.maxX
            let top = max(faceRect.minY, height * 0.05)
            let bottom = min(faceRect.maxY, height * 0.95)
            let spacing = (right - left) / CGFloat(percentages.count + 1)

            ZStack(alignment: .topLeading) {
                Text("Your Face Vertical Ratio")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .shadow(radius: 6)
                    .position(x: width / 2, y: max(top * 0.6, 14))

                ForEach(Array(percentages.enumerated()), id: \.offset) { index, percent in
                    let x = left + spacing * CGFloat(index + 1)

                    Path { path in
                        path.move(to: CGPoint(x: x, y: top))
                        path.addLine(to: CGPoint(x: x, y: bottom))
                    }
                    .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 1.1, dash: [4, 4]))

                    if index < percentages.count - 1 {
                        let nextX = left + spacing * CGFloat(index + 2)
                        ArrowLine(start: CGPoint(x: x, y: top - 10), end: CGPoint(x: nextX, y: top - 10))
                            .stroke(Color.white.opacity(0.7), lineWidth: 1)
                    }

                    Text("\(percent)%")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primaryPink.opacity(0.9), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.8))
                        .position(x: x, y: top - 25)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct FaceHorizontalRatioOverlay: View {
    let percentages: [Int]
    let normalizedFaceRect: CGRect?

    init(percentages: [Int], normalizedFaceRect: CGRect? = nil) {
        self.percentages = percentages.isEmpty ? [34, 33, 33] : percentages
        self.normalizedFaceRect = normalizedFaceRect
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            let faceRect = normalizedFaceRect.map { rect -> CGRect in
                CGRect(
                    x: rect.origin.x * width,
                    y: rect.origin.y * height,
                    width: rect.width * width,
                    height: rect.height * height
                )
            } ?? CGRect(x: width * 0.1, y: height * 0.2, width: width * 0.8, height: height * 0.7)

            let left = faceRect.minX
            let right = faceRect.maxX
            let top = faceRect.minY
            let bottom = faceRect.maxY
            let spacing = (bottom - top) / CGFloat(max(percentages.count - 1, 1))

            ZStack(alignment: .topLeading) {
                Text("Your Face Horizontal Ratio")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .shadow(radius: 6)
                    .position(x: width / 2, y: max(top - 22, 16))

                ForEach(Array(percentages.enumerated()), id: \.offset) { index, percent in
                    let y = top + spacing * CGFloat(index)

                    Path { path in
                        path.move(to: CGPoint(x: left, y: y))
                        path.addLine(to: CGPoint(x: right, y: y))
                    }
                    .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 1.1))

                    Text("\(percent)%")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primaryPink.opacity(0.9), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.8))
                        .position(x: min(width - 20, right + width * 0.05), y: y)

                    if index < percentages.count - 1 {
                        let nextY = top + spacing * CGFloat(index + 1)
                        VerticalArrowLine(
                            start: CGPoint(x: min(width - 20, right + width * 0.04), y: y),
                            end: CGPoint(x: min(width - 20, right + width * 0.04), y: nextY)
                        )
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ArrowLine: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let size: CGFloat = 5

        func drawArrow(at point: CGPoint, direction: CGFloat) {
            path.move(to: CGPoint(x: point.x - size * cos(direction + .pi / 6),
                                  y: point.y - size * sin(direction + .pi / 6)))
            path.addLine(to: point)
            path.addLine(to: CGPoint(x: point.x - size * cos(direction - .pi / 6),
                                     y: point.y - size * sin(direction - .pi / 6)))
        }

        drawArrow(at: start, direction: angle + .pi)
        drawArrow(at: end, direction: angle)
        return path
    }
}

private struct VerticalArrowLine: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        func arrow(at point: CGPoint, directionUp: Bool) {
            let size: CGFloat = 6
            let sign: CGFloat = directionUp ? -1 : 1
            path.move(to: CGPoint(x: point.x - size / 2, y: point.y + sign * size))
            path.addLine(to: point)
            path.addLine(to: CGPoint(x: point.x + size / 2, y: point.y + sign * size))
        }

        arrow(at: start, directionUp: true)
        arrow(at: end, directionUp: false)
        return path
    }
}

private extension AnalysisResult {
    var verticalRatioPercentages: [Int] {
        let dims = dimensions
        let segments = [
            max(dims.foreheadWidth, 1) * 0.7,
            max(dims.cheekboneWidth, 1) * 0.5,
            max(dims.faceLength, 1) * 0.4,
            max(dims.jawWidth, 1) * 0.45,
            max(dims.jawWidth, 1) * 0.35
        ]
        let total = segments.reduce(0, +)
        guard total > 0 else { return [20, 20, 20, 20, 20] }
        var percents = segments.map { Int(round($0 / total * 100)) }
        let diff = 100 - percents.reduce(0, +)
        if let idx = percents.indices.max(by: { percents[$0] < percents[$1] }) {
            percents[idx] += diff
        }
        return percents
    }

    var horizontalRatioPercentages: [Int] {
        let dims = dimensions
        let segments = [
            max(dims.foreheadWidth, 1) * 0.4,
            max(dims.faceLength, 1) * 0.35,
            max(dims.jawWidth, 1) * 0.25
        ]
        let total = segments.reduce(0, +)
        guard total > 0 else { return [34, 33, 33] }
        var percents = segments.map { Int(round($0 / total * 100)) }
        let diff = 100 - percents.reduce(0, +)
        if let idx = percents.indices.max(by: { percents[$0] < percents[$1] }) {
            percents[idx] += diff
        }
        return percents
    }
}

// MakeupSuggestionPanel temporarily removed

private struct DetailCallout: Identifiable {
    enum Orientation {
        case left, right
    }

    let id: String
    let title: String
    let detail: String
    let point: CGPoint
    let orientation: Orientation
}

private struct ResolvedCallout: Identifiable {
    let id: String
    let base: DetailCallout
    let bubbleFrame: CGRect
    let bubbleAnchor: CGPoint
    let lineMidPoint: CGPoint
}

private struct DetailCalloutView: View {
    let callout: ResolvedCallout

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: callout.base.point)
                path.addLine(to: callout.lineMidPoint)
                path.addLine(to: callout.bubbleAnchor)
            }
            .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 3)

            AnimatedDot()
                .position(callout.base.point)

            CalloutBubble(title: callout.base.title, detail: callout.base.detail)
                .frame(width: callout.bubbleFrame.width, height: callout.bubbleFrame.height)
                .position(x: callout.bubbleFrame.midX, y: callout.bubbleFrame.midY)
        }
    }
}

private struct AnimatedDot: View {
    @State private var ripple = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primaryPink.opacity(0.4), lineWidth: 2)
                .frame(width: 34, height: 34)
                .scaleEffect(ripple ? 1.4 : 0.3)
                .opacity(ripple ? 0 : 0.8)

            Circle()
                .fill(Color.primaryPink)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .scaleEffect(ripple ? 1.05 : 0.85)
        }
        .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: ripple)
        .onAppear { ripple = true }
    }
}

private struct CalloutBubble: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.9))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.9))
                .lineLimit(3)
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// Removed FaceMetricsPanel in favor of measurement tag callouts.

private struct FullScreenGallery: View {
    let content: FullscreenContent
    let result: AnalysisResult
    let suggestions: [RemixSuggestion]
    let isLoading: Bool
    var dismiss: () -> Void
    var onRequestRemix: (UIImage) -> Void
    var onSuggestionRemix: (UIImage, RemixSuggestion) -> Void
    var onShowMakeupStudio: (UIImage) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 26) {
                heroView
                effectCarousel
                controlGroup
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [Color.backgroundDark, Color.resultBackgroundDark],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
        )
        .overlay(alignment: .topTrailing) {
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding()
            }
        }
    }

    @ViewBuilder
    private var heroView: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.resultBackgroundDark.opacity(0.75))
                .frame(height: 520)
                .overlay {
                    switch content {
                    case .photo:
                        PhotoDetailView(
                            image: effectSourceImage,
                            result: result,
                            showAnalysisOverlay: false,
                            deferBubbles: true
                        )
                    case .map:
                        PhotoDetailView(
                            image: result.primaryImage,
                            result: result,
                            showAnalysisOverlay: true,
                            deferBubbles: true
                        )
                    case .remix(let image):
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(Color.resultBorderDark.opacity(0.85), lineWidth: 1.2)
                )
                .shadow(color: .black.opacity(0.5), radius: 40, y: 22)
                .overlay(alignment: .topLeading) {
                    Label("AI Makeup Vision", systemImage: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textDark)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                        )
                        .padding(24)
                }

            HStack(spacing: 18) {
                Label("Glass luminous finish", systemImage: "sparkles")
                Label("ETA 3s", systemImage: "timer")
                Label("Status • Live", systemImage: "waveform.path.ecg")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.textDark.opacity(0.9))
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(24)
        }
    }

    @ViewBuilder
    private var keyMetricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            MetricCard(title: "Face shape", value: readableMetric(result.faceShape))
            MetricCard(title: "Skin tone", value: readableMetric(result.skinTone))
            MetricCard(title: "Undertone", value: readableMetric(result.undertone))
            MetricCard(title: "Jaw width", value: "\(formattedMetric(result.dimensions.jawWidth)) px")
        }
    }

    @ViewBuilder
    private var effectCarousel: some View {
        if let source = effectSourceImage {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick presets")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Tap a card to preview instantly.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(suggestions) { suggestion in
                            Button {
                                onSuggestionRemix(source, suggestion)
                            } label: {
                                FullscreenEffectCard(suggestion: suggestion)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var controlGroup: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blend controls")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Adjust how the AI mixes each layer.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Button("Reset") {}
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primaryPink)
            }

            ControlSlider(label: "Intensity", value: .constant(0.76), formatter: { _ in "76%" })
            ControlSlider(label: "Color drift", value: .constant(0.62), formatter: { _ in "Cool +12" })
            FlowChipCloud(items: ["Glass skin", "Floating liner", "Luminous contour", "Stardust veil"])
        }
        .padding(20)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var actionButtons: some View {
        if let source = effectSourceImage {
            VStack(spacing: 12) {
                ButtonRow(title: "Creative remix", systemImage: "sparkles.rectangle.stack") {
                    onRequestRemix(source)
                }
                ButtonRow(title: "Try makeup studio", systemImage: "wand.and.stars", background: Color.primaryPink, foreground: .black) {
                    onShowMakeupStudio(source)
                }
            }
            .padding(.top, 4)
        }
    }

    private var effectSourceImage: UIImage? {
        switch content {
        case .photo(let image):
            return image
        case .map:
            return result.primaryImage
        case .remix:
            return nil
        }
    }
}

private struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        context.coordinator.hostingController.rootView = content
        let hosted = context.coordinator.hostingController.view!
        hosted.translatesAutoresizingMaskIntoConstraints = true
        hosted.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosted.frame = scrollView.bounds
        hosted.backgroundColor = .clear
        scrollView.addSubview(hosted)

        scrollView.contentSize = hosted.bounds.size
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = content
        let hosted = context.coordinator.hostingController.view!
        hosted.frame = uiView.bounds
        uiView.contentSize = hosted.bounds.size
        hosted.setNeedsDisplay()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hostingController: UIHostingController(rootView: content))
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hostingController: UIHostingController<Content>

        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController.view
        }
    }
}

private struct AnimatedSection<Content: View>: View {
    @State private var isVisible = false
    let delay: Double
    let content: () -> Content

    var body: some View {
        content()
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.2).delay(delay), value: isVisible)
            .onAppear { isVisible = true }
    }
}

private struct HeartbeatBackdrop: View {
    @State private var pulse = false
    @State private var ripple = false

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.55, 360)
            let gradient = LinearGradient(
                colors: [
                    Color.primaryPink.opacity(0.45),
                    Color.resultPrimary.opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "heart.fill")
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(width: width, height: width)
                        .scaleEffect(ripple ? 1.45 + CGFloat(index) * 0.18 : 0.55)
                        .opacity(ripple ? 0 : 0.12)
                        .foregroundStyle(Color.primaryPink.opacity(0.18))
                        .blur(radius: 60)
                        .animation(
                            .easeOut(duration: 1.8)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.25),
                            value: ripple
                        )
                }

                Image(systemName: "heart.fill")
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: width, height: width)
                    .scaleEffect(pulse ? 1.08 : 0.9)
                    .foregroundStyle(gradient)
                    .opacity(0.18)
                    .blur(radius: 38)
                    .animation(
                        .easeInOut(duration: 1)
                            .repeatForever(autoreverses: true),
                        value: pulse
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .offset(y: -60)
            .opacity(0.5)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .onAppear {
            pulse = true
            ripple = true
        }
    }
}

private struct SpectrumAuraEffect: ViewModifier {
    @State private var animate = false
    @State private var glowing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(glowing ? 1.015 : 0.99)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [.resultPrimary, .primaryPink, .accentColor, .resultPrimary]),
                            center: .center
                        ),
                        lineWidth: glowing ? 2.8 : 1.2
                    )
                    .blur(radius: glowing ? 1.2 : 2.5)
                    .opacity(glowing ? 0.55 : 0.2)
            )
            .overlay(
                BurstParticles()
                    .blendMode(.screen)
            )
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: glowing)
            .onAppear {
                glowing = true
            }
    }
}

private struct BurstParticles: View {
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<12, id: \.self) { index in
                    let angle = Double(index) / 12.0 * 2 * .pi
                    Circle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 4, height: 4)
                        .offset(
                            x: CGFloat(cos(angle)) * geo.size.width * (animate ? 0.45 : 0.1),
                            y: CGFloat(sin(angle)) * geo.size.height * (animate ? 0.45 : 0.1)
                        )
                        .opacity(animate ? 0.0 : 1.0)
                        .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false).delay(Double(index) * 0.05), value: animate)
                }
            }
        }
        .onAppear { animate = true }
        .allowsHitTesting(false)
    }
}

private struct MakeupEffectsView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    @State private var intensity: Double = 0.76
    @State private var colorDrift: Double = 12
    @State private var isSaving = false
    @State private var showShareSheet = false

    private let looks = MakeupLook.sample
    private let smartTips = SmartTip.sample

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                stageSection
                queueSection
                controlsSection
                looksSection
                recommendationsSection
                actionsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(colors: [Color.black, Color.cardDark], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Apply Makeup Effects")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("AI Makeup Studio")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { showShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Button(action: saveImage) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .frame(width: 38, height: 38)
                        } else {
                            Image(systemName: "tray.and.arrow.down")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareController(items: [image])
        }
    }

    private var stageSection: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 30, y: 16)

            VStack(alignment: .leading, spacing: 6) {
                Text("Active look")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                Text("Neon Bloom Contour")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                HStack(spacing: 18) {
                    Label("Glass luminous finish", systemImage: "sparkles")
                    Label("ETA 3s", systemImage: "timer")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.35).blur(radius: 20))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.top, 220)
        }
    }

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blend queue")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("AI steps processing right now")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text("LIVE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.85), in: Capsule())
            }

            VStack(spacing: 14) {
                BlendProgressRow(title: "Base skin prep", progress: 1.0, description: "Complete")
                BlendProgressRow(title: "Eye diffusion", progress: 0.72, description: "Balancing gradients")
                BlendProgressRow(title: "Contour lift", progress: 0.48, description: "Sculpting undertones")
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blend & color story")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Fine tune how the AI applies the effect.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Button("Reset") {
                    withAnimation {
                        intensity = 0.5
                        colorDrift = 0
                    }
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.primaryPink)
            }

            ControlSlider(label: "Intensity", value: $intensity, formatter: { value in
                "\(Int(value * 100))%"
            })

            ControlSlider(
                label: "Color drift",
                value: Binding(
                    get: { (colorDrift + 30) / 60 },
                    set: { colorDrift = $0 * 60 - 30 }
                ),
                formatter: { _ in
                    colorDrift >= 0 ? "Cool +\(Int(colorDrift))" : "Warm \(Int(colorDrift))"
                }
            )

            FlowChipCloud(items: ["Glass skin", "Floating liner", "Luminous contour", "Stardust veil"])
        }
        .padding(20)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var looksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Looks library")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Tap to preview shades and palettes.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Button("Browse all") {}
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.primaryPink)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(looks) { look in
                    MakeupLookCard(look: look)
                }
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Smart tips")
                .font(.system(size: 16, weight: .semibold))
            ForEach(smartTips) { tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: tip.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primaryPink)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tip.title)
                            .font(.system(size: 14, weight: .semibold))
                        Text(tip.body)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next actions")
                .font(.system(size: 16, weight: .semibold))
            ButtonRow(title: "Save preset", systemImage: "bookmark")
            ButtonRow(title: "Share look", systemImage: "square.and.arrow.up") {
                showShareSheet = true
            }
            ButtonRow(title: "Apply to photo", systemImage: "sparkles", background: Color.primaryPink, foreground: .black) {
                dismiss()
            }
        }
    }

    private func saveImage() {
        isSaving = true
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isSaving = false
        }
    }
}

private struct BlendProgressRow: View {
    let title: String
    let progress: Double
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.primaryPink)
                            .frame(width: proxy.size.width * progress)
                    }
            }
            .frame(height: 6)
        }
    }
}

private struct ControlSlider: View {
    let label: String
    @Binding var value: Double
    var formatter: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(formatter(value))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Slider(value: $value)
                .tint(Color.primaryPink)
        }
    }
}

private struct FlowChipCloud: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct FullscreenEffectCard: View {
    let suggestion: RemixSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(suggestion.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: suggestion.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Text(suggestion.prompt)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
            Spacer(minLength: 20)
            Text("Tap to preview")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(18)
        .frame(width: 200, height: 170, alignment: .leading)
        .background(
            suggestion.gradient
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
    }
}

private struct MakeupLookCard: View {
    let look: MakeupLook

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(look.category)
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.18), in: Capsule())
                Spacer()
                Image(systemName: look.icon)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Text(look.title)
                .font(.system(size: 17, weight: .semibold))
            Text(look.description)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.75))
            HStack(spacing: 6) {
                ForEach(look.palette, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 26, height: 26)
                }
            }
            Button(action: {}) {
                Text(look.cta)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            look.gradient
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct ButtonRow: View {
    let title: String
    let systemImage: String
    var background: Color = Color.white.opacity(0.08)
    var foreground: Color = .white
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: action ?? {}) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(foreground)
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct MakeupLook: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let description: String
    let palette: [Color]
    let icon: String
    let cta: String
    let gradient: LinearGradient

    static let sample: [MakeupLook] = [
        MakeupLook(
            title: "Rosé Halo",
            category: "Wedding",
            description: "Soft shimmer lids with velvet blush contouring.",
            palette: [Color.white.opacity(0.8), Color(hex: 0xFF8FD1), Color(hex: 0xF5E4FF)],
            icon: "heart.fill",
            cta: "Apply",
            gradient: LinearGradient(colors: [Color(hex: 0xFFB6D7), Color(hex: 0xFD5E90)], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        MakeupLook(
            title: "Festival Neon",
            category: "College",
            description: "Duo-chrome liner with holographic cheeks.",
            palette: [Color(hex: 0x00F5FF), Color(hex: 0x845CFF), Color(hex: 0xFF7DEB)],
            icon: "bolt.fill",
            cta: "Preview",
            gradient: LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
        ),
        MakeupLook(
            title: "Boardroom Poise",
            category: "Professional",
            description: "Soft gradient eye with muted satin lip.",
            palette: [Color(hex: 0xD8C0B0), Color(hex: 0x8E7266), Color(hex: 0xF5D2C2)],
            icon: "briefcase.fill",
            cta: "Preview",
            gradient: LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
        ),
        MakeupLook(
            title: "Cosmic Smoke",
            category: "After hours",
            description: "Inky ombré lids with glass-skin highlight.",
            palette: [Color(hex: 0x31263D), Color(hex: 0xB28DFF), Color(hex: 0x90A6FF)],
            icon: "moon.stars.fill",
            cta: "Preview",
            gradient: LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
        )
    ]
}

private struct SmartTip: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String

    static let sample: [SmartTip] = [
        SmartTip(icon: "face_retouching_natural", title: "Lift cheeks", body: "Blend blush outward from mid-cheek to lift and softly carve the jawline."),
        SmartTip(icon: "brush", title: "Layer contour", body: "Layer cream contour first, then seal with translucent halo powder."),
        SmartTip(icon: "ink_highlighter", title: "Target highlight", body: "Keep highlight concentrated along inner brow and cheekbone arc.")
    ]
}

private struct ShareController: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private func formattedMetric(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = 1
    formatter.minimumFractionDigits = 1
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
}

private func readableMetric(_ text: String) -> String {
    text.replacingOccurrences(of: "_", with: " ").capitalized
}

private func readable(_ text: String) -> String {
    readableMetric(text)
}

private func formatted(_ value: Double) -> String {
    formattedMetric(value)
}

#Preview {
    NavigationStack {
        FaceAnalysisResultView(result: .preview)
            .preferredColorScheme(.light)
    }
}
