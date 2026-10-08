import AppKit
import SwiftUI

/// Expose the actual NSTextView to accessibility instead of a decorated SwiftUI proxy.
struct NativeSequenceEditor: NSViewRepresentable {
    @Binding var text: String
    let title: String
    let identifier: String
    var onFileDrop: ((URL) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let editor = FileAwareTextView()
        editor.isRichText = false
        editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        editor.textContainerInset = NSSize(width: 5, height: 5)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.delegate = context.coordinator
        editor.registerForDraggedTypes([.fileURL])
        scroll.documentView = editor
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = true
        updateNSView(scroll, context: context)
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? FileAwareTextView else { return }
        context.coordinator.text = $text
        editor.onFileDrop = onFileDrop
        editor.isEditable = context.environment.isEnabled
        editor.isSelectable = context.environment.isEnabled
        editor.setAccessibilityIdentifier(identifier)
        editor.setAccessibilityLabel(title)
        editor.textColor = .textColor
        editor.backgroundColor = .textBackgroundColor
        scroll.backgroundColor = .textBackgroundColor
        if editor.string != text {
            let selection = editor.selectedRange()
            editor.string = text
            NSAccessibility.post(element:editor,notification:.valueChanged)
            editor.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
        }
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            text.wrappedValue = editor.string
        }
    }
}

private final class FileAwareTextView: NSTextView {
    var onFileDrop: ((URL) -> Void)?
    private func droppedFile(_ sender: NSDraggingInfo) -> URL? {
        (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL])?.first
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if onFileDrop != nil, droppedFile(sender) != nil { return .copy }
        return super.draggingEntered(sender)
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if onFileDrop != nil, droppedFile(sender) != nil { return .copy }
        return super.draggingUpdated(sender)
    }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if onFileDrop != nil, droppedFile(sender) != nil { return true }
        return super.prepareForDragOperation(sender)
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let onFileDrop, let url = droppedFile(sender) { onFileDrop(url); return true }
        return super.performDragOperation(sender)
    }
}
