import Foundation
import CoreGraphics

public enum PetBindingRules {
    public static let ownerBundleIDs: Set<String> = ["com.openai.codex", "com.openai.chat"]
    public static func suitable(role: String, width: Double, height: Double) -> Bool {
        ["AXImage", "AXButton", "AXGroup"].contains(role) &&
        width.isFinite && height.isFinite && width >= 32 && width <= 420 && height >= 40 && height <= 480 &&
        width / height >= 0.3 && width / height <= 3
    }
}

/// Explicitly calibrated region within one AX window. Invalidate when it resizes.
public struct PetRegionAnchor {
    public let relative: CGRect
    private let windowSize: CGSize
    public init?(window: CGRect, point: CGPoint) {
        guard window.contains(point), window.width.isFinite, window.height.isFinite,
              window.width >= 40, window.height >= 40 else { return nil }
        let region = CGRect(x: point.x-50, y: point.y-60, width: 100, height: 120).intersection(window)
        guard region.width >= 32, region.height >= 40 else { return nil }
        relative = CGRect(x: region.minX-window.minX, y: region.minY-window.minY, width: region.width, height: region.height)
        windowSize = window.size
    }
    public func resolve(in window: CGRect) -> CGRect? {
        guard window.minX.isFinite, window.minY.isFinite,
              abs(window.width-windowSize.width) <= 2, abs(window.height-windowSize.height) <= 2 else { return nil }
        return CGRect(x: window.minX+relative.minX, y: window.minY+relative.minY, width: relative.width, height: relative.height)
    }
}
