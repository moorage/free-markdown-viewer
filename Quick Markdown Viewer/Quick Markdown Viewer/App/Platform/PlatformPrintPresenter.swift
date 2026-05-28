import Foundation
import SwiftUI

#if os(macOS)
import AppKit
import PDFKit

enum PlatformPrintPresenter {
    private final class PaginatedHostingPrintView: NSView {
        private let contentView: NSView
        private let pageHeight: CGFloat
        private let pageBitmapCache = NSCache<NSNumber, NSBitmapImageRep>()

        init(contentView: NSView, pageHeight: CGFloat) {
            self.contentView = contentView
            self.pageHeight = pageHeight
            super.init(frame: contentView.frame)
            pageBitmapCache.countLimit = 8
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var isFlipped: Bool {
            true
        }

        private var pageCount: Int {
            max(Int(ceil(contentView.bounds.height / pageHeight)), 1)
        }

        override func knowsPageRange(_ range: NSRangePointer) -> Bool {
            range.pointee = NSRange(location: 1, length: pageCount)
            return true
        }

        override func rectForPage(_ page: Int) -> NSRect {
            let originY = CGFloat(page - 1) * pageHeight
            let remainingHeight = max(contentView.bounds.height - originY, 0)
            let resolvedHeight = min(pageHeight, remainingHeight)
            return NSRect(
                x: 0,
                y: originY,
                width: bounds.width,
                height: max(resolvedHeight, pageHeight)
            )
        }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.white.setFill()
            dirtyRect.fill()

            let firstPageIndex = max(Int(floor(dirtyRect.minY / pageHeight)), 0)
            let lastPageIndex = min(
                Int(floor(max(dirtyRect.maxY - CGFloat.ulpOfOne, 0) / pageHeight)),
                pageCount - 1
            )
            guard firstPageIndex <= lastPageIndex else { return }

            for pageIndex in firstPageIndex...lastPageIndex {
                drawPage(at: pageIndex)
            }
        }

        private func drawPage(at pageIndex: Int) {
            let originY = CGFloat(pageIndex) * pageHeight
            let sliceHeight = min(pageHeight, contentView.bounds.height - originY)
            guard sliceHeight > 0, let bitmap = pageBitmap(for: pageIndex, originY: originY, sliceHeight: sliceHeight) else {
                return
            }

            let image = NSImage(size: bitmap.size)
            image.addRepresentation(bitmap)
            image.draw(
                in: NSRect(x: 0, y: originY, width: bounds.width, height: sliceHeight),
                from: NSRect(origin: .zero, size: bitmap.size),
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
        }

        private func pageBitmap(for pageIndex: Int, originY: CGFloat, sliceHeight: CGFloat) -> NSBitmapImageRep? {
            let cacheKey = NSNumber(value: pageIndex)
            if let cachedBitmap = pageBitmapCache.object(forKey: cacheKey) {
                return cachedBitmap
            }

            let scale = NSScreen.main?.backingScaleFactor ?? 2
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: max(Int(contentView.bounds.width * scale), 1),
                pixelsHigh: max(Int(sliceHeight * scale), 1),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
            guard let bitmap else { return nil }

            bitmap.size = NSSize(width: contentView.bounds.width, height: sliceHeight)
            contentView.displayIfNeeded()
            contentView.cacheDisplay(
                in: NSRect(x: 0, y: originY, width: contentView.bounds.width, height: sliceHeight),
                to: bitmap
            )
            pageBitmapCache.setObject(bitmap, forKey: cacheKey)
            return bitmap
        }
    }

    @MainActor
    private final class ModalPrintOperationRetainer: NSObject {
        private static var activeRetainers: [ObjectIdentifier: ModalPrintOperationRetainer] = [:]
        private let operation: NSPrintOperation

        private init(operation: NSPrintOperation) {
            self.operation = operation
            super.init()
        }

        static func run(_ operation: NSPrintOperation, for window: NSWindow) {
            let retainer = ModalPrintOperationRetainer(operation: operation)
            activeRetainers[ObjectIdentifier(operation)] = retainer
            operation.runModal(
                for: window,
                delegate: retainer,
                didRun: #selector(printOperationDidRun(_:success:contextInfo:)),
                contextInfo: nil
            )
        }

        @objc private func printOperationDidRun(
            _ operation: NSPrintOperation,
            success: Bool,
            contextInfo: UnsafeMutableRawPointer?
        ) {
            Self.activeRetainers.removeValue(forKey: ObjectIdentifier(operation))
        }
    }

