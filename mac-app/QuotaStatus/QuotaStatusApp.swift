import AppKit
import Foundation
import SwiftUI

@main
struct QuotaStatusApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      QuotaPanelView()
        .frame(width: 360, height: 360)
        .fixedSize()
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentSize)
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)

    DispatchQueue.main.async {
      guard let window = NSApp.windows.first else { return }
      window.title = "Quota Status"
      window.setContentSize(NSSize(width: 360, height: 360))
      window.minSize = NSSize(width: 360, height: 360)
      window.maxSize = NSSize(width: 360, height: 360)
      window.center()
      window.titlebarAppearsTransparent = true
      window.isMovableByWindowBackground = true
      window.backgroundColor = .clear
      window.isOpaque = false
      window.standardWindowButton(.zoomButton)?.isHidden = true
    }
  }
}

struct QuotaPanelView: View {
  @StateObject private var model = QuotaViewModel()

  var body: some View {
    let palette = Palette.forPercent(model.stale ? 0 : model.primaryPercent)

    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.62, green: 0.83, blue: 1.0),
          Color(red: 0.82, green: 0.95, blue: 1.0),
          Color(red: 0.50, green: 0.80, blue: 0.93),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      RoundedRectangle(cornerRadius: 34, style: .continuous)
        .fill(
          LinearGradient(
            colors: [
              Color(red: 0.08, green: 0.18, blue: 0.22).opacity(0.98),
              Color(red: 0.04, green: 0.10, blue: 0.14).opacity(0.98),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay(
          RoundedRectangle(cornerRadius: 34, style: .continuous)
            .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.34), radius: 28, x: 0, y: 18)
        .padding(12)

      VStack(spacing: 12) {
        header(palette: palette)

        Spacer(minLength: 0)

        LiquidGauge(
          percent: model.primaryPercent,
          palette: palette
        )
        .frame(width: 170, height: 170)

        Spacer(minLength: 0)

        HStack(spacing: 10) {
          MetricCard(
            label: model.shortLabel,
            percent: model.shortPercentText,
            reset: model.shortResetText,
            palette: palette,
            highlighted: true
          )

          MetricCard(
            label: model.weeklyLabel,
            percent: model.weeklyPercentText,
            reset: model.weeklyResetText,
            palette: palette,
            highlighted: false
          )
        }
      }
      .padding(.horizontal, 28)
      .padding(.top, 28)
      .padding(.bottom, 26)
    }
  }

  private func header(palette: Palette) -> some View {
    HStack(spacing: 10) {
      Circle()
        .fill(palette.tone)
        .frame(width: 18, height: 18)
        .shadow(color: palette.tone.opacity(0.76), radius: 12, x: 0, y: 0)
        .overlay(
          Circle()
            .stroke(palette.tone.opacity(0.22), lineWidth: 10)
        )

      VStack(alignment: .leading, spacing: 3) {
        Text(model.title)
          .font(.system(size: 22, weight: .black, design: .rounded))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.72)

        Text(model.signalText)
          .font(.system(size: 14, weight: .heavy, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.72))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }

      Spacer(minLength: 6)

      VStack(spacing: 3) {
        Text("计划")
          .font(.system(size: 10, weight: .heavy, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.72))
        Text(model.planText)
          .font(.system(size: 20, weight: .black, design: .rounded))
          .foregroundStyle(palette.tone)
          .lineLimit(1)
          .minimumScaleFactor(0.66)
      }
      .frame(minWidth: 70)
      .padding(.vertical, 7)
      .padding(.horizontal, 10)
      .background(palette.tone.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(palette.tone.opacity(0.55), lineWidth: 1)
      )
    }
  }
}

struct LiquidGauge: View {
  let percent: Int
  let palette: Palette

