import CoreFoundation
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Utilities

struct RGBA {
  var r: CGFloat
  var g: CGFloat
  var b: CGFloat
  var a: CGFloat
}

func color(_ hex: UInt32, _ a: CGFloat = 1.0) -> CGColor {
  let r = CGFloat((hex >> 16) & 0xff) / 255.0
  let g = CGFloat((hex >> 8) & 0xff) / 255.0
  let b = CGFloat(hex & 0xff) / 255.0
  return CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

func uiFont(_ type: CTFontUIFontType, _ size: CGFloat, weightBold: Bool = false) -> CTFont {
  let base = CTFontCreateUIFontForLanguage(type, size, nil)
    ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
  if !weightBold { return base }
  let traits = CTFontSymbolicTraits.traitBold
  return (CTFontCreateCopyWithSymbolicTraits(base, 0, nil, traits, traits) ?? base)
}

func monoFont(_ size: CGFloat, weightBold: Bool = false) -> CTFont {
  let base = CTFontCreateUIFontForLanguage(.userFixedPitch, size, nil)
    ?? CTFontCreateWithName("Menlo" as CFString, size, nil)
  if !weightBold { return base }
  let traits = CTFontSymbolicTraits.traitBold
  return (CTFontCreateCopyWithSymbolicTraits(base, 0, nil, traits, traits) ?? base)
}

func drawRoundedRect(
  _ ctx: CGContext,
  _ rect: CGRect,
  radius: CGFloat,
  fill: CGColor? = nil,
  stroke: CGColor? = nil,
  lineWidth: CGFloat = 1,
  shadow: (color: CGColor, offset: CGSize, blur: CGFloat)? = nil
) {
  let path = CGPath(
    roundedRect: rect,
    cornerWidth: radius,
    cornerHeight: radius,
    transform: nil
  )

  ctx.saveGState()
  if let shadow {
    ctx.setShadow(offset: shadow.offset, blur: shadow.blur, color: shadow.color)
  }
  if let fill {
    ctx.addPath(path)
    ctx.setFillColor(fill)
    ctx.fillPath()
  }
  ctx.restoreGState()

  if let stroke {
    ctx.addPath(path)
    ctx.setStrokeColor(stroke)
    ctx.setLineWidth(lineWidth)
    ctx.strokePath()
  }
}

func drawLinearGradient(_ ctx: CGContext, rect: CGRect, colors: [CGColor], locations: [CGFloat], start: CGPoint, end: CGPoint) {
  guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: locations) else {
    return
  }
  ctx.saveGState()
  ctx.addRect(rect)
  ctx.clip()
  ctx.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
  ctx.restoreGState()
}

func drawRadialGlow(_ ctx: CGContext, center: CGPoint, radius: CGFloat, inner: CGColor, outer: CGColor) {
  guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [inner, outer] as CFArray, locations: [0, 1]) else {
    return
  }
  ctx.saveGState()
  ctx.drawRadialGradient(
    gradient,
    startCenter: center,
    startRadius: 0,
    endCenter: center,
    endRadius: radius,
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
  )
  ctx.restoreGState()
}

func drawGrid(_ ctx: CGContext, rect: CGRect, spacing: CGFloat, alpha: CGFloat) {
  ctx.saveGState()
  ctx.setStrokeColor(color(0xffffff, alpha))
  ctx.setLineWidth(1)
  ctx.setShouldAntialias(false)
  var x: CGFloat = rect.minX
  while x <= rect.maxX {
    ctx.move(to: CGPoint(x: x, y: rect.minY))
    ctx.addLine(to: CGPoint(x: x, y: rect.maxY))
    x += spacing
  }
  var y: CGFloat = rect.minY
  while y <= rect.maxY {
    ctx.move(to: CGPoint(x: rect.minX, y: y))
    ctx.addLine(to: CGPoint(x: rect.maxX, y: y))
    y += spacing
  }
  ctx.strokePath()
  ctx.restoreGState()
}

func drawLineText(
  _ ctx: CGContext,
  _ text: String,
  at point: CGPoint,
  font: CTFont,
  color: CGColor,
  tracking: CGFloat = 0,
  alpha: CGFloat = 1.0,
  canvasHeight: CGFloat
) {
  let attrs: [NSAttributedString.Key: Any] = [
    kCTFontAttributeName as NSAttributedString.Key: font,
    kCTForegroundColorAttributeName as NSAttributedString.Key: color.withAlpha(alpha) as Any,
    kCTKernAttributeName as NSAttributedString.Key: tracking,
  ]
  let attr = NSAttributedString(string: text, attributes: attrs)
  let line = CTLineCreateWithAttributedString(attr)
  ctx.saveGState()
  ctx.textMatrix = .identity
  ctx.translateBy(x: 0, y: canvasHeight)
  ctx.scaleBy(x: 1, y: -1)
  ctx.textPosition = point
  CTLineDraw(line, ctx)
  ctx.restoreGState()
}

