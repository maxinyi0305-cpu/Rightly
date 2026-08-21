import SwiftUI
import OSLog
import AppKit

@main
struct KeySuperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let logger = Logger(subsystem: "com.keysuper.app", category: "MainApp")
    private var receivedFileRequest = false
    private var settingsWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        logger.notice("A00 launched with accessory activation policy")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.notice("A01 main app finished launching")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, !self.receivedFileRequest else { return }
            self.logger.notice("A04 direct launch detected; opening settings")
            self.showSettingsWindow()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedFileRequest = true
        logger.notice("A02 application open URLs called, count=\(urls.count, privacy: .public)")
        Task { @MainActor in
            urls.forEach {
                self.logger.notice("A03 forwarding URL=\($0.absoluteString, privacy: .public)")
                FileCreator.handle($0)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        logger.notice("A05 app reopened; opening settings")
        showSettingsWindow()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @MainActor
    func finishBackgroundRequest() {
        let hasVisibleWindow = NSApp.windows.contains { $0.isVisible && !$0.isMiniaturized }
        logger.notice("A06 background request finished; visibleWindow=\(hasVisibleWindow, privacy: .public)")
        guard !hasVisibleWindow else { return }
        NSApp.terminate(nil)
    }

    private func showSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let settingsWindow {
            logger.notice("A07 reusing settings window, visible=\(settingsWindow.isVisible, privacy: .public)")
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        logger.notice("A08 creating settings window")
        let hostingController = NSHostingController(rootView: ContentView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "KEY SUPER 设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 500, height: 500))
        window.minSize = NSSize(width: 500, height: 500)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        logger.notice("A09 settings window presented")
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === settingsWindow else { return }
        logger.notice("A10 settings window closing")
        settingsWindow = nil
    }
}
