//
//  ContentView.swift
//  Quick Markdown Viewer
//
//  Created by Matthew Moore on 3/19/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    let onOpenFolder: (() -> Void)?
    let onOpenGitHubURLPrompt: (() -> Void)?
    let onInstallCommandLineTool: (() -> Void)?
    let shouldShowCommandLineToolPrompt: Bool

    var body: some View {
        AppRootView(
            model: model,
            onOpenFolder: onOpenFolder,
            onOpenGitHubURLPrompt: onOpenGitHubURLPrompt,
            onInstallCommandLineTool: onInstallCommandLineTool,
            shouldShowCommandLineToolPrompt: shouldShowCommandLineToolPrompt
        )
    }
}
