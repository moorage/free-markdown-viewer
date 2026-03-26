import SwiftUI

#if os(macOS)
import AppKit

struct SelectableDocumentTextView: NSViewRepresentable {
    let blocks: [MarkdownBlock]
    let fontScale: CGFloat
    let onOpenLink: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpenLink: onOpenLink)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.drawsBackground = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.allowsUndo = false
        textView.delegate = context.coordinator
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = .zero
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.linkTextAttributes = SelectableDocumentFormatter.linkTextAttributes
        textView.textStorage?.setAttributedString(
            SelectableDocumentFormatter.attributedText(from: blocks, fontScale: fontScale)
        )
        textView.setAccessibilityIdentifier(AccessibilityIDs.text)

        scrollView.setAccessibilityIdentifier(AccessibilityIDs.scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.onOpenLink = onOpenLink
        let attributedText = SelectableDocumentFormatter.attributedText(from: blocks, fontScale: fontScale)
        if !textView.attributedString().isEqual(to: attributedText) {
            textView.textStorage?.setAttributedString(attributedText)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onOpenLink: (URL) -> Void

        init(onOpenLink: @escaping (URL) -> Void) {
            self.onOpenLink = onOpenLink
        }

        func textView(
            _ textView: NSTextView,
            clickedOnLink link: Any,
            at charIndex: Int
        ) -> Bool {
            guard let url = link as? URL else { return false }
            onOpenLink(url)
            return true
        }
    }
}

#elseif os(iOS)
import UIKit

struct SelectableDocumentTextView: UIViewRepresentable {
    let blocks: [MarkdownBlock]
    let fontScale: CGFloat
    let onOpenLink: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpenLink: onOpenLink)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.delegate = context.coordinator
        textView.linkTextAttributes = SelectableDocumentFormatter.linkTextAttributes
        textView.attributedText = SelectableDocumentFormatter.attributedText(from: blocks, fontScale: fontScale)
        textView.accessibilityIdentifier = AccessibilityIDs.text
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.onOpenLink = onOpenLink
        let attributedText = SelectableDocumentFormatter.attributedText(from: blocks, fontScale: fontScale)
        if !(textView.attributedText?.isEqual(to: attributedText) ?? false) {
            textView.attributedText = attributedText
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onOpenLink: (URL) -> Void

        init(onOpenLink: @escaping (URL) -> Void) {
            self.onOpenLink = onOpenLink
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith url: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            onOpenLink(url)
            return false
        }
    }
}
#endif

#if os(macOS)
private typealias PlatformFont = NSFont
private typealias PlatformColor = NSColor
#elseif os(iOS)
private typealias PlatformFont = UIFont
private typealias PlatformColor = UIColor
#endif

