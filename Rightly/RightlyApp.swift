import SwiftUI
import OSLog
import AppKit
import ApplicationServices
import CoreGraphics
import CoreServices
import FinderSync

@main
struct RightlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private enum StartupPermissionStep: String {
        case finderExtension
        case accessibility
        case terminalAutomation
    }

    private let logger = Logger(subsystem: "com.rightly.app", category: "MainApp")
    private var receivedFileRequest = false
    private var directLaunchWorkItem: DispatchWorkItem?
    private var settingsWindow: NSWindow?
    private var pendingStartupPermissionSteps: [StartupPermissionStep] = []
    private var didStartStartupPermissionChecks = false
    private var isWaitingForSystemSettings = false
    private var didLeaveForSystemSettings = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        logger.notice("A00 launched with accessory activation policy")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.notice("A01 main app finished launching")
        ensureFinderExtensionRegistration()
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

    func applicationDidResignActive(_ notification: Notification) {
        guard isWaitingForSystemSettings else { return }
        didLeaveForSystemSettings = true
        logger.notice("A16 application left for permission settings")
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard isWaitingForSystemSettings, didLeaveForSystemSettings else { return }
        isWaitingForSystemSettings = false
        didLeaveForSystemSettings = false
        logger.notice("A17 application returned from permission settings")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.requestNextStartupPermission()
        }
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
            scheduleStartupPermissionChecks()
            return
        }

        logger.notice("A08 creating settings window")
        let hostingController = NSHostingController(rootView: ContentView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Rightly 设置"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 540, height: 760))
        window.minSize = NSSize(width: 520, height: 640)
        window.backgroundColor = .windowBackgroundColor
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        logger.notice("A09 settings window presented")
        scheduleStartupPermissionChecks()
    }

    private func scheduleStartupPermissionChecks() {
        guard !didStartStartupPermissionChecks else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            self?.startStartupPermissionChecks()
        }
    }

    private func startStartupPermissionChecks() {
        guard !didStartStartupPermissionChecks, !receivedFileRequest else { return }
        didStartStartupPermissionChecks = true

        pendingStartupPermissionSteps = [.finderExtension]
        let enabledFeatures = Set(SharedSettings.loadEnabledFeatures())
        if enabledFeatures.contains(.newFile) || enabledFeatures.contains(.clipboard) {
            pendingStartupPermissionSteps.append(.accessibility)
        }
        let enabledTerminalApps = Set(SharedSettings.loadEnabledTerminalApps())
        if enabledFeatures.contains(.terminal), enabledTerminalApps.contains(.terminal) {
            pendingStartupPermissionSteps.append(.terminalAutomation)
        }

        logger.notice("A11 startup permission checks started, count=\(self.pendingStartupPermissionSteps.count, privacy: .public)")
        requestNextStartupPermission()
    }

    private func ensureFinderExtensionRegistration(completion: (() -> Void)? = nil) {
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("RightlyUninstaller", isDirectory: false)
        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            logger.error("A10 Finder extension registration helper is missing")
            completion?()
            return
        }

        let appPath = Bundle.main.bundleURL.path
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let process = Process()
            process.executableURL = helperURL
            process.arguments = ["ensure", appPath]
            do {
                try process.run()
                process.waitUntilExit()
                self?.logger.notice("A10 Finder extension registration check completed: status=\(process.terminationStatus, privacy: .public)")
                DispatchQueue.main.async {
                    completion?()
                }
            } catch {
                self?.logger.error("A10 Finder extension registration check failed: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }
    }

    private func requestNextStartupPermission() {
        guard !isWaitingForSystemSettings else { return }
        guard !pendingStartupPermissionSteps.isEmpty else {
            logger.notice("A12 startup permission checks completed")
            return
        }

        let step = pendingStartupPermissionSteps.removeFirst()
        logger.notice("A13 checking startup permission=\(step.rawValue, privacy: .public)")
        switch step {
        case .finderExtension:
            requestFinderExtensionPermissionIfNeeded()
        case .accessibility:
            requestAccessibilityPermissionIfNeeded()
        case .terminalAutomation:
            requestTerminalAutomationPermissionIfNeeded()
        }
    }

    private func requestFinderExtensionPermissionIfNeeded() {
        guard !FIFinderSyncController.isExtensionEnabled else {
            logger.notice("A14 Finder extension already enabled")
            requestNextStartupPermission()
            return
        }

        let shouldOpen = showPermissionAlert(
            title: "启用 Rightly Finder 扩展",
            detail: "需要在系统设置的“登录项与扩展 → Finder 扩展”中启用 Rightly，Finder 右键菜单才能工作。",
            actionTitle: "打开系统设置"
        )
        guard shouldOpen else {
            logger.notice("A15 Finder extension permission deferred")
            requestNextStartupPermission()
            return
        }

        ensureFinderExtensionRegistration { [weak self] in
            guard let self else { return }
            self.waitForSystemSettings()
            FIFinderSyncController.showExtensionManagementInterface()
        }
    }

    private func requestAccessibilityPermissionIfNeeded() {
        let accessibilityTrusted = AXIsProcessTrusted()
        let canPostEvents = CGPreflightPostEventAccess()
        logger.notice(
            "A18 permission state accessibility=\(accessibilityTrusted, privacy: .public), postEvents=\(canPostEvents, privacy: .public)"
        )
        guard !accessibilityTrusted, !canPostEvents else {
            logger.notice("A18 keyboard event permission already granted")
            requestNextStartupPermission()
            return
        }

        let shouldRequest = showPermissionAlert(
            title: "允许创建后自动重命名",
            detail: "Rightly 需要辅助功能权限，才能在 Finder 选中新文件后自动进入重命名状态。",
            actionTitle: "允许"
        )
        guard shouldRequest else {
            logger.notice("A19 keyboard event permission deferred")
            requestNextStartupPermission()
            return
        }

        if CGRequestPostEventAccess() {
            logger.notice("A20 keyboard event permission granted")
            requestNextStartupPermission()
            return
        }

        logger.notice("A20 keyboard event permission not granted; opening system settings")
        openSystemSettings(
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
    }

    private func requestTerminalAutomationPermissionIfNeeded() {
        guard !NSRunningApplication.runningApplications(
            withBundleIdentifier: TerminalApp.terminal.bundleIdentifier
        ).isEmpty else {
            logger.notice("A21 Terminal is not running; automation permission will be requested on first use")
            requestNextStartupPermission()
            return
        }

        determineTerminalAutomationPermission(askUserIfNeeded: false) { [weak self] status in
            guard let self else { return }
            switch status {
            case noErr:
                self.logger.notice("A22 Terminal automation permission already granted")
                self.requestNextStartupPermission()
            case OSStatus(errAEEventWouldRequireUserConsent):
                let shouldRequest = self.showPermissionAlert(
                    title: "允许控制 Terminal",
                    detail: "Rightly 需要自动化权限，才能从 Finder 在所选文件夹中打开 Terminal。",
                    actionTitle: "继续授权"
                )
                guard shouldRequest else {
                    self.logger.notice("A23 Terminal automation permission deferred")
                    self.requestNextStartupPermission()
                    return
                }
                self.determineTerminalAutomationPermission(askUserIfNeeded: true) { [weak self] requestedStatus in
                    guard let self else { return }
                    if requestedStatus == noErr {
                        self.logger.notice("A24 Terminal automation permission granted")
                        self.requestNextStartupPermission()
                    } else {
                        self.logger.notice("A24 Terminal automation permission not granted, status=\(requestedStatus, privacy: .public)")
                        self.openSystemSettings(
                            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
                        )
                    }
                }
            case OSStatus(errAEEventNotPermitted):
                let shouldOpen = self.showPermissionAlert(
                    title: "Terminal 自动化权限已关闭",
                    detail: "请在系统设置的“隐私与安全性 → 自动化”中，允许 Rightly 控制 Terminal。",
                    actionTitle: "打开系统设置"
                )
                if shouldOpen {
                    self.openSystemSettings(
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
                    )
                } else {
                    self.requestNextStartupPermission()
                }
            default:
                self.logger.notice("A25 Terminal automation permission check skipped, status=\(status, privacy: .public)")
                self.requestNextStartupPermission()
            }
        }
    }

    private func determineTerminalAutomationPermission(
        askUserIfNeeded: Bool,
        completion: @escaping (OSStatus) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let descriptor = NSAppleEventDescriptor(
                bundleIdentifier: TerminalApp.terminal.bundleIdentifier
            )
            let status: OSStatus
            if let target = descriptor.aeDesc {
                status = AEDeterminePermissionToAutomateTarget(
                    target,
                    typeWildCard,
                    typeWildCard,
                    askUserIfNeeded
                )
            } else {
                status = OSStatus(paramErr)
            }
            DispatchQueue.main.async {
                completion(status)
            }
        }
    }

    private func showPermissionAlert(title: String, detail: String, actionTitle: String) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: actionTitle)
        alert.addButton(withTitle: "稍后")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func openSystemSettings(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            logger.error("A26 invalid System Settings URL")
            requestNextStartupPermission()
            return
        }
        waitForSystemSettings()
        guard NSWorkspace.shared.open(url) else {
            logger.error("A26 failed to open System Settings")
            isWaitingForSystemSettings = false
            didLeaveForSystemSettings = false
            requestNextStartupPermission()
            return
        }
        logger.notice("A26 System Settings opened")
    }

    private func waitForSystemSettings() {
        isWaitingForSystemSettings = true
        didLeaveForSystemSettings = false
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === settingsWindow else { return }
        logger.notice("A10 settings window closing")
        settingsWindow = nil
    }
}
