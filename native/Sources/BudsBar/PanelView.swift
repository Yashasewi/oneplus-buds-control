import AppKit
import BudsKit
import Observation
import SwiftUI

// Panel state outside the views: SwiftUI's @State is a macro, which needs Xcode.
@MainActor
@Observable
final class PanelModel {
  enum Page: Hashable { case home, sound, controls, features, tools, preset, hearing }

  private(set) var page: Page = .home
  private(set) var forward = true
  var editing: Preset?
  var editingIsNew = false
  var confirming: String?
  var ringing = false
  var bassDraft: Double?
  var promptDraft: Double?
  var heights: [Page: CGFloat] = [:]

  func open(_ next: Page) {
    forward = true
    confirming = nil
    withAnimation(.snappy(duration: 0.3)) { page = next }
  }

  func back() {
    forward = false
    confirming = nil
    withAnimation(.snappy(duration: 0.3)) { page = parent }
  }

  func home() {
    if page != .home { forward = false }
    page = .home
  }

  private var parent: Page {
    switch page {
    case .preset: .sound
    case .hearing: .tools
    default: .home
    }
  }
}

@MainActor let panelModel = PanelModel()

struct PanelView: View {
  let session: BudsSession
  let model: PanelModel
  let audio: OutputAudio
  let prefs: AppPrefs

  var body: some View {
    ZStack(alignment: .top) {
      page
        .id(model.page)
        .transition(.push(from: model.forward ? .trailing : .leading))
    }
    .frame(width: 340)
    .clipped()
    .onChange(of: session.isConnected) { _, connected in if !connected { model.home() } }
  }

  @ViewBuilder private var page: some View {
    switch session.isConnected ? model.page : .home {
    case .home: HomePage(session: session, model: model, audio: audio)
    case .sound: SoundPage(session: session, model: model)
    case .controls: ControlsPage(session: session, model: model)
    case .features: FeaturesPage(session: session, model: model, prefs: prefs)
    case .tools: ToolsPage(session: session, model: model)
    case .preset: PresetPage(session: session, model: model)
    case .hearing: HearingPage(session: session, model: model, test: HearingModel.shared)
    }
  }
}

// MARK: Home

struct HomePage: View {
  let session: BudsSession
  let model: PanelModel
  let audio: OutputAudio

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      switch session.connection {
      case .connected:
        BatteryRow(session: session).padding(.vertical, 2)
        Tile {
          NoiseControl(session: session).padding(.vertical, 10)
        }
        VolumeTile(session: session, audio: audio)
        Tile {
          NavRow(icon: "slider.vertical.3", color: .pink, title: "Sound", value: presetName) { model.open(.sound) }
          NavRow(icon: "hand.tap.fill", color: .blue, title: "Controls") { model.open(.controls) }
          NavRow(icon: "switch.2", color: .green, title: "Features") { model.open(.features) }
          NavRow(icon: "wrench.and.screwdriver.fill", color: .orange, title: "Tools") { model.open(.tools) }
        }
      case .connecting:
        HStack(spacing: 8) {
          ProgressView().controlSize(.small)
          Text("Connecting…").foregroundStyle(.secondary)
        }
      case .searching:
        Text("Looking for your earbuds…").foregroundStyle(.secondary)
      case .unavailable(let message):
        Text(message).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
      if let error = session.lastError, model.page == .home {
        Label(error, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
      footer
    }
    .padding(14)
  }

  private var presetName: String? {
    session.presets.first { $0.id == session.eq }?.name
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 10) {
      Image(systemName: "earbuds")
        .font(.system(size: 15, weight: .medium))
        .frame(width: 30, height: 30)
        .background(Circle().fill(session.isConnected ? Color.accentColor : Color.primary.opacity(0.1)))
        .foregroundStyle(session.isConnected ? Color.white : Color.secondary)
      VStack(alignment: .leading, spacing: 1) {
        Text("OnePlus Buds 4").font(.headline)
        Text(subtitle).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      if session.busy { ProgressView().controlSize(.small) }
    }
  }

  private var subtitle: String {
    guard session.isConnected else { return "Not connected" }
    return ["Connected", session.codec.flatMap { codecNames[$0] }, session.firmware.map { "Firmware \($0)" }]
      .compactMap { $0 }.joined(separator: " · ")
  }

  private var footer: some View {
    HStack {
      if session.isConnected {
        Button("Disconnect") { session.disconnect() }
      } else if case .connecting = session.connection {
        EmptyView()
      } else {
        Button("Connect") { Task { await session.connect() } }
      }
      Spacer()
      Button("Quit") { NSApplication.shared.terminate(nil) }
    }
    .buttonStyle(.borderless)
    .font(.callout)
    .foregroundStyle(.secondary)
  }
}

struct VolumeTile: View {
  let session: BudsSession
  let audio: OutputAudio

