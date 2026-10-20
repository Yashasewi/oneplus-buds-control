import BudsKit
import Observation
import SwiftUI

struct SwitchRow: View {
  let session: BudsSession
  let item: Switch
  var description: String?
  var unavailable: String?

  var body: some View {
    if session.isOn(item) != nil {
      ToggleRow(
        title: item.title,
        subtitle: unavailable ?? description,
        isOn: Binding(get: { session.isOn(item) ?? false }, set: { on in Task { await session.setSwitch(item, on) } }),
        disabled: session.busy || (unavailable != nil && session.isOn(item) != true)
      )
      StatusLine(session: session, key: "switch-\(item.rawValue)")
    }
  }
}

/// A stepped slider that writes only when released.
struct StepSlider: View {
  let title: String
  let range: ClosedRange<Double>
  let value: Int?
  let draft: Binding<Double?>
  let format: (Int) -> String
  let commit: (Int) -> Void
  var disabled = false

  var body: some View {
    let shown = draft.wrappedValue ?? Double(value ?? Int(range.lowerBound))
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(title)
        Spacer()
        Text(format(Int(shown))).monospacedDigit().foregroundStyle(.secondary)
      }
      Slider(value: Binding(get: { shown }, set: { draft.wrappedValue = $0 }), in: range, step: 1) { editing in
        guard !editing, let picked = draft.wrappedValue else { return }
        draft.wrappedValue = nil
        if Int(picked) != value { commit(Int(picked)) }
      }
      .controlSize(.small)
    }
    .padding(.vertical, 8)
    .disabled(disabled || value == nil)
  }
}

private func signedText(_ n: Int) -> String { n > 0 ? "+\(n)" : "\(n)" }

// MARK: Sound

struct SoundPage: View {
  let session: BudsSession
  @Bindable var model: PanelModel

  var body: some View {
    SubPage(title: "Sound", model: model) {
      Tile(title: "Equalizer") {
        ForEach(session.presets) { preset in
          HStack(spacing: 8) {
            Button {
              if session.eq != preset.id { Task { await session.setEq(preset.id) } }
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 2) {
                  Text(preset.name)
                  if preset.isCustom {
                    Text(preset.bands.map { signedText($0.gain) }.joined(separator: "  "))
                      .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                  }
                }
                Spacer()
                if session.eq == preset.id { Image(systemName: "checkmark").font(.callout.weight(.semibold)).foregroundStyle(Color.accentColor) }
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(session.busy)
            if preset.isCustom {
              Button {
                EditorDraft.reset()
                model.editingIsNew = false
                model.editing = preset
                model.open(.preset)
              } label: {
                Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary)
              }
              .buttonStyle(.plain)
              .help("Edit \(preset.name)")
            }
          }
          .padding(.vertical, 7)
        }
        StatusLine(session: session, key: "eq")
        if session.supports(0x0418) {
          Divider()
          Button {
            EditorDraft.reset()
            model.editingIsNew = true
            model.editing = Preset(id: 0, name: "Custom \(session.customPresets.count + 1)",
              bands: eqBands.map { Band(frequency: $0, gain: 0) })
            model.open(.preset)
          } label: {
            Label(session.customPresets.count >= eqMaxCustom ? "Up to \(eqMaxCustom) custom presets" : "New preset",
              systemImage: "plus")
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 8)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .foregroundStyle(session.customPresets.count >= eqMaxCustom ? Color.secondary : Color.accentColor)
          .disabled(session.busy || session.customPresets.count >= eqMaxCustom)
          StatusLine(session: session, key: "preset")
        }
      }
      Tile(title: "Enhancements") {
        SwitchRow(session: session, item: .bassWave, description: "Extra bass from the dynamic driver.")
        if session.isOn(.bassWave) == true, session.bass != nil {
          StepSlider(title: "Bass strength", range: -5...5, value: session.bass, draft: $model.bassDraft,
            format: signedText, commit: { level in Task { await session.setBass(level) } }, disabled: session.busy)
          StatusLine(session: session, key: "bass")
        }
        SwitchRow(session: session, item: .goldenSound,
          description: session.golden.map { "Your profile from \($0.name)." } ?? "Take the hearing test in Tools first.")
        SwitchRow(session: session, item: .spatial, description: "Spatial audio.")
        SwitchRow(session: session, item: .hiRes,
          unavailable: session.hiResAvailable ? nil
            : "Needs LHDC. This Mac uses \(session.codec.flatMap { codecNames[$0] } ?? "another codec").")
      }
    }
  }
}

