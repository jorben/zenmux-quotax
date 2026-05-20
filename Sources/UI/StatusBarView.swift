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
    private static let minimumStatusWidth: CGFloat = 44
    private static let compactMinimumStatusWidth: CGFloat = 30
    private static let horizontalContentPadding: CGFloat = 14
    private static let compactHorizontalContentPadding: CGFloat = 8
    private static let zenmuxIconAspectRatio: CGFloat = 169.0 / 220.0
    public var preferredWidthDidChange: ((CGFloat) -> Void)?
    private var preferredStatusWidth = StatusBarView.statusWidth
    private var cancellables: Set<AnyCancellable> = []
    private var zenmuxStatusIcon: NSImage?
    private var didLoadZenmuxStatusIcon = false

    public override var intrinsicContentSize: NSSize {
        NSSize(width: preferredStatusWidth, height: NSStatusBar.system.thickness)
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
        let rowHeight: CGFloat = 11
        let rowGap: CGFloat = 0
        let totalHeight = rowHeight * 2 + rowGap
        let bottomY = ((bounds.height - totalHeight) / 2).rounded()
        let topY = bottomY + rowHeight + rowGap

        let color: NSColor
        if apiService?.lastError != nil && apiService?.lastError?.type != .noAPIKey {
            color = .systemRed
        } else {
            color = statusBarDataColor()
        }

        let quota5 = quotaDisplay(for: apiService?.subscriptionData?.quota5Hour)
        let quota7 = quotaDisplay(for: apiService?.subscriptionData?.quota7Day)

        let textAttributes = baseTextAttributes(color: color)
        let labelWidth = max(
            measuredWidth(for: "5H", attributes: textAttributes),
            measuredWidth(for: "7D", attributes: textAttributes)
        )
        let reservedValueWidth = measuredWidth(for: "99.9%", attributes: textAttributes)
        let valueWidth = max(
            reservedValueWidth,
            measuredWidth(for: quota5.text, attributes: textAttributes),
            measuredWidth(for: quota7.text, attributes: textAttributes)
        )
        let iconSize = statusIconSize(in: bounds)
        let ringSize = statusRingSize(in: bounds)
        let barSize = statusBarProgressSize(in: bounds)
        let style = settings?.statusBarPresentationStyle ?? .labelsAndPercentage
        updatePreferredStatusWidth(
            preferredWidth(
                for: style,
                labelWidth: labelWidth,
                valueWidth: valueWidth,
                iconWidth: iconSize.width,
                ringWidth: ringSize.width,
                barWidth: barSize.width
            )
        )

        let context = RenderContext(
            quota5: quota5.text,
            quota7: quota7.text,
            quota5Progress: quota5.progress,
            quota7Progress: quota7.progress,
            labelWidth: labelWidth,
            valueWidth: valueWidth,
            iconSize: iconSize,
            ringSize: ringSize,
            barSize: barSize,
            textAttributes: textAttributes,
            color: color,
            bounds: bounds,
            topY: topY,
            bottomY: bottomY,
            rowHeight: rowHeight
        )

        switch style {
        case .labelsAndPercentage:
            drawLabelsAndPercentage(context)
        case .iconAndPercentage:
            drawIconAndPercentage(context)
        case .doubleRingAndPercentage:
            drawDoubleRingAndPercentage(context)
        case .doubleBarAndPercentage:
            drawDoubleBarAndPercentage(context)
        case .doubleRing:
            drawDoubleRing(context)
        case .doubleBar:
            drawDoubleBar(context)
        case .percentageOnly:
            drawPercentageOnly(context)
        case .iconOnly:
            drawIconOnly(context)
        }
    }

    private func drawLabelsAndPercentage(_ context: RenderContext) {
        let gap: CGFloat = 2
        let totalWidth = context.labelWidth + gap + context.valueWidth
        let groupX = max(0, ((context.bounds.width - totalWidth) / 2).rounded())

        let topLayout = RowLayout(
            groupX: groupX,
            labelWidth: context.labelWidth,
            valueWidth: context.valueWidth,
            y: context.topY,
            gap: gap,
            height: context.rowHeight
        )
        let bottomLayout = RowLayout(
            groupX: groupX,
            labelWidth: context.labelWidth,
            valueWidth: context.valueWidth,
            y: context.bottomY,
            gap: gap,
            height: context.rowHeight
        )

        drawRow(label: "5H", value: context.quota5, layout: topLayout, color: context.color)
        drawRow(label: "7D", value: context.quota7, layout: bottomLayout, color: context.color)
    }

    private func drawIconAndPercentage(_ context: RenderContext) {
        let gap: CGFloat = 4
        let totalWidth = context.iconSize.width + gap + context.valueWidth
        let groupX = max(0, ((context.bounds.width - totalWidth) / 2).rounded())
        let iconRect = NSRect(
            x: groupX,
            y: (context.contentMidY - context.iconSize.height / 2).rounded(),
            width: context.iconSize.width,
            height: context.iconSize.height
        )
        let valueX = groupX + context.iconSize.width + gap

        drawZenmuxIcon(in: iconRect, color: context.color)
        drawValue(
            context.quota5,
            in: NSRect(x: valueX, y: context.topY, width: context.valueWidth, height: context.rowHeight),
            color: context.color
        )
        drawValue(
            context.quota7,
            in: NSRect(x: valueX, y: context.bottomY, width: context.valueWidth, height: context.rowHeight),
            color: context.color
        )
    }

    private func drawPercentageOnly(_ context: RenderContext) {
        let groupX = max(0, ((context.bounds.width - context.valueWidth) / 2).rounded())
        drawValue(
            context.quota5,
            in: NSRect(x: groupX, y: context.topY, width: context.valueWidth, height: context.rowHeight),
            color: context.color
        )
        drawValue(
            context.quota7,
            in: NSRect(x: groupX, y: context.bottomY, width: context.valueWidth, height: context.rowHeight),
            color: context.color
        )
    }

    private func drawIconOnly(_ context: RenderContext) {
        let iconRect = NSRect(
            x: ((context.bounds.width - context.iconSize.width) / 2).rounded(),
            y: (context.contentMidY - context.iconSize.height / 2).rounded(),
            width: context.iconSize.width,
            height: context.iconSize.height
        )
        drawZenmuxIcon(in: iconRect, color: context.color)
    }

    private func drawDoubleRingAndPercentage(_ context: RenderContext) {
        let gap: CGFloat = 4
        let totalWidth = context.ringSize.width + gap + context.valueWidth
        let ringRect = NSRect(
            x: max(0, ((context.bounds.width - totalWidth) / 2).rounded()),
            y: (context.contentMidY - context.ringSize.height / 2).rounded(),
            width: context.ringSize.width,
            height: context.ringSize.height
        )
        drawDoubleRing(in: ringRect, context: context)
        let valueX = ringRect.maxX + gap
        drawValue(
            context.quota5,
            in: NSRect(x: valueX, y: context.topY, width: context.valueWidth, height: context.rowHeight),
            color: context.color
        )
        drawValue(
            context.quota7,
            in: NSRect(x: valueX, y: context.bottomY, width: context.valueWidth, height: context.rowHeight),
            color: context.color
        )
    }

    private func drawDoubleBarAndPercentage(_ context: RenderContext) {
        let gap: CGFloat = 4
        let totalWidth = context.barSize.width + gap + context.valueWidth
        let barRect = NSRect(
            x: max(0, ((context.bounds.width - totalWidth) / 2).rounded()),
            y: (context.contentMidY - context.barSize.height / 2).rounded(),
            width: context.barSize.width,
            height: context.barSize.height
        )
        drawDoubleBar(in: barRect, context: context)
        let valueX = barRect.maxX + gap
        drawValue(
            context.quota5,
            in: NSRect(x: valueX, y: context.topY, width: context.valueWidth, height: context.rowHeight),
            color: context.color
        )
        drawValue(
            context.quota7,
            in: NSRect(x: valueX, y: context.bottomY, width: context.valueWidth, height: context.rowHeight),
            color: context.color
        )
    }

    private func drawDoubleRing(_ context: RenderContext) {
        let ringRect = NSRect(
            x: ((context.bounds.width - context.ringSize.width) / 2).rounded(),
            y: (context.contentMidY - context.ringSize.height / 2).rounded(),
            width: context.ringSize.width,
            height: context.ringSize.height
        )
        drawDoubleRing(in: ringRect, context: context)
    }

    private func drawDoubleBar(_ context: RenderContext) {
        let barRect = NSRect(
            x: ((context.bounds.width - context.barSize.width) / 2).rounded(),
            y: (context.contentMidY - context.barSize.height / 2).rounded(),
            width: context.barSize.width,
            height: context.barSize.height
        )
        drawDoubleBar(in: barRect, context: context)
    }

    private func drawDoubleRing(in ringRect: NSRect, context: RenderContext) {
        drawRingTrack(in: ringRect, lineWidth: 2.8, color: context.color)
        drawRingProgress(context.quota5Progress, in: ringRect, lineWidth: 2.8, color: context.color)

        let innerRect = ringRect.insetBy(dx: 4.5, dy: 4.5)
        drawRingTrack(in: innerRect, lineWidth: 2.4, color: context.color.withAlphaComponent(0.42))
        drawRingProgress(context.quota7Progress, in: innerRect, lineWidth: 2.4, color: context.color.withAlphaComponent(0.72))
    }

    private func drawDoubleBar(in rect: NSRect, context: RenderContext) {
        let rowHeight: CGFloat = 5
        let rowGap: CGFloat = 4
        let totalHeight = rowHeight * 2 + rowGap
        let bottomY = rect.midY - totalHeight / 2
        let topY = bottomY + rowHeight + rowGap
        drawProgressBar(
            progress: context.quota5Progress,
            in: NSRect(x: rect.minX, y: topY, width: rect.width, height: rowHeight),
            color: context.color
        )
        drawProgressBar(
            progress: context.quota7Progress,
            in: NSRect(x: rect.minX, y: bottomY, width: rect.width, height: rowHeight),
            color: context.color.withAlphaComponent(0.72)
        )
    }

    private func statusBarDataColor() -> NSColor {
        switch settings?.statusBarDataColorMode ?? .auto {
        case .auto:
            return automaticStatusBarDataColor()
        case .light:
            return .white
        case .dark:
            return .black
        }
    }

    private func automaticStatusBarDataColor() -> NSColor {
        let appearance = window?.effectiveAppearance ?? effectiveAppearance
        let match = appearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua ? .white : .black
    }

    private func statusIconSize(in bounds: NSRect) -> NSSize {
        let height = min(bounds.height - 7, CGFloat(17))
        return NSSize(width: ceil(height * Self.zenmuxIconAspectRatio), height: height)
    }

    private func statusRingSize(in bounds: NSRect) -> NSSize {
        let size = min(bounds.height - 4, CGFloat(22))
        return NSSize(width: size, height: size)
    }

    private func statusBarProgressSize(in bounds: NSRect) -> NSSize {
        NSSize(width: 28, height: min(bounds.height - 8, CGFloat(18)))
    }

    private func preferredWidth(
        for style: StatusBarPresentationStyle,
        labelWidth: CGFloat,
        valueWidth: CGFloat,
        iconWidth: CGFloat,
        ringWidth: CGFloat,
        barWidth: CGFloat
    ) -> CGFloat {
        let contentWidth: CGFloat
        switch style {
        case .labelsAndPercentage:
            contentWidth = labelWidth + 2 + valueWidth
        case .iconAndPercentage:
            contentWidth = iconWidth + 4 + valueWidth
        case .doubleRingAndPercentage:
            contentWidth = ringWidth + 4 + valueWidth
        case .doubleBarAndPercentage:
            contentWidth = barWidth + 4 + valueWidth
        case .doubleRing:
            contentWidth = ringWidth
        case .doubleBar:
            contentWidth = barWidth
        case .percentageOnly:
            contentWidth = valueWidth
        case .iconOnly:
            contentWidth = iconWidth
        }
        let padding: CGFloat
        let minimumWidth: CGFloat
        switch style {
        case .doubleRing, .doubleBar, .percentageOnly, .iconOnly:
            padding = Self.compactHorizontalContentPadding
            minimumWidth = Self.compactMinimumStatusWidth
        default:
            padding = Self.horizontalContentPadding
            minimumWidth = Self.minimumStatusWidth
        }
        return max(minimumWidth, ceil(contentWidth + padding))
    }

    private func updatePreferredStatusWidth(_ width: CGFloat) {
        guard abs(width - preferredStatusWidth) >= 1 else { return }
        preferredStatusWidth = width
        invalidateIntrinsicContentSize()
        preferredWidthDidChange?(width)
    }

    private struct RowLayout {
        let groupX: CGFloat
        let labelWidth: CGFloat
        let valueWidth: CGFloat
        let y: CGFloat
        let gap: CGFloat
        let height: CGFloat
    }

    private struct RenderContext {
        let quota5: String
        let quota7: String
        let quota5Progress: Double?
        let quota7Progress: Double?
        let labelWidth: CGFloat
        let valueWidth: CGFloat
        let iconSize: NSSize
        let ringSize: NSSize
        let barSize: NSSize
        let textAttributes: [NSAttributedString.Key: Any]
        let color: NSColor
        let bounds: NSRect
        let topY: CGFloat
        let bottomY: CGFloat
        let rowHeight: CGFloat

        var contentMidY: CGFloat {
            (topY + rowHeight + bottomY) / 2
        }
    }
}