  var body: some View {
    let name: String? = if case .connected(let n) = session.connection { n } else { nil }
    let buds = audio.buds(named: name)
    if let buds, audio.current == buds, let volume = audio.volume {
      Tile {
        HStack(spacing: 10) {
          Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.fill").foregroundStyle(.secondary).frame(width: 16)
          Slider(value: Binding(get: { volume }, set: { audio.setVolume($0) }), in: 0...1)
            .controlSize(.small)
          Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
      }
    } else if let buds {
      Tile {
        HStack {
          VStack(alignment: .leading, spacing: 1) {
            Text("Sound is playing elsewhere").font(.callout)
            Text(audio.current?.name ?? "Another output").font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
          Button("Use Buds") { audio.makeDefault(buds) }.controlSize(.small)
        }
        .padding(.vertical, 8)
      }
    }
  }
}

// MARK: Building blocks

/// A rounded group, like a Control Center module.
struct Tile<Content: View>: View {
  var title: String?
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let title {
        Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 6)
      }
      VStack(alignment: .leading, spacing: 0) { content }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.055)))
    }
  }
}

struct IconBadge: View {
  let icon: String
  let color: Color

  var body: some View {
    Image(systemName: icon)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: 22, height: 22)
      .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.gradient))
  }
}

struct NavRow: View {
  let icon: String
  let color: Color
  let title: String
  var value: String?
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        IconBadge(icon: icon, color: color)
        Text(title)
        Spacer()
        if let value { Text(value).foregroundStyle(.secondary).lineLimit(1) }
        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
      }
      .padding(.vertical, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

struct ToggleRow: View {
  let title: String
  var subtitle: String?
  let isOn: Binding<Bool>
  var disabled = false

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        if let subtitle {
          Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: 8)
      Toggle(title, isOn: isOn).toggleStyle(.switch).controlSize(.mini).labelsHidden().disabled(disabled)
    }
    .padding(.vertical, 8)
  }
}

struct StatusLine: View {
  let session: BudsSession
  let key: String

  var body: some View {
    Group {
      switch session.status[key] {
      case .pending:
        HStack(spacing: 6) {
          ProgressView().controlSize(.mini)
          Text("Waiting for the earbuds…")
        }
        .foregroundStyle(.secondary)
      case .done(let text):
        Label(text ?? "Confirmed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
      case .failed(let message):
        Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      case nil:
        EmptyView()
      }
    }
    .font(.caption)
    .padding(.bottom, session.status[key] == nil ? 0 : 8)
  }
}

/// A sub-page: back button and title, with content that scrolls once it outgrows the panel.
struct SubPage<Content: View>: View {
  let title: String
  let model: PanelModel
  var onBack: (() -> Void)?
  @ViewBuilder let content: Content

  var body: some View {
    let page = model.page
    VStack(spacing: 0) {
      ZStack {
        Text(title).font(.headline)
        HStack {
          Button {
            onBack?()
            model.back()
          } label: {
            Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
              .frame(width: 26, height: 26)
              .background(Circle().fill(Color.primary.opacity(0.07)))
              .contentShape(Circle())
          }
          .buttonStyle(.plain)
          .keyboardShortcut(.cancelAction)
          Spacer()
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      ScrollView {
        VStack(alignment: .leading, spacing: 14) { content }
          .padding(.horizontal, 14)
          .padding(.bottom, 14)
          .background(GeometryReader { geometry in
            Color.clear
              .onAppear { model.heights[page] = geometry.size.height }
              .onChange(of: geometry.size.height) { _, height in model.heights[page] = height }
          })
      }
      .scrollIndicators(.automatic)
      .frame(height: min(model.heights[page] ?? 320, 540))
    }
  }
}

// MARK: Earbuds status

struct BatteryRow: View {
  let session: BudsSession

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Part.allCases, id: \.self) { part in
        BatteryGauge(part: part, level: session.battery[part], wear: session.wearing[part])
          .frame(maxWidth: .infinity)
      }
    }
  }
}

