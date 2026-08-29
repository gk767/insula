import Cocoa
import SwiftUI

final class PillHostingView<Content: View>: NSHostingView<Content> {

    var state: IslandState!

    override var safeAreaInsets: NSEdgeInsets {
        if NotchGeometry.keepsOwnerLayout {
            return super.safeAreaInsets
        }
        return NSEdgeInsets()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let pill = NotchGeometry.pillRect(
            in: bounds,
            expanded: state.isExpanded,
            collapsed: state.collapsedSize,
            activity: state.showsActivity,
            expandedHeight: state.expandedHeight,
            placement: state.placement,
            relocating: state.isRelocating,
            magnet: state.magnet
        )
        var hitRect = state.isExpanded ? pill.insetBy(dx: -4, dy: -4) : pill
        if !state.isExpanded, state.approachSquish > 0.001 {
            let factor = 1 - state.approachSquish * 0.32
            let squishedHeight = pill.height * factor
            hitRect = NSRect(x: pill.minX, y: pill.maxY - squishedHeight, width: pill.width, height: squishedHeight)
        }
        let chrome = NotchGeometry.editChromeRect(
            in: bounds,
            expanded: state.isExpanded,
            collapsed: state.collapsedSize,
            activity: state.showsActivity,
            expandedHeight: state.expandedHeight,
            placement: state.placement,
            relocating: state.isRelocating,
            magnet: state.magnet,
            editing: state.isEditing
        )
        if !chrome.isNull, chrome.width > 0 {
            hitRect = hitRect.union(chrome.insetBy(dx: -2, dy: -2))
        }
        return hitRect.contains(point) ? super.hitTest(point) : nil
    }
}
