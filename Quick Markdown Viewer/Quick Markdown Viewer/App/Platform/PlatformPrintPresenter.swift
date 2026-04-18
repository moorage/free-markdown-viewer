import Foundation
import SwiftUI

#if os(macOS)
import AppKit
import PDFKit

enum PlatformPrintPresenter {
    private final class PaginatedHostingPrintView: NSView {
        private let pageHeight: CGFloat

        init(contentView: NSView, pageHeight: CGFloat) {
            self.pageHeight = pageHeight
            super.init(frame: contentView.frame)
            addSubview(contentView)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var isFlipped: Bool {
            true
        }

        override func knowsPageRange(_ range: NSRangePointer) -> Bool {
            let pageCount = max(Int(ceil(bounds.height / pageHeight)), 1)
            range.pointee = NSRange(location: 1, length: pageCount)
            return true
        }

        override func rectForPage(_ page: Int) -> NSRect {
            let originY = CGFloat(page - 1) * pageHeight
            let remainingHeight = max(bounds.height - originY, 0)
            let resolvedHeight = min(pageHeight, remainingHeight)
            return NSRect(
                x: 0,
                y: originY,
                width: bounds.width,
                height: max(resolvedHeight, pageHeight)
            )
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
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: layout.printableRect.width,
            height: max(fittingSize.height, layout.printableRect.height)
        )
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
        let printView = paginatedPrintView(for: composition, layout: layout)
        let sourceBounds = printView.bounds
        let pageHeight = layout.printableRect.height
        let outputData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: sourceBounds.width, height: pageHeight)
        guard let consumer = CGDataConsumer(data: outputData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        let pageCount = Int(ceil(sourceBounds.height / pageHeight))
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        for pageIndex in 0..<pageCount {
            let originY = CGFloat(pageIndex) * pageHeight
            let sliceHeight = min(pageHeight, sourceBounds.height - originY)
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
            printView.cacheDisplay(in: sliceRect, to: bitmap)
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
        }

        context.closePDF()
        return outputData as Data
    }

    @MainActor
    static func present(_ composition: DocumentPrintComposition, from window: NSWindow?) {
        let pdfData = pdfData(for: composition, layout: .letter)
        guard
            let document = PDFDocument(data: pdfData),
            let operation = document.printOperation(
                for: NSPrintInfo.shared,
                scalingMode: .pageScaleNone,
                autoRotate: true
            )
        else {
            NSSound.beep()
            return
        }
        operation.jobTitle = composition.scope.title
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        if let window {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
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
