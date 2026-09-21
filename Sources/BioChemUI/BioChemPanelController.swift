import AppKit
import SwiftUI
import BioChemCore

private final class SearchablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(sender) }
}

/// Retain this controller in the host desktop pet. Does not change NSApplication's delegate or activation policy.
@MainActor
public final class BioChemPanelController {
    public let session: BioChemSession
    public let panel: NSPanel

    public init(catalog: Catalog, floating: Bool = true, onOpenSettings: (() -> Void)? = nil) {
        session = BioChemSession(catalog: catalog)
        panel = SearchablePanel(contentRect: NSRect(x: 0, y: 0, width: 920, height: 760),
                                styleMask: floating ? [.titled, .closable, .resizable, .utilityWindow] : [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        panel.title = "BioChem · 生化速查"
        panel.minSize = NSSize(width: 780, height: 700)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = floating ? .floating : .normal
        panel.collectionBehavior = [.fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: ToolkitView(session: session, onOpenSettings: onOpenSettings))
        panel.center()
    }

    public convenience init(floating: Bool = true, onOpenSettings: (() -> Void)? = nil) throws {
        self.init(catalog: try Catalog.bundled(), floating: floating, onOpenSettings: onOpenSettings)
    }

    /// Screen-space anchor uses AppKit coordinates. Omit to retain the last panel location.
    public func show(kind: EntryKind? = nil, destination: ToolDestination? = nil, near anchor: NSRect? = nil) {
        if let destination { session.destination = destination }
        if let kind { session.switchTo(kind) }
        if let anchor {
            let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
            if let frame = screen?.visibleFrame {
                let size = panel.frame.size
                let x = min(max(anchor.minX - size.width - 12, frame.minX), max(frame.minX, frame.maxX - size.width))
                let y = min(max(anchor.midY - size.height / 2, frame.minY), max(frame.minY, frame.maxY - size.height))
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
    public func hide() { panel.orderOut(nil) }
    public func toggle(near anchor: NSRect? = nil) {
        panel.isVisible ? hide() : show(near: anchor)
    }
}
