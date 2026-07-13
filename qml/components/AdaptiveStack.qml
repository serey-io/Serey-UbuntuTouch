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

    readonly property bool split: adaptive && Adaptive.isWide && rootLoader.status === Loader.Ready

    // PageStack-compatible surface (the root page counts as depth 1).
    readonly property int depth: (rootLoader.status === Loader.Ready ? 1 : 0) + detailStack.depth
    readonly property var currentPage: detailStack.depth > 0 ? detailStack.currentPage
                                                             : rootLoader.item

    function ensureRoot() { rootLoader.active = true; }

    function push(page, properties) { return detailStack.push(page, properties); }

    function pop() {
        if (detailStack.depth > 0)
            detailStack.pop();
    }

    Loader {
        id: rootLoader
        active: false
        source: adaptiveStack.rootSource
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        width: adaptiveStack.split ? Adaptive.listPaneWidth : adaptiveStack.width
        // Keep the phone-mode invariant that a covered root page is invisible
        // (several pages use `visible` to skip work while covered).
        visible: adaptiveStack.split || detailStack.depth === 0
        // Root pages call `pageStack.push()`; point that at this container so
        // their pushes land in the detail panel on wide windows.
        onLoaded: item.pageStack = adaptiveStack
    }

    // Hairline between the panels (split mode only).
    Rectangle {
        id: paneDivider
        anchors { top: parent.top; bottom: parent.bottom; left: rootLoader.right }
        width: units.dp(1)
        color: Style.divider
        visible: adaptiveStack.split
    }

    // Detail panel: right-hand pane in split mode, full-screen cover on phones.
    Item {
        id: detailPane
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: adaptiveStack.split ? adaptiveStack.width - Adaptive.listPaneWidth - paneDivider.width
                                   : adaptiveStack.width
        visible: adaptiveStack.split || detailStack.depth > 0

        // Empty-detail placeholder (only ever seen in split mode).
        Rectangle {
            anchors.fill: parent
            color: Style.surface
            visible: detailStack.depth === 0
            EmptyState {
                anchors.fill: parent
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