    @MainActor
    private static func hostingView(
        for composition: DocumentPrintComposition,
        layout: DocumentPrintPageLayout
    ) -> NSHostingView<PrintableDocumentCompositionView> {
        let hostingView = NSHostingView(
            rootView: PrintableDocumentCompositionView(
                composition: composition,
                pageLayout: layout
            )
        )
        hostingView.appearance = NSAppearance(named: .aqua)
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: layout.printableRect.width,
            height: layout.printableRect.height
        )
        hostingView.layoutSubtreeIfNeeded()
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: layout.printableRect.width,
            height: max(fittingSize.height, layout.printableRect.height)
        )
        hostingView.layoutSubtreeIfNeeded()
        return hostingView
    }

    @MainActor
    private static func paginatedPrintView(
        for composition: DocumentPrintComposition,
        layout: DocumentPrintPageLayout
    ) -> NSView {
        let contentView = hostingView(for: composition, layout: layout)
        contentView.layoutSubtreeIfNeeded()
        return PaginatedHostingPrintView(
            contentView: contentView,
            pageHeight: layout.printableRect.height
        )
    }

    @MainActor
    private static func printInfo(for layout: DocumentPrintPageLayout) -> NSPrintInfo {
        let printInfo = NSPrintInfo()
        printInfo.paperSize = layout.paperSize
        printInfo.topMargin = layout.topInset
        printInfo.leftMargin = layout.leadingInset
        printInfo.bottomMargin = layout.bottomInset
        printInfo.rightMargin = layout.trailingInset
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        return printInfo
    }

    @MainActor
    private static func pdfData(
        for composition: DocumentPrintComposition,
        layout: DocumentPrintPageLayout
    ) -> Data {
        let contentView = hostingView(for: composition, layout: layout)
        contentView.displayIfNeeded()
        let sourceBounds = contentView.bounds
        let pageHeight = layout.printableRect.height
        let outputData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: sourceBounds.width, height: pageHeight)
        guard let consumer = CGDataConsumer(data: outputData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return fallbackPDFData(for: composition, layout: layout)
        }

        let pageCount = max(Int(ceil(sourceBounds.height / pageHeight)), 1)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        var renderedPageCount = 0
        for pageIndex in 0..<pageCount {
            let originY = CGFloat(pageIndex) * pageHeight
            let sliceHeight = min(pageHeight, sourceBounds.height - originY)
            guard sliceHeight > 0 else { continue }
            let sliceRect = NSRect(x: 0, y: originY, width: sourceBounds.width, height: sliceHeight)
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(sourceBounds.width * scale),
                pixelsHigh: Int(sliceHeight * scale),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
            guard let bitmap else { continue }
            bitmap.size = NSSize(width: sourceBounds.width, height: sliceHeight)
            contentView.cacheDisplay(in: sliceRect, to: bitmap)
            guard let cgImage = bitmap.cgImage else { continue }

            context.beginPDFPage(nil)
            context.draw(
                cgImage,
                in: CGRect(
                    x: 0,
                    y: mediaBox.height - sliceHeight,
                    width: mediaBox.width,
                    height: sliceHeight
                )
            )
            context.endPDFPage()
            renderedPageCount += 1
        }

        context.closePDF()
        guard renderedPageCount > 0 else {
            return fallbackPDFData(for: composition, layout: layout)
        }
        return outputData as Data
    }

    @MainActor
    private static func fallbackPDFData(
        for composition: DocumentPrintComposition,
        layout: DocumentPrintPageLayout
    ) -> Data {
        let outputData = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: layout.paperSize)
        guard let consumer = CGDataConsumer(data: outputData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(mediaBox)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let text = composition.plainText.isEmpty ? composition.workspaceTitle : composition.plainText
        let attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.black
            ]
        )
        attributedText.draw(
            in: NSRect(
                x: layout.leadingInset,
                y: layout.bottomInset,
                width: layout.printableRect.width,
                height: layout.printableRect.height
            )
        )
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
        return outputData as Data
    }

    @MainActor
    static func printInfo(from printSettings: [NSPrintInfo.AttributeKey: Any]) -> NSPrintInfo {
        guard printSettings.isEmpty == false else {
            return NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo()
        }
        return NSPrintInfo(dictionary: printSettings)
    }

    @MainActor
    static func present(
        _ composition: DocumentPrintComposition,
        from window: NSWindow?,
        printInfo: NSPrintInfo? = nil,
        showsPrintPanel: Bool = true
    ) {
        let printView = paginatedPrintView(for: composition, layout: .letter)
        let operation = NSPrintOperation(view: printView, printInfo: printInfo ?? Self.printInfo(for: .letter))
        operation.jobTitle = composition.scope.title
        operation.showsPrintPanel = showsPrintPanel
        operation.showsProgressPanel = showsPrintPanel
        if let window {
            ModalPrintOperationRetainer.run(operation, for: window)
        } else {
            operation.run()
        }
    }

    @MainActor
    static func exportPrintOperationPDF(_ composition: DocumentPrintComposition, to destinationURL: URL) throws {
        let layout = DocumentPrintPageLayout.letter
        let printView = paginatedPrintView(for: composition, layout: layout)
        let printInfo = Self.printInfo(for: layout)
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = destinationURL
        let operation = NSPrintOperation(view: printView, printInfo: printInfo)
        operation.jobTitle = composition.scope.title
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false

        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard operation.run() else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    @MainActor
    static func exportPDF(_ composition: DocumentPrintComposition, to destinationURL: URL) throws {
        let pdfData = pdfData(for: composition, layout: .letter)
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try pdfData.write(to: destinationURL)
    }
}

