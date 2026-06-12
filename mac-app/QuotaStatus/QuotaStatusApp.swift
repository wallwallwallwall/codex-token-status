import AppKit
import Foundation
import SwiftUI

@main
struct QuotaStatusApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      QuotaPanelView()
        .frame(minWidth: 280, idealWidth: 360, maxWidth: .infinity, minHeight: 280, idealHeight: 360, maxHeight: .infinity)
    }
    .windowStyle(.hiddenTitleBar)
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)

    DispatchQueue.main.async {
      guard let window = NSApp.windows.first else { return }
      window.title = "Quota Status"
      window.setContentSize(NSSize(width: 360, height: 360))
      window.minSize = NSSize(width: 280, height: 280)
      window.contentAspectRatio = NSSize(width: 1, height: 1)
      window.center()
      window.titlebarAppearsTransparent = true
      window.titleVisibility = .hidden
      window.isMovableByWindowBackground = true
      window.backgroundColor = NSColor(red: 0.02, green: 0.08, blue: 0.10, alpha: 1)
      window.isOpaque = true
      window.standardWindowButton(.closeButton)?.isHidden = true
      window.standardWindowButton(.miniaturizeButton)?.isHidden = true
      window.standardWindowButton(.zoomButton)?.isHidden = true
    }
  }
}

struct QuotaPanelView: View {
  @StateObject private var model = QuotaViewModel()

