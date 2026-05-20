import AppKit
import Combine

@MainActor
public final class StatusBarView: NSView {
    public var apiService: ZenmuxAPIService? {
        didSet { bindService() }
    }

    public var settings: SettingsManager? {
        didSet { bindService() }
    }

    private static let statusWidth: CGFloat = AppConstants.StatusBar.width
    private var cancellables: Set<AnyCancellable> = []

    public override var intrinsicContentSize: NSSize {
        NSSize(width: Self.statusWidth, height: NSStatusBar.system.thickness)
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    private func bindService() {
        cancellables.removeAll()
        let redraw: () -> Void = { [weak self] in
            DispatchQueue.main.async { self?.needsDisplay = true }
        }
        apiService?.objectWillChange.sink { _ in redraw() }.store(in: &cancellables)
        settings?.objectWillChange.sink { _ in redraw() }.store(in: &cancellables)
        needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawQuotaStatus(in: bounds)
    }

    private func drawQuotaStatus(in bounds: NSRect) {
        drawBackground(in: bounds)

        let rowHeight: CGFloat = 10
        let totalHeight = rowHeight * 2
        let topY = (bounds.height + totalHeight) / 2 - rowHeight
        let bottomY = topY - rowHeight

        let color: NSColor
        if apiService?.lastError != nil && apiService?.lastError?.type != .noAPIKey {
            color = .systemRed
        } else {
            color = statusBarDataColor()
        }

        let quota5 = quotaDisplay(for: apiService?.subscriptionData?.quota5Hour)
        let quota7 = quotaDisplay(for: apiService?.subscriptionData?.quota7Day)

        let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color.usingColorSpace(.deviceRGB) ?? NSColor.white
        ]

        let labelWidth = max(
            measuredWidth(for: "5H", attributes: textAttributes),
            measuredWidth(for: "7D", attributes: textAttributes)
        )
        let valueWidth = max(
            measuredWidth(for: quota5.text, attributes: textAttributes),
            measuredWidth(for: quota7.text, attributes: textAttributes)
        )
        let gap: CGFloat = 2
        let totalWidth = labelWidth + gap + valueWidth
        let groupX = max(0, ((bounds.width - totalWidth) / 2).rounded())

        let topLayout = RowLayout(
            groupX: groupX,
            labelWidth: labelWidth,
            valueWidth: valueWidth,
            y: topY,
            gap: gap,
            height: rowHeight
        )
        let bottomLayout = RowLayout(
            groupX: groupX,
            labelWidth: labelWidth,
            valueWidth: valueWidth,
            y: bottomY,
            gap: gap,
            height: rowHeight
        )

        drawRow(label: "5H", value: quota5.text, layout: topLayout, color: color)
        drawRow(label: "7D", value: quota7.text, layout: bottomLayout, color: color)
    }

    private func drawBackground(in bounds: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1.5)
        NSColor.controlAccentColor.withAlphaComponent(0.08).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
    }

    private func statusBarDataColor() -> NSColor {
        switch settings?.statusBarDataColorMode ?? .white {
        case .white:
            return .white
        case .black:
            return .black
        }
    }

    private struct RowLayout {
        let groupX: CGFloat
        let labelWidth: CGFloat
        let valueWidth: CGFloat
        let y: CGFloat
        let gap: CGFloat
        let height: CGFloat
    }

    private func drawRow(label: String, value: String, layout: RowLayout, color: NSColor) {
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: color.usingColorSpace(.deviceRGB) ?? NSColor.white
        ]

        let labelParagraph = NSMutableParagraphStyle()
        labelParagraph.alignment = .right
        labelParagraph.lineBreakMode = .byClipping

        let valueParagraph = NSMutableParagraphStyle()
        valueParagraph.alignment = .left
        valueParagraph.lineBreakMode = .byTruncatingTail

        var labelAttributes = baseAttributes
        labelAttributes[.paragraphStyle] = labelParagraph
        (label as NSString).draw(
            in: NSRect(x: layout.groupX, y: layout.y, width: layout.labelWidth, height: layout.height),
            withAttributes: labelAttributes
        )

        var valueAttributes = baseAttributes
        valueAttributes[.paragraphStyle] = valueParagraph
        (value as NSString).draw(
            in: NSRect(x: layout.groupX + layout.labelWidth + layout.gap, y: layout.y, width: layout.valueWidth, height: layout.height),
            withAttributes: valueAttributes
        )
    }

    private func measuredWidth(for string: String, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        ceil((string as NSString).size(withAttributes: attributes).width)
    }

    private func quotaDisplay(for quota: ZenmuxQuotaWindow?) -> (text: String, progress: Double?) {
        let mode = settings?.statusBarQuotaDisplayMode ?? .used
        let percentage: Double?
        switch mode {
        case .used:
            percentage = quota?.usagePercentage
        case .left:
            percentage = leftPercentage(for: quota)
        }
        guard let percentage else { return ("—", nil) }
        return (formatPercent(percentage), percentage)
    }

    private func leftPercentage(for quota: ZenmuxQuotaWindow?) -> Double? {
        guard let quota else { return nil }
        if let remainingFlows = quota.remainingFlows, let maxFlows = quota.maxFlows, maxFlows > 0 {
            return remainingFlows / maxFlows
        }
        if let usagePercentage = quota.usagePercentage {
            return max(0, 1 - usagePercentage)
        }
        return nil
    }

    private func formatPercent(_ value: Double) -> String {
        let percent = value * 100
        let rounded = (percent * 100).rounded() / 100
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: rounded)) ?? String(rounded))%"
    }
}
