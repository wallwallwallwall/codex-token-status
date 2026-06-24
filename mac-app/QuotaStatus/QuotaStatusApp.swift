import AppKit
import Combine
import Foundation
import SwiftUI
import UserNotifications

private func quotaStatusNotificationTestLog(_ message: String) {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
}

private func quotaStatusDeliverFallbackNotification(title: String, body: String) {
  let notification = NSUserNotification()
  notification.title = title
  notification.informativeText = body
  notification.soundName = NSUserNotificationDefaultSoundName
  NSUserNotificationCenter.default.deliver(notification)
}

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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
  private var statusItem: NSStatusItem?
  private var cancellables = Set<AnyCancellable>()

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSUserNotificationCenter.default.delegate = self
    configureStatusItem()
    QuotaViewModel.shared.sendTestNotificationsIfRequested()

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

  nonisolated func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
    true
  }

  private func configureStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    renderStatusTitle(QuotaViewModel.shared.statusBarTitle, countdown: QuotaViewModel.shared.statusBarCountdownText, on: item)
    item.button?.target = self
    item.button?.action = #selector(showMainWindow)
    statusItem = item

    QuotaViewModel.shared.$statusBarTitle
      .combineLatest(QuotaViewModel.shared.$statusBarCountdownText)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] title, countdown in
        guard let item = self?.statusItem else { return }
        self?.renderStatusTitle(title, countdown: countdown, on: item)
      }
      .store(in: &cancellables)
  }

  private func renderStatusTitle(_ title: String, countdown: String, on item: NSStatusItem) {
    let hasCountdown = !countdown.isEmpty
    let countdownPrefix = hasCountdown ? statusBarCountdownPrefix(for: title) : ""
    let codexFontSize: CGFloat = NSFont.systemFontSize
    let metricsFontSize: CGFloat = hasCountdown ? 8.8 : NSFont.systemFontSize
    let countdownFontSize: CGFloat = 8.8
    let codexFont = NSFont.monospacedSystemFont(ofSize: codexFontSize, weight: .bold)
    let metricsFont = NSFont.monospacedSystemFont(ofSize: metricsFontSize, weight: .bold)
    let countdownFont = NSFont.monospacedSystemFont(ofSize: countdownFontSize, weight: .semibold)

    let image = renderStatusBarImage(
      title: title,
      countdown: countdown,
      countdownPrefix: countdownPrefix,
      codexFont: codexFont,
      metricsFont: metricsFont,
      countdownFont: countdownFont
    )
    item.length = image.size.width
    item.button?.title = ""
    item.button?.attributedTitle = NSAttributedString(string: "")
    item.button?.image = image
    item.button?.imagePosition = .imageOnly
    item.button?.imageScaling = .scaleNone
    item.button?.toolTip = hasCountdown ? "\(title)\n\(countdown)" : title
    item.button?.setAccessibilityLabel(hasCountdown ? "\(title)\n\(countdown)" : title)
  }

  private func renderStatusBarImage(
    title: String,
    countdown: String,
    countdownPrefix: String,
    codexFont: NSFont,
    metricsFont: NSFont,
    countdownFont: NSFont
  ) -> NSImage {
    let hasCountdown = !countdown.isEmpty
    let parts = statusBarTitleParts(title)
    let codexAttributes: [NSAttributedString.Key: Any] = [
      .font: codexFont,
      .foregroundColor: NSColor.white.withAlphaComponent(0.98),
    ]
    let metricsAttributes: [NSAttributedString.Key: Any] = [
      .font: metricsFont,
      .foregroundColor: NSColor.white.withAlphaComponent(0.96),
    ]
    let countdownAttributes: [NSAttributedString.Key: Any] = [
      .font: countdownFont,
      .foregroundColor: NSColor.white.withAlphaComponent(0.92),
    ]
    let codexSize = (parts.codex as NSString).size(withAttributes: codexAttributes)
    let spacerSize = (parts.spacer as NSString).size(withAttributes: codexAttributes)
    let metricsSize = (parts.metrics as NSString).size(withAttributes: metricsAttributes)
    let countdownSize = (countdown as NSString).size(withAttributes: countdownAttributes)
    let rightColumnX = codexSize.width + spacerSize.width
    let topLineWidth = rightColumnX + metricsSize.width
    let imageWidth = max(hasCountdown ? 92 : 78, ceil(max(topLineWidth, rightColumnX + countdownSize.width) + 4))
    let imageSize = NSSize(width: imageWidth, height: NSStatusBar.system.thickness)

    let image = NSImage(size: imageSize, flipped: true) { _ in
      if hasCountdown {
        let lineGap: CGFloat = -1.0
        let totalHeight = metricsSize.height + countdownSize.height + lineGap
        let codexY = floor((imageSize.height - codexSize.height) / 2)
        let metricsY = max(0, floor((imageSize.height - totalHeight) / 2))
        let countdownY = min(imageSize.height - countdownSize.height, metricsY + metricsSize.height + lineGap)

        (parts.codex as NSString).draw(at: CGPoint(x: 0, y: codexY), withAttributes: codexAttributes)
        (parts.metrics as NSString).draw(at: CGPoint(x: rightColumnX, y: metricsY), withAttributes: metricsAttributes)
        (countdown as NSString).draw(at: CGPoint(x: rightColumnX, y: countdownY), withAttributes: countdownAttributes)
      } else {
        let topLineHeight = max(codexSize.height, metricsSize.height)
        let titleY = max(0, floor((imageSize.height - topLineHeight) / 2))
        (parts.codex as NSString).draw(at: CGPoint(x: 0, y: titleY), withAttributes: codexAttributes)
        (parts.metrics as NSString).draw(at: CGPoint(x: rightColumnX, y: titleY), withAttributes: metricsAttributes)
      }
      return true
    }
    image.isTemplate = false
    return image
  }

  private func statusBarCountdownPrefix(for title: String) -> String {
    guard let separatorIndex = title.firstIndex(of: "\u{00A0}") else {
      return ""
    }
    let prefixLength = title.distance(from: title.startIndex, to: title.index(after: separatorIndex))
    return String(repeating: "\u{00A0}", count: prefixLength)
  }

  private func statusBarTitleParts(_ title: String) -> (codex: String, spacer: String, metrics: String) {
    guard let separatorIndex = title.firstIndex(of: "\u{00A0}") else {
      return (title, "", "")
    }

    let metricsStart = title.index(after: separatorIndex)
    return (
      String(title[..<separatorIndex]),
      String(title[separatorIndex..<metricsStart]),
      String(title[metricsStart...])
    )
  }

  @objc private func showMainWindow() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.windows.first?.makeKeyAndOrderFront(nil)
  }
}

