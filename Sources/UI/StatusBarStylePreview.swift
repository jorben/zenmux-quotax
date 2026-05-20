import AppKit
import SwiftUI

struct StatusBarStylePreviewPill: View {
    let style: StatusBarPresentationStyle

    var body: some View {
        HStack(spacing: 4) {
            previewContent
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .frame(minWidth: previewWidth, minHeight: 26)
        .background {
            Capsule(style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.6)
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch style {
        case .labelsAndPercentage:
            VStack(alignment: .trailing, spacing: 0) {
                Text("5H")
                Text("7D")
            }
            VStack(alignment: .trailing, spacing: 0) {
                Text("99%")
                Text("72%")
            }
        case .iconAndPercentage:
            ZenmuxSVGPreviewIcon()
            VStack(alignment: .trailing, spacing: 0) {
                Text("99%")
                Text("72%")
            }
        case .doubleRingAndPercentage:
            DoubleRingStylePreview()
            VStack(alignment: .trailing, spacing: 0) {
                Text("99%")
                Text("72%")
            }
        case .doubleBarAndPercentage:
            DoubleBarStylePreview()
            VStack(alignment: .trailing, spacing: 0) {
                Text("99%")
                Text("72%")
            }
        case .doubleRing:
            DoubleRingStylePreview()
        case .doubleBar:
            DoubleBarStylePreview()
        case .percentageOnly:
            VStack(alignment: .trailing, spacing: 0) {
                Text("99%")
                Text("72%")
            }
        case .iconOnly:
            ZenmuxSVGPreviewIcon()
        }
    }

    private var previewWidth: CGFloat {
        switch style {
        case .labelsAndPercentage: return 70
        case .iconAndPercentage: return 68
        case .doubleRingAndPercentage: return 76
        case .doubleBarAndPercentage: return 76
        case .doubleRing: return 36
        case .doubleBar: return 38
        case .percentageOnly: return 46
        case .iconOnly: return 34
        }
    }
}

struct ZenmuxSVGPreviewIcon: View {
    var body: some View {
        Group {
            if let image = zenmuxSVGImage() {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .foregroundStyle(Color.primary)
        .frame(width: 15, height: 20)
    }

    private func zenmuxSVGImage() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "zenmux", withExtension: "svg") else { return nil }
        let image = NSImage(contentsOf: url)
        image?.isTemplate = true
        return image
    }
}

struct DoubleRingStylePreview: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.18), lineWidth: 2.8)
                .frame(width: 22, height: 22)
            Circle()
                .trim(from: 0, to: 0.84)
                .stroke(Color.primary.opacity(0.86), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 22, height: 22)
            Circle()
                .stroke(Color.primary.opacity(0.18), lineWidth: 2.4)
                .frame(width: 13, height: 13)
            Circle()
                .trim(from: 0, to: 0.58)
                .stroke(Color.primary.opacity(0.62), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 13, height: 13)
        }
        .frame(width: 24, height: 24)
    }
}

struct DoubleBarStylePreview: View {
    var body: some View {
        VStack(spacing: 4) {
            previewBar(progress: 0.84, opacity: 0.86)
            previewBar(progress: 0.58, opacity: 0.62)
        }
        .frame(width: 28, height: 14)
    }

    private func previewBar(progress: CGFloat, opacity: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.18))
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(opacity))
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 5)
    }
}