func drawParagraphText(
  _ ctx: CGContext,
  _ text: String,
  in rect: CGRect,
  font: CTFont,
  color: CGColor,
  lineHeight: CGFloat,
  alignment: CTTextAlignment = .left,
  alpha: CGFloat = 1.0,
  canvasHeight: CGFloat
) {
  var alignmentValue = alignment
  var lineBreakValue = CTLineBreakMode.byWordWrapping
  var minLineHeight = lineHeight
  var maxLineHeight = lineHeight
  var paragraphStyle: CTParagraphStyle?
  withUnsafePointer(to: &alignmentValue) { pAlign in
    withUnsafePointer(to: &lineBreakValue) { pBreak in
      withUnsafePointer(to: &minLineHeight) { pMin in
        withUnsafePointer(to: &maxLineHeight) { pMax in
          var settings: [CTParagraphStyleSetting] = [
            CTParagraphStyleSetting(
              spec: .alignment,
              valueSize: MemoryLayout<CTTextAlignment>.size,
              value: UnsafeRawPointer(pAlign)
            ),
            CTParagraphStyleSetting(
              spec: .lineBreakMode,
              valueSize: MemoryLayout<CTLineBreakMode>.size,
              value: UnsafeRawPointer(pBreak)
            ),
            CTParagraphStyleSetting(
              spec: .minimumLineHeight,
              valueSize: MemoryLayout<CGFloat>.size,
              value: UnsafeRawPointer(pMin)
            ),
            CTParagraphStyleSetting(
              spec: .maximumLineHeight,
              valueSize: MemoryLayout<CGFloat>.size,
              value: UnsafeRawPointer(pMax)
            ),
          ]
          paragraphStyle = CTParagraphStyleCreate(&settings, settings.count)
        }
      }
    }
  }
  let resolvedParagraphStyle = paragraphStyle ?? CTParagraphStyleCreate(nil, 0)

  let attrs: [NSAttributedString.Key: Any] = [
    kCTFontAttributeName as NSAttributedString.Key: font,
    kCTForegroundColorAttributeName as NSAttributedString.Key: color.withAlpha(alpha) as Any,
    kCTParagraphStyleAttributeName as NSAttributedString.Key: resolvedParagraphStyle,
  ]
  let attr = NSAttributedString(string: text, attributes: attrs)
  let framesetter = CTFramesetterCreateWithAttributedString(attr)
  let path = CGPath(rect: rect, transform: nil)

  ctx.saveGState()
  ctx.textMatrix = .identity
  ctx.translateBy(x: 0, y: canvasHeight)
  ctx.scaleBy(x: 1, y: -1)
  let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attr.length), path, nil)
  CTFrameDraw(frame, ctx)
  ctx.restoreGState()
}

extension CGColor {
  func withAlpha(_ a: CGFloat) -> CGColor {
    self.copy(alpha: a) ?? self
  }
}

// MARK: - Ad 1