  var body: some View {
    GeometryReader { proxy in
      let size = min(proxy.size.width, proxy.size.height)
      let progress = CGFloat(max(0, min(100, percent))) / 100

      ZStack {
        Circle()
          .fill(
            RadialGradient(
              colors: [
                Color.white.opacity(0.32),
                Color(red: 0.12, green: 0.21, blue: 0.25).opacity(0.82),
              ],
              center: .topLeading,
              startRadius: 8,
              endRadius: size
            )
          )

        WaveShape(progress: progress)
          .fill(
            LinearGradient(
              colors: [palette.liquidTop, palette.liquidMid, palette.liquidBottom],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .clipShape(Circle())

        Circle()
          .fill(
            LinearGradient(
              colors: [
                Color.white.opacity(0.22),
                Color.white.opacity(0.02),
                Color.white.opacity(0.10),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )

        VStack(spacing: 5) {
          Text("\(percent)%")
            .font(.system(size: 54, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .monospacedDigit()
            .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 4)
          Text("剩余")
            .font(.system(size: 20, weight: .black, design: .rounded))
            .foregroundStyle(.white.opacity(0.86))
        }
      }
      .overlay(
        Circle()
          .stroke(Color.white.opacity(0.28), lineWidth: 1.5)
      )
      .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 12)
    }
  }
}

struct WaveShape: Shape {
  let progress: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let clamped = max(0, min(1, progress))
    let baseline = rect.maxY - rect.height * clamped
    let amplitude = max(5, rect.height * 0.035)
    let wavelength = rect.width / 1.35

    path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: baseline))

    var x = rect.minX
    while x <= rect.maxX {
      let relative = (x - rect.minX) / wavelength
      let y = baseline + sin(relative * .pi * 2) * amplitude
      path.addLine(to: CGPoint(x: x, y: y))
      x += 2
    }

    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}

struct MetricCard: View {
  let label: String
  let percent: String
  let reset: String
  let palette: Palette
  let highlighted: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(label)
        .font(.system(size: 13, weight: .black, design: .rounded))
        .foregroundStyle(Color.white.opacity(0.68))
        .lineLimit(1)
        .minimumScaleFactor(0.72)

      HStack(alignment: .lastTextBaseline, spacing: 8) {
        Text(percent)
          .font(.system(size: 20, weight: .black, design: .rounded))
          .foregroundStyle(.white)
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.72)

        Spacer(minLength: 2)

        Text(reset)
          .font(.system(size: 15, weight: .black, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.64))
          .lineLimit(1)
          .minimumScaleFactor(0.64)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(highlighted ? palette.tone.opacity(0.20) : Color.white.opacity(0.08))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(highlighted ? palette.tone.opacity(0.56) : Color.white.opacity(0.16), lineWidth: 1)
    )
  }
}

@MainActor
final class QuotaViewModel: ObservableObject {
  @Published var title = "Mac Codex"
  @Published var signalText = "读取中"
  @Published var planText = "--"
  @Published var primaryPercent = 0
  @Published var shortLabel = "5小时窗口"
  @Published var shortPercentText = "--"
  @Published var shortResetText = "--"
  @Published var weeklyLabel = "7天窗口"
  @Published var weeklyPercentText = "--"
  @Published var weeklyResetText = "--"
  @Published var stale = false

  private let accountId: String
  private let apiBase: String
  private var timer: Timer?

  init() {
    accountId = Self.argumentValue("accountId") ??
      ProcessInfo.processInfo.environment["TOKEN_USAGE_ACCOUNT_ID"] ??
      "mac-codex"
    apiBase = (ProcessInfo.processInfo.environment["TOKEN_USAGE_READ_API"] ?? "https://api.wals.top")
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

    load()
    timer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
      Task { await self?.fetchStatus() }
    }
  }

  deinit {
    timer?.invalidate()
  }

  private func load() {
    Task { await fetchStatus() }
  }

  private func fetchStatus() async {
    guard let encoded = accountId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
          let url = URL(string: "\(apiBase)/api/token-usage/status?accountId=\(encoded)") else {
      signalText = "地址错误"
      stale = true
      return
    }

    do {
      var request = URLRequest(url: url)
      request.cachePolicy = .reloadIgnoringLocalCacheData
      request.timeoutInterval = 15
      request.setValue("application/json", forHTTPHeaderField: "accept")

      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw FetchError.invalidResponse
      }
      guard (200..<300).contains(httpResponse.statusCode) else {
        throw FetchError.httpStatus(httpResponse.statusCode)
      }

      let decoded = try JSONDecoder().decode(StatusResponse.self, from: data)
      apply(decoded)
    } catch {
      stale = true
      signalText = error.userFacingMessage
    }
  }

  private func apply(_ response: StatusResponse) {
    let windows = response.usageRemaining?.windows ?? []
    let weekly = windows.first { ($0.label ?? "").lowercased() == "weekly" } ?? windows.last
    let short = windows.first { ($0.label ?? "").lowercased() != "weekly" } ?? weekly
    let percent = percentFrom(response: response, short: short, weekly: weekly)

    title = response.label ?? titleFromAccount(response.accountId ?? accountId)
    planText = planDisplay(response)
    primaryPercent = percent
    stale = response.stale ?? false
    signalText = stale ? "数据过期" : signalFor(percent)

    shortLabel = labelForWindow(short?.label, fallback: "5小时窗口")
    shortPercentText = percentText(short)
    shortResetText = resetText(short)
    weeklyLabel = labelForWindow(weekly?.label, fallback: "7天窗口")
    weeklyPercentText = percentText(weekly)
    weeklyResetText = resetText(weekly)
  }

  private func percentFrom(response: StatusResponse, short: QuotaWindow?, weekly: QuotaWindow?) -> Int {
    if let value = short?.percent { return clamp(value) }
    if let value = weekly?.percent { return clamp(value) }
    if let remaining = response.remaining, let limit = response.limit, limit > 0 {
      return clamp((remaining / limit) * 100)
    }
    return 0
  }

  private func percentText(_ window: QuotaWindow?) -> String {
    guard let window else { return "--" }
    if let text = window.percentText, !text.isEmpty { return text }
    if let percent = window.percent { return "\(clamp(percent))%" }
    return "--"
  }

  private func resetText(_ window: QuotaWindow?) -> String {
    guard let window else { return "--" }
    if let text = window.resetText, !text.isEmpty { return text }
    if let text = window.resetAt, !text.isEmpty { return text }
    return "--"
  }

  private func labelForWindow(_ label: String?, fallback: String) -> String {
    guard let label, !label.isEmpty else { return fallback }
    if label.lowercased() == "weekly" { return "7天窗口" }
    if label.lowercased() == "5h" { return "5小时窗口" }
    return label
  }

  private func planDisplay(_ response: StatusResponse) -> String {
    let raw = response.planType ?? response.plan ?? response.membership ?? response.tier ?? ""
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "--" }

    let key = trimmed
      .lowercased()
      .filter { $0.isLetter || $0.isNumber }

    switch key {
    case "prolite", "pro", "professional":
      return "PRO"
    case "plus":
      return "PLUS"
    case "team":
      return "TEAM"
    case "enterprise":
      return "ENT"
    default:
      return trimmed.uppercased()
    }
  }

  private func signalFor(_ percent: Int) -> String {
    if percent < 20 { return "红灯" }
    if percent < 50 { return "黄灯" }
    return "绿灯"
  }

  private func titleFromAccount(_ accountId: String) -> String {
    accountId
      .split { "-_.".contains($0) }
      .map { part in
        guard let first = part.first else { return "" }
        return String(first).uppercased() + String(part.dropFirst())
      }
      .joined(separator: " ")
  }

  private func clamp(_ value: Double) -> Int {
    max(0, min(100, Int(value.rounded())))
  }

  private static func argumentValue(_ name: String) -> String? {
    let prefix = "--\(name)="
    return CommandLine.arguments.first { $0.hasPrefix(prefix) }?.dropFirst(prefix.count).description
  }
}

