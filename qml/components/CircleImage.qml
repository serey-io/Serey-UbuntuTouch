import QtQuick 2.7
import QtGraphicalEffects 1.0
import "../Theme"

Item {
    id: root

    property url source: ""
    // Cap the decoded resolution (px); remote avatars are large and decoding full-size into a tiny circle wastes texture memory. 0 = uncapped.
    property int decode: 0
    // PreserveAspectFit for non-square logos (wordmarks)
    property int fillMode: Image.PreserveAspectCrop
    readonly property bool loaded: img.status === Image.Ready && String(source) !== ""

    // Qt caches a failed load, so an avatar that failed offline needs a new URL once back.
    property int _attempt: 0
    onSourceChanged: _attempt = 0
    readonly property string _url: {
        var s = String(source);
        if (_attempt === 0 || s.indexOf("http") !== 0) return s;
        return s + (s.indexOf("?") >= 0 ? "&" : "?") + "retry=" + _attempt;
    }
    Connections {
        target: Net
        function onOnlineChanged() { if (Net.online && img.status === Image.Error) root._attempt++; }
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: width / 2
        antialiasing: true
        visible: false
    }

    Image {
        id: img
        anchors.fill: parent
        source: root._url
        fillMode: root.fillMode
        asynchronous: true
        // Decode near the drawn size: uncapped, Qt scaled a 500-2560px logo straight to ~30px
        // and curved edges went to mush (flat flags survived, so only some icons looked soft).
        // 0 until the item has a size, or the first decode is 1px and flashes on re-decode.
        sourceSize.width: root.decode > 0 ? root.decode
                        : (root.width > 0 ? Math.ceil(root.width * 2) : 0)
        sourceSize.height: root.decode > 0 ? root.decode
                         : (root.height > 0 ? Math.ceil(root.height * 2) : 0)
        // Proper downsampling when the source is still much larger than the circle.
        mipmap: true
        // Honour the EXIF Orientation tag; without autoTransform, camera-captured avatars render sideways.
        autoTransform: true
        layer.enabled: true
        layer.effect: OpacityMask { maskSource: mask }
    }
}
