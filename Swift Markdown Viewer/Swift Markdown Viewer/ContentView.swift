//
//  ContentView.swift
//  Swift Markdown Viewer
//
//  Created by Matthew Moore on 3/19/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        AppRootView(model: model)
    }
}
