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

    var body: some View {
        AppRootView(model: model, onOpenFolder: onOpenFolder)
    }
}