enum SelectableDocumentFormatter {
    static var linkTextAttributes: [NSAttributedString.Key: Any] {
        [
            .foregroundColor: linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
    }

    static func attributedText(from blocks: [MarkdownBlock], fontScale: CGFloat) -> NSAttributedString {
        let rendered = NSMutableAttributedString()

        for index in blocks.indices {
            append(
                blocks[index],
                to: rendered,
                nestingLevel: blocks[index].indentLevel,
                fontScale: fontScale
            )
            if index < blocks.index(before: blocks.endIndex) {
                rendered.append(NSAttributedString(string: "\n\n"))
            }
        }

        return rendered
    }

    private static func append(
        _ block: MarkdownBlock,
        to rendered: NSMutableAttributedString,
        nestingLevel: Int,
        fontScale: CGFloat
    ) {
        rendered.append(styledText(for: block, nestingLevel: nestingLevel, fontScale: fontScale))

        guard !block.children.isEmpty else { return }

        rendered.append(NSAttributedString(string: "\n"))
        for index in block.children.indices {
            append(
                block.children[index],
                to: rendered,
                nestingLevel: nestingLevel + 1,
                fontScale: fontScale
            )
            if index < block.children.index(before: block.children.endIndex) {
                rendered.append(NSAttributedString(string: "\n"))
            }
        }
    }

    private static func styledText(
        for block: MarkdownBlock,
        nestingLevel: Int,
        fontScale: CGFloat
    ) -> NSAttributedString {
        let attributes = blockAttributes(for: block, nestingLevel: nestingLevel, fontScale: fontScale)
        let rendered = blockAttributedText(for: block, attributes: attributes)
        applyLinkStyling(to: rendered)
        return rendered
    }

    private static func blockAttributedText(
        for block: MarkdownBlock,
        attributes: [NSAttributedString.Key: Any]
    ) -> NSMutableAttributedString {
        switch block.kind {
        case .heading, .paragraph:
            return styledInlineText(MarkdownRenderer.attributedText(for: block), attributes: attributes)
        case .unorderedListItem, .orderedListItem:
            let rendered = NSMutableAttributedString(
                string: "\(listMarker(for: block)) ",
                attributes: attributes
            )
            rendered.append(styledInlineText(MarkdownRenderer.attributedText(for: block), attributes: attributes))
            return rendered
        case .blockquote:
            let rendered = NSMutableAttributedString(string: "> ", attributes: attributes)
            rendered.append(styledInlineText(MarkdownRenderer.attributedText(for: block), attributes: attributes))
            return rendered
        case .codeBlock, .rawHTML:
            return NSMutableAttributedString(string: block.sourceText, attributes: attributes)
        case .table:
            guard let table = block.table else {
                return NSMutableAttributedString(string: block.plainText, attributes: attributes)
            }
            let rendered = NSMutableAttributedString()
            appendTableRow(table.header, to: rendered, attributes: attributes)
            rendered.append(
                NSAttributedString(
                    string: "\n\(String(repeating: "-", count: max(table.header.count * 3, 3)))\n",
                    attributes: attributes
                )
            )
            for index in table.rows.indices {
                appendTableRow(table.rows[index], to: rendered, attributes: attributes)
                if index < table.rows.index(before: table.rows.endIndex) {
                    rendered.append(NSAttributedString(string: "\n", attributes: attributes))
                }
            }
            return rendered
        case .image, .animatedImage:
            guard let image = block.image else {
                return NSMutableAttributedString(string: block.plainText, attributes: attributes)
            }

            var lines: [String] = []
            if image.altText.isEmpty {
                lines.append("Image")
            } else {
                lines.append("Image: \(image.altText)")
            }
            lines.append("Source: \(image.sourceURL)")
            if let title = image.title, !title.isEmpty {
                lines.append("Title: \(title)")
            }
            return NSMutableAttributedString(string: lines.joined(separator: "\n"), attributes: attributes)
        case .video:
            guard let video = block.video else {
                return NSMutableAttributedString(string: block.plainText, attributes: attributes)
            }

            var lines: [String] = []
            if video.altText.isEmpty {
                lines.append("Video")
            } else {
                lines.append("Video: \(video.altText)")
            }
            lines.append("Source: \(video.sourceURL)")
            if let title = video.title, !title.isEmpty {
                lines.append("Title: \(title)")
            }
            return NSMutableAttributedString(string: lines.joined(separator: "\n"), attributes: attributes)
        case .thematicBreak:
            return NSMutableAttributedString(string: String(repeating: "-", count: 24), attributes: attributes)
        }
    }

    private static func blockAttributes(
        for block: MarkdownBlock,
        nestingLevel: Int,
        fontScale: CGFloat
    ) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let indentWidth = CGFloat(nestingLevel) * 20
        paragraphStyle.firstLineHeadIndent = indentWidth
        paragraphStyle.headIndent = indentWidth

        var attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            .foregroundColor: primaryTextColor
        ]

