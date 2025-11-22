import SwiftUI
import UIKit

struct FaceAnalysisResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let result: AnalysisResult

    private let gridColumns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    private let recommendationOrder = ["contour", "blush", "highlight", "eyes", "lips"]

    var body: some View {
        ZStack(alignment: .top) {
            backgroundColor
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    titleSection
                    imageGrid
                    featureSummary
                    goldenRatioCard
                    recommendationsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .bottom) { bottomCallToAction }
    }

    private var header: some View {
        ZStack {
            Text("Face Analysis")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(primaryTextColor)

            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 44, height: 44)
                        .background(cardColor.opacity(0.35))
                        .clipShape(Circle())
                }

                Spacer()
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
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
        LazyVGrid(columns: gridColumns, spacing: 16) {
            analysisImage
            overlayImage
        }
    }

    private var analysisImage: some View {
        Group {
            if let image = result.primaryImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
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

    private var overlayImage: some View {
        ZStack {
            if let image = result.primaryImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
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
                metricRow(title: "Face shape", value: readable(result.faceShape))
                metricRow(title: "Skin tone", value: readable(result.skinTone))
                metricRow(title: "Undertone", value: readable(result.undertone))

                Divider().background(borderColor.opacity(0.25))

                metricRow(title: "Forehead width", value: formatted(result.dimensions.foreheadWidth) + " px")
                metricRow(title: "Cheekbone width", value: formatted(result.dimensions.cheekboneWidth) + " px")
                metricRow(title: "Jaw width", value: formatted(result.dimensions.jawWidth) + " px")
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
                ForEach(sortedRecommendations, id: \.key) { key, recommendation in
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
                    .background(cardColor)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(borderColor.opacity(0.25), lineWidth: 1)
                    )
                }
            }
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
                .foregroundStyle(Color.resultPrimary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.resultPrimary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.resultPrimary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var sortedRecommendations: [(key: String, value: Recommendation)] {
        result.recommendations.sorted { lhs, rhs in
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

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    private func angleDegrees(_ radians: Double) -> String {
        let degrees = radians * 180 / .pi
        return String(format: "%.0f°", degrees)
    }

    private func readable(_ text: String) -> String {
        text.replacingOccurrences(of: "_", with: " ").capitalized
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

#Preview {
    NavigationStack {
        FaceAnalysisResultView(result: .preview)
            .preferredColorScheme(.light)
    }
}