/// Draft for the open editor, kept outside the view so re-renders don't reset it.
@MainActor
@Observable
final class EditorDraft {
  var name: String
  var gains: [Int]
  private let presetID: Int
  private static var current: EditorDraft?

  private init(_ preset: Preset) {
    name = preset.name
    gains = preset.bands.map(\.gain)
    presetID = preset.id
  }

  static func shared(for preset: Preset) -> EditorDraft {
    if let current, current.presetID == preset.id, current.gains.count == preset.bands.count { return current }
    let draft = EditorDraft(preset)
    current = draft
    return draft
  }
  static func reset() { current = nil }
}

struct PresetPage: View {
  let session: BudsSession
  let model: PanelModel

  var body: some View {
    if let preset = model.editing {
      let draft = EditorDraft.shared(for: preset)
      let isNew = model.editingIsNew
      SubPage(title: isNew ? "New preset" : preset.name, model: model) {
        Tile(title: "Name") {
          TextField("Name", text: Binding(get: { draft.name }, set: { draft.name = String($0.prefix(16)) }))
            .textFieldStyle(.plain)
            .padding(.vertical, 9)
        }
        if !validPresetName(draft.name) {
          Text("Use 1 to 16 plain letters, numbers or spaces.").font(.caption).foregroundStyle(.orange)
        }
        Tile(title: "Bands") {
          HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(preset.bands.enumerated()), id: \.offset) { index, band in
              VStack(spacing: 6) {
                Text(signedText(draft.gains[index])).font(.caption.monospacedDigit())
                Slider(value: Binding(
                  get: { Double(draft.gains[index]) },
                  set: { draft.gains[index] = Int($0.rounded()) }
                ), in: Double(-eqGain)...Double(eqGain), step: 1)
                  .controlSize(.small)
                  .rotationEffect(.degrees(-90))
                  .frame(width: 130, height: 20)
                  .frame(width: 30, height: 130)
                Text(band.frequency >= 1000 ? "\(band.frequency / 1000)k" : "\(band.frequency)")
                  .font(.caption2).foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity)
            }
          }
          .padding(.vertical, 12)
          Button("Flat") { draft.gains = draft.gains.map { _ in 0 } }
            .buttonStyle(.plain).font(.caption).foregroundStyle(Color.accentColor).padding(.bottom, 10)
        }
        HStack {
          if !isNew {
            Button("Delete", role: .destructive) {
              model.back()
              Task { await session.deletePreset(preset) }
            }
            .foregroundStyle(.red)
          }
          Spacer()
          Button(isNew ? "Create" : "Save") {
            let edited = Preset(id: preset.id, name: draft.name,
              bands: zip(preset.bands, draft.gains).map { Band(frequency: $0.frequency, gain: $1) })
            model.back()
            Task { await session.savePreset(edited, isNew: isNew) }
          }
          .keyboardShortcut(.defaultAction)
          .disabled(!validPresetName(draft.name) || session.busy)
        }
        .controlSize(.regular)
      }
    }
  }
}

// MARK: Controls

struct ControlsPage: View {
  let session: BudsSession
  let model: PanelModel

