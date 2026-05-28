import Cocoa
import Quartz

final class PreviewViewController: NSViewController, QLPreviewingController {
    private let textView = NSTextView(frame: .zero)

    override func loadView() {
        let scrollView = NSScrollView(frame: .zero)
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 28, height: 28)
        textView.textContainer?.widthTracksTextView = true
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        scrollView.documentView = textView
        view = scrollView
        preferredContentSize = NSSize(width: 760, height: 680)
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let source = try await Task.detached(priority: .userInitiated) {
            try MarkdownQuickLookPreviewFormatter.markdownSource(at: url)
        }.value

        title = url.lastPathComponent
        textView.textStorage?.setAttributedString(
            MarkdownQuickLookPreviewFormatter.attributedPreview(from: source)
        )
    }
}

private enum MarkdownQuickLookPreviewFormatter {
    nonisolated static func markdownSource(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let source = String(data: data, encoding: .utf8) {
            return source
        }
        if let source = String(data: data, encoding: .utf16) {
            return source
        }
        if let source = String(data: data, encoding: .isoLatin1) {
            return source
        }
        return String(decoding: data, as: UTF8.self)
    }

    static func attributedPreview(from source: String) -> NSAttributedString {
        let rendered: NSMutableAttributedString
        if let attributed = try? AttributedString(markdown: source) {
            rendered = NSMutableAttributedString(attributed)
        } else {
            rendered = NSMutableAttributedString(string: source)
        }

        let fullRange = NSRange(location: 0, length: rendered.length)
        guard fullRange.length > 0 else {
            return rendered
        }

        let bodyFont = NSFont.preferredFont(forTextStyle: .body)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = 8

        rendered.addAttributes(
            [
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ],
            range: fullRange
        )
        rendered.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            if value == nil {
                rendered.addAttribute(.font, value: bodyFont, range: range)
            }
        }
        return rendered
    }
}
