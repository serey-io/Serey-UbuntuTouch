import QtQuick 2.7
import QtMultimedia 5.12
import Lomiri.Components 1.3
import "../Theme"

/*
 * Native player for Serey-hosted videos (platform_type === "SEREY"), whose
 * `video_link` is a direct media file (mp4 on s3.serey.io / upload.serey.io /
 * fsgw.sabay.com). Third-party embeds use VideoWebView instead. Loaded lazily by
 * VideoDetailPage. On a playback error it emits `failed()` and the caller falls
 * back to a Chromium <video> (broader codec support) instead.
 */
Item {
    id: root
    property string source: ""

    // Emitted when GStreamer can't play the file (decode error or watchdog
    // timeout). The caller retries in-app via a Chromium <video> rather than the
    // external browser.
    signal failed()

    onSourceChanged: {
        // Set the player source explicitly (not via a binding + autoPlay) so the
        // file is loaded exactly once. Doing both let autoPlay start a load that
        // this handler's stop() immediately killed, then play() restarted it —
        // doubling time-to-first-frame and leaving the stage black meanwhile.
        player.stop();
        if (source.length > 0) {
            player.source = source;
            watchdog.restart();
            player.play();
        } else {
            player.source = "";
            watchdog.stop();
        }
    }

    // Ensure the GStreamer pipeline is torn down when the Loader deactivates or
    // the detail page is popped — otherwise it can keep buffering in background.
    Component.onDestruction: player.stop()

    MediaPlayer {
        id: player
        // source is assigned in onSourceChanged (single load — see above), not
        // bound here, and autoPlay is off so it can't race that explicit load.
        onError: {
            watchdog.stop();
            root.failed();
        }
        // Stop the watchdog once playback actually starts / buffers.
        onPlaybackStateChanged: if (playbackState === MediaPlayer.PlayingState) watchdog.stop()
        onStatusChanged: if (status === MediaPlayer.Buffered) watchdog.stop()
    }

    // Watchdog for stalled/unreachable files: if nothing is playing/buffered
    // after a few seconds, stop and emit failed() so the caller can retry in-app
    // (Chromium <video>) instead of leaving the UI frozen on a spinner.
    Timer {
        id: watchdog
        interval: 6000
        repeat: false
        onTriggered: {
            if (player.playbackState !== MediaPlayer.PlayingState
                && player.status !== MediaPlayer.Buffered
                && player.status !== MediaPlayer.EndOfMedia) {
                player.stop();
                root.failed();
            }
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

    // Buffering / loading spinner. Cover the whole "not yet showing frames"
    // window (Loading → Loaded → Buffering → Stalled), not just Loading/Buffering,
    // so the stage isn't a featureless black rectangle while the file streams in.
    ActivityIndicator {
        anchors.centerIn: parent
        running: root.source.length > 0
                 && player.status !== MediaPlayer.Buffered
                 && player.status !== MediaPlayer.EndOfMedia
                 && player.status !== MediaPlayer.InvalidMedia
                 && player.playbackState !== MediaPlayer.PausedState
        visible: running
    }

    // Centre play glyph while paused.
    Icon {
        anchors.centerIn: parent
        width: units.gu(7)
        height: width
        name: "media-playback-start"
        color: Style.textOnBrand
        // Only once the media is actually ready and paused — never over the black
        // frame during the initial load, where the spinner owns the stage.
        visible: player.playbackState === MediaPlayer.PausedState
                 || (player.playbackState === MediaPlayer.StoppedState
                     && player.status === MediaPlayer.Buffered)
                 || player.status === MediaPlayer.EndOfMedia
        MouseArea { anchors.fill: parent; onClicked: player.play() }
    }
}
