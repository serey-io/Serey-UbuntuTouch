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
                color: "#000000"
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
                    onClicked: {
                        if ((page.video.embedUrl || "").length > 0)
                            page.playing = true;
                        else if ((page.video.videoLink || "").length > 0)
                            Qt.openUrlExternally(page.video.videoLink);
                    }
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
                    source: page.playing ? Qt.resolvedUrl("../components/VideoWebView.qml") : ""
                    onItemChanged: if (item) item.embedUrl = page.video.embedUrl || ""
                    onStatusChanged: {
                        if (status === Loader.Error) {
                            page.playing = false;
                            if ((page.video.videoLink || "").length > 0)
                                Qt.openUrlExternally(page.video.videoLink);
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
                Item { width: units.gu(1); height: 1 }
                Label {
                    text: "▲ " + (page.video.votes || 0)
                    textSize: Label.Small
                    color: Style.textSecondary
                }
            }

            Label {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.video.body || ""
                textFormat: Text.RichText
                wrapMode: Text.WordWrap
                color: Style.textPrimary
                onLinkActivated: Qt.openUrlExternally(link)
                visible: text.length > 0
            }

            Item { width: 1; height: Style.spacingL }
        }
    }
}