  var body: some View {
    let palette = Palette.forPercent(model.stale ? 0 : model.primaryPercent)

    GeometryReader { proxy in
      let base = min(proxy.size.width, proxy.size.height)
      let scale = max(0.78, min(1.65, base / 360))
      let panelCorner = max(18, min(30, base * 0.058))
      let contentPadding = max(18, min(40, base * 0.068))
      let contentTopPadding = max(22, min(42, base * 0.074))
      let contentBottomPadding = max(18, min(36, base * 0.064))
      let gaugeSize = max(132, min(base * 0.47, base - contentTopPadding - contentBottomPadding - 132 * scale))

      ZStack {
        LinearGradient(
          colors: [
            Color(red: 0.04, green: 0.24, blue: 0.23),
            Color(red: 0.03, green: 0.13, blue: 0.16),
            Color(red: 0.02, green: 0.08, blue: 0.12),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        RoundedRectangle(cornerRadius: panelCorner, style: .continuous)
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
          .shadow(color: Color.black.opacity(0.30), radius: 22 * scale, x: 0, y: 13 * scale)

        VStack(spacing: 12 * scale) {
          header(palette: palette, scale: scale)

          Spacer(minLength: 0)

          LiquidGauge(
            percent: model.primaryPercent,
            palette: palette
          )
          .frame(width: gaugeSize, height: gaugeSize)

          Spacer(minLength: 0)

          HStack(spacing: 10 * scale) {
            MetricCard(
              label: model.shortLabel,
              percent: model.shortPercentText,
              reset: model.shortResetText,
              palette: palette,
              highlighted: true,
              scale: scale
            )

            MetricCard(
              label: model.weeklyLabel,
              percent: model.weeklyPercentText,
              reset: model.weeklyResetText,
              palette: palette,
              highlighted: false,
              scale: scale
            )
          }
        }
        .padding(.horizontal, contentPadding)
        .padding(.top, contentTopPadding)
        .padding(.bottom, contentBottomPadding)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
  }

  private func header(palette: Palette, scale: Double) -> some View {
    HStack(spacing: 10 * scale) {
      Circle()
        .fill(palette.tone)
        .frame(width: 18 * scale, height: 18 * scale)
        .shadow(color: palette.tone.opacity(0.76), radius: 10 * scale, x: 0, y: 0)
        .overlay(
          Circle()
            .stroke(palette.tone.opacity(0.22), lineWidth: 8 * scale)
        )

      VStack(alignment: .leading, spacing: 3 * scale) {
        Text(model.title)
          .font(.system(size: 22 * scale, weight: .black, design: .rounded))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.72)

        Text(model.signalText)
          .font(.system(size: 14 * scale, weight: .heavy, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.72))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }

      Spacer(minLength: 6 * scale)

      VStack(spacing: 3 * scale) {
        Text("计划")
          .font(.system(size: 10 * scale, weight: .heavy, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.72))
        Text(model.planText)
          .font(.system(size: 20 * scale, weight: .black, design: .rounded))
          .foregroundStyle(palette.tone)
          .lineLimit(1)
          .minimumScaleFactor(0.66)
      }
      .frame(minWidth: 70 * scale)
      .padding(.vertical, 7 * scale)
      .padding(.horizontal, 10 * scale)
      .background(palette.tone.opacity(0.18), in: RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
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

        TimelineView(.animation) { timeline in
          let seconds = timeline.date.timeIntervalSinceReferenceDate
          let phase = CGFloat(seconds.remainder(dividingBy: 3.2) / 3.2) * .pi * 2

          ZStack {
            WaveShape(
              progress: progress,
              phase: phase,
              amplitudeRatio: 0.038,
              wavelengthRatio: 1.22
            )
            .fill(
              LinearGradient(
                colors: [palette.liquidTop, palette.liquidMid, palette.liquidBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )

            WaveShape(
              progress: min(1, progress + 0.035),
              phase: phase * -0.72 + .pi * 0.55,
              amplitudeRatio: 0.024,
              wavelengthRatio: 0.92
            )
            .fill(Color.white.opacity(0.12))

            WaveShape(
              progress: min(1, progress + 0.018),
              phase: phase + .pi * 0.3,
              amplitudeRatio: 0.014,
              wavelengthRatio: 1.05
            )
            .stroke(Color.white.opacity(0.18), lineWidth: max(1.2, size * 0.012))
          }
          .clipShape(Circle())
        }

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

        VStack(spacing: max(3, size * 0.03)) {
          Text("\(percent)%")
            .font(.system(size: max(38, size * 0.32), weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .monospacedDigit()
            .minimumScaleFactor(0.68)
            .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 4)
          Text("剩余")
            .font(.system(size: max(15, size * 0.12), weight: .black, design: .rounded))
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
  let phase: CGFloat
  let amplitudeRatio: CGFloat
  let wavelengthRatio: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let clamped = max(0, min(1, progress))
    let baseline = rect.maxY - rect.height * clamped
    let amplitude = max(4, rect.height * amplitudeRatio)
    let wavelength = rect.width / max(0.2, wavelengthRatio)

    path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: baseline))

    var x = rect.minX
    while x <= rect.maxX {
      let relative = (x - rect.minX) / wavelength
      let y = baseline + sin(relative * .pi * 2 + phase) * amplitude
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
  let scale: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 7 * scale) {
      Text(label)
        .font(.system(size: 13 * scale, weight: .black, design: .rounded))
        .foregroundStyle(Color.white.opacity(0.68))
        .lineLimit(1)
        .minimumScaleFactor(0.72)

      HStack(alignment: .lastTextBaseline, spacing: 8 * scale) {
        Text(percent)
          .font(.system(size: 20 * scale, weight: .black, design: .rounded))
          .foregroundStyle(.white)
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.72)

        Spacer(minLength: 2 * scale)

        Text(reset)
          .font(.system(size: 15 * scale, weight: .black, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.64))
          .lineLimit(1)
          .minimumScaleFactor(0.64)
      }
    }
    .padding(10 * scale)
    .frame(maxWidth: .infinity, minHeight: 72 * scale, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
        .fill(highlighted ? palette.tone.opacity(0.20) : Color.white.opacity(0.08))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
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
  private let codexCommand: String
  private var timer: Timer?

  init() {
    accountId = Self.argumentValue("accountId") ??
      ProcessInfo.processInfo.environment["TOKEN_USAGE_ACCOUNT_ID"] ??
      "mac-codex"
    codexCommand = Self.argumentValue("codexCommand") ??
      ProcessInfo.processInfo.environment["TOKEN_USAGE_CODEX_COMMAND"] ??
      Self.defaultCodexCommand()

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
    do {
      let envelope = try await CodexRateLimitReader(command: codexCommand).read()
      guard let snapshot = envelope.snapshot else {
        throw FetchError.missingRateLimits
      }
      apply(snapshot)
    } catch {
      stale = true
      signalText = error.userFacingMessage
    }
  }

  private func apply(_ snapshot: CodexRateLimitSnapshot) {
    let short = displayWindow(snapshot.primary, label: "5h", resetKind: .time)
    let weekly = displayWindow(snapshot.secondary, label: "Weekly", resetKind: .date)
    let percent = percentFrom(short: short, weekly: weekly)

    title = titleFromAccount(accountId)
    planText = planDisplay(snapshot.planType)
    primaryPercent = percent
    stale = false
    signalText = signalFor(percent)

    shortLabel = labelForWindow(short?.label, fallback: "5小时窗口")
    shortPercentText = percentText(short)
    shortResetText = resetText(short)
    weeklyLabel = labelForWindow(weekly?.label, fallback: "7天窗口")
    weeklyPercentText = percentText(weekly)
    weeklyResetText = resetText(weekly)
  }

  private func percentFrom(short: QuotaWindow?, weekly: QuotaWindow?) -> Int {
    if let value = short?.percent { return clamp(value) }
    if let value = weekly?.percent { return clamp(value) }
    return 0
  }

  private func displayWindow(_ window: CodexRateLimitWindow?, label: String, resetKind: ResetKind) -> QuotaWindow? {
    guard let usedPercent = window?.usedPercent else { return nil }
    let percent = clamp(100 - usedPercent)
    let resetText: String
    if let resetsAt = window?.resetsAt {
      let resetDate = Date(timeIntervalSince1970: resetsAt)
      resetText = resetKind == .time ? Self.clockFormatter.string(from: resetDate) : Self.monthDayFormatter.string(from: resetDate)
    } else {
      resetText = ""
    }
    return QuotaWindow(
      label: label,
      percent: Double(percent),
      percentText: "\(percent)%",
      resetText: resetText,
      resetAt: nil
    )
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

  private func planDisplay(_ rawValue: String?) -> String {
    let trimmed = String(rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
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

  private static func defaultCodexCommand() -> String {
    let bundledPath = "/Applications/Codex.app/Contents/Resources/codex"
    if FileManager.default.isExecutableFile(atPath: bundledPath) {
      return bundledPath
    }
    return "codex"
  }

  private static let clockFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "HH:mm"
    return formatter
  }()

  private static let monthDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "M月d日"
    return formatter
  }()
}

enum ResetKind {
  case time
  case date
}

struct QuotaWindow {
  let label: String?
  let percent: Double?
  let percentText: String?
  let resetText: String?
  let resetAt: String?
}

struct CodexRateLimitEnvelope: Decodable {
  let rateLimitsByLimitId: [String: CodexRateLimitSnapshot]?
  let rateLimits: CodexRateLimitSnapshot?
  let planType: String?
  let primary: CodexRateLimitWindow?
  let secondary: CodexRateLimitWindow?

  var snapshot: CodexRateLimitSnapshot? {
    if let codex = rateLimitsByLimitId?["codex"] {
      return codex
    }
    if let rateLimits {
      return rateLimits
    }
    if planType != nil || primary != nil || secondary != nil {
      return CodexRateLimitSnapshot(planType: planType, primary: primary, secondary: secondary)
    }
    return nil
  }
}

struct CodexRateLimitSnapshot: Decodable {
  let planType: String?
  let primary: CodexRateLimitWindow?
  let secondary: CodexRateLimitWindow?
}

struct CodexRateLimitWindow: Decodable {
  let usedPercent: Double?
  let windowDurationMins: Double?
  let resetsAt: Double?
}

final class CodexRateLimitReader {
  private let command: String
  private let timeout: TimeInterval

  init(command: String, timeout: TimeInterval = 30) {
    self.command = command
    self.timeout = timeout
  }

  func read() async throws -> CodexRateLimitEnvelope {
    let command = command
    let timeout = timeout

    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        if command.contains("/") {
          process.executableURL = URL(fileURLWithPath: command)
          process.arguments = ["app-server", "--stdio"]
        } else {
          process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
          process.arguments = [command, "app-server", "--stdio"]
        }
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        func send(_ object: [String: Any]) throws {
          let data = try JSONSerialization.data(withJSONObject: object)
          inputPipe.fileHandleForWriting.write(data)
          inputPipe.fileHandleForWriting.write(Data([0x0a]))
        }

        do {
          try process.run()
          DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if process.isRunning {
              process.terminate()
            }
          }

          try send([
            "id": 1,
            "method": "initialize",
            "params": [
              "clientInfo": [
                "name": "quota-status",
                "version": "1.0.0",
              ],
              "capabilities": [
                "experimentalApi": true,
              ],
            ],
          ])

          var buffer = ""
          var sentRead = false

          while true {
            let data = outputPipe.fileHandleForReading.availableData
            if data.isEmpty {
              break
            }
            guard let text = String(data: data, encoding: .utf8) else {
              continue
            }
            buffer += text

            let lines = buffer.split(separator: "\n", omittingEmptySubsequences: false)
            buffer = lines.last.map(String.init) ?? ""

            for line in lines.dropLast() {
              guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    let lineData = String(line).data(using: .utf8),
                    let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                    let id = json["id"] as? Int else {
                continue
              }

              if id == 1, !sentRead {
                sentRead = true
                try send(["id": 2, "method": "account/rateLimits/read"])
                continue
              }

              if id == 2 {
                if let errorValue = json["error"] {
                  throw FetchError.codexProcess(String(describing: errorValue))
                }
                guard let result = json["result"] else {
                  throw FetchError.missingRateLimits
                }
                let data = try JSONSerialization.data(withJSONObject: result)
                let decoded = try JSONDecoder().decode(CodexRateLimitEnvelope.self, from: data)
                if process.isRunning {
                  process.terminate()
                }
                continuation.resume(returning: decoded)
                return
              }
            }
          }

          let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
          let errorText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          if errorText.isEmpty {
            continuation.resume(throwing: FetchError.timeout)
          } else {
            continuation.resume(throwing: FetchError.codexProcess(errorText))
          }
        } catch {
          if process.isRunning {
            process.terminate()
          }
          let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
          let errorText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          continuation.resume(throwing: errorText.isEmpty ? error : FetchError.codexProcess(errorText))
        }
      }
    }
  }
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
  case missingRateLimits
  case codexProcess(String)
  case timeout

  var errorDescription: String? {
    switch self {
    case .missingRateLimits:
      return "未读取到额度"
    case .codexProcess(let message):
      return message.isEmpty ? "Codex 读取失败" : message
    case .timeout:
      return "Codex 读取超时"
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
