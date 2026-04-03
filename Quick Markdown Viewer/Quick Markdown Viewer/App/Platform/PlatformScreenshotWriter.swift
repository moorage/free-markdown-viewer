import SwiftUI

#if os(macOS)
import AppKit
import CoreGraphics
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

    #if os(macOS)
    @MainActor
    static func write(window: NSWindow, to url: URL) throws {
        let cgImage: CGImage?
        if let screenFrame = window.screen?.frame {
            let windowFrame = window.frame
            let captureRect = CGRect(
                x: windowFrame.origin.x,
                y: screenFrame.height - windowFrame.origin.y - windowFrame.height,
                width: windowFrame.width,
                height: windowFrame.height
            )
            cgImage = CGWindowListCreateImage(
                captureRect,
                .optionIncludingWindow,
                CGWindowID(window.windowNumber),
                [.boundsIgnoreFraming, .bestResolution]
            )
        } else {
            cgImage = nil
        }

        let imageRep: NSBitmapImageRep?
        if let cgImage {
            imageRep = NSBitmapImageRep(cgImage: cgImage)
        } else if let contentView = window.contentView {
            let bounds = contentView.bounds
            if bounds.width <= 0 || bounds.height <= 0 {
                throw CocoaError(.fileWriteUnknown)
            }
            let fallbackRep = contentView.bitmapImageRepForCachingDisplay(in: bounds)
            fallbackRep.map { contentView.cacheDisplay(in: bounds, to: $0) }
            imageRep = fallbackRep
        } else {
            imageRep = nil
        }

        guard let imageRep,
              let pngData = imageRep.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try pngData.write(to: url)
    }
    #endif
}
