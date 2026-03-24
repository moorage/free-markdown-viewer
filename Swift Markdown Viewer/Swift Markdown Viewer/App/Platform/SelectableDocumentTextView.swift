import SwiftUI

#if os(macOS)
import AppKit

struct SelectableDocumentTextView: NSViewRepresentable {
    let blocks: [MarkdownBlock]

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
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = .zero
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textStorage?.setAttributedString(SelectableDocumentFormatter.attributedText(from: blocks))
        textView.setAccessibilityIdentifier(AccessibilityIDs.text)

        scrollView.setAccessibilityIdentifier(AccessibilityIDs.scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let attributedText = SelectableDocumentFormatter.attributedText(from: blocks)
        if !textView.attributedString().isEqual(to: attributedText) {
            textView.textStorage?.setAttributedString(attributedText)
        }
    }
}

#elseif os(iOS)
import UIKit

struct SelectableDocumentTextView: UIViewRepresentable {
    let blocks: [MarkdownBlock]

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.attributedText = SelectableDocumentFormatter.attributedText(from: blocks)
        textView.accessibilityIdentifier = AccessibilityIDs.text
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let attributedText = SelectableDocumentFormatter.attributedText(from: blocks)
        if !(textView.attributedText?.isEqual(to: attributedText) ?? false) {
            textView.attributedText = attributedText
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
    static func attributedText(from blocks: [MarkdownBlock]) -> NSAttributedString {
        let rendered = NSMutableAttributedString()

        for index in blocks.indices {
            append(blocks[index], to: rendered, nestingLevel: blocks[index].indentLevel)
            if index < blocks.index(before: blocks.endIndex) {
                rendered.append(NSAttributedString(string: "\n\n"))
            }
        }

        return rendered
    }

    private static func append(
        _ block: MarkdownBlock,
        to rendered: NSMutableAttributedString,
        nestingLevel: Int
    ) {
        rendered.append(styledText(for: block, nestingLevel: nestingLevel))

        guard !block.children.isEmpty else { return }

        rendered.append(NSAttributedString(string: "\n"))
        for index in block.children.indices {
            append(block.children[index], to: rendered, nestingLevel: nestingLevel + 1)
            if index < block.children.index(before: block.children.endIndex) {
                rendered.append(NSAttributedString(string: "\n"))
            }
        }
    }

    private static func styledText(for block: MarkdownBlock, nestingLevel: Int) -> NSAttributedString {
        let attributes = blockAttributes(for: block, nestingLevel: nestingLevel)
        return NSMutableAttributedString(string: blockText(for: block), attributes: attributes)
    }

    private static func blockText(for block: MarkdownBlock) -> String {
        switch block.kind {
        case .heading, .paragraph:
            return block.plainText
        case .unorderedListItem, .orderedListItem:
            return "\(listMarker(for: block)) \(block.plainText)"
        case .blockquote:
            return "> \(block.plainText)"
        case .codeBlock, .rawHTML:
            return block.sourceText
        case .table:
            guard let table = block.table else { return block.plainText }
            let header = table.header.joined(separator: " | ")
            let separator = String(repeating: "-", count: max(header.count, 3))
            let rows = table.rows.map { $0.joined(separator: " | ") }
            return ([header, separator] + rows).joined(separator: "\n")
        case .image, .animatedImage:
            guard let image = block.image else { return block.plainText }

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
            return lines.joined(separator: "\n")
        case .video:
            guard let video = block.video else { return block.plainText }

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
            return lines.joined(separator: "\n")
        case .thematicBreak:
            return String(repeating: "-", count: 24)
        }
    }

    private static func blockAttributes(
        for block: MarkdownBlock,
        nestingLevel: Int
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
            attributes[.font] = headingFont(level: block.level ?? 1)
        case .paragraph, .unorderedListItem, .orderedListItem, .image, .animatedImage, .video:
            attributes[.font] = bodyFont
        case .blockquote:
            paragraphStyle.firstLineHeadIndent = indentWidth + 12
            paragraphStyle.headIndent = indentWidth + 12
            attributes[.font] = italicBodyFont
            attributes[.foregroundColor] = secondaryTextColor
        case .codeBlock:
            attributes[.font] = monospacedBodyFont
            attributes[.backgroundColor] = codeBlockBackgroundColor
        case .table:
            attributes[.font] = monospacedBodyFont
        case .rawHTML, .thematicBreak:
            attributes[.font] = monospacedBodyFont
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

    private static var bodyFont: PlatformFont {
        PlatformFont.preferredFont(forTextStyle: .body)
    }

    private static var italicBodyFont: PlatformFont {
        #if os(macOS)
        return NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask)
        #else
        return bodyFont.withTraits(.traitItalic)
        #endif
    }

    private static var monospacedBodyFont: PlatformFont {
        PlatformFont.monospacedSystemFont(ofSize: bodyFont.pointSize, weight: .regular)
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

    private static func headingFont(level: Int) -> PlatformFont {
        switch level {
        case 1:
            return PlatformFont.systemFont(ofSize: bodyFont.pointSize * 1.8, weight: .semibold)
        case 2:
            return PlatformFont.systemFont(ofSize: bodyFont.pointSize * 1.45, weight: .semibold)
        case 3:
            return PlatformFont.systemFont(ofSize: bodyFont.pointSize * 1.2, weight: .semibold)
        default:
            return PlatformFont.systemFont(ofSize: bodyFont.pointSize, weight: .semibold)
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
