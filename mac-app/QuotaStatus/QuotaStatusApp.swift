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
      window.styleMask.insert(.fullSizeContentView)
      window.contentAspectRatio = NSSize(width: 1, height: 1)
      window.center()
      window.titlebarAppearsTransparent = true
      window.titlebarSeparatorStyle = .none
      window.titleVisibility = .hidden
      window.isMovableByWindowBackground = true
      window.backgroundColor = .clear
      window.isOpaque = false
      window.standardWindowButton(.closeButton)?.isHidden = true
      window.standardWindowButton(.miniaturizeButton)?.isHidden = true
      window.standardWindowButton(.zoomButton)?.isHidden = true
    }
  }
}

struct QuotaPanelView: View {
  @StateObject private var model = QuotaViewModel()
  @StateObject private var themeStore = ThemeStore()
  @State private var showingThemeSheet = false

  var body: some View {
    let palette = themeStore.palette(for: model.stale ? 0 : model.primaryPercent)

    GeometryReader { proxy in
      let base = min(proxy.size.width, proxy.size.height)
      let scale = max(0.78, min(1.65, base / 360))
      let panelCorner = max(18, min(30, base * 0.058))
      let contentPadding = max(14, min(26, base * 0.05))
      let contentTopPadding = max(14, min(24, base * 0.042))
      let contentBottomPadding = max(14, min(20, base * 0.04))
      let sectionSpacing = max(8, min(12, base * 0.022))
      let gaugeSize = max(112, min(base * 0.36, 154))

      ZStack {
        RoundedRectangle(cornerRadius: panelCorner, style: .continuous)
          .fill(
            LinearGradient(
              colors: [
                palette.backgroundTop,
                palette.backgroundBottom,
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .overlay(
            RoundedRectangle(cornerRadius: panelCorner, style: .continuous)
              .fill(
                LinearGradient(
                  colors: [
                    palette.panelTop.opacity(0.92),
                    palette.panelBottom.opacity(0.96),
                  ],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
          )
          .overlay(
            RoundedRectangle(cornerRadius: panelCorner, style: .continuous)
              .stroke(Color.white.opacity(0.06), lineWidth: 1)
          )
          .shadow(color: Color.black.opacity(0.30), radius: 22 * scale, x: 0, y: 13 * scale)

        VStack(spacing: sectionSpacing) {
          header(palette: palette, scale: scale)

          LiquidGauge(
            percent: model.primaryPercent,
            palette: palette
          )
          .frame(width: gaugeSize, height: gaugeSize)

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

          MetricCard(
            label: model.resetLabel,
            percent: model.resetCountText,
            reset: model.resetAvailableText,
            palette: palette,
            highlighted: false,
            scale: scale,
            isButton: true,
            isEnabled: model.canConsumeReset,
            helpText: model.resetButtonHelpText,
            action: handleResetTap
          )

          HStack {
            Spacer(minLength: 0)
            themeButton(palette: palette, scale: scale)
          }
        }
        .padding(.horizontal, contentPadding)
        .padding(.top, contentTopPadding)
        .padding(.bottom, contentBottomPadding)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .clipShape(RoundedRectangle(cornerRadius: panelCorner, style: .continuous))
    }
    .sheet(isPresented: $showingThemeSheet) {
      ThemeSettingsSheet(themeStore: themeStore)
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
          .font(.system(size: 20 * scale, weight: .black, design: .rounded))
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
          .font(.system(size: 18 * scale, weight: .black, design: .rounded))
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

  private func themeButton(palette: Palette, scale: Double) -> some View {
    Button {
      showingThemeSheet = true
    } label: {
      Image(systemName: "paintpalette.fill")
        .font(.system(size: 13 * scale, weight: .black))
        .foregroundStyle(.white.opacity(0.88))
        .frame(width: 32 * scale, height: 32 * scale)
        .background(Color.black.opacity(0.16), in: Circle())
        .overlay(
          Circle()
            .stroke(palette.cardStroke.opacity(0.95), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
    .help("打开主题与自定义配色")
  }

  private func handleResetTap() {
    Task { await model.consumeResetCredit() }
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
  var isButton: Bool = false
  var isEnabled: Bool = true
  var helpText: String? = nil
  var action: (() -> Void)? = nil

  var body: some View {
    let card = VStack(alignment: .leading, spacing: 7 * scale) {
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
    .padding(9 * scale)
    .frame(maxWidth: .infinity, minHeight: 58 * scale, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
        .fill(highlighted ? palette.tone.opacity(0.20) : palette.cardBackground)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
        .stroke(highlighted ? palette.tone.opacity(0.56) : palette.cardStroke, lineWidth: 1)
    )

    if isButton, let action {
      Button(action: action) {
        card
      }
      .buttonStyle(.plain)
      .disabled(!isEnabled)
      .opacity(isEnabled ? 1 : 0.58)
      .contentShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
      .help(helpText ?? "使用官方重置功能")
    } else {
      card
    }
  }
}

struct ThemeSettingsSheet: View {
  @ObservedObject var themeStore: ThemeStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    let custom = themeStore.customColors

    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("主题")
              .font(.system(size: 22, weight: .black, design: .rounded))
            Text("4 套内置模板 + 1 套自定义配色")
              .foregroundStyle(.secondary)
          }
          Spacer()
          Button("完成") { dismiss() }
        }

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
          ForEach(ThemePreset.allCases, id: \.self) { preset in
            Button {
              themeStore.select(preset)
            } label: {
              HStack {
                Circle()
                  .fill(themeStore.previewAccent(for: preset))
                  .frame(width: 12, height: 12)
                Text(preset.displayName)
                  .font(.system(size: 13, weight: .heavy, design: .rounded))
                Spacer()
              }
              .padding(10)
              .background(Color.white.opacity(themeStore.selectedPreset == preset ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
              .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .stroke(themeStore.selectedPreset == preset ? Color.white.opacity(0.5) : Color.white.opacity(0.14), lineWidth: 1)
              )
            }
            .buttonStyle(.plain)
          }
        }

        if themeStore.selectedPreset == .custom {
          VStack(alignment: .leading, spacing: 10) {
            Text("Custom")
              .font(.system(size: 16, weight: .black, design: .rounded))

            colorPickerRow("背景上层", color: themeStore.binding(for: \.backgroundTop))
            colorPickerRow("背景下层", color: themeStore.binding(for: \.backgroundBottom))
            colorPickerRow("面板上层", color: themeStore.binding(for: \.panelTop))
            colorPickerRow("面板下层", color: themeStore.binding(for: \.panelBottom))
            colorPickerRow("强调色", color: themeStore.binding(for: \.accent))
            colorPickerRow("液体上层", color: themeStore.binding(for: \.liquidTop))
            colorPickerRow("液体中层", color: themeStore.binding(for: \.liquidMid))
            colorPickerRow("液体下层", color: themeStore.binding(for: \.liquidBottom))

            Button("恢复默认 Custom 配色") {
              themeStore.resetCustomColors()
            }
            .buttonStyle(.bordered)
          }
        } else {
          VStack(alignment: .leading, spacing: 6) {
            Text("当前模板")
              .font(.system(size: 16, weight: .black, design: .rounded))
            Text("切到 Custom 后可以分别自定义背景、面板、液体和强调色。")
              .foregroundStyle(.secondary)
          }
        }

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 20)
      .padding(.top, 28)
      .padding(.bottom, 20)
    }
    .frame(minWidth: 440, minHeight: 520)
    .background(
      LinearGradient(
        colors: [custom.backgroundTop.opacity(0.20), custom.backgroundBottom.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
  }

  private func colorPickerRow(_ title: String, color: Binding<Color>) -> some View {
    HStack {
      Text(title)
        .font(.system(size: 13, weight: .heavy, design: .rounded))
      Spacer()
      ColorPicker(title, selection: color, supportsOpacity: false)
        .labelsHidden()
    }
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
  @Published var resetLabel = "剩余重置次数"
  @Published var resetCountText = "--"
  @Published var resetAvailableText = "--"
  @Published var resetButtonHelpText = "读取中"
  @Published var canConsumeReset = false
  @Published var isResetting = false
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
    resetLabel = "剩余重置次数"
    resetCountText = resetCount(snapshot.rateLimitResetCredits)
    resetAvailableText = resetAvailability(snapshot.rateLimitResetCredits)
    canConsumeReset = (snapshot.rateLimitResetCredits?.availableCount ?? 0) > 0 && !isResetting
    resetButtonHelpText = resetHelpText(snapshot.rateLimitResetCredits)
  }

  func consumeResetCredit() async {
    guard canConsumeReset, !isResetting else { return }

    isResetting = true
    canConsumeReset = false
    signalText = "正在重置"

    do {
      _ = try await CodexRateLimitReader(command: codexCommand).consumeResetCredit()
      try? await Task.sleep(nanoseconds: 350_000_000)
      isResetting = false
      await fetchStatus()
    } catch {
      isResetting = false
      stale = true
      signalText = error.userFacingMessage
      canConsumeReset = true
      resetButtonHelpText = "官方重置失败，点击重试"
    }
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

  private func resetCount(_ credits: CodexRateLimitResetCredits?) -> String {
    guard let count = credits?.availableCount else { return "--" }
    return "剩余重置次数 \(count)"
  }

  private func resetAvailability(_ credits: CodexRateLimitResetCredits?) -> String {
    if isResetting { return "正在使用官方重置" }
    guard let count = credits?.availableCount else { return "官方未提供" }
    return count > 0 ? "当前可立即使用" : "当前暂不可用"
  }

  private func resetHelpText(_ credits: CodexRateLimitResetCredits?) -> String {
    if isResetting { return "正在调用官方重置" }
    guard let count = credits?.availableCount else { return "官方暂未返回重置能力" }
    return count > 0 ? "点击使用官方重置次数" : "当前没有可用重置次数"
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
  let rateLimitResetCredits: CodexRateLimitResetCredits?
  let planType: String?
  let primary: CodexRateLimitWindow?
  let secondary: CodexRateLimitWindow?

  var snapshot: CodexRateLimitSnapshot? {
    if let codex = rateLimitsByLimitId?["codex"] {
      return CodexRateLimitSnapshot(
        planType: codex.planType,
        primary: codex.primary,
        secondary: codex.secondary,
        rateLimitResetCredits: rateLimitResetCredits
      )
    }
    if let rateLimits {
      return CodexRateLimitSnapshot(
        planType: rateLimits.planType,
        primary: rateLimits.primary,
        secondary: rateLimits.secondary,
        rateLimitResetCredits: rateLimitResetCredits
      )
    }
    if planType != nil || primary != nil || secondary != nil {
      return CodexRateLimitSnapshot(
        planType: planType,
        primary: primary,
        secondary: secondary,
        rateLimitResetCredits: rateLimitResetCredits
      )
    }
    return nil
  }
}

struct CodexRateLimitSnapshot: Decodable {
  let planType: String?
  let primary: CodexRateLimitWindow?
  let secondary: CodexRateLimitWindow?
  let rateLimitResetCredits: CodexRateLimitResetCredits?
}

struct CodexRateLimitWindow: Decodable {
  let usedPercent: Double?
  let windowDurationMins: Double?
  let resetsAt: Double?
}

struct CodexRateLimitResetCredits: Decodable {
  let availableCount: Int?
}

struct CodexResetOutcome: Decodable {
  let outcome: String?
}

enum ThemePreset: String, CaseIterable {
  case amberCurrent
  case glacierMint
  case graphiteRose
  case forestNeon
  case custom

  var displayName: String {
    switch self {
    case .amberCurrent: return "Amber Current"
    case .glacierMint: return "Glacier Mint"
    case .graphiteRose: return "Graphite Rose"
    case .forestNeon: return "Forest Neon"
    case .custom: return "Custom"
    }
  }
}

struct CustomThemeColors {
  var backgroundTop: Color
  var backgroundBottom: Color
  var panelTop: Color
  var panelBottom: Color
  var accent: Color
  var liquidTop: Color
  var liquidMid: Color
  var liquidBottom: Color

  static let `default` = CustomThemeColors(
    backgroundTop: Color(hex: "#103642"),
    backgroundBottom: Color(hex: "#071720"),
    panelTop: Color(hex: "#173644"),
    panelBottom: Color(hex: "#0c202a"),
    accent: Color(hex: "#ffbf61"),
    liquidTop: Color(hex: "#ffd9a2"),
    liquidMid: Color(hex: "#ffb560"),
    liquidBottom: Color(hex: "#e28934")
  )
}

@MainActor
final class ThemeStore: ObservableObject {
  @Published var selectedPreset: ThemePreset
  @Published var customColors: CustomThemeColors

  private let defaults = UserDefaults.standard
  private let presetKey = "QuotaStatus.themePreset"
  private let customPrefix = "QuotaStatus.customTheme."

  init() {
    let raw = defaults.string(forKey: presetKey) ?? ThemePreset.amberCurrent.rawValue
    selectedPreset = ThemePreset(rawValue: raw) ?? .amberCurrent
    customColors = Self.loadCustomColors(defaults: defaults)
  }

  func select(_ preset: ThemePreset) {
    selectedPreset = preset
    defaults.set(preset.rawValue, forKey: presetKey)
  }

  func previewAccent(for preset: ThemePreset) -> Color {
    palette(for: 60, presetOverride: preset).tone
  }

  func resetCustomColors() {
    customColors = .default
    persistCustomColors()
  }

  func binding(for keyPath: WritableKeyPath<CustomThemeColors, Color>) -> Binding<Color> {
    Binding(
      get: { self.customColors[keyPath: keyPath] },
      set: { newValue in
        self.customColors[keyPath: keyPath] = newValue
        self.persistCustomColors()
      }
    )
  }

  func palette(for percent: Int, presetOverride: ThemePreset? = nil) -> Palette {
    let preset = presetOverride ?? selectedPreset
    switch preset {
    case .amberCurrent:
      return Palette(
        backgroundTop: Color(hex: "#0c3d3b"),
        backgroundBottom: Color(hex: "#071620"),
        panelTop: Color(hex: "#143241"),
        panelBottom: Color(hex: "#0b1e28"),
        cardBackground: Color.white.opacity(0.08),
        cardStroke: Color.white.opacity(0.16),
        tone: Palette.accentColor(for: percent, low: RGB(255, 113, 111), mid: RGB(255, 199, 106), high: RGB(67, 228, 141)),
        liquidTop: Color(hex: "#ffd9a2"),
        liquidMid: Color(hex: "#ffb560"),
        liquidBottom: Color(hex: "#e28934")
      )
    case .glacierMint:
      return Palette(
        backgroundTop: Color(hex: "#123440"),
        backgroundBottom: Color(hex: "#08141c"),
        panelTop: Color(hex: "#17303c"),
        panelBottom: Color(hex: "#0c1820"),
        cardBackground: Color(hex: "#d7f6ff").opacity(0.09),
        cardStroke: Color(hex: "#d7f6ff").opacity(0.18),
        tone: Palette.accentColor(for: percent, low: RGB(122, 174, 255), mid: RGB(121, 240, 214), high: RGB(171, 255, 205)),
        liquidTop: Color(hex: "#baf7ff"),
        liquidMid: Color(hex: "#78dfd1"),
        liquidBottom: Color(hex: "#3faea3")
      )
    case .graphiteRose:
      return Palette(
        backgroundTop: Color(hex: "#221d26"),
        backgroundBottom: Color(hex: "#0b0d14"),
        panelTop: Color(hex: "#2a2630"),
        panelBottom: Color(hex: "#131721"),
        cardBackground: Color(hex: "#f5dbe7").opacity(0.09),
        cardStroke: Color(hex: "#f5dbe7").opacity(0.18),
        tone: Palette.accentColor(for: percent, low: RGB(255, 144, 144), mid: RGB(244, 176, 138), high: RGB(234, 196, 172)),
        liquidTop: Color(hex: "#ffd8df"),
        liquidMid: Color(hex: "#d9a0a7"),
        liquidBottom: Color(hex: "#8b626f")
      )
    case .forestNeon:
      return Palette(
        backgroundTop: Color(hex: "#0a2f24"),
        backgroundBottom: Color(hex: "#07120f"),
        panelTop: Color(hex: "#113027"),
        panelBottom: Color(hex: "#0a1d18"),
        cardBackground: Color(hex: "#dfff8d").opacity(0.08),
        cardStroke: Color(hex: "#dfff8d").opacity(0.18),
        tone: Palette.accentColor(for: percent, low: RGB(255, 141, 84), mid: RGB(208, 255, 120), high: RGB(89, 255, 176)),
        liquidTop: Color(hex: "#d6ff8f"),
        liquidMid: Color(hex: "#7df38a"),
        liquidBottom: Color(hex: "#22c98b")
      )
    case .custom:
      return Palette(
        backgroundTop: customColors.backgroundTop,
        backgroundBottom: customColors.backgroundBottom,
        panelTop: customColors.panelTop,
        panelBottom: customColors.panelBottom,
        cardBackground: Color.white.opacity(0.08),
        cardStroke: customColors.accent.opacity(0.35),
        tone: customColors.accent,
        liquidTop: customColors.liquidTop,
        liquidMid: customColors.liquidMid,
        liquidBottom: customColors.liquidBottom
      )
    }
  }

  private func persistCustomColors() {
    defaults.set(selectedPreset.rawValue, forKey: presetKey)
    defaults.set(customColors.backgroundTop.hexString, forKey: customPrefix + "backgroundTop")
    defaults.set(customColors.backgroundBottom.hexString, forKey: customPrefix + "backgroundBottom")
    defaults.set(customColors.panelTop.hexString, forKey: customPrefix + "panelTop")
    defaults.set(customColors.panelBottom.hexString, forKey: customPrefix + "panelBottom")
    defaults.set(customColors.accent.hexString, forKey: customPrefix + "accent")
    defaults.set(customColors.liquidTop.hexString, forKey: customPrefix + "liquidTop")
    defaults.set(customColors.liquidMid.hexString, forKey: customPrefix + "liquidMid")
    defaults.set(customColors.liquidBottom.hexString, forKey: customPrefix + "liquidBottom")
  }

  private static func loadCustomColors(defaults: UserDefaults) -> CustomThemeColors {
    let fallback = CustomThemeColors.default
    return CustomThemeColors(
      backgroundTop: Color(hex: defaults.string(forKey: "QuotaStatus.customTheme.backgroundTop") ?? fallback.backgroundTop.hexString),
      backgroundBottom: Color(hex: defaults.string(forKey: "QuotaStatus.customTheme.backgroundBottom") ?? fallback.backgroundBottom.hexString),
      panelTop: Color(hex: defaults.string(forKey: "QuotaStatus.customTheme.panelTop") ?? fallback.panelTop.hexString),
      panelBottom: Color(hex: defaults.string(forKey: "QuotaStatus.customTheme.panelBottom") ?? fallback.panelBottom.hexString),
      accent: Color(hex: defaults.string(forKey: "QuotaStatus.customTheme.accent") ?? fallback.accent.hexString),
      liquidTop: Color(hex: defaults.string(forKey: "QuotaStatus.customTheme.liquidTop") ?? fallback.liquidTop.hexString),
      liquidMid: Color(hex: defaults.string(forKey: "QuotaStatus.customTheme.liquidMid") ?? fallback.liquidMid.hexString),
      liquidBottom: Color(hex: defaults.string(forKey: "QuotaStatus.customTheme.liquidBottom") ?? fallback.liquidBottom.hexString)
    )
  }
}

final class CodexRateLimitReader {
  private let command: String
  private let timeout: TimeInterval

  init(command: String, timeout: TimeInterval = 30) {
    self.command = command
    self.timeout = timeout
  }

  func read() async throws -> CodexRateLimitEnvelope {
    try await perform(method: "account/rateLimits/read", params: [:], as: CodexRateLimitEnvelope.self)
  }

  func consumeResetCredit() async throws -> CodexResetOutcome {
    try await perform(
      method: "account/rateLimitResetCredit/consume",
      params: ["idempotencyKey": UUID().uuidString],
      as: CodexResetOutcome.self
    )
  }

  private func perform<Result: Decodable>(
    method: String,
    params: [String: Any],
    as type: Result.Type
  ) async throws -> Result {
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
          var sentRequest = false

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

              if id == 1, !sentRequest {
                sentRequest = true
                try send(["id": 2, "method": method, "params": params])
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
                let decoded = try JSONDecoder().decode(Result.self, from: data)
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
  let backgroundTop: Color
  let backgroundBottom: Color
  let panelTop: Color
  let panelBottom: Color
  let cardBackground: Color
  let cardStroke: Color
  let tone: Color
  let liquidTop: Color
  let liquidMid: Color
  let liquidBottom: Color

  static func accentColor(for percent: Int, low: RGB, mid: RGB, high: RGB) -> Color {
    let value = max(0, min(100, Double(percent)))
    let lowStop = PaletteStop(percent: 0, tone: low)
    let midStop = PaletteStop(percent: 50, tone: mid)
    let highStop = PaletteStop(percent: 100, tone: high)
    let range = value <= 50 ? (lowStop, midStop) : (midStop, highStop)
    let amount = (value - range.0.percent) / (range.1.percent - range.0.percent)
    return RGB.mix(range.0.tone, range.1.tone, amount).color
  }
}

struct PaletteStop {
  let percent: Double
  let tone: RGB
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

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let red = Double((int >> 16) & 0xFF) / 255
    let green = Double((int >> 8) & 0xFF) / 255
    let blue = Double(int & 0xFF) / 255
    self.init(red: red, green: green, blue: blue)
  }

  var hexString: String {
    let color = NSColor(self).usingColorSpace(.deviceRGB) ?? .black
    let red = Int(round(color.redComponent * 255))
    let green = Int(round(color.greenComponent * 255))
    let blue = Int(round(color.blueComponent * 255))
    return String(format: "#%02X%02X%02X", red, green, blue)
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
