// swift-tools-version: 5.9
// Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
// USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
// Licensed under GPL-3.0; see the repository LICENSE.
import PackageDescription
let package = Package(name: "USBAnywhereMac", platforms: [.macOS(.v13)], products: [
    .executable(name: "usbanywhere-server-mac", targets: ["USBAnywhereDaemon"]),
    .executable(name: "USBAnywhereApp", targets: ["USBAnywhereApp"])
], targets: [
    .target(name: "ExceptionGuard", publicHeadersPath: "include"),
    .target(name: "USBAnywhereCore", dependencies: ["ExceptionGuard"], linkerSettings: [.linkedFramework("IOUSBHost"), .linkedFramework("IOKit")]),
    .executableTarget(name: "USBAnywhereDaemon", dependencies: ["USBAnywhereCore"]),
    .executableTarget(name: "USBAnywhereApp", dependencies: ["USBAnywhereCore"]),
    .testTarget(name: "USBAnywhereCoreTests", dependencies: ["USBAnywhereCore"])
])
