// Link proof: open the Buds 4 control channel over RFCOMM, read identity and battery, print live events.
import Foundation
import IOBluetooth

let serviceUUID: [UInt8] = [
  0x00, 0x00, 0x07, 0x9A, 0xD1, 0x02, 0x11, 0xE1, 0x9B, 0x23, 0x00, 0x02, 0x5B, 0x00, 0xA5, 0xA5,
]
let model = "065414"
let listenSeconds = 60.0

func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined(separator: " ") }
func log(_ text: String) {
  let time = Date().formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute().second())
  print("[\(time)] \(text)")
  fflush(stdout)
}

// Frame: AA <LEB128 length> 00 00 <cmd LE> <seq> <payload length LE> <payload>; replies set cmd | 0x8000.
func encode(_ command: UInt16, _ sequence: UInt8, _ payload: [UInt8]) -> [UInt8] {
  var size = 7 + payload.count
  var length: [UInt8] = []
  repeat {
    var byte = UInt8(size & 127)
    size >>= 7
    if size > 0 { byte |= 128 }
    length.append(byte)
  } while size > 0
  return [0xAA] + length + [0, 0, UInt8(command & 0xFF), UInt8(command >> 8), sequence,
    UInt8(payload.count & 0xFF), UInt8(payload.count >> 8)] + payload
}

struct Frame { let command: UInt16; let sequence: UInt8; let payload: [UInt8] }

struct Framer {
  private var buffer: [UInt8] = []
  mutating func push(_ chunk: [UInt8]) -> [Frame] {
    buffer += chunk
    var frames: [Frame] = []
    while !buffer.isEmpty {
      if buffer[0] != 0xAA { buffer.removeFirst(); continue }
      var size = 0, count = 0, complete = false
      var i = 1
      while i < buffer.count && i <= 3 {
        size += Int(buffer[i] & 127) << (7 * count)
        count += 1
        if buffer[i] & 128 == 0 { complete = true; break }
        i += 1
      }
      if !complete { if buffer.count >= 4 { buffer.removeFirst(); continue } else { break } }
      if size < 7 || size > 8192 { buffer.removeFirst(); continue }
      let prefix = 1 + count, total = prefix + size
      if buffer.count < total { break }
      let bytes = Array(buffer[0..<total])
      buffer.removeFirst(total)
      let n = Int(bytes[prefix + 5]) | Int(bytes[prefix + 6]) << 8
      guard bytes[prefix] == 0, bytes[prefix + 1] == 0, n == size - 7 else { continue }
      frames.append(Frame(
        command: UInt16(bytes[prefix + 2]) | UInt16(bytes[prefix + 3]) << 8,
        sequence: bytes[prefix + 4],
        payload: Array(bytes[(prefix + 7)...])))
    }
    return frames
  }
}

