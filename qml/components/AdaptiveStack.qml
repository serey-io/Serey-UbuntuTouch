import QtQuick 2.12
import Lomiri.Components 1.3
import "../Theme"
import "../Session"

/*
 * Convergent per-tab navigation container (HIG: adapt, not scale).
 *
 * Narrow windows keep the phone model: the root page fills the tab and pushed
 * pages cover it full-screen, exactly like the plain PageStack this replaces.
 * Wide windows (Adaptive.isWide) show the root page as a fixed-width leading
 * panel and route pushed pages into a detail panel on the right, Dekko / System
 * Settings style. Crossing the breakpoint is a pure geometry change: nothing is
 * reparented, so live WebViews and players survive a window resize.
 *
 * It mirrors the PageStack API surface the app uses (push/pop/depth/
 * currentPage) and assigns itself as the root page's `pageStack`, so every
 * existing `pageStack.push()` call site keeps working unchanged. Pages pushed
 * into the detail panel live in a real PageStack and pop as usual.
 */
Item {
    id: adaptiveStack

    // The tab's root page; loaded lazily via ensureRoot() (all four tabs at
    // once made the Homepage web view janky on low-end devices).
    property url rootSource
    // false = full-screen pushes at every width (Homepage: the web app is the
    // panel). true = master-detail on wide windows.
    property bool adaptive: true
    // Placeholder shown in the empty detail panel in split mode.
    property string emptyIcon: "stock_note"
    property string emptyText: Lang.tr("Select an item to view it here")

    // Resizable leading panel. Lomiri panels are meant to be resizable (a
    // toolkit PageColumn is draggable whenever its min and max widths differ),
    // so the divider can be dragged. `listWidth` holds the current width; it is
    // read back clamped so a window resize can't strand it out of bounds.
    // Widening the list shrinks the detail toward the reading-width cap, which
    // is how you make a centered article fill its pane on an ultra-wide window.
    property real listWidth: Adaptive.listPaneWidth
    readonly property real minListWidth: units.gu(30)
    readonly property real maxListWidth: Math.max(minListWidth,
                                         Math.min(width * 0.6, width - units.gu(45)))
    readonly property real _listW: Math.max(minListWidth, Math.min(maxListWidth, listWidth))

    // Split is decided by window width alone, NOT by whether the root has
    // loaded yet: rootStack must already be its list width BEFORE ensureRoot()
    // pushes the page, or PageStack sizes the page at the full width first and
    // it stays there (the panel then just clips/overlaps the overflow).
    readonly property bool split: adaptive && Adaptive.isWide

    // PageStack-compatible surface (the root page counts as depth 1).
    readonly property int depth: (rootStack.depth > 0 ? 1 : 0) + detailStack.depth
    readonly property var currentPage: detailStack.depth > 0 ? detailStack.currentPage
                                                             : rootStack.currentPage

    // The root lives in a real (single-page) PageStack, NOT a bare Loader: a
    // Lomiri Page sizes itself against its nearest PageTreeNode ancestor, so
    // outside a PageStack it anchors to the MainView and escapes the panel.
    function ensureRoot() {
        if (rootStack.depth > 0)
            return;
        var pg = rootStack.push(adaptiveStack.rootSource);
        // Root pages call `pageStack.push()`; re-point that at this container
        // (overriding what PageStack.push just set) so their pushes land in
        // the detail panel on wide windows.
        if (pg) pg.pageStack = adaptiveStack;
    }

    function push(page, properties) { return detailStack.push(page, properties); }

    function pop() {
        if (detailStack.depth > 0)
            detailStack.pop();
    }

    // Leading (list) panel. rootStack must FILL a sized container via anchors,
    // exactly like detailStack fills detailPane: a Lomiri Page sizes itself to
    // its PageStack, but only tracks it reliably when the PageStack fills its
    // parent by anchors. An explicit `width` on the PageStack itself does NOT
    // propagate to the page (it stays full width and the panel just clips it).
    Item {
        id: listPane
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: adaptiveStack.split ? adaptiveStack._listW : adaptiveStack.width
        // Keep the phone-mode invariant that a covered root page is invisible
        // (several pages use `visible` to skip work while covered).
        visible: adaptiveStack.split || detailStack.depth === 0
        clip: true

        PageStack {
            id: rootStack
            anchors.fill: parent
        }
    }

    // Hairline between the panels (split mode only).
    Rectangle {
        id: paneDivider
        anchors { top: parent.top; bottom: parent.bottom; left: listPane.right }
        width: units.dp(1)
        color: dragHandle.containsMouse || dragHandle.pressed ? Style.brand : Style.divider
        visible: adaptiveStack.split
    }

    // Drag handle straddling the divider: makes the split resizable and, as a
    // pointer affordance, shows the horizontal-resize cursor on hover.
    MouseArea {
        id: dragHandle
        visible: adaptiveStack.split
        anchors { top: parent.top; bottom: parent.bottom }
        x: listPane.width - width / 2
        width: units.gu(1.5)
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.SplitHCursor
        onPositionChanged: {
            if (!pressed) return;
            // Absolute pointer X in adaptiveStack coords == desired list width;
            // reading it absolutely (not incrementally) avoids drag feedback as
            // the handle re-centers on the moving divider.
            var ax = mapToItem(adaptiveStack, mouse.x, 0).x;
            adaptiveStack.listWidth = Math.max(adaptiveStack.minListWidth,
                                      Math.min(adaptiveStack.maxListWidth, ax));
        }
    }

    // Detail panel: right-hand pane in split mode, full-screen cover on phones.
    Item {
        id: detailPane
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: adaptiveStack.split ? adaptiveStack.width - listPane.width - paneDivider.width
                                   : adaptiveStack.width
        visible: adaptiveStack.split || detailStack.depth > 0

        // Opaque panel background (Pages are transparent) + empty placeholder.
        Rectangle {
            anchors.fill: parent
            color: Style.surface
            visible: adaptiveStack.split || detailStack.depth === 0
            EmptyState {
                anchors.fill: parent
                visible: detailStack.depth === 0
                iconName: adaptiveStack.emptyIcon
                message: adaptiveStack.emptyText
            }
        }

        PageStack {
            id: detailStack
            anchors.fill: parent
        }
    }
}
