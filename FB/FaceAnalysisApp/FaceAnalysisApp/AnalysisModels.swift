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
        imageHeight: Int
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
            imageHeight: Int(imageSize.height)
        )
    }
}

extension AnalysisResult {
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
            ]
        )
        return AnalysisResult(payload: payload, imageData: data, imageSize: CGSize(width: 300, height: 360))
    }()
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
}
