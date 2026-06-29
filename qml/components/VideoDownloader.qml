import QtQuick 2.7
import Lomiri.DownloadManager 1.2

/*
 * Per-download wrapper over Lomiri.DownloadManager's SingleDownload. This is the
 * ONLY file that imports the module, so its absence (e.g. the WSL desktop
 * preview, which has no download daemon) is contained: Downloads.qml creates
 * this via Qt.createComponent and tolerates a Component.Error status, exactly
 * like Main.qml guards PushClient.
 *
 * The system daemon streams the file to the app's confined download cache and
 * keeps going while the app is backgrounded; on completion it hands back an
 * absolute path which Downloads.qml persists for offline playback.
 */
Item {
    id: dl

    property string url: ""
    property string title: ""

    signal progress(real pct)        // 0..100
    signal finished(string path)     // absolute path on disk
    signal failed(string message)

    function start(u) {
        if (u && u.length > 0)
            dl.url = u;
        single.download(dl.url);
    }

    SingleDownload {
        id: single
        autoStart: false
        allowMobileDownload: true
        metadata: Metadata { showInIndicator: true; title: dl.title }

        onProgressChanged: dl.progress(progress)
        onFinished: dl.finished(path)
        onErrorChanged: if (errorMessage && errorMessage.length > 0) dl.failed(errorMessage)
    }
}
