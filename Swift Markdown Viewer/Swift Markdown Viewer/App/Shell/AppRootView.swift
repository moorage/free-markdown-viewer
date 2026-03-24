import SwiftUI
#if os(macOS)
import AppKit
#endif

struct AppRootView: View {
    @ObservedObject var model: AppModel
    let onOpenFolder: (() -> Void)?
    #if os(macOS)
    @State private var liveWindow: NSWindow?
    #endif

    var body: some View {
        GeometryReader { proxy in
            let renderSize = resolvedRenderSize(from: proxy.size)
            ViewerShellView(model: model, onOpenFolder: onOpenFolder)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    model.bootstrap()
                }
                .onAppear {
                    #if os(macOS)
                    if let liveWindow {
                        model.installScreenshotWriter { url in
                            try PlatformScreenshotWriter.write(window: liveWindow, to: url)
                        }
                    } else {
                        model.installScreenshotWriter { url in
                            try PlatformScreenshotWriter.write(
                                content: ViewerShellView(model: model, onOpenFolder: onOpenFolder)
                                    .frame(width: renderSize.width, height: renderSize.height),
                                to: url
                            )
                        }
                    }
                    #else
                    model.installScreenshotWriter { url in
                        try PlatformScreenshotWriter.write(
                            content: ViewerShellView(model: model, onOpenFolder: onOpenFolder)
                                .frame(width: renderSize.width, height: renderSize.height),
                            to: url
                        )
                    }
                    #endif
                    model.updateViewport(renderSize)
                    model.fulfillLaunchArtifactRequestsIfNeeded()
                }
                .onChange(of: proxy.size) { newSize in
                    model.updateViewport(resolvedRenderSize(from: newSize))
                    model.fulfillLaunchArtifactRequestsIfNeeded()
                }
                .onChange(of: model.isReady) { _ in
                    model.fulfillLaunchArtifactRequestsIfNeeded()
                }
                #if os(macOS)
                .background(WindowAccessorView { window in
                    liveWindow = window
                    model.installScreenshotWriter { url in
                        try PlatformScreenshotWriter.write(window: window, to: url)
                    }
                    model.fulfillLaunchArtifactRequestsIfNeeded()
                })
                #endif
        }
    }

    private func resolvedRenderSize(from liveSize: CGSize) -> CGSize {
        model.launchOptions.windowSize ?? liveSize
    }
}

#if os(macOS)
private struct WindowAccessorView: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}
#endif
