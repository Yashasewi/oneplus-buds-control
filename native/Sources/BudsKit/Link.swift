import Foundation
import IOBluetooth

/// The Buds 4 control channel over classic Bluetooth RFCOMM (the same service Chrome reaches through Web Serial).
/// macOS only opens RFCOMM channels for processes launched as an app bundle, not for bare terminal binaries.
@MainActor
final class RFCOMMLink: NSObject {
  var onData: (Bytes) -> Void = { _ in }
  var onClose: () -> Void = {}
  private var channel: IOBluetoothRFCOMMChannel?
  private var openContinuation: CheckedContinuation<Void, Error>?
  private var sdpContinuation: CheckedContinuation<IOReturn, Never>?

  static let uuid: IOBluetoothSDPUUID = budsServiceUUID.withUnsafeBytes {
    IOBluetoothSDPUUID(bytes: $0.baseAddress, length: 16)
  }

  /// Paired devices that advertise (or, when not yet cached, are named like) the Buds control service.
  static func candidates() -> [IOBluetoothDevice] {
    let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
    return paired.filter { $0.getServiceRecord(for: uuid) != nil || ($0.name ?? "").contains("OnePlus Buds") }
  }

  func channelID(on device: IOBluetoothDevice) async -> BluetoothRFCOMMChannelID? {
    if let id = Self.cachedChannel(device) { return id }
    let status = await withCheckedContinuation { continuation in
      sdpContinuation = continuation
      if device.performSDPQuery(self) != kIOReturnSuccess { finishSDP(kIOReturnError) }
    }
    return status == kIOReturnSuccess ? Self.cachedChannel(device) : nil
  }

  private static func cachedChannel(_ device: IOBluetoothDevice) -> BluetoothRFCOMMChannelID? {
    var id: BluetoothRFCOMMChannelID = 0
    guard let record = device.getServiceRecord(for: uuid), record.getRFCOMMChannelID(&id) == kIOReturnSuccess else { return nil }
    return id
  }

  func open(_ device: IOBluetoothDevice, channel id: BluetoothRFCOMMChannelID) async throws {
    var opened: IOBluetoothRFCOMMChannel?
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      openContinuation = continuation
      let status = device.openRFCOMMChannelAsync(&opened, withChannelID: id, delegate: self)
      channel = opened
      if status != kIOReturnSuccess { finishOpen(.failure(LinkError.openFailed(status))) }
      DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        MainActor.assumeIsolated { self.finishOpen(.failure(LinkError.openTimedOut)) }
      }
    }
  }

  func write(_ bytes: Bytes) throws {
    guard let channel, channel.isOpen() else { throw BudsError.disconnected }
    var data = bytes
    let status = channel.writeSync(&data, length: UInt16(data.count))
    guard status == kIOReturnSuccess else { throw LinkError.writeFailed(status) }
  }

  func close() {
    let current = channel
    channel = nil
    current?.setDelegate(nil)
    current?.close()
    finishOpen(.failure(BudsError.disconnected))
  }

  private func finishOpen(_ result: Result<Void, Error>) {
    guard let continuation = openContinuation else { return }
    openContinuation = nil
    if case .failure = result { channel?.setDelegate(nil); channel?.close(); channel = nil }
    continuation.resume(with: result)
  }

  private func finishSDP(_ status: IOReturn) {
    sdpContinuation?.resume(returning: status)
    sdpContinuation = nil
  }

  @objc func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) { finishSDP(status) }
}

extension RFCOMMLink: @preconcurrency IOBluetoothRFCOMMChannelDelegate {
  func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
    finishOpen(error == kIOReturnSuccess ? .success(()) : .failure(LinkError.openFailed(error)))
  }
  func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data: UnsafeMutableRawPointer!, length: Int) {
    onData(Array(UnsafeRawBufferPointer(start: data, count: length).bindMemory(to: UInt8.self)))
  }
  func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
    guard rfcommChannel === channel else { return }
    channel = nil
    onClose()
  }
}

enum LinkError: LocalizedError {
  case openFailed(IOReturn)
  case openTimedOut
  case writeFailed(IOReturn)

  var errorDescription: String? {
    switch self {
    case .openFailed, .openTimedOut:
      "Couldn’t open the earbuds’ control link. If Chrome or another app is connected to them, disconnect it there."
    case .writeFailed(let s): "Couldn’t send to the earbuds (\(String(format: "0x%08x", s)))."
    }
  }
}

/// Bluetooth connect/disconnect notifications, which need an Objective-C target.
@MainActor
final class DeviceWatcher: NSObject {
  var onConnect: (IOBluetoothDevice) -> Void = { _ in }
  var onDisconnect: (IOBluetoothDevice) -> Void = { _ in }
  private var connectNote: IOBluetoothUserNotification?
  private var disconnectNotes: [IOBluetoothUserNotification] = []

  func start() {
    connectNote = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
  }
  func watchDisconnect(of device: IOBluetoothDevice) {
    disconnectNotes.forEach { $0.unregister() }
    disconnectNotes = [device.register(forDisconnectNotification: self, selector: #selector(disconnected(_:device:)))].compactMap { $0 }
  }

  @objc private func connected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) { onConnect(device) }
  @objc private func disconnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) { onDisconnect(device) }
}