// <count> (<id> <value>)*, optionally after a status byte; ids 1 left, 2 right, 3 case.
func pairs(_ p: [UInt8], status: Bool) -> [(String, UInt8)]? {
  for offset in status ? [1] : [0, 1] {
    if offset == 1 && p.first != 0 { continue }
    guard p.count > offset else { continue }
    let count = Int(p[offset])
    guard count <= 3, p.count == offset + 1 + 2 * count else { continue }
    return (0..<count).compactMap { i in
      let id = p[offset + 1 + i * 2], value = p[offset + 2 + i * 2]
      guard (1...3).contains(id) else { return nil }
      return (["left", "right", "case"][Int(id) - 1], value)
    }
  }
  return nil
}
func battery(_ p: [UInt8], status: Bool) -> String {
  guard let list = pairs(p, status: status) else { return "unrecognized \(hex(p))" }
  return list.map { side, v in "\(side) \(v & 127)%\(v & 128 != 0 ? " charging" : "")" }.joined(separator: ", ")
}
func wearing(_ p: [UInt8]) -> String {
  guard let list = pairs(p, status: false) else { return "unrecognized \(hex(p))" }
  return list.map { side, v in
    side == "case" ? "case lid \(v & 4 != 0 ? "open" : "closed")"
      : "\(side) \(v & 2 != 0 ? "in ear" : v & 1 == 0 ? "in case" : "out of ear")"
  }.joined(separator: ", ")
}
func firmware(_ p: [UInt8]) -> String {
  guard p.count > 2, p[0] == 0 else { return "unrecognized \(hex(p))" }
  let parts = String(decoding: p[2...], as: UTF8.self).split(separator: ",", omittingEmptySubsequences: false)
  guard parts.count % 3 == 0 else { return "unrecognized \(hex(p))" }
  return stride(from: 0, to: parts.count, by: 3)
    .filter { parts[$0 + 1].trimmingCharacters(in: .whitespaces) == "2" }
    .map { parts[$0 + 2].trimmingCharacters(in: .whitespaces) }.joined(separator: ".")
}
let noiseNames: [Int: String] = [
  8: "off", 2: "noise cancelling", 16: "noise cancelling, deep", 32: "noise cancelling, medium",
  64: "noise cancelling, light", 128: "noise cancelling, smart", 256: "transparency",
  512: "voice transparency", 2048: "adaptive",
]
func noise(_ p: [UInt8]) -> String {
  guard p.count >= 4, p[0] == 0, p[1] == 1, p[2] == 1 else { return "unrecognized \(hex(p))" }
  let raw = p[3...].enumerated().reduce(0) { $0 | Int($1.element) << (8 * $1.offset) }
  return noiseNames[raw] ?? "unrecognized mode \(raw)"
}

struct Request { let label: String; let command: UInt16; let payload: [UInt8]; let decode: ([UInt8]) -> String }

@MainActor
final class Probe: NSObject {
  private var channel: IOBluetoothRFCOMMChannel?
  private var device: IOBluetoothDevice?
  private var framer = Framer()
  private var sequence: UInt8 = 1
  private var queue: [Request] = []
  private var waiting: (key: UInt32, request: Request, timeout: DispatchWorkItem)?
  private var sdpTried = false

  private lazy var uuid: IOBluetoothSDPUUID = serviceUUID.withUnsafeBytes {
    IOBluetoothSDPUUID(bytes: $0.baseAddress, length: 16)
  }

  func start() {
    let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
    log("Paired devices: " + (paired.isEmpty ? "none (is Bluetooth on, and does this terminal have Bluetooth permission?)"
      : paired.map { "\($0.name ?? "unnamed")\($0.isConnected() ? " (connected)" : "")" }.joined(separator: ", ")))
    if CommandLine.arguments.contains("--fresh"), !sdpTried,
      let buds = paired.first(where: { $0.isConnected() && ($0.name ?? "").contains("OnePlus Buds") })
    {
      sdpTried = true
      log("Asking \(buds.name ?? "the earbuds") for a fresh service list…")
      buds.performSDPQuery(self)
      return
    }
    for candidate in paired {
      if let record = candidate.getServiceRecord(for: uuid) {
        var id: BluetoothRFCOMMChannelID = 0
        if record.getRFCOMMChannelID(&id) == kIOReturnSuccess { return open(candidate, channel: id) }
      }
    }
    // Service records may not be cached yet; ask connected buds for them once.
    let buds = paired.filter { $0.isConnected() && ($0.name ?? "").localizedCaseInsensitiveContains("buds") }
    guard !sdpTried, !buds.isEmpty else {
      return finish("No paired device offers the Buds control service. Connect the earbuds to this Mac first.", code: 1)
    }
    sdpTried = true
    log("Service record not cached; querying \(buds.map { $0.name ?? "?" }.joined(separator: ", "))…")
    for d in buds { d.performSDPQuery(self) }
  }

