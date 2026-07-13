pragma Singleton
import QtQuick 2.7
import Lomiri.Components 1.3

/*
 * Convergence state (HIG: adapt, not scale). Main.qml feeds windowWidth/Height;
 * pages and components read the derived metrics instead of guessing from their
 * own width, so every screen switches layout at the same threshold.
 *
 * The numbers mirror the toolkit's AdaptivePageLayout defaults: split into two
 * panels above 80gu, with a fixed 40gu leading (list) column and the detail
 * panel taking the rest.
 */
QtObject {
    id: adaptive

    // Bound to the MainView's size by Main.qml.
    property real windowWidth: units.gu(45)
    property real windowHeight: units.gu(80)

    // Master-detail split point (AdaptivePageLayout collapses at <= 80gu).
    readonly property bool isWide: windowWidth > units.gu(80)

    // Fixed width of the leading (list) panel in split mode.
    readonly property real listPaneWidth: units.gu(40)

    // Cap for long-form reading columns (article bodies) on wide windows.
    readonly property real readingMaxWidth: units.gu(80)

    // Cap for bottom sheets / pickers so they present as centered panels
    // instead of stretching across a desktop window.
    readonly property real sheetMaxWidth: units.gu(50)

    // Width of the vertical nav rail that replaces the bottom tab bar on
    // wide windows.
    readonly property real navRailWidth: units.gu(9)
}
