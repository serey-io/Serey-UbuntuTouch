import QtQuick 2.7

// Focus on a real tap only; a drag cancels this, so scrolling can't open the keyboard
MouseArea {
    property Item field

    anchors.fill: parent
    // off once focused so the field's own selection and caret dragging work
    enabled: !!field && !field.activeFocus

    Component.onCompleted: field.activeFocusOnPress = false

    onClicked: {
        field.forceActiveFocus();
        // Lomiri TextField takes x only
        field.cursorPosition = field.hasClearButton !== undefined ? field.positionAt(mouse.x)
                                                                  : field.positionAt(mouse.x, mouse.y);
        if (!field.readOnly) Qt.inputMethod.show();
    }
}
