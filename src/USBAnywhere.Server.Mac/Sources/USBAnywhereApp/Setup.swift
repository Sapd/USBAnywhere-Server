// USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
// Copyright 2026 Denis Arnst (Sapd) — https://github.com/Sapd
// Licensed under GPL-3.0; see the repository LICENSE.
import AppKit
import Darwin
import Foundation
import SwiftUI

struct ComputerChoice: Identifiable, Sendable {
  let id: String
  let name: String
}
struct NetworkChoices: Sendable {
  var local = ""
  var computers = [ComputerChoice]()
}
func validIPv4(_ string: String) -> Bool {
  var address = in_addr()
  return inet_pton(AF_INET, string, &address) == 1 && address.s_addr != 0
}
private final class ProcessOutput: @unchecked Sendable {
  private let lock = NSLock()
  private var data = Data()
  func store(_ value: Data) {
    lock.lock()
    data = value
    lock.unlock()
  }
  func read() -> Data {
    lock.lock()
    defer { lock.unlock() }
    return data
  }
}
func runTool(_ executable: String, _ arguments: [String], timeout: TimeInterval = 10) throws -> Data
{
  let process = Process()
  let pipe = Pipe()
  let output = ProcessOutput()
  let finished = DispatchGroup()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  process.standardOutput = pipe
  process.standardError = pipe
  try process.run()
  finished.enter()
  DispatchQueue.global(qos: .utility).async {
    output.store(pipe.fileHandleForReading.readDataToEndOfFile())
    finished.leave()
  }
  let end = Date().addingTimeInterval(timeout)
  while process.isRunning && Date() < end { Thread.sleep(forTimeInterval: 0.05) }
  if process.isRunning {
    process.terminate()
    throw NSError(
      domain: "Setup", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "The setup command timed out. Please try again."])
  }
  process.waitUntilExit()
  _ = finished.wait(timeout: .now() + 2)
  let result = output.read()
  guard process.terminationStatus == 0 else {
    throw NSError(
      domain: "Setup", code: Int(process.terminationStatus),
      userInfo: [
        NSLocalizedDescriptionKey: String(data: result.prefix(4096), encoding: .utf8)
          ?? "Setup did not finish"
      ])
  }
  return result
}
func networkChoices() -> NetworkChoices {
  var result = NetworkChoices()
  for path in [
    "/usr/local/bin/tailscale", "/opt/homebrew/bin/tailscale",
    "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
  ] where FileManager.default.isExecutableFile(atPath: path) {
    if let data = try? runTool(path, ["status", "--json"], timeout: 5),
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    {
      if let own = root["Self"] as? [String: Any], let addresses = own["TailscaleIPs"] as? [String]
      {
        result.local = addresses.first(where: validIPv4) ?? ""
      }
      if let peers = root["Peer"] as? [String: [String: Any]] {
        result.computers = peers.values.compactMap { peer in
          guard peer["OS"] as? String == "windows",
            let addresses = peer["TailscaleIPs"] as? [String],
            let ip = addresses.first(where: validIPv4)
          else { return nil }
          let name = peer["HostName"] as? String ?? ip
          return ComputerChoice(
            id: ip, name: name + (peer["Online"] as? Bool == false ? " (offline)" : ""))
        }.sorted { $0.name < $1.name }
      }
      if !result.local.isEmpty { return result }
    }
  }
  var list: UnsafeMutablePointer<ifaddrs>?
  if getifaddrs(&list) == 0 {
    defer { freeifaddrs(list) }
    var cursor = list
    while let entry = cursor {
      defer { cursor = entry.pointee.ifa_next }
      guard let addr = entry.pointee.ifa_addr, addr.pointee.sa_family == AF_INET,
        entry.pointee.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
        entry.pointee.ifa_flags & UInt32(IFF_UP) != 0
      else { continue }
      let ipv4 = UnsafeRawPointer(addr).assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr
      var copy = ipv4
      var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
      if inet_ntop(AF_INET, &copy, &buffer, socklen_t(buffer.count)) != nil {
        let ip = String(cString: buffer)
        if result.local.isEmpty || ip.hasPrefix("100.") { result.local = ip }
      }
    }
  }
  return result
}
private func shellQuote(_ value: String) -> String {
  "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}
func installBundledService(local: String, peer: String) throws {
  guard validIPv4(local), validIPv4(peer), let resources = Bundle.main.resourceURL else {
    throw NSError(
      domain: "Setup", code: 2,
      userInfo: [NSLocalizedDescriptionKey: "Enter valid Mac and Windows IPv4 addresses."])
  }
  let manager = FileManager.default
  let staging = manager.temporaryDirectory.appendingPathComponent(
    "USBAnywhere-" + UUID().uuidString)
  defer { try? manager.removeItem(at: staging) }
  let package = staging.appendingPathComponent("Package")
  let build = package.appendingPathComponent("build")
  try manager.createDirectory(
    at: build, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
  try manager.copyItem(
    at: resources.appendingPathComponent("Server/usbanywhere-server-mac"),
    to: build.appendingPathComponent("usbanywhere-server-mac"))
  try manager.copyItem(
    at: resources.appendingPathComponent("Server/usbanywhere-ctl"),
    to: build.appendingPathComponent("usbanywhere-ctl"))
  try manager.copyItem(
    at: resources.appendingPathComponent("Server/install-server-mac.sh"),
    to: staging.appendingPathComponent("install.sh"))
  // Stage outside Documents so the administrator process does not need broad privacy access.
  try manager.copyItem(
    at: Bundle.main.bundleURL, to: build.appendingPathComponent("USBAnywhere.app"))
  let command =
    "USBANYWHERE_PACKAGE_DIR=" + shellQuote(package.path) + " /bin/sh "
    + shellQuote(staging.appendingPathComponent("install.sh").path) + " " + shellQuote(local) + " "
    + shellQuote(peer)
  let appleScript =
    "do shell script \""
    + command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(
      of: "\"", with: "\\\"") + "\" with administrator privileges"
  _ = try runTool("/usr/bin/osascript", ["-e", appleScript], timeout: 180)
}
struct SetupView: View {
  @ObservedObject var model: SharingModel
  private var installedLocation: Bool { Bundle.main.bundleURL.deletingLastPathComponent().path == "/Applications" }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("Set up USB sharing", systemImage: "sparkles").font(.title2.bold())
      Text(
        "Choose the Windows PC that will use your devices. After a one-time administrator approval, sharing starts automatically with your Mac."
      ).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      if !model.computers.isEmpty {
        Picker("Windows PC", selection: $model.peerAddress) {
          Text("Enter an address below").tag("")
          ForEach(model.computers) { computer in Text(computer.name).tag(computer.id) }
        }
      }
      TextField("Windows PC address", text: $model.peerAddress)
      DisclosureGroup("Mac connection") {
        TextField("This Mac's address", text: $model.localAddress).padding(.top, 6)
      }
      Toggle("Open USBAnywhere when I log in", isOn: $model.setupLaunchAtLogin)
        .toggleStyle(.checkbox).disabled(model.installing)
      Text("Optional. Device sharing starts with your Mac even when the app is closed.")
        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      if !installedLocation {
        Text("Drag USBAnywhere into Applications, then open it there to finish setup.")
          .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        Button("Open Applications Folder") { NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications")) }
      }
      if let issue = model.setupIssue {
        Text(issue).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
      }
      HStack {
        Button("Find computers") { model.findComputers() }.disabled(model.installing)
        Spacer()
        if model.installing { ProgressView().controlSize(.small) }
        Button("Set Up Sharing") { model.installService() }.buttonStyle(.borderedProminent)
          .disabled(
            model.installing || !installedLocation || !validIPv4(model.localAddress) || !validIPv4(model.peerAddress))
      }
      Text(
        "Uses your existing private network or Tailscale. On Windows, install USBAnywhere Client and enable automatic reconnect."
      ).font(.caption).foregroundStyle(.secondary)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }.padding(20).background(
      Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14)
    )
    .task { if model.localAddress.isEmpty { model.findComputers() } }
  }
}