private extension StatusBarView {
    private func drawRow(label: String, value: String, layout: RowLayout, color: NSColor) {
        drawText(
            label,
            in: NSRect(x: layout.groupX, y: layout.y, width: layout.labelWidth, height: layout.height),
            color: color,
            alignment: .right,
            lineBreakMode: .byClipping
        )
        drawValue(
            value,
            in: NSRect(
                x: layout.groupX + layout.labelWidth + layout.gap,
                y: layout.y,
                width: layout.valueWidth,
                height: layout.height
            ),
            color: color
        )
    }

    private func drawValue(
        _ value: String,
        in rect: NSRect,
        color: NSColor,
        alignment: NSTextAlignment = .right
    ) {
        drawText(value, in: rect, color: color, alignment: alignment, lineBreakMode: .byTruncatingTail)
    }

    private func drawText(
        _ text: String,
        in rect: NSRect,
        color: NSColor,
        alignment: NSTextAlignment,
        lineBreakMode: NSLineBreakMode
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = lineBreakMode

        var attributes = baseTextAttributes(color: color)
        attributes[.paragraphStyle] = paragraph
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    private func baseTextAttributes(color: NSColor) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: color.usingColorSpace(.deviceRGB) ?? NSColor.white
        ]
    }

    private func drawZenmuxIcon(in rect: NSRect, color: NSColor) {
        guard let icon = zenmuxIcon() else {
            drawFallbackIcon(in: rect, color: color)
            return
        }
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        color.setFill()
        NSBezierPath(rect: rect).fill()
        icon.draw(
            in: rect,
            from: .zero,
            operation: .destinationIn,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private func drawFallbackIcon(in rect: NSRect, color: NSColor) {
        color.setFill()
        let fallbackRect = rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.12)
        NSBezierPath(ovalIn: fallbackRect).fill()
    }

    private func drawRingTrack(in rect: NSRect, lineWidth: CGFloat, color: NSColor) {
        color.withAlphaComponent(0.18).setStroke()
        let path = NSBezierPath(ovalIn: rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
        path.lineWidth = lineWidth
        path.stroke()
    }

    private func drawRingProgress(_ progress: Double?, in rect: NSRect, lineWidth: CGFloat, color: NSColor) {
        guard let progress else { return }
        let normalized = min(max(0, progress), 1)
        guard normalized > 0 else { return }
        color.setStroke()
        let radius = min(rect.width, rect.height) / 2 - lineWidth / 2
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let path = NSBezierPath()
        path.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - normalized * 360,
            clockwise: true
        )
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.stroke()
    }

    private func drawProgressBar(progress: Double?, in rect: NSRect, color: NSColor) {
        color.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()

        guard let progress else { return }
        let normalized = min(max(0, progress), 1)
        guard normalized > 0 else { return }
        let fillWidth = rect.width * normalized
        guard fillWidth >= 1 else { return }
        let fillRect = NSRect(x: rect.minX, y: rect.minY, width: fillWidth, height: rect.height)
        color.setFill()
        NSBezierPath(roundedRect: fillRect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
    }

    private func zenmuxIcon() -> NSImage? {
        guard !didLoadZenmuxStatusIcon else { return zenmuxStatusIcon }
        didLoadZenmuxStatusIcon = true
        guard let resourceURL = Bundle.main.url(forResource: "zenmux", withExtension: "svg") else {
            return nil
        }
        zenmuxStatusIcon = NSImage(contentsOf: resourceURL)
        return zenmuxStatusIcon
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
        let normalized = min(max(0, value), 1)
        let percent = normalized * 100
        let rounded = (percent * 10).rounded() / 10
        if rounded >= 100 {
            return "100%"
        }
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: rounded)) ?? String(rounded))%"
    }
}
