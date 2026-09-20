import Foundation
import CoreGraphics

/// Owns a matched right-button sequence so the host never receives half a click.
public struct RightClickMenuGate {
    public enum Event { case down, dragged, up, other }
    public enum Result { case passThrough, consume, showMenu }
    private var start: CGPoint?
    private var moved = false
    public init() {}

    public mutating func handle(_ event: Event, at point: CGPoint,
                               isTarget: Bool, hasModifiers: Bool) -> Result {
        switch event {
        case .other: return .passThrough
        case .down:
            start = isTarget && !hasModifiers ? point : nil
            moved = false
            return start == nil ? .passThrough : .consume
        case .dragged, .up:
            guard let start else { return .passThrough }
            if hypot(point.x-start.x, point.y-start.y) > 5 { moved = true }
            if event == .dragged { return .consume }
            defer { cancel() }
            return !moved && isTarget && !hasModifiers ? .showMenu : .consume
        }
    }
    public mutating func cancel() { start = nil; moved = false }
}
