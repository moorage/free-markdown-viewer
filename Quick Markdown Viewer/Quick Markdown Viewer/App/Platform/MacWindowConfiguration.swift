#if os(macOS)
import AppKit
import SwiftUI

struct MacWindowConfiguration: NSViewRepresentable {
    let title: String
    let contentSize: CGSize?

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.title = title
            window.titleVisibility = .visible
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unifiedCompact
            window.isMovableByWindowBackground = true
            if let contentSize {
                let resolvedSize = NSSize(width: max(contentSize.width, 1), height: max(contentSize.height, 1))
                if window.contentLayoutRect.size != resolvedSize {
                    window.setContentSize(resolvedSize)
                }
            }
        }
    }
}
#endif
