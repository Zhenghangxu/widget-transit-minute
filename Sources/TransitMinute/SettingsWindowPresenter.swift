import AppKit
import SwiftUI

@MainActor
final class SettingsWindowPresenter: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let windowSize = NSSize(width: 720, height: 560)

    func open(model: AppModel) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: windowSize),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Transit Minute Settings"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .automatic
            window.toolbar?.showsBaselineSeparator = false
            window.titlebarSeparatorStyle = .none
            window.backgroundColor = .windowBackgroundColor
            window.isOpaque = true
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.minSize = windowSize
            window.contentView = NSHostingView(
                rootView: SettingsView()
                    .environmentObject(model)
                    .frame(width: windowSize.width, height: windowSize.height)
            )
            window.delegate = self
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            window = nil
        }
    }
}