        switch block.kind {
        case .heading:
            attributes[.font] = headingFont(level: block.level ?? 1, fontScale: fontScale)
        case .paragraph, .unorderedListItem, .orderedListItem, .image, .animatedImage, .video:
            attributes[.font] = bodyFont(fontScale: fontScale)
        case .blockquote:
            paragraphStyle.firstLineHeadIndent = indentWidth + 12
            paragraphStyle.headIndent = indentWidth + 12
            attributes[.font] = italicBodyFont(fontScale: fontScale)
            attributes[.foregroundColor] = secondaryTextColor
        case .codeBlock:
            attributes[.font] = monospacedBodyFont(fontScale: fontScale)
            attributes[.backgroundColor] = codeBlockBackgroundColor
        case .table:
            attributes[.font] = monospacedBodyFont(fontScale: fontScale)
        case .rawHTML, .thematicBreak:
            attributes[.font] = monospacedBodyFont(fontScale: fontScale)
            attributes[.foregroundColor] = secondaryTextColor
        }

        return attributes
    }

    private static func listMarker(for block: MarkdownBlock) -> String {
        if block.isTaskItem {
            return block.isTaskCompleted == true ? "[x]" : "[ ]"
        }
        if block.kind == .orderedListItem {
            return "\(block.listItemIndex ?? 1)."
        }
        return "-"
    }

    private static func bodyFont(fontScale: CGFloat) -> PlatformFont {
        scaled(PlatformFont.preferredFont(forTextStyle: .body), by: fontScale)
    }

    private static func italicBodyFont(fontScale: CGFloat) -> PlatformFont {
        let baseFont = bodyFont(fontScale: fontScale)
        #if os(macOS)
        return NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        #else
        return baseFont.withTraits(.traitItalic)
        #endif
    }

    private static func monospacedBodyFont(fontScale: CGFloat) -> PlatformFont {
        PlatformFont.monospacedSystemFont(ofSize: bodyFont(fontScale: fontScale).pointSize, weight: .regular)
    }

    private static var codeBlockBackgroundColor: PlatformColor {
        #if os(macOS)
        return .textBackgroundColor
        #else
        return .secondarySystemBackground
        #endif
    }

    private static var primaryTextColor: PlatformColor {
        #if os(macOS)
        return .labelColor
        #else
        return .label
        #endif
    }

    private static var secondaryTextColor: PlatformColor {
        #if os(macOS)
        return .secondaryLabelColor
        #else
        return .secondaryLabel
        #endif
    }

    private static var linkColor: PlatformColor {
        #if os(macOS)
        return .linkColor
        #else
        return .link
        #endif
    }

    private static func headingFont(level: Int, fontScale: CGFloat) -> PlatformFont {
        let pointSize = bodyFont(fontScale: fontScale).pointSize
        switch level {
        case 1:
            return PlatformFont.systemFont(ofSize: pointSize * 1.8, weight: .semibold)
        case 2:
            return PlatformFont.systemFont(ofSize: pointSize * 1.45, weight: .semibold)
        case 3:
            return PlatformFont.systemFont(ofSize: pointSize * 1.2, weight: .semibold)
        default:
            return PlatformFont.systemFont(ofSize: pointSize, weight: .semibold)
        }
    }

    private static func scaled(_ font: PlatformFont, by fontScale: CGFloat) -> PlatformFont {
        font.withSize(font.pointSize * fontScale)
    }

    private static func styledInlineText(
        _ text: AttributedString,
        attributes: [NSAttributedString.Key: Any]
    ) -> NSMutableAttributedString {
        let rendered = NSMutableAttributedString(text)
        rendered.addAttributes(attributes, range: NSRange(location: 0, length: rendered.length))
        return rendered
    }

    private static func appendTableRow(
        _ cells: [MarkdownTableCell],
        to rendered: NSMutableAttributedString,
        attributes: [NSAttributedString.Key: Any]
    ) {
        for index in cells.indices {
            if index > 0 {
                rendered.append(NSAttributedString(string: " | ", attributes: attributes))
            }
            rendered.append(styledInlineText(MarkdownRenderer.attributedText(for: cells[index]), attributes: attributes))
        }
    }

    private static func applyLinkStyling(to text: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: text.length)
        text.enumerateAttribute(.link, in: fullRange) { value, range, _ in
            guard value != nil else { return }
            text.addAttributes(linkTextAttributes, range: range)
        }
    }
}

#if os(iOS)
private extension UIFont {
    func withTraits(_ symbolicTraits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(symbolicTraits) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
#endif
