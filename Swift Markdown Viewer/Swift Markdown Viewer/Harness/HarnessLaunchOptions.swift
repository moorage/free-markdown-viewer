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

    static func fromProcess(arguments: [String] = ProcessInfo.processInfo.arguments) -> HarnessLaunchOptions {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
                return nil
            }
            return arguments[index + 1]
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

    private static func resolvedURL(from raw: String) -> URL {
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