struct BatteryGauge: View {
  let part: Part
  let level: BatteryLevel?
  let wear: WearState?

  var body: some View {
    VStack(spacing: 6) {
      ZStack {
        Circle().stroke(.quaternary, lineWidth: 4)
        Circle()
          .trim(from: 0, to: Double(level?.percent ?? 0) / 100)
          .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
          .rotationEffect(.degrees(-90))
          .animation(.easeOut(duration: 0.5), value: level?.percent)
        Image(systemName: part == .chargingCase ? "earbuds.case" : "earbuds")
          .font(.system(size: 17))
          .foregroundStyle(level?.percent == nil ? .tertiary : .primary)
      }
      .frame(width: 48, height: 48)
      HStack(spacing: 2) {
        if level?.charging == true { Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.green) }
        Text(level?.percent.map { "\($0)%" } ?? "–").font(.callout.monospacedDigit())
      }
      Text(note).font(.caption).foregroundStyle(.secondary)
    }
  }

  private var tint: Color {
    guard let level, let percent = level.percent else { return .clear }
    if level.charging { return .green }
    return percent <= 15 ? .red : .primary
  }
  private var note: String {
    if part == .chargingCase {
      // The case reports its battery only with the lid open and a bud inside.
      if level?.percent != nil { return "Case" }
      return wear?.lidOpen == true ? "Put a bud in" : "Open the lid"
    }
    guard let wear else { return part.label }
    return wear.inEar ? "\(part.label), in ear" : wear.inCase ? "\(part.label), in case" : part.label
  }
}

struct NoiseControl: View {
  let session: BudsSession

  private enum Group: CaseIterable {
    case anc, adaptive, transparency, off
    var mode: NoiseMode {
      switch self {
      case .anc: .anc
      case .adaptive: .adaptive
      case .transparency: .transparency
      case .off: .off
      }
    }
    var title: String {
      switch self {
      case .anc: "Noise Cancellation"
      case .adaptive: "Adaptive"
      case .transparency: "Transparency"
      case .off: "Off"
      }
    }
    var symbol: String {
      switch self {
      case .anc: "person.and.background.dotted"
      case .adaptive: "sparkles"
      case .transparency: "ear.and.waveform"
      case .off: "circle.slash"
      }
    }
  }

  private var current: Group? {
    guard let mode = session.noise?.mode else { return nil }
    if mode.isANC { return .anc }
    return Group.allCases.first { $0.mode == mode }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Noise Control").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
      HStack(alignment: .top, spacing: 6) {
        ForEach(Group.allCases, id: \.self) { group in
          Button {
            guard current != group else { return }
            Task { await session.setNoise(group.mode) }
          } label: {
            VStack(spacing: 6) {
              Image(systemName: group.symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 40, height: 40)
                .background(Circle().fill(current == group ? Color.accentColor : Color.primary.opacity(0.1)))
                .foregroundStyle(current == group ? Color.white : Color.primary)
              Text(group.title)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .disabled(session.busy)
          .accessibilityAddTraits(current == group ? .isSelected : [])
        }
      }
      if current == .anc {
        Picker("Strength", selection: Binding(
          get: { NoiseMode.ancLevels.contains(session.noise?.mode ?? .off) ? session.noise?.mode : nil },
          set: { if let mode = $0 { Task { await session.setNoise(mode) } } }
        )) {
          ForEach(NoiseMode.ancLevels, id: \.self) { mode in
            Text(mode.rawValue.capitalized).tag(Optional(mode))
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
        .disabled(session.busy)
        if session.noise?.mode == .smart, let level = session.smartLevel, level != .smart {
          Text("Smart is using \(level.rawValue) right now.").font(.caption).foregroundStyle(.secondary)
        }
      }
      StatusLine(session: session, key: "noise")
    }
  }
}
