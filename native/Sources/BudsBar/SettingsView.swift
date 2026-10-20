import AppKit
import BudsKit
import Observation
import SwiftUI

// View-local state lives here: SwiftUI's @State is a macro, which needs Xcode.
@MainActor
@Observable
final class SettingsModel {
  var editing: Preset?
  var editingIsNew = false
  var hearingOpen = false
  var confirmRing = false
  var confirmFit = false
  var ringing = false
  var bassDraft: Double?
  var promptDraft: Double?
}

@MainActor let settingsModel = SettingsModel()

struct SettingsView: View {
  let session: BudsSession

  var body: some View {
    Group {
      if session.isConnected {
        TabView {
          SoundTab(session: session, model: settingsModel).tabItem { Label("Sound", systemImage: "waveform") }
          ControlsTab(session: session).tabItem { Label("Controls", systemImage: "hand.tap") }
          FeaturesTab(session: session, model: settingsModel).tabItem { Label("Features", systemImage: "switch.2") }
          ToolsTab(session: session, model: settingsModel).tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
          AboutTab(session: session).tabItem { Label("About", systemImage: "info.circle") }
        }
      } else {
        VStack(spacing: 12) {
          Image(systemName: "earbuds").font(.system(size: 36)).foregroundStyle(.secondary)
          Text(disconnectedText).foregroundStyle(.secondary).multilineTextAlignment(.center)
          if case .unavailable = session.connection {
            Button("Connect") { Task { await session.connect() } }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
      }
    }
    .frame(minWidth: 520, idealWidth: 540, minHeight: 520, idealHeight: 620)
  }

  private var disconnectedText: String {
    switch session.connection {
    case .connecting: "Connecting…"
    case .searching: "Looking for your earbuds…"
    case .unavailable(let message): message
    case .connected: ""
    }
  }
}

// MARK: Shared pieces

struct StatusLine: View {
  let session: BudsSession
  let key: String

  var body: some View {
    switch session.status[key] {
    case .pending:
      HStack(spacing: 6) {
        ProgressView().controlSize(.small)
        Text("Waiting for the earbuds…")
      }
      .font(.caption).foregroundStyle(.secondary)
    case .done(let text):
      Label(text ?? "Confirmed", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
    case .failed(let message):
      Label(message, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
    case nil:
      EmptyView()
    }
  }
}

struct SwitchRow: View {
  let session: BudsSession
  let item: Switch
  var description: String?
  var unavailable: String?

  var body: some View {
    if session.isOn(item) != nil {
      VStack(alignment: .leading, spacing: 4) {
        Toggle(isOn: Binding(
          get: { session.isOn(item) ?? false },
          set: { on in Task { await session.setSwitch(item, on) } }
        )) {
          VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
            if let text = unavailable ?? description {
              Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
          }
        }
        .toggleStyle(.switch)
        .disabled(session.busy || (unavailable != nil && session.isOn(item) != true))
        StatusLine(session: session, key: "switch-\(item.rawValue)")
      }
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
    LabeledContent(title) {
      HStack {
        Slider(
          value: Binding(get: { shown }, set: { draft.wrappedValue = $0 }),
          in: range, step: 1
        ) { editing in
          guard !editing, let picked = draft.wrappedValue else { return }
          draft.wrappedValue = nil
          if Int(picked) != value { commit(Int(picked)) }
        }
        .frame(minWidth: 160)
        Text(format(Int(shown))).monospacedDigit().frame(width: 32, alignment: .trailing)
      }
    }
    .disabled(disabled || value == nil)
  }
}

// MARK: Sound

struct SoundTab: View {
  let session: BudsSession
  @Bindable var model: SettingsModel

  var body: some View {
    Form {
      Section {
        NoiseControl(session: session)
        StatusLine(session: session, key: "noise")
      }
      Section("Equalizer") {
        Picker("Preset", selection: Binding(
          get: { session.eq ?? -1 },
          set: { id in Task { await session.setEq(id) } }
        )) {
          if session.eq == nil || !session.presets.contains(where: { $0.id == session.eq }) {
            Text("Unknown").tag(session.eq ?? -1)
          }
          ForEach(session.presets) { preset in Text(preset.name).tag(preset.id) }
        }
        .disabled(session.busy)
        StatusLine(session: session, key: "eq")
        ForEach(session.customPresets) { preset in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(preset.name)
              Text(preset.bands.map { $0.gain > 0 ? "+\($0.gain)" : "\($0.gain)" }.joined(separator: "  "))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit") {
              EditorDraft.reset()
              model.editingIsNew = false
              model.editing = preset
            }
          }
        }
        if session.supports(0x0418) {
          HStack {
            Button("New preset…") {
              EditorDraft.reset()
              model.editingIsNew = true
              model.editing = Preset(id: 0, name: "Custom \(session.customPresets.count + 1)",
                bands: eqBands.map { Band(frequency: $0, gain: 0) })
            }
            .disabled(session.busy || session.customPresets.count >= eqMaxCustom)
            if session.customPresets.count >= eqMaxCustom {
              Text("The earbuds hold up to \(eqMaxCustom) custom presets.").font(.caption).foregroundStyle(.secondary)
            }
          }
          StatusLine(session: session, key: "preset")
        }
      }
      Section("Enhancements") {
        SwitchRow(session: session, item: .bassWave, description: "Extra bass from the dynamic driver.")
        if session.isOn(.bassWave) == true, session.bass != nil {
          StepSlider(title: "Strength", range: -5...5, value: session.bass, draft: $model.bassDraft,
            format: { $0 > 0 ? "+\($0)" : "\($0)" }, commit: { level in Task { await session.setBass(level) } },
            disabled: session.busy)
          StatusLine(session: session, key: "bass")
        }
        SwitchRow(session: session, item: .goldenSound,
          description: session.golden.map { "Profile from \($0.name)." } ?? "Take the hearing test in Tools to create a profile.")
        SwitchRow(session: session, item: .spatial, description: "Spatial audio.")
        SwitchRow(session: session, item: .hiRes,
          unavailable: session.hiResAvailable ? nil
            : "Needs the LHDC codec. This Mac connects with \(session.codec.flatMap { codecNames[$0] } ?? "another codec"), which the earbuds refuse.")
      }
    }
    .formStyle(.grouped)
    .sheet(item: $model.editing) { preset in
      PresetEditor(session: session, model: model, preset: preset, isNew: model.editingIsNew)
    }
  }
}

struct PresetEditor: View {
  let session: BudsSession
  let model: SettingsModel
  let preset: Preset
  let isNew: Bool
  private let draft: EditorDraft

  init(session: BudsSession, model: SettingsModel, preset: Preset, isNew: Bool) {
    self.session = session
    self.model = model
    self.preset = preset
    self.isNew = isNew
    draft = EditorDraft.shared(for: preset)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(isNew ? "New preset" : "Edit \(preset.name)").font(.headline)
      TextField("Name", text: Binding(get: { draft.name }, set: { draft.name = String($0.prefix(16)) }))
      HStack(alignment: .bottom, spacing: 18) {
        ForEach(Array(preset.bands.enumerated()), id: \.offset) { index, band in
          VStack(spacing: 6) {
            Text(draft.gains[index] > 0 ? "+\(draft.gains[index])" : "\(draft.gains[index])").font(.caption.monospacedDigit())
            Slider(value: Binding(
              get: { Double(draft.gains[index]) },
              set: { draft.gains[index] = Int($0.rounded()) }
            ), in: Double(-eqGain)...Double(eqGain), step: 1)
              .rotationEffect(.degrees(-90))
              .frame(width: 140, height: 24)
              .frame(width: 30, height: 140)
            Text(band.frequency >= 1000 ? "\(band.frequency / 1000)k" : "\(band.frequency)")
              .font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      .frame(maxWidth: .infinity)
      if !validPresetName(draft.name) {
        Text("Use 1 to 16 plain letters, numbers or spaces.").font(.caption).foregroundStyle(.orange)
      }
      HStack {
        if !isNew {
          Button("Delete", role: .destructive) {
            model.editing = nil
            Task { await session.deletePreset(preset) }
          }
        }
        Spacer()
        Button("Cancel") { model.editing = nil }.keyboardShortcut(.cancelAction)
        Button(isNew ? "Create" : "Save") {
          let edited = Preset(id: preset.id, name: draft.name,
            bands: zip(preset.bands, draft.gains).map { Band(frequency: $0.frequency, gain: $1) })
          model.editing = nil
          Task { await session.savePreset(edited, isNew: isNew) }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!validPresetName(draft.name) || session.busy)
      }
    }
    .padding(20)
    .frame(width: 420)
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

// MARK: Controls

struct ControlsTab: View {
  let session: BudsSession

  var body: some View {
    Form {
      ForEach(Ear.allCases, id: \.self) { ear in
        Section("\(ear.title) earbud") {
          let actions = Gestures.order.filter { slot(ear, $0) != nil }
          if actions.isEmpty { Text("No controls reported for this earbud.").foregroundStyle(.secondary) }
          ForEach(actions, id: \.self) { action in
            gestureRow(ear, action)
          }
        }
      }
      let calls = Gestures.callMenus.keys.sorted().filter { action in
        session.gestures.contains { $0.button == 6 && $0.action == action }
      }
      if !calls.isEmpty {
        Section("During calls") {
          ForEach(calls, id: \.self) { action in
            VStack(alignment: .leading, spacing: 4) {
              Picker(Gestures.actions[action] ?? "Action \(action)", selection: Binding(
                get: { session.gestures.first { $0.button == 6 && $0.action == action }?.function ?? 0 },
                set: { fn in Task { await session.setCallGesture(action: action, function: fn) } }
              )) {
                functionOptions(Gestures.callMenus[action] ?? [],
                  current: session.gestures.first { $0.button == 6 && $0.action == action }?.function)
              }
              .disabled(session.busy)
              StatusLine(session: session, key: "call-\(action)")
            }
          }
        }
      }
    }
    .formStyle(.grouped)
  }

  private func slot(_ ear: Ear, _ action: UInt8) -> GestureSlot? {
    session.gestures.first { $0.device == ear.rawValue && $0.action == action && $0.button != 6 }
  }

  @ViewBuilder
  private func gestureRow(_ ear: Ear, _ action: UInt8) -> some View {
    let current = slot(ear, action)?.function
    VStack(alignment: .leading, spacing: 6) {
      Picker(Gestures.actions[action] ?? "Action \(action)", selection: Binding(
        get: { current ?? 0 },
        set: { fn in Task { await session.setGesture(ear, action: action, function: fn) } }
      )) {
        functionOptions(Gestures.menus[action] ?? [], current: current)
      }
      .disabled(session.busy)
      StatusLine(session: session, key: "gesture-\(ear.rawValue)-\(action)")
      if action == 4, current == 8, let modes = session.holdCycle {
        HoldCycleRow(session: session, modes: modes)
      }
    }
  }

  @ViewBuilder
  private func functionOptions(_ menu: [UInt8], current: UInt8?) -> some View {
    if let current, !menu.contains(current) {
      Text(Gestures.functions[current] ?? "Unknown (\(current))").tag(current)
    }
    ForEach(menu, id: \.self) { fn in Text(Gestures.functions[fn] ?? "Function \(fn)").tag(fn) }
  }
}

struct HoldCycleRow: View {
  let session: BudsSession
  let modes: Set<HoldMode>

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Modes to cycle through, on both earbuds").font(.caption).foregroundStyle(.secondary)
      HStack {
        ForEach(HoldMode.allCases, id: \.self) { mode in
          let on = modes.contains(mode)
          Toggle(mode.title, isOn: Binding(
            get: { on },
            set: { want in
              Task { await session.setHoldCycle(want ? modes.union([mode]) : modes.subtracting([mode])) }
            }
          ))
          .toggleStyle(.button)
          .disabled(session.busy || (on && modes.count == 1))
        }
      }
      StatusLine(session: session, key: "holdCycle")
    }
    .padding(.leading, 4)
  }
}

// MARK: Features

struct FeaturesTab: View {
  let session: BudsSession
  @Bindable var model: SettingsModel

  var body: some View {
    Form {
      Section("Listening") {
        SwitchRow(session: session, item: .wearDetection, description: "Pause when you take an earbud out.")
        SwitchRow(session: session, item: .smartVolume, description: "Adjust volume to the noise around you.")
        SwitchRow(session: session, item: .gameMode, description: "Lower latency, for games and video.")
        if session.promptVolume != nil {
          StepSlider(title: "Prompt volume", range: 1...10, value: session.promptVolume, draft: $model.promptDraft,
            format: { "\($0)" }, commit: { level in Task { await session.setPromptVolume(level) } }, disabled: session.busy)
          Text("Each change plays a prompt in your ears.").font(.caption).foregroundStyle(.secondary)
          StatusLine(session: session, key: "promptVolume")
        }
      }
      Section("Connections") {
        SwitchRow(session: session, item: .dualConnection, description: "Stay connected to two devices at once.")
        if let devices = session.devices, !devices.isEmpty {
          ForEach(devices) { device in
            HStack {
              Image(systemName: device.thisDevice ? "laptopcomputer" : "iphone")
                .foregroundStyle(device.connected ? .primary : .tertiary)
                .frame(width: 20)
              Text(device.name.isEmpty ? "Unnamed device" : device.name)
              if device.thisDevice { Text("This Mac").font(.caption).foregroundStyle(.secondary) }
              Spacer()
              if device.playing { Image(systemName: "speaker.wave.2.fill").foregroundStyle(.secondary) }
              Text(device.connected ? "Connected" : "Not connected").font(.caption).foregroundStyle(.secondary)
            }
          }
        }
      }
    }
    .formStyle(.grouped)
  }
}

// MARK: Tools

struct ToolsTab: View {
  let session: BudsSession
  @Bindable var model: SettingsModel

  var body: some View {
    Form {
      if session.supports(0x0400) {
        Section {
          toolRow("Find earbuds", "Play a sound from both earbuds to find them.", key: "find") {
            Button(model.ringing ? "Stop ringing" : "Ring") {
              if model.ringing {
                Task { if await session.findEarbuds(false) { model.ringing = false } }
              } else {
                model.confirmRing = true
              }
            }
            .tint(model.ringing ? .red : nil)
            .disabled(session.busy)
          }
        }
      }
      if session.supports(0x0405) {
        Section {
          toolRow("Fit test", fitText, key: "fit") {
            Button("Check fit") { model.confirmFit = true }.disabled(session.busy)
          }
        }
      }
      if session.supports(0x040D) {
        Section {
          toolRow("Hearing test", "Twelve short tones, six per ear. The result becomes your Golden Sound profile.", key: "hearing") {
            Button("Start test") {
              HearingModel.shared.reset()
              model.hearingOpen = true
            }
            .disabled(session.busy)
          }
        }
      }
    }
    .formStyle(.grouped)
    .confirmationDialog("Ring your earbuds?", isPresented: $model.confirmRing) {
      Button("Ring") { Task { if await session.findEarbuds(true) { model.ringing = true } } }
    } message: {
      Text("They will play a loud sound. Take them out of your ears first.")
    }
    .confirmationDialog("Check the fit?", isPresented: $model.confirmFit) {
      Button("Start") { Task { await session.fitTest() } }
    } message: {
      Text("Wear both earbuds. A short sound plays while the seal is measured, for about 10 seconds.")
    }
    .sheet(isPresented: $model.hearingOpen) {
      HearingTestView(session: session, test: HearingModel.shared, model: model)
    }
  }

  private var fitText: String {
    guard let fit = session.fit else { return "Check that the ear tips seal well." }
    return "Last result. Left: \(fit.left ?? "not measured"). Right: \(fit.right ?? "not measured")."
  }

  private func toolRow(_ title: String, _ description: String, key: String, @ViewBuilder control: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
          Text(description).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        control()
      }
      StatusLine(session: session, key: key)
    }
  }
}

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

struct HearingTestView: View {
  let session: BudsSession
  let test: HearingModel
  let model: SettingsModel

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Hearing test").font(.headline)
      if test.step < 0 {
        Text("Sit somewhere quiet and wear both earbuds. For each tone, move the slider until you can only just hear it.")
          .fixedSize(horizontal: false, vertical: true)
        Text("Your earbuds keep one profile. Finishing replaces the current one.")
          .font(.callout).foregroundStyle(.secondary)
      } else {
        HStack(alignment: .firstTextBaseline) {
          Text("\(test.step < 6 ? "Left ear" : "Right ear"), \(hearingFrequencies[test.step % 6])")
          Spacer()
          Text("\(test.step + 1) of 12").monospacedDigit().foregroundStyle(.secondary)
        }
        HStack(spacing: 3) {
          ForEach(0..<12, id: \.self) { i in
            Capsule()
              .fill(i < test.step ? Color.accentColor.opacity(0.6) : i == test.step ? Color.accentColor : Color.primary.opacity(0.1))
              .frame(height: 4)
              .padding(.leading, i == 6 ? 6 : 0)
          }
        }
        VStack(spacing: 4) {
          Slider(value: Binding(
            get: { Double(test.levels[test.step]) },
            set: { value in
              let index = Int(value.rounded())
              guard index != test.levels[test.step] else { return }
              test.levels[test.step] = index
              test.timer?.cancel()
              let step = test.step
              let work = DispatchWorkItem { MainActor.assumeIsolated { play(step) } }
              test.timer = work
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
            }
          ), in: 0...Double(hearingStops.count - 1), step: 1)
          HStack {
            Text("Quieter")
            Spacer()
            Text("Louder")
          }
          .font(.caption).foregroundStyle(.secondary)
        }
      }
      Text(session.hearingNote ?? test.note ?? " ").font(.callout).foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
      HStack {
        Button("Cancel") { close() }.keyboardShortcut(.cancelAction)
        Spacer()
        if test.step > 0 { Button("Back") { go(test.step - 1) } }
        if test.step < 0 {
          Button(test.starting ? "Starting…" : "Start") { start() }
            .keyboardShortcut(.defaultAction).disabled(test.starting)
        } else if test.step < 11 {
          Button("Next") { go(test.step + 1) }.keyboardShortcut(.defaultAction)
        } else {
          Button("Finish and apply") { finish() }.keyboardShortcut(.defaultAction)
        }
      }
    }
    .padding(20)
    .frame(width: 440)
    .onChange(of: session.isConnected) { _, connected in if !connected { model.hearingOpen = false } }
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

  private func close() {
    model.hearingOpen = false
    Task { await end() }
  }

  private func finish() {
    let levels = test.levels
    model.hearingOpen = false
    Task {
      await end()
      await session.applyHearing(levels: levels)
    }
  }
}

// MARK: About

struct AboutTab: View {
  let session: BudsSession

  var body: some View {
    Form {
      Section {
        LabeledContent("Model", value: "OnePlus Buds 4")
        LabeledContent("Firmware", value: session.firmware ?? "–")
        LabeledContent("Codec", value: session.codec.flatMap { codecNames[$0] } ?? "–")
        if let updated = session.updatedAt {
          LabeledContent("Last read", value: updated.formatted(date: .omitted, time: .shortened))
        }
      }
      Section {
        Button("Read everything again") { Task { await session.refresh() } }.disabled(session.busy)
      }
    }
    .formStyle(.grouped)
  }
}