struct QuotaPanelView: View {
  @ObservedObject private var model = QuotaViewModel.shared
  @StateObject private var themeStore = ThemeStore()
  @State private var showingThemeSheet = false

  var body: some View {
    let palette = themeStore.palette(for: model.primaryPercent)

    GeometryReader { proxy in
      let base = min(proxy.size.width, proxy.size.height)
      let scale = max(0.78, min(1.65, base / 360))
      let panelCorner = max(18, min(30, base * 0.058))
      let contentPadding = max(16, min(28, base * 0.052))
      let contentTopPadding = max(16, min(24, base * 0.044))
      let contentBottomPadding = max(12, min(18, base * 0.036))
      let sectionSpacing = max(8, min(12, base * 0.02))
      let gaugeSize = max(108, min(base * 0.36, 148))

      ZStack {
        RoundedRectangle(cornerRadius: panelCorner, style: .continuous)
          .fill(glassPanelFill(palette: palette))
          .overlay(
            RoundedRectangle(cornerRadius: panelCorner, style: .continuous)
              .fill(
                LinearGradient(
                  colors: [
                    Color.white.opacity(0.04),
                    Color.clear,
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
              highlighted: false,
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

          ResetActionCard(
            label: model.resetLabel,
            percent: model.resetCountText,
            status: model.resetAvailableText,
            palette: palette,
            scale: scale,
            isEnabled: model.canConsumeReset,
            helpText: model.resetButtonHelpText,
            action: handleResetTap
          )
        }
        .padding(.horizontal, contentPadding)
        .padding(.top, contentTopPadding)
        .padding(.bottom, contentBottomPadding)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .clipShape(RoundedRectangle(cornerRadius: panelCorner, style: .continuous))
    }
    .ignoresSafeArea()
    .sheet(isPresented: $showingThemeSheet) {
      ThemeSettingsSheet(themeStore: themeStore, model: model)
    }
  }

  private func glassPanelFill(palette: Palette) -> LinearGradient {
    LinearGradient(
      colors: [
        palette.backgroundTop,
        palette.panelTop,
        palette.panelBottom,
        palette.backgroundBottom,
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private func header(palette: Palette, scale: Double) -> some View {
    HStack(spacing: 10 * scale) {
      Circle()
        .fill(palette.tone)
        .frame(width: 14 * scale, height: 14 * scale)
        .shadow(color: palette.tone.opacity(0.36), radius: 8 * scale, x: 0, y: 0)
        .overlay(
          Circle()
            .stroke(palette.tone.opacity(0.12), lineWidth: 6 * scale)
        )

      VStack(alignment: .leading, spacing: 3 * scale) {
        Text(model.title)
          .font(.system(size: 18 * scale, weight: .bold))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.72)

        Text(model.signalText)
          .font(.system(size: 12 * scale, weight: .semibold))
          .foregroundStyle(Color.white.opacity(0.62))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }

      Spacer(minLength: 6 * scale)

      HStack(spacing: 8 * scale) {
        VStack(alignment: .trailing, spacing: 2 * scale) {
          Text("计划")
            .font(.system(size: 9 * scale, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.45))
          Text(model.planText)
            .font(.system(size: 17 * scale, weight: .bold))
            .foregroundStyle(palette.tone)
            .lineLimit(1)
            .minimumScaleFactor(0.66)
        }

        settingsMenuButton(palette: palette, scale: scale)
      }
    }
  }

  private func settingsMenuButton(palette: Palette, scale: Double) -> some View {
    Menu {
      Button {
        minimizeWindow()
      } label: {
        Label("最小化", systemImage: "minus")
      }

      Button {
        hideDockIcon()
      } label: {
        Label("隐藏", systemImage: "dock.rectangle")
      }

      Button {
        quitApp()
      } label: {
        Label("退出", systemImage: "power")
      }

      Divider()

      Button {
        showingThemeSheet = true
      } label: {
        Label("设置", systemImage: "slider.horizontal.3")
      }
    } label: {
      Image(systemName: "slider.horizontal.3")
        .font(.system(size: 12 * scale, weight: .bold))
        .foregroundStyle(.white.opacity(0.88))
        .frame(width: 26 * scale, height: 26 * scale)
        .background(Color.white.opacity(0.05), in: Circle())
        .overlay(
          Circle()
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
    .controlSize(.small)
    .menuStyle(.button)
    .help("打开窗口菜单")
  }

  private func minimizeWindow() {
    NSApp.keyWindow?.miniaturize(nil)
  }

  private func hideDockIcon() {
    NSApp.setActivationPolicy(.accessory)
  }

  private func quitApp() {
    NSApp.terminate(nil)
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
                Color.white.opacity(0.16),
                Color(red: 0.09, green: 0.13, blue: 0.17).opacity(0.88),
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
            .fill(Color.white.opacity(0.08))

            WaveShape(
              progress: min(1, progress + 0.018),
              phase: phase + .pi * 0.3,
              amplitudeRatio: 0.014,
              wavelengthRatio: 1.05
            )
            .stroke(Color.white.opacity(0.12), lineWidth: max(1.0, size * 0.01))
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
            .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)
          Text("剩余")
            .font(.system(size: max(14, size * 0.10), weight: .semibold))
            .foregroundStyle(.white.opacity(0.78))
        }
      }
      .overlay(
        Circle()
          .stroke(Color.white.opacity(0.18), lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 8)
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
        .font(.system(size: 12 * scale, weight: .semibold))
        .foregroundStyle(Color.white.opacity(0.58))
        .lineLimit(1)
        .minimumScaleFactor(0.72)

      metricValueRow
    }
    .padding(.horizontal, 12 * scale)
    .padding(.vertical, 11 * scale)
    .frame(maxWidth: .infinity, minHeight: 58 * scale, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
        .fill(glassCardFill(palette: palette, highlighted: highlighted))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
        .stroke(highlighted ? palette.tone.opacity(0.24) : Color.white.opacity(0.10), lineWidth: 1)
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

  private func glassCardFill(palette: Palette, highlighted: Bool) -> LinearGradient {
    LinearGradient(
      colors: highlighted ? [
        palette.tone.opacity(0.12),
        Color.white.opacity(0.04),
      ] : [
        palette.cardBackground,
        palette.cardBackground.opacity(0.82),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var metricPercentColumnWidth: Double {
    52 * scale
  }

  private var metricResetColumnWidth: Double {
    54 * scale
  }

  private var percentView: some View {
    Text(percent)
      .font(.system(size: 16 * scale, weight: .bold))
      .foregroundStyle(.white)
      .monospacedDigit()
      .lineLimit(1)
      .minimumScaleFactor(0.5)
      .allowsTightening(true)
      .layoutPriority(5)
  }

  private var metricValueRow: some View {
    HStack(alignment: .lastTextBaseline, spacing: 0) {
      percentView
        .frame(width: metricPercentColumnWidth, alignment: .leading)

      Spacer(minLength: 8 * scale)

      Text(reset)
        .font(.system(size: 13.5 * scale, weight: .semibold))
        .foregroundStyle(Color.white.opacity(0.52))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .allowsTightening(true)
        .layoutPriority(4)
        .frame(width: metricResetColumnWidth, alignment: .trailing)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct ResetActionCard: View {
  let label: String
  let percent: String
  let status: String
  let palette: Palette
  let scale: Double
  let isEnabled: Bool
  let helpText: String?
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10 * scale) {
        VStack(alignment: .leading, spacing: 8 * scale) {
          Text(label)
            .font(.system(size: 12 * scale, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.58))
            .lineLimit(1)

          Text(percent)
            .font(.system(size: 18 * scale, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)

          Text(status)
            .font(.system(size: 14 * scale, weight: .semibold))
            .foregroundStyle(isEnabled ? palette.tone : Color.white.opacity(0.44))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }

        Spacer(minLength: 0)

        VStack(spacing: 7 * scale) {
          Image(systemName: isEnabled ? "arrow.clockwise.circle.fill" : "minus.circle")
            .font(.system(size: 24 * scale, weight: .semibold))
            .foregroundStyle(isEnabled ? palette.tone : Color.white.opacity(0.30))

          Text(isEnabled ? "立即重置" : "暂无次数")
            .font(.system(size: 11 * scale, weight: .bold))
            .foregroundStyle(isEnabled ? Color.black.opacity(0.78) : Color.white.opacity(0.45))
            .padding(.vertical, 6 * scale)
            .padding(.horizontal, 10 * scale)
            .background(
              Capsule(style: .continuous)
                .fill(isEnabled ? palette.tone : Color.white.opacity(0.06))
            )
        }
      }
      .padding(.horizontal, 12 * scale)
      .padding(.vertical, 12 * scale)
      .frame(maxWidth: .infinity, minHeight: 74 * scale, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
          .fill(
            LinearGradient(
              colors: isEnabled ? [
                palette.tone.opacity(0.18),
                palette.cardBackground.opacity(0.94),
              ] : [
                palette.cardBackground,
                palette.cardBackground.opacity(0.82),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
          .stroke(isEnabled ? palette.tone.opacity(0.34) : Color.white.opacity(0.08), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.9)
    .contentShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
    .help(helpText ?? "使用官方重置功能")
  }
}

struct ThemeSettingsSheet: View {
  @ObservedObject var themeStore: ThemeStore
  @ObservedObject var model: QuotaViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    let custom = themeStore.customColors

    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("设置")
              .font(.system(size: 22, weight: .black, design: .rounded))
            Text("状态栏、通知和配色")
              .foregroundStyle(.secondary)
          }
          Spacer()
          Button("完成") { dismiss() }
        }

        settingsSection("Token 数据刷新") {
          Text("默认 30 秒，从本机 Codex 读取 token 数据。")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)

          Picker("刷新间隔", selection: Binding(
            get: { model.refreshIntervalMode },
            set: { model.setRefreshIntervalMode($0) }
          )) {
            Text("30 秒").tag(RefreshIntervalMode.seconds30)
            Text("1 分钟").tag(RefreshIntervalMode.minute1)
            Text("5 分钟").tag(RefreshIntervalMode.minute5)
            Text("自定义").tag(RefreshIntervalMode.custom)
          }
          .pickerStyle(.segmented)

          if model.refreshIntervalMode == .custom {
            HStack(spacing: 10) {
              Text("自定义间隔")
              TextField("秒", value: Binding(
                get: { model.refreshIntervalCustomSeconds },
                set: { model.setRefreshIntervalCustomSeconds($0) }
              ), format: .number)
              .textFieldStyle(.roundedBorder)
              .frame(width: 88)
              Text("秒")
              Spacer()
            }

            Text("支持 10 秒到 86400 秒。当前每 \(model.refreshIntervalDisplayText) 读取一次。")
              .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundStyle(.secondary)
          } else {
            Text("当前每 \(model.refreshIntervalDisplayText) 读取一次。")
              .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundStyle(.secondary)
          }
        }

        settingsSection("状态栏") {
          HStack(spacing: 16) {
            Toggle("显示倒计时", isOn: Binding(
              get: { model.statusBarShowsCountdown },
              set: { model.setStatusBarShowsCountdown($0) }
            ))

            Toggle("显示重置时间", isOn: Binding(
              get: { model.statusBarShowsResetTime },
              set: { model.setStatusBarShowsResetTime($0) }
            ))
          }

          Picker("倒计时来源", selection: Binding(
            get: { model.statusBarCountdownTarget },
            set: { model.setStatusBarCountdownTarget($0) }
          )) {
            Text("5小时倒计时").tag(CountdownTarget.fiveHour)
            Text("7天倒计时").tag(CountdownTarget.sevenDay)
          }
          .pickerStyle(.segmented)
          .disabled(!model.statusBarShowsCountdown)

          Picker("重置时间来源", selection: Binding(
            get: { model.statusBarResetTimeTarget },
            set: { model.setStatusBarResetTimeTarget($0) }
          )) {
            Text("5小时重置").tag(CountdownTarget.fiveHour)
            Text("7天重置").tag(CountdownTarget.sevenDay)
          }
          .pickerStyle(.segmented)
          .disabled(!model.statusBarShowsResetTime)
        }

        settingsSection("通知提醒") {
          Toggle("开启通知提醒", isOn: Binding(
            get: { model.notificationsEnabled },
            set: { model.setNotificationsEnabled($0) }
          ))

          Toggle("5小时剩余 50%", isOn: Binding(
            get: { model.notificationEnabled(for: .fifty) },
            set: { model.setNotificationThreshold(.fifty, enabled: $0) }
          ))
          .disabled(!model.notificationsEnabled)

          Toggle("5小时剩余 20%", isOn: Binding(
            get: { model.notificationEnabled(for: .twenty) },
            set: { model.setNotificationThreshold(.twenty, enabled: $0) }
          ))
          .disabled(!model.notificationsEnabled)

          Toggle("5小时剩余 5%", isOn: Binding(
            get: { model.notificationEnabled(for: .five) },
            set: { model.setNotificationThreshold(.five, enabled: $0) }
          ))
          .disabled(!model.notificationsEnabled)
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

  private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.system(size: 16, weight: .black, design: .rounded))
      content()
    }
    .padding(12)
    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(Color.white.opacity(0.12), lineWidth: 1)
    )
  }
}

enum CountdownTarget: String, CaseIterable, Identifiable {
  case fiveHour
  case sevenDay

  var id: String { rawValue }
}

enum RefreshIntervalMode: String, CaseIterable, Identifiable {
  case seconds30
  case minute1
  case minute5
  case custom

  var id: String { rawValue }

  var seconds: Int {
    switch self {
    case .seconds30: return 30
    case .minute1: return 60
    case .minute5: return 300
    case .custom: return 0
    }
  }
}

enum NotificationThreshold: Int, CaseIterable, Identifiable {
  case fifty = 50
  case twenty = 20
  case five = 5

  var id: Int { rawValue }
}

@MainActor
final class QuotaViewModel: ObservableObject {
  static let shared = QuotaViewModel()

  private static let defaults = UserDefaults.standard
  private static let showsCountdownKey = "QuotaStatus.statusBar.showsCountdown"
  private static let showsResetTimeKey = "QuotaStatus.statusBar.showsResetTime"
  private static let countdownTargetKey = "QuotaStatus.statusBar.countdownTarget"
  private static let resetTimeTargetKey = "QuotaStatus.statusBar.resetTimeTarget"
  private static let refreshIntervalModeKey = "QuotaStatus.refresh.intervalMode"
  private static let refreshIntervalCustomSecondsKey = "QuotaStatus.refresh.customSeconds"
  private static let displayCacheKey = "QuotaStatus.display.cache"
  private static let notificationsEnabledKey = "QuotaStatus.notifications.enabled"
  private static let notify50Key = "QuotaStatus.notifications.threshold50"
  private static let notify20Key = "QuotaStatus.notifications.threshold20"
  private static let notify5Key = "QuotaStatus.notifications.threshold5"

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
  @Published var statusBarTitle = "CodeX\u{00A0}--|--"
  @Published var statusBarCountdownText = ""
  @Published var statusBarShowsCountdown = QuotaViewModel.storedBool(QuotaViewModel.showsCountdownKey, defaultValue: false)
  @Published var statusBarShowsResetTime = QuotaViewModel.storedBool(QuotaViewModel.showsResetTimeKey, defaultValue: false)
  @Published var statusBarCountdownTarget = CountdownTarget(rawValue: QuotaViewModel.defaults.string(forKey: QuotaViewModel.countdownTargetKey) ?? "") ?? .fiveHour
  @Published var statusBarResetTimeTarget = CountdownTarget(rawValue: QuotaViewModel.defaults.string(forKey: QuotaViewModel.resetTimeTargetKey) ?? "") ?? .fiveHour
  @Published var refreshIntervalMode = RefreshIntervalMode(rawValue: QuotaViewModel.defaults.string(forKey: QuotaViewModel.refreshIntervalModeKey) ?? "") ?? .seconds30
  @Published var refreshIntervalCustomSeconds = QuotaViewModel.storedRefreshIntervalCustomSeconds()
  @Published var notificationsEnabled = QuotaViewModel.storedBool(QuotaViewModel.notificationsEnabledKey, defaultValue: false)
  @Published var notifyAt50 = QuotaViewModel.storedBool(QuotaViewModel.notify50Key, defaultValue: true)
  @Published var notifyAt20 = QuotaViewModel.storedBool(QuotaViewModel.notify20Key, defaultValue: true)
  @Published var notifyAt5 = QuotaViewModel.storedBool(QuotaViewModel.notify5Key, defaultValue: true)

  private let displayTitle: String
  private let codexCommand: String
  private var timer: Timer?
  private var countdownTimer: Timer?
  private var shortResetDate: Date?
  private var weeklyResetDate: Date?
  private var shortRemainingPercent: Int?
  private var notifiedWindowKey: String?
  private var notifiedThresholds = Set<Int>()

  init() {
    displayTitle = Self.argumentValue("title") ??
      ProcessInfo.processInfo.environment["QUOTA_STATUS_TITLE"] ??
      "Mac Codex"
    codexCommand = Self.argumentValue("codexCommand") ??
      ProcessInfo.processInfo.environment["QUOTA_STATUS_CODEX_COMMAND"] ??
      Self.defaultCodexCommand()

    if statusBarShowsCountdown && statusBarShowsResetTime {
      statusBarShowsResetTime = false
      Self.defaults.set(false, forKey: Self.showsResetTimeKey)
    }

    restoreDisplayCache()
    load()
    scheduleStatusTimer()
    countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      Task { await self?.refreshStatusBarDisplay() }
    }
  }

  deinit {
    timer?.invalidate()
    countdownTimer?.invalidate()
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
      if hasDisplayData {
        signalText = "读取失败，保留上次数据"
        resetButtonHelpText = sanitizeFetchMessage(error.userFacingMessage)
        refreshStatusBarDisplay()
      } else {
        signalText = sanitizeFetchMessage(error.userFacingMessage)
      }
    }
  }

  private func apply(_ snapshot: CodexRateLimitSnapshot) {
    let short = displayWindow(snapshot.primary, label: "5h", resetKind: .time)
    let weekly = displayWindow(snapshot.secondary, label: "Weekly", resetKind: .date)
    let percent = percentFrom(short: short, weekly: weekly)

    title = displayTitle
    planText = planDisplay(snapshot.planType)
    primaryPercent = percent
    stale = false
    signalText = signalFor(percent)
    shortResetDate = short?.resetDate
    weeklyResetDate = weekly?.resetDate
    shortRemainingPercent = short.map { clamp($0.percent ?? 0) }

    shortLabel = labelForWindow(short?.label, fallback: "5小时窗口")
    shortPercentText = percentText(short)
    shortResetText = resetText(short)
    weeklyLabel = labelForWindow(weekly?.label, fallback: "7天窗口")
    weeklyPercentText = percentText(weekly)
    weeklyResetText = resetText(weekly)
    refreshStatusBarDisplay()
    sendThresholdNotificationsIfNeeded()
    resetLabel = "剩余重置次数"
    resetCountText = resetCount(snapshot.rateLimitResetCredits)
    resetAvailableText = resetAvailability(snapshot.rateLimitResetCredits)
    canConsumeReset = (snapshot.rateLimitResetCredits?.availableCount ?? 0) > 0 && !isResetting
    resetButtonHelpText = resetHelpText(snapshot.rateLimitResetCredits)
    saveDisplayCache()
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
      signalText = sanitizeFetchMessage(error.userFacingMessage)
      canConsumeReset = true
      resetButtonHelpText = "官方重置失败，点击重试"
    }
  }

  func setStatusBarShowsCountdown(_ enabled: Bool) {
    statusBarShowsCountdown = enabled
    Self.defaults.set(enabled, forKey: Self.showsCountdownKey)
    if enabled {
      statusBarShowsResetTime = false
      Self.defaults.set(false, forKey: Self.showsResetTimeKey)
    }
    refreshStatusBarDisplay()
  }

  func setStatusBarShowsResetTime(_ enabled: Bool) {
    statusBarShowsResetTime = enabled
    Self.defaults.set(enabled, forKey: Self.showsResetTimeKey)
    if enabled {
      statusBarShowsCountdown = false
      Self.defaults.set(false, forKey: Self.showsCountdownKey)
    }
    refreshStatusBarDisplay()
  }

  func setStatusBarCountdownTarget(_ target: CountdownTarget) {
    statusBarCountdownTarget = target
    Self.defaults.set(target.rawValue, forKey: Self.countdownTargetKey)
    refreshStatusBarDisplay()
  }

  func setStatusBarResetTimeTarget(_ target: CountdownTarget) {
    statusBarResetTimeTarget = target
    Self.defaults.set(target.rawValue, forKey: Self.resetTimeTargetKey)
    refreshStatusBarDisplay()
  }

  var statusRefreshIntervalSeconds: TimeInterval {
    let seconds = refreshIntervalMode == .custom ? refreshIntervalCustomSeconds : refreshIntervalMode.seconds
    return TimeInterval(Self.clampRefreshIntervalSeconds(seconds))
  }

  var refreshIntervalDisplayText: String {
    Self.refreshIntervalText(Int(statusRefreshIntervalSeconds))
  }

  func setRefreshIntervalMode(_ mode: RefreshIntervalMode) {
    refreshIntervalMode = mode
    Self.defaults.set(mode.rawValue, forKey: Self.refreshIntervalModeKey)
    scheduleStatusTimer()
    Task { await fetchStatus() }
  }

  func setRefreshIntervalCustomSeconds(_ seconds: Int) {
    let clamped = Self.clampRefreshIntervalSeconds(seconds)
    refreshIntervalCustomSeconds = clamped
    Self.defaults.set(clamped, forKey: Self.refreshIntervalCustomSecondsKey)
    if refreshIntervalMode == .custom {
      scheduleStatusTimer()
    }
  }

  func setNotificationsEnabled(_ enabled: Bool) {
    notificationsEnabled = enabled
    Self.defaults.set(enabled, forKey: Self.notificationsEnabledKey)
    if enabled {
      requestNotificationAuthorization()
      sendThresholdNotificationsIfNeeded()
    }
  }

  func notificationEnabled(for threshold: NotificationThreshold) -> Bool {
    switch threshold {
    case .fifty: return notifyAt50
    case .twenty: return notifyAt20
    case .five: return notifyAt5
    }
  }

  func setNotificationThreshold(_ threshold: NotificationThreshold, enabled: Bool) {
    switch threshold {
    case .fifty:
      notifyAt50 = enabled
      Self.defaults.set(enabled, forKey: Self.notify50Key)
    case .twenty:
      notifyAt20 = enabled
      Self.defaults.set(enabled, forKey: Self.notify20Key)
    case .five:
      notifyAt5 = enabled
      Self.defaults.set(enabled, forKey: Self.notify5Key)
    }
    sendThresholdNotificationsIfNeeded()
  }

  func sendTestNotificationsIfRequested() {
    guard ProcessInfo.processInfo.environment["QUOTA_STATUS_TEST_NOTIFICATIONS"] == "1" else {
      return
    }

    let testIdentifiers = NotificationThreshold.allCases.map { "quota-status-5h-\($0.rawValue)-0" }
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: testIdentifiers)
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: testIdentifiers)

    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
      if let error {
        quotaStatusNotificationTestLog("QuotaStatus notification test authorization error: \(error.localizedDescription)")
      }
      quotaStatusNotificationTestLog("QuotaStatus notification test authorization granted=\(granted)")

      Task { @MainActor in
        for threshold in NotificationThreshold.allCases {
          self.sendNotification(for: threshold, currentPercent: threshold.rawValue)
          quotaStatusNotificationTestLog("QuotaStatus notification test sent threshold=\(threshold.rawValue)")
        }
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
          let deliveredCount = notifications.filter { testIdentifiers.contains($0.request.identifier) }.count
          quotaStatusNotificationTestLog("QuotaStatus notification test delivered count=\(deliveredCount)")
        }
      }
    }
  }

  private func scheduleStatusTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: statusRefreshIntervalSeconds, repeats: true) { [weak self] _ in
      Task { await self?.fetchStatus() }
    }
    timer?.tolerance = min(statusRefreshIntervalSeconds * 0.1, 10)
  }

  private func refreshStatusBarDisplay() {
    statusBarTitle = "CodeX\u{00A0}\(shortPercentText)|\(weeklyPercentText)"
    if statusBarShowsCountdown {
      let resetDate = statusBarCountdownTarget == .fiveHour ? shortResetDate : weeklyResetDate
      statusBarCountdownText = countdownText(until: resetDate, target: statusBarCountdownTarget)
      return
    }
    if statusBarShowsResetTime {
      statusBarCountdownText = statusBarResetTimeText()
      return
    }
    statusBarCountdownText = ""
  }

  private func statusBarResetTimeText() -> String {
    statusBarResetTimeTarget == .fiveHour ? shortResetText : weeklyResetText
  }

  private var hasDisplayData: Bool {
    shortPercentText != "--" || weeklyPercentText != "--"
  }

  private func restoreDisplayCache() {
    guard let data = Self.defaults.data(forKey: Self.displayCacheKey),
          let cache = try? JSONDecoder().decode(QuotaDisplayCache.self, from: data) else {
      return
    }

    title = cache.title
    signalText = cache.signalText
    planText = cache.planText
    primaryPercent = cache.primaryPercent
    shortLabel = cache.shortLabel
    shortPercentText = cache.shortPercentText
    shortResetText = cache.shortResetText
    weeklyLabel = cache.weeklyLabel
    weeklyPercentText = cache.weeklyPercentText
    weeklyResetText = cache.weeklyResetText
    resetLabel = cache.resetLabel
    resetCountText = cache.resetCountText
    resetAvailableText = cache.resetAvailableText
    resetButtonHelpText = cache.resetButtonHelpText
    canConsumeReset = false
    stale = false
    refreshStatusBarDisplay()
  }

  private func saveDisplayCache() {
    let cache = QuotaDisplayCache(
      title: title,
      signalText: signalText,
      planText: planText,
      primaryPercent: primaryPercent,
      shortLabel: shortLabel,
      shortPercentText: shortPercentText,
      shortResetText: shortResetText,
      weeklyLabel: weeklyLabel,
      weeklyPercentText: weeklyPercentText,
      weeklyResetText: weeklyResetText,
      resetLabel: resetLabel,
      resetCountText: resetCountText,
      resetAvailableText: resetAvailableText,
      resetButtonHelpText: resetButtonHelpText
    )
    if let data = try? JSONEncoder().encode(cache) {
      Self.defaults.set(data, forKey: Self.displayCacheKey)
    }
  }

  private func sanitizeFetchMessage(_ message: String) -> String {
    let withoutEscape = message.replacingOccurrences(of: "\u{001B}", with: "")
    let withoutAnsi = withoutEscape.replacingOccurrences(
      of: #"\[[0-9;]*[A-Za-z]"#,
      with: "",
      options: .regularExpression
    )
    let firstLine = withoutAnsi
      .split(whereSeparator: \.isNewline)
      .first
      .map(String.init) ?? "Codex 读取失败"
    let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "Codex 读取失败" }
    if trimmed.count > 34 {
      return "\(trimmed.prefix(34))..."
    }
    return trimmed
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
      resetAt: nil,
      resetDate: window?.resetsAt.map { Date(timeIntervalSince1970: $0) }
    )
  }

  private func countdownText(until resetDate: Date?, target: CountdownTarget) -> String {
    guard let resetDate else { return "--" }
    let totalSeconds = max(0, Int(resetDate.timeIntervalSinceNow.rounded()))
    let days = totalSeconds / 86_400
    let totalHours = totalSeconds / 3_600
    let hours = (totalSeconds % 86_400) / 3_600
    let minutes = (totalSeconds % 3_600) / 60

    switch target {
    case .fiveHour: return "\(totalHours)h \(minutes)m"
    case .sevenDay: return "\(days)d \(hours)h"
    }
  }

  private func sendThresholdNotificationsIfNeeded() {
    guard notificationsEnabled, let percent = shortRemainingPercent, let resetDate = shortResetDate else {
      return
    }

    let windowKey = String(Int(resetDate.timeIntervalSince1970))
    if notifiedWindowKey != windowKey {
      notifiedWindowKey = windowKey
      notifiedThresholds.removeAll()
    }

    for threshold in NotificationThreshold.allCases where notificationEnabled(for: threshold) {
      guard percent <= threshold.rawValue, !notifiedThresholds.contains(threshold.rawValue) else {
        continue
      }
      notifiedThresholds.insert(threshold.rawValue)
      sendNotification(for: threshold, currentPercent: percent)
    }
  }

  private func requestNotificationAuthorization() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  private func sendNotification(for threshold: NotificationThreshold, currentPercent: Int) {
    let title = "CodeX 5小时额度提醒"
    let body = "5小时剩余额度已到 \(threshold.rawValue)%，当前剩余 \(currentPercent)%"
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: "quota-status-5h-\(threshold.rawValue)-\(Int(shortResetDate?.timeIntervalSince1970 ?? 0))",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request) { error in
      if let error {
        quotaStatusNotificationTestLog("QuotaStatus notification add error: \(error.localizedDescription)")
        DispatchQueue.main.async {
          quotaStatusDeliverFallbackNotification(title: title, body: body)
          if ProcessInfo.processInfo.environment["QUOTA_STATUS_TEST_NOTIFICATIONS"] == "1" {
            quotaStatusNotificationTestLog("QuotaStatus notification legacy fallback sent threshold=\(threshold.rawValue)")
          }
        }
      } else if ProcessInfo.processInfo.environment["QUOTA_STATUS_TEST_NOTIFICATIONS"] == "1" {
        quotaStatusNotificationTestLog("QuotaStatus notification test added threshold=\(threshold.rawValue)")
      }
    }
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

  private func clamp(_ value: Double) -> Int {
    max(0, min(100, Int(value.rounded())))
  }

  private static func storedBool(_ key: String, defaultValue: Bool) -> Bool {
    guard defaults.object(forKey: key) != nil else { return defaultValue }
    return defaults.bool(forKey: key)
  }

  private static func storedRefreshIntervalCustomSeconds() -> Int {
    guard defaults.object(forKey: refreshIntervalCustomSecondsKey) != nil else {
      return 300
    }
    return clampRefreshIntervalSeconds(defaults.integer(forKey: refreshIntervalCustomSecondsKey))
  }

  private static func clampRefreshIntervalSeconds(_ seconds: Int) -> Int {
    min(86_400, max(10, seconds))
  }

  private static func refreshIntervalText(_ seconds: Int) -> String {
    if seconds < 60 {
      return "\(seconds) 秒"
    }
    if seconds % 3600 == 0 {
      return "\(seconds / 3600) 小时"
    }
    if seconds % 60 == 0 {
      return "\(seconds / 60) 分钟"
    }
    return "\(seconds) 秒"
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
  let resetDate: Date?
}

