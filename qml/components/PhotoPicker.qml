import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Content 1.3
import "../Theme"

/*
 * Photo importer built on Content Hub. Call pick() to show the system peer
 * picker (Gallery, Camera, … each appears as a source); when the user picks an
 * image it's transferred into the app's cache and `picked(fileUrl)` fires with
 * a local file:// URL. Mount this as a full-bleed overlay inside a Page.
 *
 * Requires the `content_exchange` AppArmor policy group (see serey.apparmor).
 */
Item {
    id: picker

    signal picked(string fileUrl)
    signal cancelled()

    property var activeTransfer: null

    anchors.fill: parent
    visible: peerPicker.visible
    z: 1000

    function pick() {
        peerPicker.visible = true;
    }

    // Opaque backdrop so the underlying page doesn't show through the picker.
    Rectangle {
        anchors.fill: parent
        color: Style.surface
        visible: peerPicker.visible
    }

    ContentPeerPicker {
        id: peerPicker
        anchors.fill: parent
        visible: false
        showTitle: true
        contentType: ContentType.Pictures
        handler: ContentHandler.Source

        onPeerSelected: {
            peer.selectionType = ContentTransfer.Single;
            picker.activeTransfer = peer.request();
            peerPicker.visible = false;
        }
        onCancelPressed: {
            peerPicker.visible = false;
            picker.cancelled();
        }
    }

    Connections {
        target: picker.activeTransfer
        onStateChanged: {
            var t = picker.activeTransfer;
            if (!t)
                return;
            if (t.state === ContentTransfer.Charged) {
                if (t.items.length > 0)
                    picker.picked(t.items[0].url);
                picker.activeTransfer = null;
            } else if (t.state === ContentTransfer.Aborted) {
                picker.activeTransfer = null;
                picker.cancelled();
            }
        }
    }
}
