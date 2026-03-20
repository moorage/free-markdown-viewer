//
//  Swift_Markdown_ViewerApp.swift
//  Swift Markdown Viewer
//
//  Created by Matthew Moore on 3/19/26.
//

import SwiftUI

@main
struct Swift_Markdown_ViewerApp: App {
    @StateObject private var model = AppModel(launchOptions: HarnessLaunchOptions.fromProcess())

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
