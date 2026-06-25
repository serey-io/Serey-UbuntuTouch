import QtQuick 2.7
import QtMultimedia 5.12
import Lomiri.Components 1.3
import "../Theme"

/*
 * Native player for Serey-hosted videos (platform_type === "SEREY"), whose
 * `video_link` is a direct media file (mp4 on s3.serey.io / upload.serey.io /
 * fsgw.sabay.com). Third-party embeds use VideoWebView instead. Loaded lazily by
 * VideoDetailPage. On a playback error it opens the file externally (system
 * player / browser) via `fallbackUrl`.
 */
Item {
    id: root
    property string source: ""
    property string fallbackUrl: ""

    onSourceChanged: {
        player.stop();
        if (source.length > 0)
            player.play();
    }

    MediaPlayer {
        id: player
        source: root.source
        autoPlay: true
        onError: {
            if (root.fallbackUrl.length > 0)
                Qt.openUrlExternally(root.fallbackUrl);
        }
    }

    VideoOutput {
        anchors.fill: parent
        source: player
        fillMode: VideoOutput.PreserveAspectFit
    }

    // Tap to toggle play / pause.
    MouseArea {
        anchors.fill: parent
        onClicked: player.playbackState === MediaPlayer.PlayingState
                   ? player.pause() : player.play()
    }

    // Buffering / loading spinner.
    ActivityIndicator {
        anchors.centerIn: parent
        running: player.status === MediaPlayer.Loading
                 || player.status === MediaPlayer.Buffering
        visible: running
    }

    // Centre play glyph while paused.
    Icon {
        anchors.centerIn: parent
        width: units.gu(7)
        height: width
        name: "media-playback-start"
        color: Style.textOnBrand
        visible: player.playbackState !== MediaPlayer.PlayingState
                 && player.status !== MediaPlayer.Loading
                 && player.status !== MediaPlayer.Buffering
        MouseArea { anchors.fill: parent; onClicked: player.play() }
    }
}
