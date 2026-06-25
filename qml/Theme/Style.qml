pragma Singleton
import QtQuick 2.7
import Lomiri.Components 1.3

/*
 * Central design tokens so colours / spacing are defined once. Spacing uses
 * grid units (`units.gu`) which scale with the device. Colours are kept
 * explicit here for deterministic rendering; switching them to `theme.palette`
 * for automatic dark-mode is a future enhancement.
 */
QtObject {
    id: style

    // Brand
    readonly property color brand: "#2FAA4C"
    readonly property color brandDark: "#1C7C36"

    // Text
    readonly property color textPrimary: "#111111"
    readonly property color textSecondary: "#6E6E6E"
    readonly property color textOnBrand: "#FFFFFF"

    // Surfaces
    readonly property color surface: "#FFFFFF"
    readonly property color card: "#FFFFFF"
    readonly property color divider: "#E4E4E4"
    readonly property color pressed: "#F0F0F0"

    readonly property color danger: "#C7162B"

    // Spacing (grid units)
    readonly property real spacingXs: units.gu(0.5)
    readonly property real spacingS: units.gu(1)
    readonly property real spacingM: units.gu(2)
    readonly property real spacingL: units.gu(3)

    // Radii / sizes
    readonly property real radius: units.gu(1)
    readonly property real thumbSize: units.gu(10)
    readonly property real avatarSize: units.gu(4)

    // Typography. The bundled Noto Sans Khmer covers Khmer (and Latin), so
    // labels that can contain Khmer set `font.family: Style.fontFamily`.
    // (Qt's automatic glyph fallback ignores app-added fonts on fontconfig
    // platforms, so the family must be set explicitly — loading alone isn't
    // enough.) Falls back to the default sans family if the file is missing.
    property FontLoader fontLoader: FontLoader {
        source: Qt.resolvedUrl("../../assets/fonts/NotoSansKhmer-Regular.ttf")
    }
    readonly property string fontFamily: fontLoader.status === FontLoader.Ready
                                         ? fontLoader.name : "Ubuntu"
}
