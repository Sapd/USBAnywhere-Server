// USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
// Copyright 2026 Denis Arnst (Sapd) — https://github.com/Sapd
// Licensed under GPL-3.0; see the repository LICENSE.
import AppKit

@MainActor enum AppArtwork {
    static let menuBar: NSImage = {
        let image = Bundle.main.url(forResource: "MenuBarIconTemplate", withExtension: "pdf")
            .flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "cable.connector.horizontal", accessibilityDescription: "USBAnywhere Server")!
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()
    static var appIcon: NSImage {
        Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            .flatMap { NSImage(contentsOf: $0) } ?? NSApp.applicationIconImage
    }
}
@MainActor final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = AppArtwork.appIcon
        let savedDockChoice = UserDefaults.standard.object(forKey: "showInDock") as? Bool
        NSApp.setActivationPolicy((savedDockChoice ?? true) ? .regular : .accessory)
        DispatchQueue.main.async { WindowPresentation.shared.show() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowPresentation.shared.show()
        return false
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
