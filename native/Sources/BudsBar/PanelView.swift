import AppKit
import BudsKit
import SwiftUI

struct PanelView: View {
  let session: BudsSession

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header
      switch session.connection {
      case .connected:
        BatteryRow(session: session)
        Divider()
        NoiseControl(session: session)
        Divider()
        EqualizerRow(session: session)
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
      if let error = session.lastError {
        Label(error, systemImage: "exclamationmark.triangle.fill")
          .font(.callout)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
      Divider()
      footer
    }
    .padding(16)
    .frame(width: 320)
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text("OnePlus Buds 4").font(.headline)
        if let firmware = session.firmware, session.isConnected {
          Text("Firmware \(firmware)").font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer()
      if session.busy { ProgressView().controlSize(.small) }
    }
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
  }
}

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
        Image(systemName: symbol)
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

  private var symbol: String {
    switch part {
    case .left: "earbuds"
    case .right: "earbuds"
    case .chargingCase: "earbuds.case"
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
      Text("Noise Control").font(.subheadline.weight(.semibold))
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
        .disabled(session.busy)
        if session.noise?.mode == .smart, let level = session.smartLevel, level != .smart {
          Text("Smart is using \(level.rawValue) right now.").font(.caption).foregroundStyle(.secondary)
        }
      }
    }
  }
}

struct EqualizerRow: View {
  let session: BudsSession

  var body: some View {
    HStack {
      Text("Equalizer").font(.subheadline.weight(.semibold))
      Spacer()
      Picker("Equalizer", selection: Binding(
        get: { session.eq ?? -1 },
        set: { id in Task { await session.setEq(id) } }
      )) {
        if session.eq == nil || !session.presets.contains(where: { $0.id == session.eq }) {
          Text("Unknown").tag(session.eq ?? -1)
        }
        ForEach(session.presets) { preset in Text(preset.name).tag(preset.id) }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .fixedSize()
      .disabled(session.busy)
    }
  }
}
