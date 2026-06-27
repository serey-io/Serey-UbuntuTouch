import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../services/Uploads.js" as Uploads

/*
 * Non-visual orchestrator for "pick → downscale → upload". Call upload(fileUrl)
 * with a local file:// URL (from PhotoPicker); it emits uploaded(url) with the
 * hosted image URL, or failed(message).
 *
 * Why downscale first: full-resolution gallery photos are several MB. Reading
 * those bytes and POSTing them over mobile is slow and — because QML's
 * XMLHttpRequest silently ignores `timeout`/`ontimeout` — a slow upload spins
 * forever (the "stuck in uploading" bug). A camera capture is small enough to
 * finish quickly, which is why it appeared to work and a gallery image didn't.
 * We decode the picture at a capped sourceSize and grab it to a temp JPEG so
 * every upload is small and fast. If decoding/grabbing fails for any reason we
 * fall back to uploading the original bytes, so this never does worse than
 * before. A watchdog Timer guarantees the spinner can't hang indefinitely.
 */
Item {
    id: root
    width: 0; height: 0

    property int maxDimension: 1600    // longest side after downscale (px)
    property int timeoutMs: 60000      // hard ceiling — QML XHR ignores `timeout`
    property bool uploading: false

    signal uploaded(string url)
    signal failed(string message)

    function upload(fileUrl) {
        if (root.uploading)
            return;
        root.uploading = true;
        watchdog.restart();
        // Reassign even if the same file is re-picked so onStatusChanged fires.
        resizer.source = "";
        resizer.source = fileUrl;
    }

    function _finishOk(url) { watchdog.stop(); root.uploading = false; root.uploaded(url); }
    function _finishErr(msg) { watchdog.stop(); root.uploading = false; root.failed(msg); }

    function _uploadFile(fileUrl) {
        Uploads.uploadImage(Config.uploadUrl, Config.uploadSecret, fileUrl,
            function (url) { root._finishOk(url); },
            function (err) { root._finishErr((err && err.message) || i18n.tr("Upload failed.")); });
    }

    function _onDecoded() {
        var w = resizer.implicitWidth;
        var h = resizer.implicitHeight;
        if (w <= 0 || h <= 0) {            // couldn't measure — send original
            root._uploadFile(String(resizer.source));
            return;
        }
        resizer.width = w;
        resizer.height = h;
        var src = String(resizer.source);
        var dir = src.substring(0, src.lastIndexOf("/")).replace(/^file:\/\//, "");
        var outLocal = dir + "/serey_up_" + Date.now() + ".jpg";
        resizer.grabToImage(function (result) {
            if (result && result.saveToFile(outLocal))
                root._uploadFile("file://" + outLocal);
            else
                root._uploadFile(String(resizer.source));   // fall back to original
        }, Qt.size(w, h));
    }

    // QML XMLHttpRequest does not honour its own `timeout`, so this is the only
    // reliable ceiling: abort the request and report a timeout.
    Timer {
        id: watchdog
        interval: root.timeoutMs
        onTriggered: {
            Uploads.abort();
            root._finishErr(i18n.tr("Upload timed out. Try a smaller image or check your connection."));
        }
    }

    // Off-screen decoder. Kept at opacity 0 (NOT visible:false, which would drop
    // it from the scene graph and make grabToImage return nothing) and sized to
    // the capped decode size so the grab is a clean downscaled bitmap.
    Image {
        id: resizer
        opacity: 0
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        fillMode: Image.PreserveAspectFit
        sourceSize.width: root.maxDimension
        sourceSize.height: root.maxDimension
        onStatusChanged: {
            if (status === Image.Ready)
                root._onDecoded();
            else if (status === Image.Error)
                root._uploadFile(String(resizer.source));   // upload original bytes
        }
    }
}
