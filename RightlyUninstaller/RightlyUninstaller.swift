import Foundation

@main
struct RightlyUninstaller {
    static func main() {
        guard CommandLine.arguments.count >= 3 else {
            fputs("Usage: RightlyUninstaller <ensure|register|unregister|uninstall> <Rightly.app path> [parent PID]\n", stderr)
            exit(EXIT_FAILURE)
        }

        let action = CommandLine.arguments[1]
        let appURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let pluginURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("PlugIns", isDirectory: true)
            .appendingPathComponent("RightlyFinderExtension.appex", isDirectory: true)

        guard FileManager.default.fileExists(atPath: pluginURL.path) else {
            fputs("Finder extension not found at \(pluginURL.path)\n", stderr)
            exit(EXIT_FAILURE)
        }

        if action == "uninstall" {
            guard isExpectedRightlyApp(appURL) else {
                fputs("Refusing to uninstall unexpected application at \(appURL.path)\n", stderr)
                exit(EXIT_FAILURE)
            }

            unregisterAllRegistrations(for: pluginURL)
            refreshFinder()

            if CommandLine.arguments.count >= 4,
               let parentPID = Int32(CommandLine.arguments[3]) {
                waitForProcessToExit(parentPID)
            }

            removeRightlyData()

            do {
                var trashedURL: NSURL?
                try FileManager.default.trashItem(at: appURL, resultingItemURL: &trashedURL)
                exit(EXIT_SUCCESS)
            } catch {
                fputs("Unable to move Rightly to Trash: \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
        }

        if action == "ensure" {
            let inspect = Process()
            let output = Pipe()
            inspect.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            inspect.arguments = ["-m", "-ADv", "-i", "com.rightly.app.RightlyFinderExtension"]
            inspect.standardOutput = output
            inspect.standardError = output

            do {
                try inspect.run()
                inspect.waitUntilExit()
            } catch {
                fputs("Unable to inspect Finder extension registration: \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }

            if let registration = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) {
                // Xcode builds and app updates can leave registrations pointing at
                // deleted copies. Remove those stale entries so System Settings
                // shows one Rightly extension instead of several duplicates.
                let registeredPaths = registration
                    .split(whereSeparator: \.isNewline)
                    .compactMap { line -> String? in
                        guard line.contains("RightlyFinderExtension.appex") else { return nil }
                        return line.split(separator: "\t").last.map(String.init)
                    }
                for path in registeredPaths where path != pluginURL.path {
                    removeRegistration(at: path)
                }

                // A '-' entry is a deliberately disabled extension. Keep it
                // disabled; only add the extension when no current registration
                // exists at all.
                if registeredPaths.contains(pluginURL.path) {
                    exit(EXIT_SUCCESS)
                }
            }
        }

        if action == "unregister" {
            unregisterAllRegistrations(for: pluginURL)
            refreshFinder()
            exit(EXIT_SUCCESS)
        }

        let pluginkitAction: String
        switch action {
        case "ensure", "register":
            pluginkitAction = "-a"
        default:
            fputs("Unknown action: \(action)\n", stderr)
            exit(EXIT_FAILURE)
        }

        let pluginkit = Process()
        pluginkit.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        pluginkit.arguments = [pluginkitAction, pluginURL.path]

        do {
            try pluginkit.run()
            pluginkit.waitUntilExit()
        } catch {
            fputs("Unable to run pluginkit: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }

        guard pluginkit.terminationStatus == 0 else {
            fputs("pluginkit exited with status \(pluginkit.terminationStatus)\n", stderr)
            exit(EXIT_FAILURE)
        }

        refreshFinder()
    }

    private static func removeRegistration(at path: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = ["-r", path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }

    private static func unregisterAllRegistrations(for pluginURL: URL) {
        let inspect = Process()
        let output = Pipe()
        inspect.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        inspect.arguments = ["-m", "-ADv", "-i", "com.rightly.app.RightlyFinderExtension"]
        inspect.standardOutput = output
        inspect.standardError = output
        try? inspect.run()
        inspect.waitUntilExit()

        let registration = String(
            data: output.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let paths = registration
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> String? in
                guard line.contains("RightlyFinderExtension.appex") else { return nil }
                return line.split(separator: "\t").last.map(String.init)
            }

        var pathsToRemove = Set(paths)
        pathsToRemove.insert(pluginURL.path)
        for path in pathsToRemove {
            removeRegistration(at: path)
        }
    }

    private static func refreshFinder() {
        let refreshFinder = Process()
        refreshFinder.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        refreshFinder.arguments = ["Finder"]
        try? refreshFinder.run()
        refreshFinder.waitUntilExit()
    }

    private static func isExpectedRightlyApp(_ appURL: URL) -> Bool {
        guard appURL.lastPathComponent == "Rightly.app",
              appURL.path != "/",
              let bundle = Bundle(url: appURL) else {
            return false
        }
        return bundle.bundleIdentifier == "com.rightly.app"
    }

    private static func removeRightlyData() {
        let fileManager = FileManager.default
        let library = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
        let paths = [
            library.appendingPathComponent("Group Containers/group.com.rightly.app", isDirectory: true),
            library.appendingPathComponent("Containers/com.rightly.app", isDirectory: true),
            library.appendingPathComponent("Containers/com.rightly.app.RightlyFinderExtension", isDirectory: true),
            library.appendingPathComponent("Application Scripts/group.com.rightly.app", isDirectory: true),
            library.appendingPathComponent("Application Scripts/com.rightly.app", isDirectory: true),
            library.appendingPathComponent("Application Scripts/com.rightly.app.RightlyFinderExtension", isDirectory: true),
            library.appendingPathComponent("Preferences/com.rightly.app.plist", isDirectory: false),
            library.appendingPathComponent("Preferences/com.rightly.app.RightlyFinderExtension.plist", isDirectory: false),
            library.appendingPathComponent("Caches/com.rightly.app", isDirectory: true),
            library.appendingPathComponent("Caches/com.rightly.app.RightlyFinderExtension", isDirectory: true),
            library.appendingPathComponent("Saved Application State/com.rightly.app.savedState", isDirectory: true),
            URL(fileURLWithPath: "/Users/Shared/Rightly Debug", isDirectory: true),
        ]

        for url in paths where fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                fputs("Unable to remove \(url.path): \(error.localizedDescription)\n", stderr)
            }
        }
    }

    private static func waitForProcessToExit(_ processID: Int32) {
        for _ in 0..<100 {
            if kill(processID, 0) != 0 { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
}