#elseif os(iOS)
import UIKit

enum PlatformPrintPresenter {
    @MainActor
    private static func measuredContentHeight(
        for composition: DocumentPrintComposition,
        layout: DocumentPrintPageLayout
    ) -> CGFloat {
        let hostingController = UIHostingController(
            rootView: AnyView(
                PrintableDocumentCompositionView(
                    composition: composition,
                    pageLayout: layout
                )
                .environment(\.colorScheme, .light)
            )
        )
        hostingController.view.backgroundColor = .white
        let contentWidth = layout.printableRect.width
        hostingController.view.bounds = CGRect(x: 0, y: 0, width: contentWidth, height: 1)
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        let fittingSize = hostingController.sizeThatFits(in: CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
        return max(fittingSize.height, layout.printableRect.height)
    }

    @MainActor
    private static func pageSliceImage(
        for composition: DocumentPrintComposition,
        layout: DocumentPrintPageLayout,
        originY: CGFloat
    ) -> UIImage? {
        let pageHeight = layout.printableRect.height
        let pageContent = PrintableDocumentCompositionView(
            composition: composition,
            pageLayout: layout
        )
        .environment(\.colorScheme, .light)
        .frame(
            width: layout.printableRect.width,
            alignment: .topLeading
        )
        .offset(x: 0, y: -originY)
        .frame(
            width: layout.printableRect.width,
            height: pageHeight,
            alignment: .topLeading
        )
        .background(Color.white)
        .clipped()

        let renderer = ImageRenderer(content: pageContent)
        renderer.proposedSize = ProposedViewSize(
            width: layout.printableRect.width,
            height: pageHeight
        )
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }

    @MainActor
    private static func pdfData(
        for composition: DocumentPrintComposition,
        layout: DocumentPrintPageLayout
    ) -> Data {
        let contentHeight = measuredContentHeight(for: composition, layout: layout)
        let pageHeight = layout.printableRect.height
        let pageCount = max(Int(ceil(contentHeight / pageHeight)), 1)
        let paperRect = CGRect(origin: .zero, size: layout.paperSize)
        let renderer = UIGraphicsPDFRenderer(bounds: paperRect)

        return renderer.pdfData { context in
            for pageIndex in 0..<pageCount {
                let originY = CGFloat(pageIndex) * pageHeight
                context.beginPage()
                UIColor.white.setFill()
                context.fill(paperRect)
                pageSliceImage(
                    for: composition,
                    layout: layout,
                    originY: originY
                )?.draw(in: layout.printableRect)
            }
        }
    }

    @MainActor
    static func present(_ composition: DocumentPrintComposition) {
        let controller = UIPrintInteractionController.shared
        let layout = DocumentPrintPageLayout.letter
        let pdfData = pdfData(for: composition, layout: layout)
        controller.printingItem = pdfData
        controller.printInfo = {
            let info = UIPrintInfo(dictionary: nil)
            info.jobName = composition.scope.title
            info.outputType = .general
            return info
        }()

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
              .first(where: { $0.activationState == .foregroundActive }),
              let rootViewController = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            controller.present(animated: true)
            return
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            controller.present(from: rootViewController.view.bounds, in: rootViewController.view, animated: true)
        } else {
            controller.present(animated: true)
        }
    }

    @MainActor
    static func exportPDF(_ composition: DocumentPrintComposition, to destinationURL: URL) throws {
        let pdfData = pdfData(for: composition, layout: .letter)
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try pdfData.write(to: destinationURL)
    }
}
#endif