struct QuotaDisplayCache: Codable {
  let title: String
  let signalText: String
  let planText: String
  let primaryPercent: Int
  let shortLabel: String
  let shortPercentText: String
  let shortResetText: String
  let weeklyLabel: String
  let weeklyPercentText: String
  let weeklyResetText: String
  let resetLabel: String
  let resetCountText: String
  let resetAvailableText: String
  let resetButtonHelpText: String
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
    backgroundTop: Color(hex: "#132736"),
    backgroundBottom: Color(hex: "#09131B"),
    panelTop: Color(hex: "#1A3243"),
    panelBottom: Color(hex: "#101D28"),
    accent: Color(hex: "#F2C078"),
    liquidTop: Color(hex: "#F8D8A7"),
    liquidMid: Color(hex: "#E9B56E"),
    liquidBottom: Color(hex: "#C9894C")
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
        backgroundTop: Color(hex: "#122736"),
        backgroundBottom: Color(hex: "#08131B"),
        panelTop: Color(hex: "#193244"),
        panelBottom: Color(hex: "#0E1C27"),
        cardBackground: Color.white.opacity(0.075),
        cardStroke: Color.white.opacity(0.12),
        tone: Palette.accentColor(for: percent, low: RGB(216, 128, 96), mid: RGB(240, 192, 120), high: RGB(125, 209, 169)),
        liquidTop: Color(hex: "#F7D8A9"),
        liquidMid: Color(hex: "#E9B56E"),
        liquidBottom: Color(hex: "#CB8C4F")
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
