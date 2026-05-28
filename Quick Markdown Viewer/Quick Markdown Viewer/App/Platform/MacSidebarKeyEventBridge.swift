import SwiftUI
#if os(macOS)
import AppKit

struct MacSidebarKeyEventBridge: NSViewRepresentable {
    let isEnabled: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void
    let onSearchDocument: () -> Void
    let onSearchAllDocuments: () -> Void
    let onNextSearchResult: () -> Void
    let onQuickFilter: () -> Void
    let onToggleFocus: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown,
            onMoveLeft: onMoveLeft,
            onMoveRight: onMoveRight,
            onSearchDocument: onSearchDocument,
            onSearchAllDocuments: onSearchAllDocuments,
            onNextSearchResult: onNextSearchResult,
            onQuickFilter: onQuickFilter,
            onToggleFocus: onToggleFocus
        )
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.installMonitor()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onMoveUp = onMoveUp
        context.coordinator.onMoveDown = onMoveDown
        context.coordinator.onMoveLeft = onMoveLeft
        context.coordinator.onMoveRight = onMoveRight
        context.coordinator.onSearchDocument = onSearchDocument
        context.coordinator.onSearchAllDocuments = onSearchAllDocuments
        context.coordinator.onNextSearchResult = onNextSearchResult
        context.coordinator.onQuickFilter = onQuickFilter
        context.coordinator.onToggleFocus = onToggleFocus
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        var isEnabled = false
        var onMoveUp: () -> Void
        var onMoveDown: () -> Void
        var onMoveLeft: () -> Void
        var onMoveRight: () -> Void
        var onSearchDocument: () -> Void
        var onSearchAllDocuments: () -> Void
        var onNextSearchResult: () -> Void
        var onQuickFilter: () -> Void
        var onToggleFocus: () -> Void
        private var monitor: Any?

        init(
            onMoveUp: @escaping () -> Void,
            onMoveDown: @escaping () -> Void,
            onMoveLeft: @escaping () -> Void,
            onMoveRight: @escaping () -> Void,
            onSearchDocument: @escaping () -> Void,
            onSearchAllDocuments: @escaping () -> Void,
            onNextSearchResult: @escaping () -> Void,
            onQuickFilter: @escaping () -> Void,
            onToggleFocus: @escaping () -> Void
        ) {
            self.onMoveUp = onMoveUp
            self.onMoveDown = onMoveDown
            self.onMoveLeft = onMoveLeft
            self.onMoveRight = onMoveRight
            self.onSearchDocument = onSearchDocument
            self.onSearchAllDocuments = onSearchAllDocuments
            self.onNextSearchResult = onNextSearchResult
            self.onQuickFilter = onQuickFilter
            self.onToggleFocus = onToggleFocus
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                if self.handleSearchShortcut(event) {
                    return nil
                }
                guard self.isEnabled else { return event }
                if event.keyCode == 48 {
                    self.onToggleFocus()
                    return nil
                }
                switch event.keyCode {
                case 123:
                    self.onMoveLeft()
                    return nil
                case 124:
                    self.onMoveRight()
                    return nil
                case 125:
                    self.onMoveDown()
                    return nil
                case 126:
                    self.onMoveUp()
                    return nil
                default:
                    return event
                }
            }
        }

        func handleSearchShortcut(_ event: NSEvent) -> Bool {
            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard modifiers.contains(.command),
                  modifiers.isDisjoint(with: [.option, .control]),
                  let key = event.charactersIgnoringModifiers?.lowercased() else {
                return false
            }

            if key == "f" {
                if modifiers.contains(.shift) {
                    onSearchAllDocuments()
                } else {
                    onSearchDocument()
                }
                return true
            }

            guard key == "g", modifiers.contains(.shift) == false else { return false }
            onNextSearchResult()
            return true
        }

        func removeMonitor() {
            guard let monitor else { return }
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        deinit {
            removeMonitor()
        }
    }
}
#endif
