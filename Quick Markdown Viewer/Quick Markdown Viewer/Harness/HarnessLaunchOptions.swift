import CoreGraphics
import Foundation
#if os(iOS)
import UIKit
#endif

enum HarnessPlatformTarget: String, Codable {
    case macos
    case ios
}

enum HarnessDeviceClass: String, Codable {
    case mac
    case iphone
    case ipad
}

struct HarnessLaunchOptions {
    let fixtureRoot: URL?
    let openFile: String?
    let uiTestOpenFolderURLs: [URL]
    let theme: String?
    let windowSize: CGSize?
    let disableFileWatch: Bool
    let dumpVisibleStateURL: URL?
    let dumpPerfStateURL: URL?
    let screenshotPathURL: URL?
    let commandDirectoryURL: URL?
    let uiTestMode: Bool
    let platformTarget: HarnessPlatformTarget
    let deviceClass: HarnessDeviceClass

    var uiTestOpenFolderURL: URL? {
        uiTestOpenFolderURLs.first
    }

    init(
        fixtureRoot: URL?,
        openFile: String?,
        uiTestOpenFolderURL: URL?,
        theme: String?,
        windowSize: CGSize?,
        disableFileWatch: Bool,
        dumpVisibleStateURL: URL?,
        dumpPerfStateURL: URL?,
        screenshotPathURL: URL?,
        commandDirectoryURL: URL?,
        uiTestMode: Bool,
        platformTarget: HarnessPlatformTarget,
        deviceClass: HarnessDeviceClass
    ) {
        self.init(
            fixtureRoot: fixtureRoot,
            openFile: openFile,
            uiTestOpenFolderURLs: uiTestOpenFolderURL.map { [$0] } ?? [],
            theme: theme,
            windowSize: windowSize,
            disableFileWatch: disableFileWatch,
            dumpVisibleStateURL: dumpVisibleStateURL,
            dumpPerfStateURL: dumpPerfStateURL,
            screenshotPathURL: screenshotPathURL,
            commandDirectoryURL: commandDirectoryURL,
            uiTestMode: uiTestMode,
            platformTarget: platformTarget,
            deviceClass: deviceClass
        )
    }

    init(
        fixtureRoot: URL?,
        openFile: String?,
        uiTestOpenFolderURLs: [URL],
        theme: String?,
        windowSize: CGSize?,
        disableFileWatch: Bool,
        dumpVisibleStateURL: URL?,
        dumpPerfStateURL: URL?,
        screenshotPathURL: URL?,
        commandDirectoryURL: URL?,
        uiTestMode: Bool,
        platformTarget: HarnessPlatformTarget,
        deviceClass: HarnessDeviceClass
    ) {
        self.fixtureRoot = fixtureRoot
        self.openFile = openFile
        self.uiTestOpenFolderURLs = uiTestOpenFolderURLs
        self.theme = theme
        self.windowSize = windowSize
        self.disableFileWatch = disableFileWatch
        self.dumpVisibleStateURL = dumpVisibleStateURL
        self.dumpPerfStateURL = dumpPerfStateURL
        self.screenshotPathURL = screenshotPathURL
        self.commandDirectoryURL = commandDirectoryURL
        self.uiTestMode = uiTestMode
        self.platformTarget = platformTarget
        self.deviceClass = deviceClass
    }

    static func fromProcess(arguments: [String] = ProcessInfo.processInfo.arguments) -> HarnessLaunchOptions {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
                return nil
            }
            return arguments[index + 1]
        }

        func values(after flag: String) -> [String] {
            var resolved: [String] = []
            var index = arguments.startIndex
            while index < arguments.endIndex {
                if arguments[index] == flag, arguments.indices.contains(index + 1) {
                    resolved.append(arguments[index + 1])
                    index += 2
                } else {
                    index += 1
                }
            }
            return resolved
        }

        func resolveURL(after flag: String) -> URL? {
            guard let raw = value(after: flag) else { return nil }
            return resolvedURL(from: raw)
        }

        let windowSize = value(after: "--window-size").flatMap { raw -> CGSize? in
            let parts = raw.split(separator: "x").compactMap { Double($0) }
            guard parts.count == 2 else { return nil }
            return CGSize(width: parts[0], height: parts[1])
        }

        let platformTarget = HarnessPlatformTarget(rawValue: value(after: "--platform-target") ?? "") ?? defaultPlatformTarget()
        let deviceClass = HarnessDeviceClass(rawValue: value(after: "--device-class") ?? "") ?? defaultDeviceClass(for: platformTarget)

        return HarnessLaunchOptions(
            fixtureRoot: resolveURL(after: "--fixture-root"),
            openFile: value(after: "--open-file"),
            uiTestOpenFolderURLs: values(after: "--ui-test-open-folder").map(resolvedURL(from:)),
            theme: value(after: "--theme"),
            windowSize: windowSize,
            disableFileWatch: arguments.contains("--disable-file-watch"),
            dumpVisibleStateURL: resolveURL(after: "--dump-visible-state"),
            dumpPerfStateURL: resolveURL(after: "--dump-perf-state"),
            screenshotPathURL: resolveURL(after: "--screenshot-path") ?? value(after: "--screenshot-dir").map { resolvedURL(from: $0).appendingPathComponent("window.png") },
            commandDirectoryURL: resolveURL(after: "--harness-command-dir"),
            uiTestMode: arguments.contains("--ui-test-mode"),
            platformTarget: platformTarget,
            deviceClass: deviceClass
        )
    }

    private nonisolated static func resolvedURL(from raw: String) -> URL {
        let candidate = URL(fileURLWithPath: raw)
        if candidate.path.hasPrefix("/") {
            return candidate
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(raw)
    }

    private static func defaultPlatformTarget() -> HarnessPlatformTarget {
        #if os(macOS)
        return .macos
        #else
        return .ios
        #endif
    }

    private static func defaultDeviceClass(for platformTarget: HarnessPlatformTarget) -> HarnessDeviceClass {
        switch platformTarget {
        case .macos:
            return .mac
        case .ios:
            #if os(iOS)
            return UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
            #else
            return .iphone
            #endif
        }
    }
}