func renderAd1(size: CGSize) -> CGImage {
  let width = Int(size.width)
  let height = Int(size.height)

  let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
  let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
  let ctx = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: bitmapInfo
  )!

  // Background
  ctx.setFillColor(color(0x0a0e17, 1))
  ctx.fill(CGRect(origin: .zero, size: size))

  // Mesh glows
  drawRadialGlow(ctx, center: CGPoint(x: 290, y: 300), radius: 560, inner: color(0x38bdf8, 0.18), outer: color(0x38bdf8, 0.0))
  drawRadialGlow(ctx, center: CGPoint(x: 1310, y: 320), radius: 520, inner: color(0x818cf8, 0.16), outer: color(0x818cf8, 0.0))
  drawRadialGlow(ctx, center: CGPoint(x: 900, y: 1070), radius: 520, inner: color(0x4ade80, 0.10), outer: color(0x4ade80, 0.0))

  // Grid (subtle, vignetted by drawing only near top-left)
  ctx.saveGState()
  ctx.addRect(CGRect(x: 0, y: 0, width: size.width * 0.62, height: size.height * 0.58))
  ctx.clip()
  drawGrid(ctx, rect: CGRect(origin: .zero, size: size), spacing: 44, alpha: 0.05)
  ctx.restoreGState()

  let marginX: CGFloat = 80
  let marginY: CGFloat = 70
  let gap: CGFloat = 32
  let col1W: CGFloat = 820
  let col2W: CGFloat = size.width - (marginX * 2) - gap - col1W

  let topRowY: CGFloat = marginY
  let topRowH: CGFloat = 64

  // Brand mark
  let markRect = CGRect(x: marginX, y: topRowY + 8, width: 42, height: 42)
  drawRoundedRect(ctx, markRect, radius: 12, fill: color(0x38bdf8, 1), stroke: nil, lineWidth: 0, shadow: (color(0x38bdf8, 0.15), CGSize(width: 0, height: 12), 30))
  drawLinearGradient(
    ctx,
    rect: markRect,
    colors: [color(0x38bdf8, 1), color(0x818cf8, 1)],
    locations: [0, 1],
    start: CGPoint(x: markRect.minX, y: markRect.minY),
    end: CGPoint(x: markRect.maxX, y: markRect.maxY)
  )

  // Logo name
  let nameFont = uiFont(.emphasizedSystem, 20, weightBold: true)
  drawLineText(ctx, "EnvGuard", at: CGPoint(x: markRect.maxX + 12, y: topRowY + 36), font: nameFont, color: color(0xffffff, 1), canvasHeight: size.height)
  drawLineText(ctx, "Pro", at: CGPoint(x: markRect.maxX + 12 + 92, y: topRowY + 36), font: nameFont, color: color(0x38bdf8, 1), canvasHeight: size.height)

  // Pill right
  let pillText = "CI / CD READY"
  let pillFont = uiFont(.system, 12, weightBold: true)
  let pillW: CGFloat = 150
  let pillH: CGFloat = 34
  let pillRect = CGRect(x: size.width - marginX - pillW, y: topRowY + 15, width: pillW, height: pillH)
  drawRoundedRect(ctx, pillRect, radius: pillH / 2, fill: color(0x38bdf8, 0.12), stroke: color(0x38bdf8, 0.35))
  drawLineText(ctx, pillText, at: CGPoint(x: pillRect.minX + 18, y: pillRect.minY + 22), font: pillFont, color: color(0x38bdf8, 1), tracking: 1.2, canvasHeight: size.height)

  // Headline block (left)
  let h1Font = uiFont(.emphasizedSystem, 58, weightBold: true)
  drawLineText(ctx, "Stop deploys with", at: CGPoint(x: marginX, y: topRowY + topRowH + 84), font: h1Font, color: color(0xffffff, 1), canvasHeight: size.height)

  // Gradient phrase: draw as two lines with different colors to hint gradient
  drawLineText(ctx, "missing env vars", at: CGPoint(x: marginX, y: topRowY + topRowH + 146), font: h1Font, color: color(0x38bdf8, 1), canvasHeight: size.height)
  drawLineText(ctx, "missing env vars", at: CGPoint(x: marginX + 1.2, y: topRowY + topRowH + 146), font: h1Font, color: color(0x818cf8, 0.65), canvasHeight: size.height)

  let subFont = uiFont(.system, 20, weightBold: false)
  drawParagraphText(
    ctx,
    "Validate environment variables across your codebase, export SARIF for security workflows, and verify AWS SSM / Secrets before release.",
    in: CGRect(x: marginX, y: topRowY + topRowH + 172, width: col1W - 40, height: 120),
    font: subFont,
    color: color(0x94a3b8, 1),
    lineHeight: 30,
    canvasHeight: size.height
  )

  // Tags
  func tag(_ x: CGFloat, _ y: CGFloat, dot: CGColor, label: String, w: CGFloat) {
    let rect = CGRect(x: x, y: y, width: w, height: 40)
    drawRoundedRect(ctx, rect, radius: 20, fill: color(0x111827, 0.70), stroke: color(0xffffff, 0.09))
    // dot
    let d = CGRect(x: rect.minX + 14, y: rect.minY + 15, width: 10, height: 10)
    ctx.setFillColor(dot)
    ctx.fillEllipse(in: d)
    ctx.setFillColor(dot.withAlpha(0.12))
    ctx.fillEllipse(in: d.insetBy(dx: -6, dy: -6))
    drawLineText(ctx, label, at: CGPoint(x: rect.minX + 34, y: rect.minY + 26), font: uiFont(.system, 14, weightBold: true), color: color(0xe2e8f0, 1), canvasHeight: size.height)
  }
  let tagsY: CGFloat = topRowY + topRowH + 308
  tag(marginX, tagsY, dot: color(0x4ade80, 1), label: "Detect fallbacks & warn intelligently", w: 340)
  tag(marginX + 350, tagsY, dot: color(0xfbbf24, 1), label: "Parse shared set-env.sh files", w: 298)
  tag(marginX + 660, tagsY, dot: color(0x38bdf8, 1), label: "Produce GitHub Security SARIF", w: 306)

  // Right panel
  let panelX = marginX + col1W + gap
  let panelY = topRowY + topRowH + 20
  let panelRect = CGRect(x: panelX, y: panelY, width: col2W, height: 610)
  drawRoundedRect(ctx, panelRect, radius: 18, fill: color(0x111827, 0.78), stroke: color(0xffffff, 0.09), shadow: (color(0x000000, 0.45), CGSize(width: 0, height: 20), 50))

  // Panel header strip
  let panelHead = CGRect(x: panelRect.minX, y: panelRect.minY, width: panelRect.width, height: 58)
  drawRoundedRect(ctx, panelHead, radius: 18, fill: color(0x0f172a, 0.72), stroke: nil)
  drawLineText(ctx, "Pipeline Scan Overview", at: CGPoint(x: panelHead.minX + 18, y: panelHead.minY + 36), font: uiFont(.emphasizedSystem, 16, weightBold: true), color: color(0xffffff, 1), canvasHeight: size.height)
  // Chip
  let chipLabel = "envguard-pro scan --ci"
  let chipRect = CGRect(x: panelHead.maxX - 210, y: panelHead.minY + 14, width: 192, height: 30)
  drawRoundedRect(ctx, chipRect, radius: 15, fill: color(0xffffff, 0.04), stroke: color(0xffffff, 0.12))
  drawLineText(ctx, chipLabel, at: CGPoint(x: chipRect.minX + 10, y: chipRect.minY + 20), font: uiFont(.system, 12, weightBold: true), color: color(0x94a3b8, 1), canvasHeight: size.height)

  // Metrics cards
  let metricsTop: CGFloat = panelRect.minY + 78
  let metricW = (panelRect.width - 18 * 2 - 12 * 2) / 3
  let metricH: CGFloat = 104
  let metricFill = color(0x0f172a, 0.55)
  let metricStroke = color(0xffffff, 0.08)
  let metricKFont = uiFont(.system, 12, weightBold: true)
  let metricVFont = uiFont(.emphasizedSystem, 34, weightBold: true)
  let metricSFont = uiFont(.system, 13, weightBold: false)

  func metric(_ idx: Int, title: String, value: String, subtitle: String) {
    let x = panelRect.minX + 18 + CGFloat(idx) * (metricW + 12)
    let rect = CGRect(x: x, y: metricsTop, width: metricW, height: metricH)
    drawRoundedRect(ctx, rect, radius: 14, fill: metricFill, stroke: metricStroke)
    drawLineText(ctx, title.uppercased(), at: CGPoint(x: rect.minX + 14, y: rect.minY + 26), font: metricKFont, color: color(0x94a3b8, 1), tracking: 1.2, canvasHeight: size.height)
    drawLineText(ctx, value, at: CGPoint(x: rect.minX + 14, y: rect.minY + 62), font: metricVFont, color: color(0xffffff, 1), canvasHeight: size.height)
    drawLineText(ctx, subtitle, at: CGPoint(x: rect.minX + 14, y: rect.minY + 86), font: metricSFont, color: color(0x94a3b8, 1), canvasHeight: size.height)
  }

  metric(0, title: "Files Scanned", value: "1,842", subtitle: "JS / TS / YAML / Docker")
  metric(1, title: "Env Vars Found", value: "216", subtitle: "Runtime + build-time")
  metric(2, title: "Action Items", value: "7", subtitle: "2 errors • 5 warnings")

  // Terminal box inside panel
  let termRect = CGRect(x: panelRect.minX + 18, y: panelRect.minY + 206, width: panelRect.width - 36, height: 360)
  drawRoundedRect(ctx, termRect, radius: 14, fill: color(0x020617, 0.68), stroke: color(0xffffff, 0.09))
  let termTop = CGRect(x: termRect.minX, y: termRect.minY, width: termRect.width, height: 40)
  drawRoundedRect(ctx, termTop, radius: 14, fill: color(0x0a0e17, 0.55), stroke: nil)

  // Window lights
  func light(_ x: CGFloat, _ c: CGColor) {
    let r = CGRect(x: x, y: termTop.minY + 15, width: 10, height: 10)
    ctx.setFillColor(c)
    ctx.fillEllipse(in: r)
  }
  light(termTop.minX + 14, color(0xf87171, 0.9))
  light(termTop.minX + 30, color(0xfbbf24, 0.9))
  light(termTop.minX + 46, color(0x4ade80, 0.9))
  drawLineText(ctx, "envguard-pro • summary", at: CGPoint(x: termTop.minX + 70, y: termTop.minY + 27), font: uiFont(.system, 12, weightBold: true), color: color(0x94a3b8, 1), canvasHeight: size.height)

  // Terminal content
  let termText = """
✔ Loaded config: .envguardrc.json
✔ Imported env files: set-env.sh, shared-env.sh

✖ Missing required variables (2)
    - STRIPE_SECRET_KEY  (src/payments/stripe.ts:14)
    - SENTRY_AUTH_TOKEN  (.github/workflows/release.yml:58)

⚠ Missing variables with fallbacks (5)
    - LOG_LEVEL (defaults to "info")
    - REDIS_TTL (defaults to 3600)

✔ Exit 1 (CI): errors present
"""
  drawParagraphText(
    ctx,
    termText,
    in: CGRect(x: termRect.minX + 14, y: termRect.minY + 52, width: termRect.width - 28, height: termRect.height - 62),
    font: monoFont(13, weightBold: false),
    color: color(0xe2e8f0, 0.92),
    lineHeight: 20,
    canvasHeight: size.height
  )

  // Feature row cards
  let featY: CGFloat = panelRect.maxY + 36
  let featH: CGFloat = 200
  let featW = (size.width - marginX * 2 - 18 * 2) / 3
  let featFill = color(0x111827, 0.70)
  let featStroke = color(0xffffff, 0.09)

  func feature(_ i: Int, badge: String, title: String, desc: String) {
    let x = marginX + CGFloat(i) * (featW + 18)
    let rect = CGRect(x: x, y: featY, width: featW, height: featH)
    drawRoundedRect(ctx, rect, radius: 18, fill: featFill, stroke: featStroke)
    // badge box
    let b = CGRect(x: rect.minX + 20, y: rect.minY + 20, width: 34, height: 34)
    drawRoundedRect(ctx, b, radius: 12, fill: color(0x38bdf8, 0.12), stroke: color(0x38bdf8, 0.35))
    drawLineText(ctx, badge, at: CGPoint(x: b.minX + 7, y: b.minY + 23), font: uiFont(.emphasizedSystem, 14, weightBold: true), color: color(0x38bdf8, 1), canvasHeight: size.height)
    drawLineText(ctx, title, at: CGPoint(x: b.maxX + 12, y: b.minY + 23), font: uiFont(.emphasizedSystem, 18, weightBold: true), color: color(0xffffff, 1), canvasHeight: size.height)
    drawParagraphText(
      ctx,
      desc,
      in: CGRect(x: rect.minX + 20, y: rect.minY + 60, width: rect.width - 40, height: rect.height - 74),
      font: uiFont(.system, 14, weightBold: false),
      color: color(0x94a3b8, 1),
      lineHeight: 22,
      canvasHeight: size.height
    )
  }

  feature(0, badge: "SARIF", title: "Security-ready reporting", desc: "Export SARIF results to surface missing configuration in code scanning dashboards and PR checks.")
  feature(1, badge: "AWS", title: "Validate before deploy", desc: "Verify SSM parameters and Secrets Manager references exist — catch broken releases early.")
  feature(2, badge: "PRO", title: "Shared env scripts", desc: "Import export VAR=... from shell scripts used across repos and teams.")

  // Footer
  drawLineText(ctx, "Environment variable validation with SARIF output and AWS integration", at: CGPoint(x: marginX, y: size.height - 38), font: uiFont(.system, 13, weightBold: false), color: color(0x94a3b8, 0.85), canvasHeight: size.height)
  let ctaRect = CGRect(x: size.width - marginX - 160, y: size.height - 56, width: 160, height: 40)
  drawLinearGradient(ctx, rect: ctaRect, colors: [color(0x38bdf8, 0.95), color(0x818cf8, 0.95)], locations: [0, 1], start: CGPoint(x: ctaRect.minX, y: ctaRect.minY), end: CGPoint(x: ctaRect.maxX, y: ctaRect.maxY))
  drawRoundedRect(ctx, ctaRect, radius: 20, fill: nil, stroke: nil)
  drawLineText(ctx, "Ship safer today", at: CGPoint(x: ctaRect.minX + 20, y: ctaRect.minY + 26), font: uiFont(.emphasizedSystem, 14, weightBold: true), color: color(0x07101c, 1), canvasHeight: size.height)

  return ctx.makeImage()!
}