  private func open(_ target: IOBluetoothDevice, channel found: BluetoothRFCOMMChannelID) {
    let override = CommandLine.arguments.firstIndex(of: "--channel").flatMap { i in
      CommandLine.arguments.indices.contains(i + 1) ? BluetoothRFCOMMChannelID(CommandLine.arguments[i + 1]) : nil
    }
    let id = override ?? found
    device = target
    log("Opening RFCOMM channel \(id) on \(target.name ?? "earbuds")…")
    var opened: IOBluetoothRFCOMMChannel?
    if CommandLine.arguments.contains("--sync") {
      let status = target.openRFCOMMChannelSync(&opened, withChannelID: id, delegate: self)
      log("Blocking open returned \(String(format: "0x%08x", status)), channel open: \(opened?.isOpen() ?? false)")
      channel = opened
      if status == kIOReturnSuccess { connected() } else { finish("Blocking open failed.", code: 1) }
      return
    }
    let status = target.openRFCOMMChannelAsync(&opened, withChannelID: id, delegate: self)
    guard status == kIOReturnSuccess else {
      return finish("Could not open the channel (\(String(format: "0x%08x", status))). Is Chrome connected to the earbuds? Disconnect it first.", code: 1)
    }
    channel = opened
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
      MainActor.assumeIsolated {
        if !self.isOpen {
          log("Channel state: open \(self.channel?.isOpen() ?? false), MTU \(self.channel?.getMTU() ?? 0), baseband connected \(target.isConnected())")
          self.finish("The channel did not open within 10 s. Run this as an app bundle (scripts/run-probe.sh), not as a bare binary, and make sure no Chrome tab is connected to the earbuds.", code: 1)
        }
      }
    }
  }
  private var isOpen = false

  private func connected() {
    isOpen = true
    log("Connected.")
    if CommandLine.arguments.contains("--channel") { return finish("Opened the test channel; closing without sending anything.", code: 0) }
    queue = [
      Request(label: "Capabilities", command: 0x0100, payload: []) { $0.first == 0 ? hex(Array($0.dropFirst())) : "declined \(hex($0))" },
      Request(label: "Model", command: 0x0103, payload: []) { p in
        guard p.count == 4, p[0] == 0 else { return "unrecognized \(hex(p))" }
        let m = String(format: "%06x", Int(p[1]) | Int(p[2]) << 8 | Int(p[3]) << 16)
        return m == model ? "\(m) (OnePlus Buds 4)" : "\(m) (not Buds 4)"
      },
      Request(label: "Firmware", command: 0x0105, payload: [], decode: firmware),
      Request(label: "Battery", command: 0x0106, payload: []) { battery($0, status: true) },
      Request(label: "Wearing", command: 0x0109, payload: [], decode: wearing),
      Request(label: "Noise mode", command: 0x010C, payload: [1, 1], decode: noise),
      // Reply grammar is only partly known (seen: 01 03 01 00 02 00 03 00); live events arriving is the real check.
      Request(label: "Subscribe to battery, wearing, noise", command: 0x0205, payload: [3, 1, 2, 3]) { "acknowledged (\(hex($0)))" },
    ]
    next()
  }

  private func next() {
    guard waiting == nil else { return }
    guard !queue.isEmpty else {
      log("Listening for live events for \(Int(listenSeconds)) s. Take a bud out, put it back, or change noise mode. Ctrl-C to stop.")
      DispatchQueue.main.asyncAfter(deadline: .now() + listenSeconds) {
        MainActor.assumeIsolated { self.finish("Done. The native link works.", code: 0) }
      }
      return
    }
    let request = queue.removeFirst()
    let seq = sequence
    sequence = seq == 254 ? 1 : seq + 1
    let timeout = DispatchWorkItem {
      MainActor.assumeIsolated {
        log("\(request.label): no reply")
        self.waiting = nil
        self.next()
      }
    }
    waiting = (UInt32(request.command | 0x8000) << 8 | UInt32(seq), request, timeout)
    write(encode(request.command, seq, request.payload))
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: timeout)
  }

  private func write(_ bytes: [UInt8]) {
    guard let channel else { return }
    var data = bytes
    let status = channel.writeSync(&data, length: UInt16(data.count))
    if status != kIOReturnSuccess { log("Write failed (\(String(format: "0x%08x", status)))") }
  }

  fileprivate func received(_ bytes: [UInt8]) {
    for frame in framer.push(bytes) { handle(frame) }
  }

  private func handle(_ frame: Frame) {
    let key = UInt32(frame.command) << 8 | UInt32(frame.sequence)
    if let waiting, waiting.key == key {
      waiting.timeout.cancel()
      self.waiting = nil
      log("\(waiting.request.label): \(waiting.request.decode(frame.payload))")
      // A short gap between requests, as the web app does.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { MainActor.assumeIsolated { self.next() } }
      return
    }
    let p = frame.payload
    switch frame.command {
    case 0x0204 where p.first == 1: log("Live battery: \(battery(Array(p.dropFirst()), status: false))")
    case 0x0204 where p.first == 2: log("Live wearing: \(wearing(Array(p.dropFirst())))")
    case 0x0204 where p.first == 3 && p.count >= 4 && p[1] == 1 && p[2] == 1: log("Live noise mode: \(noise([0] + p.dropFirst()))")
    case 0x0204 where p.first == 6: log("Connected-devices update (names not shown)")
    case 0x0500:
      // The buds ask for the time; HeyMelody answers 00 <unix seconds u32 LE>.
      let now = UInt32(Date().timeIntervalSince1970)
      write(encode(0x8500, frame.sequence, [0, UInt8(now & 0xFF), UInt8(now >> 8 & 0xFF), UInt8(now >> 16 & 0xFF), UInt8(now >> 24)]))
      log("Answered the earbuds' time request")
    default: log("Other frame \(String(format: "%04x", frame.command)): \(hex(p))")
    }
  }

  func finish(_ message: String, code: Int32) {
    log(message)
    channel?.setDelegate(nil)
    channel?.close()
    exit(code)
  }

  fileprivate func sdpComplete(_ target: IOBluetoothDevice, status: IOReturn) {
    log("Service query finished (\(String(format: "0x%08x", status))). Services:")
    for record in (target.services as? [IOBluetoothSDPServiceRecord]) ?? [] {
      var id: BluetoothRFCOMMChannelID = 0
      let rfcomm = record.getRFCOMMChannelID(&id) == kIOReturnSuccess ? "RFCOMM \(id)" : "no RFCOMM"
      log("  \(record.getServiceName() ?? "unnamed"): \(rfcomm)\(record.hasService(from: [uuid]) ? "  <- Buds control" : "")")
    }
    guard status == kIOReturnSuccess, let record = target.getServiceRecord(for: uuid) else {
      return finish("\(target.name ?? "Device") does not offer the Buds control service.", code: 1)
    }
    var id: BluetoothRFCOMMChannelID = 0
    guard record.getRFCOMMChannelID(&id) == kIOReturnSuccess else { return finish("No RFCOMM channel in the service record.", code: 1) }
    if channel == nil { open(target, channel: id) }
  }

  fileprivate func opened(status: IOReturn) {
    if status == kIOReturnSuccess { connected() }
    else { finish("Channel did not open (\(String(format: "0x%08x", status))). Is Chrome connected to the earbuds? Disconnect it first.", code: 1) }
  }
}

extension Probe: @preconcurrency IOBluetoothRFCOMMChannelDelegate {
  func rfcommChannelOpenComplete(_ channel: IOBluetoothRFCOMMChannel!, status error: IOReturn) { opened(status: error) }
  func rfcommChannelData(_ channel: IOBluetoothRFCOMMChannel!, data: UnsafeMutableRawPointer!, length: Int) {
    received(Array(UnsafeRawBufferPointer(start: data, count: length).bindMemory(to: UInt8.self)))
  }
  func rfcommChannelClosed(_ channel: IOBluetoothRFCOMMChannel!) {
    self.channel = nil
    finish("The earbuds closed the channel.", code: 1)
  }
}

extension Probe {
  @objc func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) { sdpComplete(device, status: status) }
}

let probe = Probe()
signal(SIGINT, SIG_IGN)
let interrupt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
interrupt.setEventHandler { MainActor.assumeIsolated { probe.finish("Stopped.", code: 0) } }
interrupt.resume()
probe.start()
RunLoop.main.run()
