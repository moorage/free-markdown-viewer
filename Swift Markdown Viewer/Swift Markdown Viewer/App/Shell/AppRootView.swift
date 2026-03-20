import SwiftUI

struct AppRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GeometryReader { proxy in
            let renderSize = resolvedRenderSize(from: proxy.size)
            ViewerShellView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    model.bootstrap()
                }
                .onAppear {
                    model.installScreenshotWriter { url in
                        try PlatformScreenshotWriter.write(
                            content: ViewerShellView(model: model)
                                .frame(width: renderSize.width, height: renderSize.height),
                            to: url
                        )
                    }
                    model.updateViewport(renderSize)
                    model.fulfillLaunchArtifactRequestsIfNeeded()
                }
                .onChange(of: proxy.size) { _, newSize in
                    model.updateViewport(resolvedRenderSize(from: newSize))
                    model.fulfillLaunchArtifactRequestsIfNeeded()
                }
                .onChange(of: model.isReady) { _, _ in
                    model.fulfillLaunchArtifactRequestsIfNeeded()
                }
        }
    }

    private func resolvedRenderSize(from liveSize: CGSize) -> CGSize {
        model.launchOptions.windowSize ?? liveSize
    }
}