// MARK: - Ad 2

func renderAd2(size: CGSize) -> CGImage {
  let width = Int(size.width)
  let height = Int(size.height)

  let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
  let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
  let ctx = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: bitmapInfo
  )!

  ctx.setFillColor(color(0x0a0e17, 1))
  ctx.fill(CGRect(origin: .zero, size: size))

  drawRadialGlow(ctx, center: CGPoint(x: 320, y: 260), radius: 560, inner: color(0x38bdf8, 0.16), outer: color(0x38bdf8, 0.0))
  drawRadialGlow(ctx, center: CGPoint(x: 1280, y: 280), radius: 580, inner: color(0x818cf8, 0.16), outer: color(0x818cf8, 0.0))
  drawRadialGlow(ctx, center: CGPoint(x: 1180, y: 1000), radius: 520, inner: color(0x4ade80, 0.10), outer: color(0x4ade80, 0.0))
  drawRadialGlow(ctx, center: CGPoint(x: 360, y: 1000), radius: 520, inner: color(0xfbbf24, 0.06), outer: color(0xfbbf24, 0.0))

  let marginX: CGFloat = 80
  let marginY: CGFloat = 70

  // Top brand row
  let markRect = CGRect(x: marginX, y: marginY + 6, width: 42, height: 42)
  drawLinearGradient(
    ctx,
    rect: markRect,
    colors: [color(0x38bdf8, 0.9), color(0x818cf8, 0.9)],
    locations: [0, 1],
    start: CGPoint(x: markRect.minX, y: markRect.minY),
    end: CGPoint(x: markRect.maxX, y: markRect.maxY)
  )
  drawRoundedRect(ctx, markRect, radius: 12, fill: nil, stroke: nil, shadow: (color(0x38bdf8, 0.15), CGSize(width: 0, height: 16), 60))
  drawLineText(ctx, "EnvGuard", at: CGPoint(x: markRect.maxX + 12, y: marginY + 34), font: uiFont(.emphasizedSystem, 20, weightBold: true), color: color(0xffffff, 1), canvasHeight: size.height)
  drawLineText(ctx, "Pro", at: CGPoint(x: markRect.maxX + 12 + 92, y: marginY + 34), font: uiFont(.emphasizedSystem, 20, weightBold: true), color: color(0x38bdf8, 1), canvasHeight: size.height)

  // Green pill right
  let pillW: CGFloat = 132
  let pillH: CGFloat = 34
  let pillRect = CGRect(x: size.width - marginX - pillW, y: marginY + 14, width: pillW, height: pillH)
  drawRoundedRect(ctx, pillRect, radius: pillH / 2, fill: color(0x4ade80, 0.12), stroke: color(0x4ade80, 0.35))
  drawLineText(ctx, "AWS + SARIF", at: CGPoint(x: pillRect.minX + 18, y: pillRect.minY + 22), font: uiFont(.system, 12, weightBold: true), color: color(0x4ade80, 1), tracking: 1.1, canvasHeight: size.height)

  // Headline
  let h1Font = uiFont(.emphasizedSystem, 54, weightBold: true)
  drawLineText(ctx, "Prove your config is", at: CGPoint(x: marginX, y: marginY + 126), font: h1Font, color: color(0xffffff, 1), canvasHeight: size.height)
  drawLineText(ctx, "deployable", at: CGPoint(x: marginX + 510, y: marginY + 126), font: h1Font, color: color(0x38bdf8, 1), canvasHeight: size.height)
  drawLineText(ctx, "deployable", at: CGPoint(x: marginX + 511.2, y: marginY + 126), font: h1Font, color: color(0x818cf8, 0.62), canvasHeight: size.height)

  drawParagraphText(
    ctx,
    "Validate environment variables in code, then verify AWS SSM / Secrets Manager (including nested JSON keys) and export SARIF for security dashboards.",
    in: CGRect(x: marginX, y: marginY + 150, width: size.width - marginX * 2, height: 90),
    font: uiFont(.system, 18, weightBold: false),
    color: color(0x94a3b8, 1),
    lineHeight: 28,
    canvasHeight: size.height
  )

  // Two main cards
  let gap: CGFloat = 18
  let mainY: CGFloat = marginY + 250
  let mainH: CGFloat = size.height - mainY - 70
  let leftW: CGFloat = 860
  let rightW: CGFloat = size.width - marginX * 2 - gap - leftW

  let cardShadow = (color: color(0x000000, 0.50), offset: CGSize(width: 0, height: 24), blur: CGFloat(90))

  let leftCard = CGRect(x: marginX, y: mainY, width: leftW, height: mainH)
  drawRoundedRect(ctx, leftCard, radius: 18, fill: color(0x111827, 0.76), stroke: color(0xffffff, 0.09), shadow: cardShadow)
  let leftHead = CGRect(x: leftCard.minX, y: leftCard.minY, width: leftCard.width, height: 58)
  drawRoundedRect(ctx, leftHead, radius: 18, fill: color(0x0f172a, 0.64), stroke: nil)
  drawLineText(ctx, "CLI Scan + AWS Validation", at: CGPoint(x: leftHead.minX + 18, y: leftHead.minY + 36), font: uiFont(.emphasizedSystem, 16, weightBold: true), color: color(0xffffff, 1), canvasHeight: size.height)
  let chipRect = CGRect(x: leftHead.maxX - 274, y: leftHead.minY + 14, width: 256, height: 30)
  drawRoundedRect(ctx, chipRect, radius: 15, fill: color(0xffffff, 0.04), stroke: color(0xffffff, 0.12))
  drawLineText(ctx, "--aws --aws-deep --format sarif", at: CGPoint(x: chipRect.minX + 10, y: chipRect.minY + 20), font: uiFont(.system, 12, weightBold: true), color: color(0x94a3b8, 1), canvasHeight: size.height)

  // Terminal inside left card
  let termRect = CGRect(x: leftCard.minX + 18, y: leftCard.minY + 80, width: leftCard.width - 36, height: 360)
  drawRoundedRect(ctx, termRect, radius: 14, fill: color(0x020617, 0.70), stroke: color(0xffffff, 0.09))
  let termTop = CGRect(x: termRect.minX, y: termRect.minY, width: termRect.width, height: 40)
  drawRoundedRect(ctx, termTop, radius: 14, fill: color(0x0a0e17, 0.55), stroke: nil)
  func light(_ x: CGFloat, _ c: CGColor) {
    let r = CGRect(x: x, y: termTop.minY + 15, width: 10, height: 10)
    ctx.setFillColor(c)
    ctx.fillEllipse(in: r)
  }
  light(termTop.minX + 14, color(0xf87171, 0.9))
  light(termTop.minX + 30, color(0xfbbf24, 0.9))
  light(termTop.minX + 46, color(0x4ade80, 0.9))
  drawLineText(ctx, "envguard-pro • aws checks", at: CGPoint(x: termTop.minX + 70, y: termTop.minY + 27), font: uiFont(.system, 12, weightBold: true), color: color(0x94a3b8, 1), canvasHeight: size.height)

  let termText = """
$ envguard-pro scan --ci --aws --aws-deep --format sarif --output results.sarif

✔ Serverless references detected (SSM + Secrets)
✔ SSM parameters validated (14)
⚠ Missing Secret Keys (1)
    - myapp/dev/aurora.username (used by AURORA_USERNAME)

✔ SARIF written: results.sarif
✖ Exit 1 (CI): errors present
"""
  drawParagraphText(
    ctx,
    termText,
    in: CGRect(x: termRect.minX + 14, y: termRect.minY + 52, width: termRect.width - 28, height: termRect.height - 62),
    font: monoFont(12.8, weightBold: false),
    color: color(0xe2e8f0, 0.92),
    lineHeight: 20,
    canvasHeight: size.height
  )

  // KPIs
  let kpiY: CGFloat = termRect.maxY + 14
  let kpiW = (termRect.width - 12) / 2
  let kpiH: CGFloat = 110
  func kpi(_ i: Int, key: String, value: String, sub: String) {
    let rect = CGRect(x: termRect.minX + CGFloat(i) * (kpiW + 12), y: kpiY, width: kpiW, height: kpiH)
    drawRoundedRect(ctx, rect, radius: 16, fill: color(0x0f172a, 0.62), stroke: color(0xffffff, 0.08))
    drawLineText(ctx, key.uppercased(), at: CGPoint(x: rect.minX + 14, y: rect.minY + 26), font: uiFont(.system, 12, weightBold: true), color: color(0x94a3b8, 1), tracking: 1.2, canvasHeight: size.height)
    drawLineText(ctx, value, at: CGPoint(x: rect.minX + 14, y: rect.minY + 60), font: uiFont(.emphasizedSystem, 30, weightBold: true), color: color(0xffffff, 1), canvasHeight: size.height)
    drawLineText(ctx, sub, at: CGPoint(x: rect.minX + 14, y: rect.minY + 86), font: uiFont(.system, 13, weightBold: false), color: color(0x94a3b8, 1), canvasHeight: size.height)
  }
  kpi(0, key: "AWS Resources", value: "15", sub: "Validated in seconds")
  kpi(1, key: "SARIF Findings", value: "3", sub: "PR + Security tab ready")

  // Right card
  let rightCard = CGRect(x: leftCard.maxX + gap, y: mainY, width: rightW, height: mainH)
  drawRoundedRect(ctx, rightCard, radius: 18, fill: color(0x111827, 0.76), stroke: color(0xffffff, 0.09), shadow: cardShadow)
  let rightHead = CGRect(x: rightCard.minX, y: rightCard.minY, width: rightCard.width, height: 58)
  drawRoundedRect(ctx, rightHead, radius: 18, fill: color(0x0f172a, 0.64), stroke: nil)
  drawLineText(ctx, "Security Findings (SARIF)", at: CGPoint(x: rightHead.minX + 18, y: rightHead.minY + 36), font: uiFont(.emphasizedSystem, 16, weightBold: true), color: color(0xffffff, 1), canvasHeight: size.height)
  let rightChip = CGRect(x: rightHead.maxX - 128, y: rightHead.minY + 14, width: 110, height: 30)
  drawRoundedRect(ctx, rightChip, radius: 15, fill: color(0xffffff, 0.04), stroke: color(0xffffff, 0.12))
  drawLineText(ctx, "results.sarif", at: CGPoint(x: rightChip.minX + 10, y: rightChip.minY + 20), font: uiFont(.system, 12, weightBold: true), color: color(0x94a3b8, 1), canvasHeight: size.height)

  let listX = rightCard.minX + 18
  var rowY = rightCard.minY + 84
  let rowW = rightCard.width - 36
  let rowH: CGFloat = 88

  func row(_ badge: String, badgeColor: (fill: CGColor, stroke: CGColor, text: CGColor), title: String, desc: String, meta: String) {
    let rect = CGRect(x: listX, y: rowY, width: rowW, height: rowH)
    drawRoundedRect(ctx, rect, radius: 16, fill: color(0x0f172a, 0.52), stroke: color(0xffffff, 0.08))
    let b = CGRect(x: rect.minX + 12, y: rect.minY + 26, width: 34, height: 34)
    drawRoundedRect(ctx, b, radius: 12, fill: badgeColor.fill, stroke: badgeColor.stroke)
    drawLineText(ctx, badge, at: CGPoint(x: b.minX + 12, y: b.minY + 23), font: uiFont(.emphasizedSystem, 14, weightBold: true), color: badgeColor.text, canvasHeight: size.height)
    drawLineText(ctx, title, at: CGPoint(x: b.maxX + 12, y: rect.minY + 34), font: uiFont(.emphasizedSystem, 16, weightBold: true), color: color(0xffffff, 1), canvasHeight: size.height)
    drawLineText(ctx, desc, at: CGPoint(x: b.maxX + 12, y: rect.minY + 58), font: uiFont(.system, 13, weightBold: false), color: color(0x94a3b8, 1), canvasHeight: size.height)
    let metaRect = CGRect(x: rect.maxX - 120, y: rect.minY + 30, width: 108, height: 28)
    drawRoundedRect(ctx, metaRect, radius: 14, fill: color(0xffffff, 0.04), stroke: color(0xffffff, 0.11))
    drawLineText(ctx, meta, at: CGPoint(x: metaRect.minX + 12, y: metaRect.minY + 19), font: uiFont(.system, 12, weightBold: true), color: color(0x94a3b8, 0.95), canvasHeight: size.height)
    rowY += rowH + 10
  }

  row(
    "E",
    badgeColor: (fill: color(0xf87171, 0.12), stroke: color(0xf87171, 0.35), text: color(0xf87171, 1)),
    title: "Missing required env var",
    desc: "SENTRY_AUTH_TOKEN referenced in release workflow",
    meta: "CI • Blocker"
  )
  row(
    "E",
    badgeColor: (fill: color(0xf87171, 0.12), stroke: color(0xf87171, 0.35), text: color(0xf87171, 1)),
    title: "AWS secret key missing",
    desc: "myapp/dev/aurora.username used by AURORA_USERNAME",
    meta: "AWS • Deep"
  )
  row(
    "W",
    badgeColor: (fill: color(0xfbbf24, 0.12), stroke: color(0xfbbf24, 0.35), text: color(0xfbbf24, 1)),
    title: "Fallback detected",
    desc: "LOG_LEVEL defaults to \"info\" (non-fatal)",
    meta: "Warn • Triage"
  )
  row(
    "✔",
    badgeColor: (fill: color(0x4ade80, 0.12), stroke: color(0x4ade80, 0.35), text: color(0x4ade80, 1)),
    title: "SSM parameters valid",
    desc: "/myapp/dev/* validated in us-west-2",
    meta: "AWS • OK"
  )

  // Bottom footer inside right card
  drawLineText(ctx, "Designed for CI pipelines and security reporting.", at: CGPoint(x: rightCard.minX + 18, y: rightCard.maxY - 30), font: uiFont(.system, 13, weightBold: false), color: color(0x94a3b8, 0.85), canvasHeight: size.height)
  let ctaRect = CGRect(x: rightCard.maxX - 180, y: rightCard.maxY - 48, width: 160, height: 34)
  drawLinearGradient(ctx, rect: ctaRect, colors: [color(0x38bdf8, 0.95), color(0x818cf8, 0.95)], locations: [0, 1], start: CGPoint(x: ctaRect.minX, y: ctaRect.minY), end: CGPoint(x: ctaRect.maxX, y: ctaRect.maxY))
  drawRoundedRect(ctx, ctaRect, radius: 17, fill: nil, stroke: nil)
  drawLineText(ctx, "Validate & ship", at: CGPoint(x: ctaRect.minX + 24, y: ctaRect.minY + 22), font: uiFont(.emphasizedSystem, 13, weightBold: true), color: color(0x07101c, 1), canvasHeight: size.height)

  return ctx.makeImage()!
}

// MARK: - Export

func writePNG(_ image: CGImage, to url: URL) throws {
  let dir = url.deletingLastPathComponent()
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

  guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    throw NSError(domain: "render_ads", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
  }
  CGImageDestinationAddImage(dest, image, [
    kCGImagePropertyPNGDictionary: [
      kCGImagePropertyPNGGamma: 0.45455,
    ],
  ] as CFDictionary)
  if !CGImageDestinationFinalize(dest) {
    throw NSError(domain: "render_ads", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize PNG"])
  }
}

let size = CGSize(width: 1600, height: 1200)
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let ad1URL = root.appendingPathComponent("marketing/ads/envguard-pro-ad-1.png")
let ad2URL = root.appendingPathComponent("marketing/ads/envguard-pro-ad-2.png")

try writePNG(renderAd1(size: size), to: ad1URL)
try writePNG(renderAd2(size: size), to: ad2URL)

print("Wrote:")
print("- \(ad1URL.path)")
print("- \(ad2URL.path)")
