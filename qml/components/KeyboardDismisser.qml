import QtQuick 2.12
import QtQuick.Window 2.2
import Lomiri.Components 1.3
import "../Theme"

// Tap outside the focused input closes the keyboard; taps still reach what's below
Item {
    id: root
    anchors.fill: parent
    z: 100000

    Item { id: sink }
    property var _focusAtTap: null

    function _inside(item, x, y, margin) {
        var p = item.mapFromItem(null, x, y);
        return item.visible && p.x >= -margin && p.y >= -margin
               && p.x <= item.width + margin && p.y <= item.height + margin;
    }

    function _check(x, y) {
        if (Config.keepKeyboardTap) { Config.keepKeyboardTap = false; return; }
        var focused = Window.activeFocusItem;
        // the tap's own handler moved focus to an input
        if (focused && focused !== root._focusAtTap && focused.cursorPosition !== undefined) return;
        // inner text line is shorter than its field
        if (focused && root._inside(focused, x, y, units.gu(1))) return;
        for (var it = focused; it; it = it.parent) {
            var keep = it.keepKeyboardItems || [];
            for (var i = 0; i < keep.length; i++)
                if (root._inside(keep[i], x, y, 0)) return;
        }
        Qt.inputMethod.commit();
        sink.forceActiveFocus();
        Qt.inputMethod.hide();
    }

    // hidden, not just disabled: a disabled handler still sits in touch delivery
    Item {
        anchors.fill: parent
        visible: Qt.inputMethod.visible

        TapHandler {
            // later: runs after the tap moved focus or pressed a button
            onTapped: {
                Config.keepKeyboardTap = false;
                root._focusAtTap = Window.activeFocusItem;
                Qt.callLater(root._check, eventPoint.scenePosition.x, eventPoint.scenePosition.y);
            }
        }
    }
}
