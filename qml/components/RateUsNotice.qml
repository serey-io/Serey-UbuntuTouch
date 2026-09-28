import QtQuick 2.7
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import "../Theme"
import "../Session"

// OpenStore rating prompt
Item {
    id: root
    anchors.fill: parent
    visible: false
    z: 1690

    readonly property string storeUrl: "https://open-store.io/app/serey.serey-io"
    readonly property int minLaunches: 5
    readonly property real minDaysInstalled: 3
    readonly property real remindDays: 7
    readonly property int showDelayMs: 20000
    readonly property real _day: 86400000

    Settings {
        id: store
        category: "RateUs"
        property int launches: 0
        property real firstLaunch: 0
        property real nextAskAt: 0
        property bool done: false
    }

    // Wait for cookie notice
    Settings {
        id: cookie
        category: "NoCookieNotice"
        property bool seen: false
    }

    readonly property bool eligible: !store.done && cookie.seen
        && store.launches >= minLaunches
        && Date.now() - store.firstLaunch >= minDaysInstalled * _day
        && Date.now() >= store.nextAskAt

    Component.onCompleted: {
        if (store.firstLaunch <= 0) store.firstLaunch = Date.now();
        store.launches++;
    }

    Timer {
        interval: root.showDelayMs
        running: root.eligible
        onTriggered: root.open()
    }

    function open() {
        if (!root.eligible || root.visible) return;
        stars.rating = 0;
        root.visible = true;
        closeAnim.stop();
        openAnim.restart();
    }

    function close() {
        if (!root.visible || closeAnim.running) return;
        openAnim.stop();
        closeAnim.restart();
    }

    function rate() {
        store.done = true;
        Qt.openUrlExternally(root.storeUrl);
        root.close();
    }

    function later() {
        store.nextAskAt = Date.now() + remindDays * _day;
        root.close();
    }

    function never() {
        store.done = true;
        root.close();
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: backdrop; property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutQuad }
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutQuad }
        NumberAnimation { target: card; property: "offsetY"; from: units.gu(2); to: 0; duration: 250; easing.type: Easing.OutQuad }
        SequentialAnimation {
            PropertyAction { target: stars; property: "shown"; value: 0 }
            PauseAnimation { duration: 300 }
            NumberAnimation { target: stars; property: "shown"; to: 5; duration: 600 }
        }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: backdrop; property: "opacity"; to: 0; duration: 250; easing.type: Easing.InQuad }
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 250; easing.type: Easing.InQuad }
            NumberAnimation { target: card; property: "offsetY"; to: units.gu(2); duration: 250; easing.type: Easing.InQuad }
        }
        PropertyAction { target: root; property: "visible"; value: false }
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        // Tap outside: later
        MouseArea { anchors.fill: parent; onClicked: root.later() }
    }

    Rectangle {
        id: card
        property real offsetY: 0
        width: Math.min(parent.width - units.gu(5), units.gu(50))
        height: content.implicitHeight + units.gu(6)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: offsetY
        radius: units.gu(2.5)
        color: Style.card
        // Swallow taps on card
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            x: units.gu(3)
            y: units.gu(3)
            width: parent.width - units.gu(6)
            spacing: 0

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: Qt.resolvedUrl("../../assets/serey-logo.png")
                height: units.gu(7)
                width: height
                fillMode: Image.PreserveAspectFit
                sourceSize.height: height * 2
            }

            Item { width: 1; height: units.gu(2) }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Lang.tr("Enjoying Serey?")
                font.pixelSize: Style.fontTitle * 0.95
                font.weight: Font.Bold
                font.family: Style.fontFor(text)
                color: Style.dark ? Style.textTitle : "#0B1F4B"
                wrapMode: Text.WordWrap
            }

            Item { width: 1; height: units.gu(1.25) }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Lang.tr("A quick rating on the OpenStore helps other people find Serey.")
                font.pixelSize: Style.fontLarge
                font.family: Style.fontFor(text)
                lineHeight: 1.3
                color: Style.textSecondary
                wrapMode: Text.WordWrap
            }

            Item { width: 1; height: units.gu(2) }

            // Tap to rate; pop in on open
            Row {
                id: stars
                property real shown: 0
                property int rating: 0
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: units.gu(0.25)

                Repeater {
                    model: 5
                    delegate: AbstractButton {
                        width: units.gu(5); height: width
                        scale: Math.max(0, Math.min(1, stars.shown - index))
                        onClicked: { stars.rating = index + 1; bounce.restart(); }

                        Icon {
                            id: starIcon
                            anchors.centerIn: parent
                            width: units.gu(3.5); height: width
                            readonly property bool filled: index < stars.rating
                            name: filled ? "starred" : "non-starred"
                            color: filled ? "#F5B301" : Style.textSecondary
                        }
                        // Tap bounce
                        SequentialAnimation {
                            id: bounce
                            NumberAnimation { target: starIcon; property: "scale"; to: 1.3; duration: 90; easing.type: Easing.OutQuad }
                            NumberAnimation { target: starIcon; property: "scale"; to: 1; duration: 160; easing.type: Easing.OutBack }
                        }
                    }
                }
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: stars.rating > 0 ? Lang.tr("%1 of 5 stars").arg(stars.rating) : Lang.tr("Tap a star to rate")
                font.pixelSize: Style.fontSmall
                font.family: Style.fontFor(text)
                color: Style.textSecondary
            }

            Item { width: 1; height: units.gu(3) }

            PrimaryButton {
                width: parent.width
                text: Lang.tr("Rate on OpenStore")
                onClicked: root.rate()
            }

            Item { width: 1; height: units.gu(1.25) }

            SecondaryButton {
                width: parent.width
                text: Lang.tr("Maybe later")
                onClicked: root.later()
            }

            Item { width: 1; height: units.gu(0.5) }

            AbstractButton {
                width: parent.width
                height: units.gu(4.5)
                onClicked: root.never()
                Label {
                    anchors.centerIn: parent
                    text: Lang.tr("No thanks")
                    font.pixelSize: Style.fontRegular
                    font.family: Style.fontFor(text)
                    color: Style.textSecondary
                }
            }
        }
    }
}