struct StatusResponse: Decodable {
  let accountId: String?
  let label: String?
  let planType: String?
  let plan: String?
  let membership: String?
  let tier: String?
  let stale: Bool?
  let remaining: Double?
  let limit: Double?
  let usageRemaining: UsageRemaining?
}

struct UsageRemaining: Decodable {
  let windows: [QuotaWindow]?
}

struct QuotaWindow: Decodable {
  let label: String?
  let percent: Double?
  let percentText: String?
  let resetText: String?
  let resetAt: String?
}

struct Palette {
  let tone: Color
  let liquidTop: Color
  let liquidMid: Color
  let liquidBottom: Color

  static func forPercent(_ percent: Int) -> Palette {
    let value = max(0, min(100, Double(percent)))
    let low = PaletteStop(
      percent: 0,
      tone: RGB(255, 113, 111),
      top: RGB(255, 196, 191),
      mid: RGB(255, 138, 125),
      bottom: RGB(217, 75, 94)
    )
    let mid = PaletteStop(
      percent: 50,
      tone: RGB(255, 199, 106),
      top: RGB(255, 231, 173),
      mid: RGB(255, 189, 106),
      bottom: RGB(223, 143, 57)
    )
    let high = PaletteStop(
      percent: 100,
      tone: RGB(67, 228, 141),
      top: RGB(150, 255, 203),
      mid: RGB(40, 198, 240),
      bottom: RGB(24, 141, 232)
    )

    let range = value <= 50 ? (low, mid) : (mid, high)
    let t = (value - range.0.percent) / (range.1.percent - range.0.percent)

    return Palette(
      tone: RGB.mix(range.0.tone, range.1.tone, t).color,
      liquidTop: RGB.mix(range.0.top, range.1.top, t).color,
      liquidMid: RGB.mix(range.0.mid, range.1.mid, t).color,
      liquidBottom: RGB.mix(range.0.bottom, range.1.bottom, t).color
    )
  }
}

struct PaletteStop {
  let percent: Double
  let tone: RGB
  let top: RGB
  let mid: RGB
  let bottom: RGB
}

struct RGB {
  let red: Double
  let green: Double
  let blue: Double

  init(_ red: Double, _ green: Double, _ blue: Double) {
    self.red = red
    self.green = green
    self.blue = blue
  }

  var color: Color {
    Color(red: red / 255, green: green / 255, blue: blue / 255)
  }

  static func mix(_ start: RGB, _ end: RGB, _ amount: Double) -> RGB {
    let clamped = max(0, min(1, amount))
    return RGB(
      start.red + (end.red - start.red) * clamped,
      start.green + (end.green - start.green) * clamped,
      start.blue + (end.blue - start.blue) * clamped
    )
  }
}

enum FetchError: LocalizedError {
  case invalidResponse
  case httpStatus(Int)

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      return "响应异常"
    case .httpStatus(let status):
      return "HTTP \(status)"
    }
  }
}

extension Error {
  var userFacingMessage: String {
    if let localized = (self as? LocalizedError)?.errorDescription, !localized.isEmpty {
      return localized
    }
    return localizedDescription
  }
}
