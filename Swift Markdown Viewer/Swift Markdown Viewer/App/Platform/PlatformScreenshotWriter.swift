import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum PlatformScreenshotWriter {
    @MainActor
    static func write<Content: View>(content: Content, to url: URL) throws {
        #if os(macOS)
        let renderer = ImageRenderer(content: content)
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        #else
        let host = UIHostingController(rootView: content)
        let targetSize = host.sizeThatFits(in: CGSize(width: 1024, height: 768))
        let renderSize = CGSize(
            width: max(targetSize.width, 1),
            height: max(targetSize.height, 1)
        )
        host.view.bounds = CGRect(origin: .zero, size: renderSize)
        host.view.backgroundColor = .clear
        host.view.layoutIfNeeded()

        let image = UIGraphicsImageRenderer(size: renderSize).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        guard let pngData = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        #endif
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try pngData.write(to: url)
    }
}
