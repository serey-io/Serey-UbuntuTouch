import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../components"

/*
 * Video detail. Shows the thumbnail with a play button; tapping play loads the
 * embed URL in an in-app WebView (lazily, via a Loader). An "Open in browser"
 * action is always available as a fallback (e.g. native YouTube app).
 */
Page {
    id: page

    property var video: ({})
    property bool playing: false
    // true → Serey direct file via native MediaPlayer; false → web embed
    property bool nativeMode: false

    function isDirectFile(u) {
        return /\.(mp4|webm|m4v|mov)(\?|$)/i.test(u || "");
    }

    // Decide how to play and start. Serey-hosted files play inline natively;
    // YouTube/TikTok/Facebook embeds play in the WebView; anything else opens
    // externally.
    function startPlay() {
        var v = page.video;
        if (v.platform === "SEREY" || isDirectFile(v.videoLink) || isDirectFile(v.embedUrl)) {
            page.nativeMode = true;
            page.playing = true;
        } else if ((v.embedUrl || "").length > 0) {
            page.nativeMode = false;
            page.playing = true;
        } else if ((v.videoLink || "").length > 0) {
            Qt.openUrlExternally(v.videoLink);
        }
    }

    header: PageHeader {
        title: page.video.title || i18n.tr("Video")
        trailingActionBar.actions: [
            Action {
                iconName: "external-link"
                text: i18n.tr("Open in browser")
                visible: (page.video.videoLink || "").length > 0
                onTriggered: Qt.openUrlExternally(page.video.videoLink)
            }
        ]
    }

    Flickable {
        anchors { top: page.header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentWidth: width
        contentHeight: col.height
        clip: true

        Column {
            id: col
            width: parent.width
            spacing: Style.spacingM

            // Player / thumbnail (16:9)
            Rectangle {
                id: stage
                width: parent.width
                height: width * 9 / 16
                color: Style.videoStage
                clip: true

                Image {
                    anchors.fill: parent
                    source: page.video.thumbnail || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: !page.playing && status === Image.Ready
                }

                AbstractButton {
                    anchors.fill: parent
                    visible: !page.playing
                    onClicked: page.startPlay()
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(7)
                        height: width
                        name: "media-playback-start"
                        color: Style.textOnBrand
                    }
                }

                Loader {
                    id: webLoader
                    anchors.fill: parent
                    active: page.playing
                    source: page.playing
                        ? (page.nativeMode ? Qt.resolvedUrl("../components/VideoNativePlayer.qml")
                                           : Qt.resolvedUrl("../components/VideoWebView.qml"))
                        : ""
                    onLoaded: {
                        if (page.nativeMode) {
                            item.fallbackUrl = page.video.videoLink || page.video.embedUrl || "";
                            item.source = page.video.videoLink || page.video.embedUrl || "";
                        } else {
                            item.wrap = true;
                            item.embedUrl = page.video.embedUrl || "";
                        }
                    }
                    onStatusChanged: {
                        if (status === Loader.Error) {
                            page.playing = false;
                            var link = page.video.videoLink || page.video.embedUrl;
                            if ((link || "").length > 0)
                                Qt.openUrlExternally(link);
                        }
                    }
                }
            }

            Label {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.video.title || ""
                textSize: Label.Large
                font.weight: Font.DemiBold
                font.family: Style.fontFamily
                color: Style.textPrimary
                wrapMode: Text.WordWrap
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - Style.spacingM * 2
                spacing: Style.spacingM

                Label {
                    text: "@" + (page.video.author || "")
                    textSize: Label.Small
                    color: Style.brand
                }
                Label {
                    text: page.video.date || ""
                    textSize: Label.Small
                    color: Style.textSecondary
                }
            }

            VoteBar {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                author: page.video.author || ""
                permlink: page.video.permlink || ""
                voteType: "post"
                votes: page.video.votes || 0
                comments: page.video.comments || 0
                payout: page.video.payout || ""
                showComments: false
                onRequireLogin: page.pageStack.push(Qt.resolvedUrl("LoginPage.qml"))
            }

            Label {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.video.body || ""
                textFormat: Text.RichText
                font.family: Style.fontFamily
                wrapMode: Text.WordWrap
                color: Style.textPrimary
                onLinkActivated: Qt.openUrlExternally(link)
                visible: text.length > 0
            }

            Item { width: 1; height: Style.spacingL }
        }
    }
}
