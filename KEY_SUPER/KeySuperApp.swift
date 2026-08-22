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
    private var directLaunchWorkItem: DispatchWorkItem?
    private var settingsWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        logger.notice("A00 launched with accessory activation policy")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.notice("A01 main app finished launching")
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.receivedFileRequest else {
                self?.logger.notice("A04 background URL request detected; settings window suppressed")
                return
            }
            self.logger.notice("A04 direct launch detected; opening settings")
            self.showSettingsWindow()
        }
        directLaunchWorkItem = workItem
        // URL-open events can arrive just after launch. Give the event time to
        // mark this as a background request before presenting the settings UI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedFileRequest = true
        directLaunchWorkItem?.cancel()
        directLaunchWorkItem = nil
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
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 900, height: 720))
        window.minSize = NSSize(width: 820, height: 590)
        window.backgroundColor = .windowBackgroundColor
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
