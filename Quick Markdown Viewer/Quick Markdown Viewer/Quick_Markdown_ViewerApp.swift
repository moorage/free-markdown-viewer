//
//  Quick_Markdown_ViewerApp.swift
//  Quick Markdown Viewer
//
//  Created by Matthew Moore on 3/19/26.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct Quick_Markdown_ViewerApp: App {
    private let launchOptions: HarnessLaunchOptions
    @StateObject private var sessionStore: WorkspaceWindowSessionStore

    init() {
        let resolvedLaunchOptions = HarnessLaunchOptions.fromProcess()
        launchOptions = resolvedLaunchOptions
        UITestOpenFolderSelectionStore.shared.configureIfNeeded(using: resolvedLaunchOptions)
        _sessionStore = StateObject(
            wrappedValue: WorkspaceWindowSessionStore(launchOptions: resolvedLaunchOptions)
        )
        #if os(macOS)
        Self.installApplicationIcon()
        #endif
    }

    var body: some Scene {
        WindowGroup(for: String.self) { $sceneID in
            WindowSceneRootView(
                launchOptions: launchOptions,
                sceneID: sceneID,
                sessionStore: sessionStore
            )
        } defaultValue: {
            UUID().uuidString
        }
        #if os(macOS)
        .commands {
            WindowOpenFolderCommands()
        }
        #endif
    }

    #if os(macOS)
    private static func installApplicationIcon() {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = iconImage
            return
        }

        if let iconImage = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = iconImage
        }
    }
    #endif
}