  var body: some View {
    SubPage(title: "Controls", model: model) {
      ForEach(Ear.allCases, id: \.self) { ear in
        let actions = Gestures.order.filter { slot(ear, $0) != nil }
        Tile(title: "\(ear.title) earbud") {
          if actions.isEmpty {
            Text("No controls reported.").foregroundStyle(.secondary).padding(.vertical, 8)
          }
          ForEach(actions, id: \.self) { action in gestureRow(ear, action) }
        }
      }
      let calls = Gestures.callMenus.keys.sorted().filter { action in
        session.gestures.contains { $0.button == 6 && $0.action == action }
      }
      if !calls.isEmpty {
        Tile(title: "During calls") {
          ForEach(calls, id: \.self) { action in
            let current = session.gestures.first { $0.button == 6 && $0.action == action }?.function
            menuRow(Gestures.actions[action] ?? "Action \(action)", menu: Gestures.callMenus[action] ?? [], current: current) { fn in
              Task { await session.setCallGesture(action: action, function: fn) }
            }
            StatusLine(session: session, key: "call-\(action)")
          }
        }
      }
    }
  }

  private func slot(_ ear: Ear, _ action: UInt8) -> GestureSlot? {
    session.gestures.first { $0.device == ear.rawValue && $0.action == action && $0.button != 6 }
  }

  @ViewBuilder
  private func gestureRow(_ ear: Ear, _ action: UInt8) -> some View {
    let current = slot(ear, action)?.function
    menuRow(Gestures.actions[action] ?? "Action \(action)", menu: Gestures.menus[action] ?? [], current: current) { fn in
      Task { await session.setGesture(ear, action: action, function: fn) }
    }
    StatusLine(session: session, key: "gesture-\(ear.rawValue)-\(action)")
    if action == 4, current == 8, let modes = session.holdCycle {
      HoldCycleRow(session: session, modes: modes)
    }
  }

  private func menuRow(_ title: String, menu: [UInt8], current: UInt8?, set: @escaping @Sendable (UInt8) -> Void) -> some View {
    HStack {
      Text(title)
      Spacer()
      Picker(title, selection: Binding(get: { current ?? 0 }, set: set)) {
        if let current, !menu.contains(current) {
          Text(Gestures.functions[current] ?? "Unknown (\(current))").tag(current)
        }
        ForEach(menu, id: \.self) { fn in Text(Gestures.functions[fn] ?? "Function \(fn)").tag(fn) }
      }
      .pickerStyle(.menu)
      .labelsHidden()
      .fixedSize()
      .disabled(session.busy)
    }
    .padding(.vertical, 5)
  }
}

struct HoldCycleRow: View {
  let session: BudsSession
  let modes: Set<HoldMode>

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Cycles through, on both earbuds").font(.caption).foregroundStyle(.secondary)
      HStack(spacing: 6) {
        ForEach(HoldMode.allCases, id: \.self) { mode in
          let on = modes.contains(mode)
          Button {
            Task { await session.setHoldCycle(on ? modes.subtracting([mode]) : modes.union([mode])) }
          } label: {
            Text(mode == .anc ? "Noise canc." : mode.title)
              .font(.caption)
              .lineLimit(1)
              .padding(.horizontal, 8)
              .padding(.vertical, 5)
              .frame(maxWidth: .infinity)
              .background(Capsule().fill(on ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.07)))
              .foregroundStyle(on ? Color.accentColor : Color.primary)
          }
          .buttonStyle(.plain)
          .disabled(session.busy || (on && modes.count == 1))
        }
      }
      StatusLine(session: session, key: "holdCycle")
    }
    .padding(.bottom, 8)
  }
}

// MARK: Features

struct FeaturesPage: View {
  let session: BudsSession
  @Bindable var model: PanelModel
  let prefs: AppPrefs

