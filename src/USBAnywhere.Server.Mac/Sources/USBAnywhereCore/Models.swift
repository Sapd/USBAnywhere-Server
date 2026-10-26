// USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
import Darwin
import ExceptionGuard
// Copyright 2026 Denis Arnst (Sapd) — https://github.com/Sapd
// Licensed under GPL-3.0; see the repository LICENSE.
import Foundation

public enum USBError: Error, CustomStringConvertible {
  case message(String)
  public var description: String {
    if case .message(let s) = self { return s }
    return "USB error"
  }
}
func guarded<T>(_ operation: () throws -> T) throws -> T {
  var outcome: Result<T, Error>?
  // The block runs synchronously; no Swift exception crosses the Objective-C boundary.
  try withoutActuallyEscaping(operation) { block in
    var exception: NSError?
    guard USBGuard({ outcome = Result { try block() } }, &exception) else {
      throw exception ?? USBError.message("USB exception") as NSError
    }
  }
  return try outcome!.get()
}

extension NSLock {
  @discardableResult func withLock<T>(_ body: () throws -> T) rethrows -> T {
    lock()
    defer { unlock() }
    return try body()
  }
}
public struct TargetConfig: Codable, Equatable, Sendable {
  public var vendor: UInt16
  public var product: UInt16
  public var location: UInt32
  public var label: String
  public init(vendor: UInt16, product: UInt16, location: UInt32, label: String) {
    self.vendor = vendor
    self.product = product
    self.location = location
    self.label = label
  }
  public func matches(vendor: UInt32, product: UInt32, location: UInt32) -> Bool {
    UInt32(self.vendor) == vendor && UInt32(self.product) == product
      && (!label.isEmpty || self.location == location)
  }
}
public struct DaemonConfig {
  public let listen: String
  public let peer: String
  public let targets: [TargetConfig]
  init(loopbackTest: Void) {
    listen = "127.0.0.1"
    peer = "127.0.0.1"
    targets = []
  }
  public init(arguments: [String]) throws {
    let legacy = arguments.count == 5
    guard
      arguments.count == 2 || legacy
        || (arguments.count >= 6 && (arguments.count - 2) % 4 == 0
          && (arguments.count - 2) / 4 <= 16)
    else { throw USBError.message("Expected LISTEN_IPV4 PEER_IPV4 VID PID LOCATION LABEL [...] ") }
    var a = in_addr()
    var b = in_addr()
    guard inet_pton(AF_INET, arguments[0], &a) == 1, a.s_addr != 0,
      inet_pton(AF_INET, arguments[1], &b) == 1, b.s_addr != 0
    else { throw USBError.message("Explicit IPv4 addresses required") }
    listen = arguments[0]
    peer = arguments[1]
    var items = [TargetConfig]()
    for i in 0..<(legacy ? 1 : (arguments.count - 2) / 4) {
      let n = 2 + i * 4
      guard let v = UInt16(arguments[n], radix: 16), let p = UInt16(arguments[n + 1], radix: 16),
        let l = UInt32(arguments[n + 2], radix: 16)
      else { throw USBError.message("Invalid USB identifiers") }
      let label = legacy ? "" : arguments[n + 3]
      guard
        legacy
          || (!label.isEmpty && label.count <= 32
            && label.utf8.allSatisfy {
              (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
            })
      else { throw USBError.message("Invalid identity label") }
      guard
        !items.contains(where: {
          $0.location == l
            || (!legacy && ($0.label == label || ($0.vendor == v && $0.product == p)))
        })
      else { throw USBError.message("Ambiguous duplicate target") }
      items.append(TargetConfig(vendor: v, product: p, location: l, label: label))
    }
    targets = items
  }
}
public struct DeviceStatus: Codable, Identifiable, Sendable {
  public var id: String
  public var name: String
  public var model: String
  public var serial: String
  public var enabled: Bool
  public var state: String
  public var location: String
  public var completed: UInt64
  public var bytes: UInt64
  public var errors: UInt64
  public var pending: Int
  public var lastActivity: Date?
  public var lastError: String?
}
public struct ServerStatus: Codable, Sendable {
  public var version: String
  public var started: Date
  public var listen: String
  public var peer: String
  public var devices: [DeviceStatus]
  public var availableDevices: [LocalUSBDevice]? = nil
}
public struct ControlRequest: Codable, Sendable {
  public var action: String
  public var busID: String?
  public var device: LocalUSBDevice?
  public init(action: String, busID: String? = nil, device: LocalUSBDevice? = nil) {
    self.action = action
    self.busID = busID
    self.device = device
  }
}
public struct ControlReply: Codable, Sendable {
  public var ok: Bool
  public var message: String
  public var status: ServerStatus?
}
public enum Paths {
  public static let directory = "/var/run/usbanywhere-mac"
  public static let socket = directory + "/control.sock"
  public static let state = "/Library/Application Support/USBAnywhereMac/sharing.json"
  public static let targets = "/Library/Application Support/USBAnywhereMac/targets.json"
  public static let log = "/Library/Logs/USBAnywhereMac/swift-server.log"
}
final class EventLog {
  static let shared = EventLog()
  private let lock = NSLock()
  func write(_ message: String) {
    lock.withLock {
      let line = "\(ISO8601DateFormatter().string(from:Date())) \(message)\n"
      guard geteuid() == 0 else { return }
      if let attrs = try? FileManager.default.attributesOfItem(atPath: Paths.log),
        let size = attrs[.size] as? NSNumber, size.intValue > 2 * 1024 * 1024
      {
        try? FileManager.default.removeItem(atPath: Paths.log + ".1")
        try? FileManager.default.moveItem(atPath: Paths.log, toPath: Paths.log + ".1")
      }
      if !FileManager.default.fileExists(atPath: Paths.log) {
        FileManager.default.createFile(
          atPath: Paths.log, contents: nil, attributes: [.posixPermissions: 0o644])
      }
      if let handle = FileHandle(forWritingAtPath: Paths.log) {
        defer { try? handle.close() }
        do {
          try handle.seekToEnd()
          try handle.write(contentsOf: Data(line.utf8))
        } catch {}
      }
    }
  }
}
