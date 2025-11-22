import SwiftUI

struct AnalysisResult: Identifiable, Codable, Hashable {
    let id: UUID
    let createdAt: Date
    let faceShape: String
    let skinTone: String
    let undertone: String
    let dimensions: FaceDimensions
    let recommendations: [String: Recommendation]
    let overlay: Overlay
    let skinSampleRGB: [Int]
    let imageData: Data
    let imageWidth: Int
    let imageHeight: Int
    let insights: FeatureInsights?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        faceShape: String,
        skinTone: String,
        undertone: String,
        dimensions: FaceDimensions,
        recommendations: [String: Recommendation],
        overlay: Overlay,
        skinSampleRGB: [Int],
        imageData: Data,
        imageWidth: Int,
        imageHeight: Int,
        insights: FeatureInsights? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.faceShape = faceShape
        self.skinTone = skinTone
        self.undertone = undertone
        self.dimensions = dimensions
        self.recommendations = recommendations
        self.overlay = overlay
        self.skinSampleRGB = skinSampleRGB
        self.imageData = imageData
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.insights = insights
    }

    var primaryImage: UIImage? {
        UIImage(data: imageData)
    }
}

struct FaceDimensions: Codable, Hashable {
    let foreheadWidth: Double
    let cheekboneWidth: Double
    let jawWidth: Double
    let faceLength: Double
    let jawAngle: Double
}

struct GoldenRatioSummary: Hashable {
    let ratio: Double
    let difference: Double
    let interpretation: String
    let guidance: String

    var formattedRatio: String {
        String(format: "%.2f : 1", ratio)
    }

    static let goldenRatio: Double = 1.618
}

struct Overlay: Codable, Hashable {
    let boundingBox: [Double]
    let zones: [String: [[Double]]]

    func normalizedZones(imageWidth: Int, imageHeight: Int) -> [String: [CGPoint]] {
        guard boundingBox.count == 4,
              imageWidth > 0,
              imageHeight > 0 else { return [:] }

        let minX = boundingBox[0] / Double(imageWidth)
        let minY = boundingBox[1] / Double(imageHeight)
        let maxX = boundingBox[2] / Double(imageWidth)
        let maxY = boundingBox[3] / Double(imageHeight)

        let width = maxX - minX
        let height = maxY - minY
        guard width > 0, height > 0 else { return [:] }

        var mapped: [String: [CGPoint]] = [:]
        for (key, points) in zones {
            let cgPoints = points.compactMap { values -> CGPoint? in
                guard values.count == 2 else { return nil }
                let x = values[0] / Double(imageWidth)
                let y = values[1] / Double(imageHeight)
                return CGPoint(x: x, y: y)
            }
            mapped[key] = cgPoints
        }
        return mapped
    }

