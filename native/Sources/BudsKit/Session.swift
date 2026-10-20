import Foundation
import IOBluetooth
import Observation

/// Swift port of app/src/lib/session.ts: one request at a time, replies matched by sequence,
/// live pushes applied to state, and every change verified by reading it back.
@MainActor
@Observable
public final class BudsSession {
  public enum Connection: Equatable {
    case searching
    case connecting(String)
    case connected(String)
    case unavailable(String)
  }

  public private(set) var connection: Connection = .searching
  public private(set) var battery: [Part: BatteryLevel] = [:]
  public private(set) var wearing: [Part: WearState] = [:]
  public private(set) var firmware: String?
  public private(set) var noise: NoiseState?
  public private(set) var smartLevel: NoiseMode?
  public private(set) var eq: Int?
  public private(set) var customPresets: [Preset] = []
  public private(set) var busy = false
  public private(set) var lastError: String?

  public var isConnected: Bool { if case .connected = connection { true } else { false } }
  public var presets: [Preset] { Preset.builtIn + customPresets }
  /// Lowest earbud level, for the menu-bar icon.
  public var lowestBud: Int? { [battery[.left]?.percent, battery[.right]?.percent].compactMap { $0 }.min() }

  @ObservationIgnored private let link = RFCOMMLink()
  @ObservationIgnored private let watcher = DeviceWatcher()
  @ObservationIgnored private var device: IOBluetoothDevice?
  @ObservationIgnored private var framer = Framer()
  @ObservationIgnored private var caps: Capabilities?
  @ObservationIgnored private var sequence: UInt8 = 1
  @ObservationIgnored private var pending: [UInt32: CheckedContinuation<Bytes, Error>] = [:]
  @ObservationIgnored private var locked = false
  @ObservationIgnored private var lockWaiters: [CheckedContinuation<Void, Never>] = []
  @ObservationIgnored private var userDisconnected = false
  @ObservationIgnored private var connecting = false
  @ObservationIgnored private var batteryTimer: DispatchWorkItem?

  public init() {
    link.onData = { [weak self] bytes in self?.received(bytes) }
    link.onClose = { [weak self] in self?.closed(reason: "The earbuds disconnected.") }
    watcher.onConnect = { [weak self] device in
      guard let self, RFCOMMLink.candidates().contains(where: { $0.addressString == device.addressString }) else { return }
      // Give the buds a moment to bring up their services after the baseband connects.
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { MainActor.assumeIsolated { self.autoConnect() } }
    }
    watcher.onDisconnect = { [weak self] _ in self?.closed(reason: "The earbuds disconnected.") }
  }

  public func start() {
    watcher.start()
    autoConnect()
  }

  private func autoConnect() {
    guard !userDisconnected else { return }
    Task { await connect() }
  }

  public func connect() async {
    guard !isConnected, !connecting else { return }
    userDisconnected = false
    guard let target = RFCOMMLink.candidates().first(where: { $0.isConnected() }) else {
      connection = .unavailable("Your OnePlus Buds 4 aren’t connected to this Mac.")
      return
    }
    connecting = true
    defer { connecting = false }
    let name = target.name ?? "OnePlus Buds 4"
    connection = .connecting(name)
    lastError = nil
    do {
      guard let id = await link.channelID(on: target) else {
        throw BudsError.notOffered("The control service")
      }
      try await link.open(target, channel: id)
      device = target
      watcher.watchDisconnect(of: target)
      framer = Framer()
      try await Task.sleep(for: .milliseconds(300))
      caps = try decodeCapabilities(try await query(0x0100))
      let model = try decodeModel(try await query(0x0103))
      guard model == budsModel else { throw BudsError.unrecognized("model \(model); this app supports OnePlus Buds 4 only") }
      connection = .connected(name)
      await refresh()
      try? await subscribeEvents()
    } catch {
      link.close()
      failPending()
      connection = .unavailable(error.localizedDescription)
    }
  }

  public func disconnect() {
    userDisconnected = true
    link.close()
    closed(reason: "Disconnected. Click Connect to reconnect.")
  }

  private func closed(reason: String) {
    guard isConnected || connecting else { return }
    batteryTimer?.cancel()
    failPending()
    device = nil
    connection = .unavailable(reason)
  }

  private func failPending() {
    let waiting = pending
    pending = [:]
    waiting.values.forEach { $0.resume(throwing: BudsError.disconnected) }
  }

  // MARK: Requests

  private func lock() async {
    if !locked { locked = true; return }
    await withCheckedContinuation { lockWaiters.append($0) }
  }
  private func unlock() {
    if lockWaiters.isEmpty { locked = false } else { lockWaiters.removeFirst().resume() }
  }

