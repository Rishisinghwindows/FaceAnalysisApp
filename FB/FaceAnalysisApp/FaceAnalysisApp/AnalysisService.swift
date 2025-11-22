import Combine
import CoreImage
import Foundation
import Metal
import UIKit
import Vision

enum AnalysisError: LocalizedError {
    case encodingFailed
    case noFaceDetected
    case analysisFailed(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "We couldn't prepare the photo for analysis. Please try a different image."
        case .noFaceDetected:
            return "No face detected. Please retake the selfie with better lighting."
        case let .analysisFailed(message):
            return message
        case .unknown:
            return "Something went wrong while analyzing the photo."
        }
    }
}

protocol AnalysisServing {
    func analyze(image: UIImage) -> AnyPublisher<AnalysisResult, AnalysisError>
}

final class AnalysisService: AnalysisServing {
    private let processingQueue = DispatchQueue(label: "com.facemapbeauty.analysis", qos: .userInitiated)
    private let ciContext: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device)
        }
        return CIContext(options: [.useSoftwareRenderer: true])
    }()

    func analyze(image: UIImage) -> AnyPublisher<AnalysisResult, AnalysisError> {
        Future { [weak self] promise in
            guard let self else { return }
            processingQueue.async {
                guard let cgImage = image.normalizedCGImage() else {
                    promise(.failure(.encodingFailed))
                    return
                }

                let orientation = CGImagePropertyOrientation.up
                let faceRectanglesRequest = VNDetectFaceRectanglesRequest()
                faceRectanglesRequest.usesCPUOnly = true
                let rectanglesHandler = VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: orientation,
                    options: [:]
                )

                do {
                    try rectanglesHandler.perform([faceRectanglesRequest])
                } catch {
                    let message = error.localizedDescription.isEmpty ? "Face analysis failed to complete." : error.localizedDescription
                    promise(.failure(.analysisFailed(message)))
                    return
                }

                guard let baseObservation = faceRectanglesRequest.results?.first as? VNFaceObservation else {
                    promise(.failure(.noFaceDetected))
                    return
                }

                let revisions = VNDetectFaceLandmarksRequest.supportedRevisions.sorted(by: >)
                var observation: VNFaceObservation?
                var lastError: Error?

                for revision in revisions {
                    let request = VNDetectFaceLandmarksRequest()
                    request.revision = revision
                    request.usesCPUOnly = true
                    request.inputFaceObservations = [baseObservation]

                    let handler = VNImageRequestHandler(
                        cgImage: cgImage,
                        orientation: orientation,
                        options: [:]
                    )

                    do {
                        try handler.perform([request])
                        if let result = request.results?.first as? VNFaceObservation {
                            observation = result
                            break
                        }
                    } catch {
                        lastError = error
                    }
                }

                guard let observation else {
                    if let error = lastError {
                        let message = error.localizedDescription.isEmpty ? "Face analysis failed to complete." : error.localizedDescription
                        promise(.failure(.analysisFailed(message)))
                    } else {
                        promise(.failure(.noFaceDetected))
                    }
                    return
                }

                let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

                do {
                    let payload = try self.buildPayload(
                        for: observation,
                        image: cgImage,
                        imageSize: imageSize
                    )
                    let jpegData = image.jpegData(compressionQuality: 0.9) ?? Data()
                    let result = AnalysisResult(
                        faceShape: payload.faceShape,
                        skinTone: payload.skinTone,
                        undertone: payload.undertone,
                        dimensions: payload.dimensions,
                        recommendations: payload.recommendations,
                        overlay: payload.overlay,
                        skinSampleRGB: payload.skinSampleRGB,
                        imageData: jpegData,
                        imageWidth: Int(imageSize.width),
                        imageHeight: Int(imageSize.height)
                    )
                    promise(.success(result))
                } catch let analysisError as AnalysisError {
                    promise(.failure(analysisError))
                } catch {
                    promise(.failure(.unknown))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func buildPayload(
        for observation: VNFaceObservation,
        image: CGImage,
        imageSize: CGSize
    ) throws -> LocalPayload {
        let pixelBoundingBox = pixelBoundingBox(for: observation, in: imageSize)
        let landmarkPoints = FaceLandmarkPoints(
            observation: observation,
            boundingBox: pixelBoundingBox
        )
        let dimensions = calculateDimensions(from: landmarkPoints, boundingBox: pixelBoundingBox)
        let faceShape = classifyFace(dimensions: dimensions)
        let skinToneResult = analyzeSkinTone(in: image, faceRect: pixelBoundingBox)
        let overlay = buildOverlay(for: faceShape, boundingBox: pixelBoundingBox)
        let recommendations = buildRecommendations(shape: faceShape, undertone: skinToneResult.undertone)

        return LocalPayload(
            faceShape: faceShape,
            skinTone: skinToneResult.tone,
            undertone: skinToneResult.undertone,
            skinSampleRGB: skinToneResult.rgb,
            dimensions: dimensions,
            overlay: overlay,
            recommendations: recommendations
        )
    }

    private func pixelBoundingBox(for observation: VNFaceObservation, in imageSize: CGSize) -> CGRect {
        let boundingBox = observation.boundingBox
        let width = boundingBox.width * imageSize.width
        let height = boundingBox.height * imageSize.height
        let x = boundingBox.origin.x * imageSize.width
        let y = (1 - boundingBox.origin.y) * imageSize.height - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func calculateDimensions(from points: FaceLandmarkPoints, boundingBox: CGRect) -> FaceDimensions {
        let foreheadWidth = distance(points.leftBrow ?? CGPoint(x: boundingBox.minX, y: boundingBox.minY),
                                     points.rightBrow ?? CGPoint(x: boundingBox.maxX, y: boundingBox.minY))
        let cheekboneWidth = distance(points.leftCheek ?? CGPoint(x: boundingBox.minX, y: boundingBox.midY),
                                      points.rightCheek ?? CGPoint(x: boundingBox.maxX, y: boundingBox.midY))
        let jawWidth = distance(points.jawLeft ?? CGPoint(x: boundingBox.minX, y: boundingBox.maxY),
                                points.jawRight ?? CGPoint(x: boundingBox.maxX, y: boundingBox.maxY))

        let topY = min(points.forehead?.y ?? boundingBox.minY, boundingBox.minY)
        let faceLength = abs((points.chin?.y ?? boundingBox.maxY) - topY)

        let chin = points.chin ?? CGPoint(x: boundingBox.midX, y: boundingBox.maxY)
        let jawLeftVector = vector(from: chin, to: points.jawLeft ?? CGPoint(x: boundingBox.minX, y: boundingBox.maxY))
        let jawRightVector = vector(from: chin, to: points.jawRight ?? CGPoint(x: boundingBox.maxX, y: boundingBox.maxY))

        let denominator = max(
            hypot(jawLeftVector.dx, jawLeftVector.dy) * hypot(jawRightVector.dx, jawRightVector.dy),
            1.0
        )
        let cosine = max(-1.0, min(1.0, ((jawLeftVector.dx * jawRightVector.dx) + (jawLeftVector.dy * jawRightVector.dy)) / denominator))
        let jawAngle = Double(acos(cosine))

        return FaceDimensions(
            foreheadWidth: Double(foreheadWidth),
            cheekboneWidth: Double(cheekboneWidth),
            jawWidth: Double(jawWidth),
            faceLength: Double(faceLength),
            jawAngle: jawAngle
        )
    }

    private func classifyFace(dimensions: FaceDimensions) -> String {
        let forehead = dimensions.foreheadWidth
        let cheekbone = dimensions.cheekboneWidth
        let jaw = dimensions.jawWidth
        let length = dimensions.faceLength
        let jawAngle = dimensions.jawAngle

        let widthAverage = (forehead + cheekbone + jaw) / 3.0
        let lengthRatio = length / max(widthAverage, 1.0)
        let cheekToJaw = cheekbone / max(jaw, 1.0)
        let foreheadToJaw = forehead / max(jaw, 1.0)

        if lengthRatio < 1.05 {
            if jawAngle < .pi / 3.4 {
                return "square"
            }
            if cheekToJaw > 1.05 {
                return "heart"
            }
            return "round"
        }

        if lengthRatio >= 1.35 {
            if cheekToJaw > 1.1 && foreheadToJaw < 0.95 {
                return "diamond"
            }
            return "oblong"
        }

        if cheekToJaw > 1.15 {
            return "heart"
        }

        if jawAngle < .pi / 3.5 {
            return "square"
        }

        if cheekToJaw > 1.05 && foreheadToJaw > 1.05 {
            return "heart"
        }

        return "oval"
    }

    private func analyzeSkinTone(in image: CGImage, faceRect: CGRect) -> (tone: String, undertone: String, rgb: [Int]) {
        let imageHeight = CGFloat(image.height)
        let sampleRect = CGRect(
            x: max(faceRect.minX + faceRect.width * 0.3, 0),
            y: max(faceRect.minY + faceRect.height * 0.45, 0),
            width: min(faceRect.width * 0.4, CGFloat(image.width) - faceRect.minX),
            height: min(faceRect.height * 0.2, CGFloat(image.height) - faceRect.minY)
        ).integral

        guard sampleRect.width > 0, sampleRect.height > 0 else {
            return ("medium", "neutral", [200, 170, 160])
        }

        let ciImage = CIImage(cgImage: image)
        let extent = CIVector(
            x: sampleRect.minX,
            y: imageHeight - sampleRect.maxY,
            z: sampleRect.width,
            w: sampleRect.height
        )

        guard
            let filter = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: extent
            ]),
            let outputImage = filter.outputImage
        else {
            return ("medium", "neutral", [200, 170, 160])
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let rgb = [Int(bitmap[0]), Int(bitmap[1]), Int(bitmap[2])]
        let lab = rgbToLab(rgb: rgb.map { Double($0) / 255.0 })
        let ita = atan2(lab[0] - 50.0, lab[2] + 1e-6) * 180.0 / .pi

        let tone: String
        switch ita {
        case 55...:
            tone = "very_light"
        case 41..<55:
            tone = "light"
        case 28..<41:
            tone = "medium"
        case 10..<28:
            tone = "tan"
        default:
            tone = "deep"
        }

        let undertone: String
        if lab[1] < -2 && lab[2] < 10 {
            undertone = "cool"
        } else if lab[2] > 15 {
            undertone = "warm"
        } else {
            undertone = "neutral"
        }

        return (tone, undertone, rgb)
    }

    private func rgbToLab(rgb: [Double]) -> [Double] {
        func gammaCorrect(_ value: Double) -> Double {
            if value <= 0.04045 { return value / 12.92 }
            return pow((value + 0.055) / 1.055, 2.4)
        }

        let r = gammaCorrect(rgb[0])
        let g = gammaCorrect(rgb[1])
        let b = gammaCorrect(rgb[2])

        var x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
        var y = (0.2126 * r + 0.7152 * g + 0.0722 * b)
        var z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

        func f(_ value: Double) -> Double {
            if value > 0.008856 { return pow(value, 1.0 / 3.0) }
            return (7.787 * value) + (16.0 / 116.0)
        }

        x = f(x)
        y = f(y)
        z = f(z)

        let l = (116.0 * y) - 16.0
        let a = 500.0 * (x - y)
        let bb = 200.0 * (y - z)
        return [l, a, bb]
    }

    private func buildOverlay(for shape: String, boundingBox: CGRect) -> Overlay {
        let minX = Double(boundingBox.minX)
        let maxX = Double(boundingBox.maxX)
        let minY = Double(boundingBox.minY)
        let maxY = Double(boundingBox.maxY)

        func makeZone(factorY: Double, height: Double, inset: Double) -> [[Double]] {
            let x1 = minX + (maxX - minX) * inset
            let x2 = maxX - (maxX - minX) * inset
            let top = minY + (maxY - minY) * factorY
            let bottom = top + (maxY - minY) * height
            return [
                [x1, bottom],
                [x1 + (maxX - minX) * 0.05, top],
                [x2 - (maxX - minX) * 0.05, top],
                [x2, bottom]
            ]
        }

        func ellipse(centerYFactor: Double, widthFactor: Double, heightFactor: Double) -> [[Double]] {
            let centerX = (minX + maxX) / 2
            let centerY = minY + (maxY - minY) * centerYFactor
            let radiusX = (maxX - minX) * widthFactor / 2
            let radiusY = (maxY - minY) * heightFactor / 2
            var points: [[Double]] = []
            for degree in stride(from: 0, to: 360, by: 30) {
                let radians = Double(degree) * .pi / 180.0
                let x = centerX + cos(radians) * radiusX
                let y = centerY + sin(radians) * radiusY
                points.append([x, y])
            }
            return points
        }

        let zones: [String: [[Double]]]
        switch shape {
        case "round":
            zones = [
                "contour": makeZone(factorY: 0.35, height: 0.4, inset: 0.15),
                "blush": ellipse(centerYFactor: 0.55, widthFactor: 0.35, heightFactor: 0.25),
                "highlight": ellipse(centerYFactor: 0.4, widthFactor: 0.2, heightFactor: 0.2)
            ]
        case "oval":
            zones = [
                "contour": makeZone(factorY: 0.3, height: 0.4, inset: 0.18),
                "blush": ellipse(centerYFactor: 0.6, widthFactor: 0.3, heightFactor: 0.2),
                "highlight": ellipse(centerYFactor: 0.38, widthFactor: 0.2, heightFactor: 0.18)
            ]
        case "square":
            zones = [
                "contour": makeZone(factorY: 0.3, height: 0.5, inset: 0.1),
                "blush": ellipse(centerYFactor: 0.58, widthFactor: 0.32, heightFactor: 0.18),
                "highlight": ellipse(centerYFactor: 0.38, widthFactor: 0.22, heightFactor: 0.18)
            ]
        case "heart":
            zones = [
                "contour": makeZone(factorY: 0.25, height: 0.45, inset: 0.12),
                "blush": ellipse(centerYFactor: 0.55, widthFactor: 0.28, heightFactor: 0.18),
                "highlight": ellipse(centerYFactor: 0.35, widthFactor: 0.2, heightFactor: 0.2)
            ]
        case "oblong":
            zones = [
                "contour": makeZone(factorY: 0.25, height: 0.5, inset: 0.18),
                "blush": ellipse(centerYFactor: 0.6, widthFactor: 0.28, heightFactor: 0.18),
                "highlight": ellipse(centerYFactor: 0.42, widthFactor: 0.22, heightFactor: 0.18)
            ]
        default: // diamond
            zones = [
                "contour": makeZone(factorY: 0.28, height: 0.45, inset: 0.1),
                "blush": ellipse(centerYFactor: 0.55, widthFactor: 0.32, heightFactor: 0.2),
                "highlight": ellipse(centerYFactor: 0.36, widthFactor: 0.2, heightFactor: 0.18)
            ]
        }

        return Overlay(
            boundingBox: [
                minX,
                minY,
                maxX,
                maxY
            ],
            zones: zones
        )
    }

    private func buildRecommendations(shape: String, undertone: String) -> [String: Recommendation] {
        func palette(for category: String) -> [String] {
            let palettes: [String: [String: [String]]] = [
                "warm": [
                    "blush": ["Peach", "Apricot", "Warm coral"],
                    "eyes": ["Bronze", "Warm taupe", "Olive green"],
                    "lips": ["Terracotta", "Warm nude", "Rust red"]
                ],
                "cool": [
                    "blush": ["Rose", "Soft berry", "Cool pink"],
                    "eyes": ["Plum", "Soft grey", "Slate blue"],
                    "lips": ["Berry", "Cool mauve", "Blue-based red"]
                ],
                "neutral": [
                    "blush": ["Dusty rose", "Neutral coral", "Soft mauve"],
                    "eyes": ["Champagne", "Neutral brown", "Soft copper"],
                    "lips": ["Rosewood", "Balanced nude", "Classic red"]
                ]
            ]
            return palettes[undertone, default: palettes["neutral"] ?? [:]][category] ?? []
        }

        let guidance: [String: [String: String]] = [
            "round": [
                "blush": "Sweep blush above the apples and pull back toward temples.",
                "contour": "Contour beneath cheekbones and jawline for definition.",
                "highlight": "Highlight center of forehead, nose bridge, and chin."
            ],
            "oval": [
                "blush": "Apply to apples and blend outward along cheekbones.",
                "contour": "Light contour under cheekbones and temples.",
                "highlight": "Highlight cheekbone tops, brow bone, and cupid's bow."
            ],
            "square": [
                "blush": "Focus on cheek centers and blend softly to diffuse angles.",
                "contour": "Soften jawline and outer forehead, blending well.",
                "highlight": "Highlight center of face and cheekbone peaks."
            ],
            "heart": [
                "blush": "Place blush lower on cheeks and blend upward.",
                "contour": "Shade sides of forehead and lightly under cheekbones.",
                "highlight": "Highlight cheekbones and cupid's bow subtly on forehead."
            ],
            "oblong": [
                "blush": "Apply horizontally across cheeks to add width.",
                "contour": "Contour forehead top and chin to shorten appearance.",
                "highlight": "Highlight cheekbones and cupid's bow, skip chin."
            ],
            "diamond": [
                "blush": "Tap blush on apples and curve outward to soften cheekbones.",
                "contour": "Contour under cheekbones tapering toward temples.",
                "highlight": "Highlight forehead center, nose bridge, and chin."
            ]
        ]

        let base = guidance[shape, default: guidance["oval"]!]

        return [
            "blush": Recommendation(
                details: base["blush"],
                suggestedShades: palette(for: "blush"),
                suggestedFinishes: nil
            ),
            "contour": Recommendation(
                details: base["contour"],
                suggestedShades: nil,
                suggestedFinishes: ["Soft matte stick", "Sheer cream", "Buildable powder"]
            ),
            "highlight": Recommendation(
                details: base["highlight"],
                suggestedShades: nil,
                suggestedFinishes: ["Cream luminizer", "Soft pearl powder", "Liquid glow"]
            ),
            "eyes": Recommendation(
                details: "Choose shades that complement your undertone and layer from matte to shimmer.",
                suggestedShades: palette(for: "eyes"),
                suggestedFinishes: nil
            ),
            "lips": Recommendation(
                details: "Match lip families to undertone; adjust intensity for day or night looks.",
                suggestedShades: palette(for: "lips"),
                suggestedFinishes: nil
            )
        ]
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private func vector(from origin: CGPoint, to point: CGPoint) -> CGVector {
        CGVector(dx: point.x - origin.x, dy: point.y - origin.y)
    }
}

private struct LocalPayload {
    let faceShape: String
    let skinTone: String
    let undertone: String
    let skinSampleRGB: [Int]
    let dimensions: FaceDimensions
    let overlay: Overlay
    let recommendations: [String: Recommendation]
}

private struct FaceLandmarkPoints {
    let forehead: CGPoint?
    let leftBrow: CGPoint?
    let rightBrow: CGPoint?
    let leftCheek: CGPoint?
    let rightCheek: CGPoint?
    let jawLeft: CGPoint?
    let jawRight: CGPoint?
    let chin: CGPoint?

    init(observation: VNFaceObservation, boundingBox: CGRect) {
        func convert(region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            guard let region else { return [] }
            return region.normalizedPoints.map { point in
                let x = boundingBox.origin.x + CGFloat(point.x) * boundingBox.width
                let y = boundingBox.origin.y + CGFloat(point.y) * boundingBox.height
                return CGPoint(x: x, y: y)
            }
        }

        let landmarks = observation.landmarks
        let browLeftPoints = convert(region: landmarks?.leftEyebrow)
        let browRightPoints = convert(region: landmarks?.rightEyebrow)
        let faceContourPoints = convert(region: landmarks?.faceContour)

        forehead = browLeftPoints.first.flatMap { left in
            guard let right = browRightPoints.last else { return nil }
            return CGPoint(
                x: (left.x + right.x) / 2.0,
                y: min(left.y, right.y) - boundingBox.height * 0.15
            )
        }
        leftBrow = browLeftPoints.first
        rightBrow = browRightPoints.last
        leftCheek = faceContourPoints[safe: Int(Double(faceContourPoints.count) * 0.2)]
        rightCheek = faceContourPoints[safe: Int(Double(faceContourPoints.count) * 0.8)]
        jawLeft = faceContourPoints.first
        jawRight = faceContourPoints.last
        chin = faceContourPoints[safe: faceContourPoints.count / 2]
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}

private extension UIImage {
    func normalizedCGImage() -> CGImage? {
        if imageOrientation == .up, let existing = cgImage {
            return existing
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }
}