    func normalizedBoundingRect(imageWidth: Int, imageHeight: Int) -> CGRect? {
        guard boundingBox.count == 4,
              imageWidth > 0,
              imageHeight > 0 else { return nil }
        let minX = boundingBox[0] / Double(imageWidth)
        let minY = boundingBox[1] / Double(imageHeight)
        let maxX = boundingBox[2] / Double(imageWidth)
        let maxY = boundingBox[3] / Double(imageHeight)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

struct Recommendation: Codable, Hashable {
    let details: String?
    let suggestedShades: [String]?
    let suggestedFinishes: [String]?

    enum CodingKeys: String, CodingKey {
        case details
        case suggestedShades = "suggested_shades"
        case suggestedFinishes = "suggested_finishes"
    }
}

struct AnalysisResponsePayload: Codable {
    let dimensions: FaceDimensionsPayload
    let faceShape: String
    let skinTone: String
    let undertone: String
    let skinSampleRGB: [Int]
    let overlay: OverlayPayload
    let recommendations: [String: Recommendation]
    let insights: FeatureInsights?

    struct FaceDimensionsPayload: Codable {
        let foreheadWidth: Double
        let cheekboneWidth: Double
        let jawWidth: Double
        let faceLength: Double
        let jawAngle: Double

        enum CodingKeys: String, CodingKey {
            case foreheadWidth = "forehead_width"
            case cheekboneWidth = "cheekbone_width"
            case jawWidth = "jaw_width"
            case faceLength = "face_length"
            case jawAngle = "jaw_angle"
        }
    }

    struct OverlayPayload: Codable {
        let boundingBox: [Double]
        let zones: [String: [[Double]]]

        enum CodingKeys: String, CodingKey {
            case boundingBox = "bounding_box"
            case zones
        }
    }

    enum CodingKeys: String, CodingKey {
        case dimensions
        case faceShape = "face_shape"
        case skinTone = "skin_tone"
        case undertone
        case skinSampleRGB = "skin_sample_rgb"
        case overlay
        case recommendations
        case insights
    }
}

extension AnalysisResult {
    init(payload: AnalysisResponsePayload, imageData: Data, imageSize: CGSize) {
        self.init(
            faceShape: payload.faceShape,
            skinTone: payload.skinTone,
            undertone: payload.undertone,
            dimensions: FaceDimensions(
                foreheadWidth: payload.dimensions.foreheadWidth,
                cheekboneWidth: payload.dimensions.cheekboneWidth,
                jawWidth: payload.dimensions.jawWidth,
                faceLength: payload.dimensions.faceLength,
                jawAngle: payload.dimensions.jawAngle
            ),
            recommendations: payload.recommendations,
            overlay: Overlay(
                boundingBox: payload.overlay.boundingBox,
                zones: payload.overlay.zones
            ),
            skinSampleRGB: payload.skinSampleRGB,
            imageData: imageData,
            imageWidth: Int(imageSize.width),
            imageHeight: Int(imageSize.height),
            insights: payload.insights
        )
    }
}

struct FeatureInsights: Codable, Hashable {
    struct FeatureRatio: Codable, Hashable, Identifiable {
        var id: String { name }
        let name: String
        let value: Double
        let ideal: Double
        let delta: Double
        let message: String

        var formattedValue: String {
            String(format: "%.2f", value)
        }

        var formattedIdeal: String {
            String(format: "%.2f", ideal)
        }
    }

    struct ToneSummary: Codable, Hashable {
        let hex: String
        let keywords: [String]
        let finishTips: [String]

        enum CodingKeys: String, CodingKey {
            case hex
            case keywords
            case finishTips = "finish_tips"
        }
    }

    struct KeyFeature: Codable, Hashable, Identifiable {
        let feature: String
        let observation: String

        var id: String {
            "\(feature)-\(observation)"
        }
    }

    struct StyleRecommendations: Codable, Hashable {
        let hairstyles: [String]?
        let glasses: [String]?
        let makeup: [String]?
        let beardGrooming: String?

        enum CodingKeys: String, CodingKey {
            case hairstyles
            case glasses
            case makeup
            case beardGrooming = "beard_grooming"
        }

        var hasSuggestions: Bool {
            let textBased = [beardGrooming]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return !(hairstyles?.isEmpty ?? true)
                || !(glasses?.isEmpty ?? true)
                || !(makeup?.isEmpty ?? true)
                || !textBased.isEmpty
        }
    }

    let symmetryScore: Double
    let symmetryDescription: String
    let eyeAlignmentDifference: Double
    let guidance: String
    let browBalanceScore: Double
    let jawDefinitionScore: Double
    let featureRatios: [FeatureRatio]
    let toneSummary: ToneSummary
    let faceShape: String?
    let confidence: String?
    let keyFeatures: [KeyFeature]?
    let skinObservations: String?
    let analysisSummary: String?
    let styleRecommendations: StyleRecommendations?
    let cautions: [String]?
    let additionalNotes: String?

    init(
        symmetryScore: Double,
        symmetryDescription: String,
        eyeAlignmentDifference: Double,
        guidance: String,
        browBalanceScore: Double,
        jawDefinitionScore: Double,
        featureRatios: [FeatureRatio],
        toneSummary: ToneSummary,
        faceShape: String?,
        confidence: String? = nil,
        keyFeatures: [KeyFeature]? = nil,
        skinObservations: String? = nil,
        analysisSummary: String? = nil,
        styleRecommendations: StyleRecommendations? = nil,
        cautions: [String]? = nil,
        additionalNotes: String? = nil
    ) {
        self.symmetryScore = symmetryScore
        self.symmetryDescription = symmetryDescription
        self.eyeAlignmentDifference = eyeAlignmentDifference
        self.guidance = guidance
        self.browBalanceScore = browBalanceScore
        self.jawDefinitionScore = jawDefinitionScore
        self.featureRatios = featureRatios
        self.toneSummary = toneSummary
        self.faceShape = faceShape
        self.confidence = confidence
        self.keyFeatures = keyFeatures
        self.skinObservations = skinObservations
        self.analysisSummary = analysisSummary
        self.styleRecommendations = styleRecommendations
        self.cautions = cautions
        self.additionalNotes = additionalNotes
    }

    enum CodingKeys: String, CodingKey {
        case symmetryScore = "symmetry_score"
        case symmetryDescription = "symmetry_description"
        case eyeAlignmentDifference = "eye_alignment_difference"
        case guidance
        case browBalanceScore = "brow_balance_score"
        case jawDefinitionScore = "jaw_definition_score"
        case featureRatios = "feature_ratios"
        case toneSummary = "tone_summary"
        case faceShape = "face_shape"
        case confidence
        case keyFeatures = "key_features"
        case skinObservations = "skin_observations"
        case analysisSummary = "analysis_summary"
        case styleRecommendations = "style_recommendations"
        case cautions
        case additionalNotes = "additional_notes"
    }

    var formattedSymmetryPercentage: String {
        let percent = symmetryScore.clamped(to: 0...1) * 100
        return String(format: "%.0f%%", percent)
    }

    var formattedEyeAlignment: String {
        String(format: "%.1f°", eyeAlignmentDifference)
    }

    var formattedBrowBalance: String {
        String(format: "%.0f%%", browBalanceScore.clamped(to: 0...1) * 100)
    }

    var formattedJawDefinition: String {
        String(format: "%.0f%%", jawDefinitionScore.clamped(to: 0...1) * 100)
    }
}

extension FeatureInsights {
    var hasDetailedObservations: Bool {
        let trimmedSummary = analysisSummary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedSkin = skinObservations?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedConfidence = confidence?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedNotes = additionalNotes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasFeatures = !(keyFeatures?.isEmpty ?? true)
        let hasCautions = !(cautions?.isEmpty ?? true)
        return !trimmedSummary.isEmpty || !trimmedSkin.isEmpty || !trimmedConfidence.isEmpty || !trimmedNotes.isEmpty || hasFeatures || hasCautions
    }

    var hasStyleGuidance: Bool {
        styleRecommendations?.hasSuggestions ?? false
    }

    var cleanedKeyFeatures: [KeyFeature] {
        keyFeatures?.filter { !$0.feature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.observation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
    }

    var cleanedCautions: [String] {
        cautions?.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
    }

    var hairFeatures: [KeyFeature] {
        cleanedKeyFeatures.filter {
            let lowerFeature = $0.feature.lowercased()
            let lowerObservation = $0.observation.lowercased()
            return lowerFeature.contains("hair") || lowerFeature.contains("hairline") || lowerObservation.contains("hairline") || lowerObservation.contains("hair")
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension AnalysisResult {
    var faceLengthWidthRatio: Double? {
        guard dimensions.cheekboneWidth > 0 else { return nil }
        return dimensions.faceLength / dimensions.cheekboneWidth
    }

    var goldenRatioSummary: GoldenRatioSummary? {
        guard let ratio = faceLengthWidthRatio else { return nil }
        let difference = abs(ratio - GoldenRatioSummary.goldenRatio)

        let interpretation: String
        switch difference {
        case ..<0.05:
            interpretation = "Very close to the classical 1:1.618 proportion."
        case ..<0.12:
            interpretation = "Within a harmonious range of the golden ratio."
        case ..<0.25:
            interpretation = "Shows a soft variation from the golden ratio."
        default:
            interpretation = "Highlights a distinctive proportion beyond the golden ratio." 
        }

        let guidance: String
        if difference < 0.12 {
            guidance = "Use light contour under cheekbones and a lifted blush placement to maintain balance."
        } else if ratio > GoldenRatioSummary.goldenRatio {
            guidance = "Elongated proportions benefit from horizontal blush sweeps and soft jawline shading."
        } else {
            guidance = "Slightly wider proportions pair well with vertical highlighting along the center line."
        }

        return GoldenRatioSummary(
            ratio: ratio,
            difference: difference,
            interpretation: interpretation,
            guidance: guidance
        )
    }

    static let preview: AnalysisResult = {
        let image = UIImage(systemName: "person.crop.circle.fill") ?? UIImage()
        let data = image.jpegData(compressionQuality: 0.9) ?? Data()
        let payload = AnalysisResponsePayload(
            dimensions: .init(foreheadWidth: 140, cheekboneWidth: 150, jawWidth: 120, faceLength: 180, jawAngle: 1.2),
            faceShape: "Oval",
            skinTone: "medium",
            undertone: "warm",
            skinSampleRGB: [210, 170, 150],
            overlay: .init(
                boundingBox: [0, 0, 300, 360],
                zones: [
                    "contour": [[60, 200], [80, 120], [220, 120], [240, 200]],
                    "blush": [[90, 210], [120, 170], [180, 170], [210, 210]],
                    "highlight": [[120, 160], [150, 130], [180, 160]]
                ]
            ),
            recommendations: [
                "blush": Recommendation(details: "Sweep above the apples and blend back toward temples.", suggestedShades: ["Peach", "Apricot"], suggestedFinishes: nil),
                "contour": Recommendation(details: "Soft contour beneath cheekbones.", suggestedShades: nil, suggestedFinishes: ["Cream stick", "Soft powder"]),
                "highlight": Recommendation(details: "Tap on cheekbone peaks and cupid's bow.", suggestedShades: nil, suggestedFinishes: ["Liquid glow"]),
                "eyes": Recommendation(details: "Layer warm neutrals with a shimmer accent.", suggestedShades: ["Bronze", "Warm taupe"], suggestedFinishes: nil),
                "lips": Recommendation(details: "Choose terracotta or warm nude shades.", suggestedShades: ["Terracotta", "Warm nude"], suggestedFinishes: nil)
            ],
            insights: FeatureInsights(
                symmetryScore: 0.86,
                symmetryDescription: "Softly balanced features with a slight cheek prominence.",
                eyeAlignmentDifference: 1.4,
                guidance: "Use mirrored highlight placement along cheekbones and brow arches to emphasize symmetry.",
                browBalanceScore: 0.78,
                jawDefinitionScore: 0.72,
                featureRatios: [
                    FeatureInsights.FeatureRatio(name: "Face length vs. width", value: 1.35, ideal: 1.33, delta: 0.02, message: "Elongated"),
                    FeatureInsights.FeatureRatio(name: "Forehead vs. jaw width", value: 1.05, ideal: 1.0, delta: 0.05, message: "Stronger forehead"),
                    FeatureInsights.FeatureRatio(name: "Cheekbone vs. jaw width", value: 1.12, ideal: 1.05, delta: 0.07, message: "Pronounced cheekbones")
                ],
                toneSummary: FeatureInsights.ToneSummary(
                    hex: "#D2A689",
                    keywords: ["Golden", "Sunlit", "Balanced"],
                    finishTips: [
                        "Soft glazed blush and luminous bronzer enhance warmth.",
                        "Choose satin contour sticks for seamless blending."
                    ]
                ),
                faceShape: "Oval",
                confidence: "85%",
                keyFeatures: [
                    FeatureInsights.KeyFeature(feature: "Jawline", observation: "Soft, rounded jawline with gentle contours"),
                    FeatureInsights.KeyFeature(feature: "Cheekbones", observation: "Prominent but not overly angular, creating subtle structure"),
                    FeatureInsights.KeyFeature(feature: "Forehead", observation: "Moderate width with smooth transition to temples")
                ],
                skinObservations: "Smooth, even-toned skin with no visible texture irregularities in monochrome rendering.",
                analysisSummary: "Balanced oval silhouette with rounded chin, soft jawline, and prominent cheekbones for a classic profile.",
                styleRecommendations: FeatureInsights.StyleRecommendations(
                    hairstyles: ["Long side-parted waves", "Soft volume at crown", "High ponytail framing the jawline"],
                    glasses: ["Thin metal frames", "Cat-eye shapes"],
                    makeup: ["Subtle contouring on cheekbones", "Natural lip color"],
                    beardGrooming: nil
                ),
                cautions: ["Avoid extreme cheek contouring", "Minimize harsh chin definition"],
                additionalNotes: "Analysis based on preview selfie; monochrome reference reduces texture readings."
            )
        )
        return AnalysisResult(payload: payload, imageData: data, imageSize: CGSize(width: 300, height: 360))
    }()
}