  var body: some View {
    SubPage(title: "Features", model: model) {
      Tile(title: "Listening") {
        SwitchRow(session: session, item: .wearDetection, description: "Pause when you take an earbud out.")
        SwitchRow(session: session, item: .smartVolume, description: "Adjust volume to the noise around you.")
        SwitchRow(session: session, item: .gameMode, description: "Lower latency for games and video.")
        if session.promptVolume != nil {
          StepSlider(title: "Prompt volume", range: 1...10, value: session.promptVolume, draft: $model.promptDraft,
            format: { "\($0)" }, commit: { level in Task { await session.setPromptVolume(level) } }, disabled: session.busy)
          StatusLine(session: session, key: "promptVolume")
        }
      }
      Tile(title: "Connections") {
        SwitchRow(session: session, item: .dualConnection, description: "Stay connected to two devices.")
        ForEach(session.devices ?? []) { device in
          HStack(spacing: 10) {
            Image(systemName: device.thisDevice ? "laptopcomputer" : "iphone")
              .foregroundStyle(device.connected ? .primary : .tertiary)
              .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
              Text(device.name.isEmpty ? "Unnamed device" : device.name).lineLimit(1)
              Text([device.connected ? "Connected" : "Not connected", device.thisDevice ? "this Mac" : nil, device.playing ? "playing" : nil]
                .compactMap { $0 }.joined(separator: ", "))
                .font(.caption).foregroundStyle(.secondary)
            }
          }
          .padding(.vertical, 6)
        }
      }
      Tile(title: "This Mac") {
        ToggleRow(title: "Open at login", isOn: Binding(get: { prefs.openAtLogin }, set: { prefs.setOpenAtLogin($0) }))
        if let error = prefs.loginError {
          Text(error).font(.caption).foregroundStyle(.orange).padding(.bottom, 8)
        }
        ToggleRow(title: "Low battery alerts", subtitle: "Notify at 20% and 10%.",
          isOn: Binding(get: { prefs.batteryAlerts }, set: { prefs.batteryAlerts = $0 }))
        ToggleRow(title: "Show card on connect", isOn: Binding(get: { prefs.connectCard }, set: { prefs.connectCard = $0 }))
      }
    }
  }
}

// MARK: Tools

struct ToolsPage: View {
  let session: BudsSession
  let model: PanelModel

  var body: some View {
    SubPage(title: "Tools", model: model) {
      if session.supports(0x0400) {
        Tile {
          toolRow(icon: "dot.radiowaves.left.and.right", color: .red, title: "Find earbuds", description: "Play a sound from both earbuds.") {
            Button(model.ringing ? "Stop" : "Ring") {
              if model.ringing {
                Task { if await session.findEarbuds(false) { model.ringing = false } }
              } else {
                model.confirming = "find"
              }
            }
            .disabled(session.busy || model.confirming == "find")
          }
          if model.confirming == "find" {
            confirm("They will play a loud sound. Take them out of your ears first.", action: "Ring") {
              Task { if await session.findEarbuds(true) { model.ringing = true } }
            }
          }
          StatusLine(session: session, key: "find")
        }
      }
      if session.supports(0x0405) {
        Tile {
          toolRow(icon: "ear", color: .teal, title: "Fit test", description: fitText) {
            Button("Check") { model.confirming = "fit" }.disabled(session.busy || model.confirming == "fit")
          }
          if model.confirming == "fit" {
            confirm("Wear both earbuds. A short sound plays for about 10 seconds.", action: "Start") {
              Task { await session.fitTest() }
            }
          }
          StatusLine(session: session, key: "fit")
        }
      }
      if session.supports(0x040D) {
        Tile {
          toolRow(icon: "waveform.path.ecg", color: .yellow, title: "Hearing test",
            description: "Twelve short tones. The result becomes your Golden Sound profile.") {
            Button("Start") {
              HearingModel.shared.reset()
              model.open(.hearing)
            }
            .disabled(session.busy)
          }
          StatusLine(session: session, key: "hearing")
        }
      }
    }
  }

  private var fitText: String {
    guard let fit = session.fit else { return "Check that the ear tips seal well." }
    return "Left: \(fit.left ?? "not measured"). Right: \(fit.right ?? "not measured")."
  }

  private func toolRow(icon: String, color: Color, title: String, description: String, @ViewBuilder control: () -> some View) -> some View {
    HStack(alignment: .center, spacing: 10) {
      IconBadge(icon: icon, color: color)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        Text(description).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 8)
      control().controlSize(.small)
    }
    .padding(.vertical, 9)
  }

  private func confirm(_ text: String, action: String, run: @escaping () -> Void) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(text).font(.caption).fixedSize(horizontal: false, vertical: true)
      HStack {
        Spacer()
        Button("Cancel") { model.confirming = nil }
        Button(action) {
          model.confirming = nil
          run()
        }
        .keyboardShortcut(.defaultAction)
      }
      .controlSize(.small)
    }
    .padding(10)
    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.orange.opacity(0.12)))
    .padding(.bottom, 9)
  }
}