  func query(_ command: UInt16, _ payload: Bytes = [], timeout: Double = 3.5) async throws -> Bytes {
    await lock()
    defer { unlock() }
    let seq = sequence
    sequence = seq == 254 ? 1 : seq + 1
    let bytes = try encode(command, seq, payload)
    let key = UInt32(command | 0x8000) << 8 | UInt32(seq)
    let reply = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bytes, Error>) in
      pending[key] = continuation
      do { try link.write(bytes) } catch {
        pending.removeValue(forKey: key)?.resume(throwing: error)
        return
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
        MainActor.assumeIsolated { self.pending.removeValue(forKey: key)?.resume(throwing: BudsError.timeout(command)) }
      }
    }
    try? await Task.sleep(for: .milliseconds(150))
    return reply
  }

  private func supports(_ command: UInt16) -> Bool { caps?.supports(command) ?? false }

  public func refresh() async {
    guard isConnected else { return }
    if let p = try? await query(0x0106), (try? requireSuccess(p, 2)) != nil, let b = decodeBattery(p, status: true) { battery = b }
    if supports(0x0105), let v = try? decodeFirmware(try await query(0x0105)) { firmware = v }
    if supports(0x0109), let p = try? await query(0x0109), let w = decodeWearing(p) { wearing = w }
    if supports(0x010C) {
      if let v = try? decodeNoise(try await query(0x010C, [1, 1])) { noise = v }
      if let v = try? decodeSmartLevel(try await query(0x010C, [4, 1])) { smartLevel = v }
    }
    if supports(0x010F), let v = try? decodeByte(try await query(0x010F)) { eq = v }
    if supports(0x0122), let v = try? decodeCustomPresets(try await query(0x0122)) { customPresets = v }
  }

  private func subscribeEvents() async throws {
    let p = try await query(0x0200)
    try requireSuccess(p, 2)
    guard p.count == Int(p[1]) + 2 else { return }
    let ids = [UInt8](arrayLiteral: 1, 2, 3).filter { p[2...].contains($0) }
    if !ids.isEmpty, supports(0x0205) { _ = try await query(0x0205, [UInt8(ids.count)] + ids) }
  }

  // MARK: Incoming

  private func received(_ bytes: Bytes) {
    for frame in framer.push(bytes) { handle(frame) }
  }

  private func handle(_ frame: Frame) {
    if let continuation = pending.removeValue(forKey: UInt32(frame.command) << 8 | UInt32(frame.sequence)) {
      continuation.resume(returning: frame.payload)
      return
    }
    let p = frame.payload
    switch frame.command {
    case 0x0204 where p.first == 1:
      if let b = decodeBattery(Array(p.dropFirst()), status: false) { battery.merge(b) { $1 } }
    case 0x0204 where p.first == 2:
      guard let w = decodeWearing(Array(p.dropFirst())) else { return }
      let wasVisible = caseVisible(wearing)
      wearing.merge(w) { $1 }
      // The case reports battery only with its lid open, and opening it does not always push a battery event.
      if caseVisible(wearing) && !wasVisible { rereadBatterySoon() }
    case 0x0204 where p.first == 3 && p.count >= 4:
      let status: Bytes = [0] + p.dropFirst()
      if p[1] == 1, p[2] == 1, let v = try? decodeNoise(status) { noise = v }
      if p[1] == 4, p[2] == 1, let v = try? decodeSmartLevel(status) { smartLevel = v }
    case 0x0504 where p.count == 1:
      eq = Int(p[0])
    case 0x0500:
      // The buds ask for the time; HeyMelody answers 00 <unix seconds u32 LE>.
      let now = UInt32(Date().timeIntervalSince1970)
      if let bytes = try? encode(0x8500, frame.sequence, [0] + (0..<4).map { UInt8(now >> (8 * $0) & 0xFF) }) { try? link.write(bytes) }
    default:
      break
    }
  }

  private func caseVisible(_ w: [Part: WearState]) -> Bool {
    w[.chargingCase]?.lidOpen == true || [Part.left, .right].contains { w[$0]?.inCase == true && w[$0]?.lidOpen == true }
  }

  private func rereadBatterySoon() {
    batteryTimer?.cancel()
    let work = DispatchWorkItem { [weak self] in
      MainActor.assumeIsolated {
        guard let self, self.isConnected else { return }
        Task {
          if let p = try? await self.query(0x0106), let b = decodeBattery(p, status: true) { self.battery = b }
        }
      }
    }
    batteryTimer = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
  }

  // MARK: Changes

  private func change(_ name: String, _ command: UInt16, _ payload: Bytes, verify: () async throws -> Bool) async {
    guard isConnected, !busy else { return }
    guard supports(command) else { lastError = BudsError.notOffered(name).localizedDescription; return }
    busy = true
    lastError = nil
    defer { busy = false }
    do {
      try acknowledged(command, try await query(command, payload))
      // An acknowledgement alone does not prove a write took.
      guard try await verify() else { throw BudsError.unverified(name) }
    } catch {
      lastError = error.localizedDescription
    }
  }

  public func setNoise(_ mode: NoiseMode) async {
    await change("Noise control", 0x0404, noisePayload(mode)) {
      let state = try decodeNoise(try await query(0x010C, [1, 1]))
      noise = state
      if mode == .smart || mode == .anc { smartLevel = try? decodeSmartLevel(try await query(0x010C, [4, 1])) }
      return mode.reports.contains(state.raw)
    }
  }

  public func setEq(_ id: Int) async {
    await change("Equalizer", 0x0406, [UInt8(id)]) {
      let value = try decodeByte(try await query(0x010F))
      eq = value
      return value == id
    }
  }
}