// MARK: Hearing test

@MainActor
@Observable
final class HearingModel {
  static let shared = HearingModel()
  var step = -1
  var levels = Array(repeating: hearingStart, count: 12)
  var starting = false
  var note: String?
  @ObservationIgnored var warned = false
  @ObservationIgnored var active = false
  @ObservationIgnored var timer: DispatchWorkItem?

  func reset() {
    step = -1
    levels = Array(repeating: hearingStart, count: 12)
    starting = false
    note = nil
    warned = false
    active = false
  }
}

struct HearingPage: View {
  let session: BudsSession
  let model: PanelModel
  let test: HearingModel

  var body: some View {
    SubPage(title: "Hearing test", model: model, onBack: { Task { await end() } }) {
      if test.step < 0 {
        Tile {
          VStack(alignment: .leading, spacing: 8) {
            Text("Sit somewhere quiet and wear both earbuds. For each tone, move the slider until you can only just hear it.")
              .fixedSize(horizontal: false, vertical: true)
            Text("Your earbuds keep one profile. Finishing replaces the current one.")
              .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
          }
          .padding(.vertical, 10)
        }
      } else {
        Tile {
          VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
              Text("\(test.step < 6 ? "Left ear" : "Right ear"), \(hearingFrequencies[test.step % 6])").font(.headline)
              Spacer()
              Text("\(test.step + 1) of 12").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 3) {
              ForEach(0..<12, id: \.self) { i in
                Capsule()
                  .fill(i < test.step ? Color.accentColor.opacity(0.55) : i == test.step ? Color.accentColor : Color.primary.opacity(0.1))
                  .frame(height: 4)
                  .padding(.leading, i == 6 ? 6 : 0)
              }
            }
            Slider(value: Binding(get: { Double(test.levels[test.step]) }, set: { slide(to: $0) }),
              in: 0...Double(hearingStops.count - 1), step: 1)
            HStack {
              Text("Quieter")
              Spacer()
              Text("Louder")
            }
            .font(.caption).foregroundStyle(.secondary)
          }
          .padding(.vertical, 12)
        }
      }
      if let note = session.hearingNote ?? test.note {
        Text(note).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
      }
      HStack {
        if test.step > 0 { Button("Back") { go(test.step - 1) } }
        Spacer()
        if test.step < 0 {
          Button(test.starting ? "Starting…" : "Start") { start() }.keyboardShortcut(.defaultAction).disabled(test.starting)
        } else if test.step < 11 {
          Button("Next") { go(test.step + 1) }.keyboardShortcut(.defaultAction)
        } else {
          Button("Finish and apply") { finish() }.keyboardShortcut(.defaultAction)
        }
      }
    }
  }

  private func slide(to value: Double) {
    let index = Int(value.rounded())
    guard index != test.levels[test.step] else { return }
    test.levels[test.step] = index
    test.timer?.cancel()
    let step = test.step
    let work = DispatchWorkItem { MainActor.assumeIsolated { play(step) } }
    test.timer = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
  }

  private func play(_ step: Int) {
    let level = test.levels[step]
    if level >= hearingLoud, !test.warned {
      test.warned = true
      test.note = "This level is loud. Lower it if it is uncomfortable."
    }
    Task { await session.playTone(step: step, level: level) }
  }

  private func start() {
    test.starting = true
    Task {
      do {
        try await session.startHearingTest()
        test.active = true
        test.note = nil
        test.step = 0
        play(0)
      } catch {
        test.note = error.localizedDescription
      }
      test.starting = false
    }
  }

  private func go(_ next: Int) {
    test.step = next
    play(next)
  }

  private func end() async {
    test.timer?.cancel()
    if test.active { await session.endHearingTest() }
    test.active = false
  }

  private func finish() {
    let levels = test.levels
    model.back()
    Task {
      await end()
      await session.applyHearing(levels: levels)
    }
  }
}
