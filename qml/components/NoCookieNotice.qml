import QtQuick 2.7
import Qt.labs.settings 1.0
import QtGraphicalEffects 1.0
import Lomiri.Components 1.3
import "../Theme"
import "../Session"

// One-time "no cookies" welcome, same as web
Item {
    id: root
    anchors.fill: parent
    visible: false
    z: 1700

    readonly property int showDelayMs: 5000
    readonly property string privacyUrl: "https://serey.io/privacy-policy"
    // Web's two-column layout
    readonly property bool wide: width >= units.gu(70)

    Settings {
        id: store
        category: "NoCookieNotice"
        property bool seen: false
    }

    Timer {
        interval: root.showDelayMs
        running: !store.seen
        onTriggered: root.open()
    }

    function open() {
        if (store.seen || root.visible) return;
        root.visible = true;
        closeAnim.stop();
        openAnim.restart();
    }

    function close() {
        store.seen = true;
        if (!root.visible || closeAnim.running) return;
        openAnim.stop();
        closeAnim.restart();
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: backdrop; property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutQuad }
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutQuad }
        NumberAnimation { target: card; property: "offsetY"; from: units.gu(2); to: 0; duration: 250; easing.type: Easing.OutQuad }
        SequentialAnimation {
            PropertyAction { target: ring; property: "scale"; value: 0 }
            PropertyAction { target: slash; property: "grow"; value: 0 }
            PauseAnimation { duration: 550 }
            NumberAnimation { target: ring; property: "scale"; to: 1; duration: 350; easing.type: Easing.OutBack }
        }
        SequentialAnimation {
            PauseAnimation { duration: 800 }
            NumberAnimation { target: slash; property: "grow"; to: 1; duration: 250; easing.type: Easing.OutQuad }
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
        // Tap outside: dismiss
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Item {
        id: card
        property real offsetY: 0
        width: Math.min(parent.width - units.gu(5), units.gu(97))
        height: root.wide ? Math.max(units.gu(45), content.implicitHeight + units.gu(6))
                          : art.height + content.implicitHeight + units.gu(5)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: offsetY
        // Swallow taps on card
        MouseArea { anchors.fill: parent }

        // Rounded clip
        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: units.gu(2.5)
            color: Style.card

            // Art panel: navy bg + no-cookie sign
            // Mask: card-shaped, cropped to art
            Item {
                id: artMask
                width: art.width; height: art.height
                visible: false
                clip: true
                Rectangle { width: cardBg.width; height: cardBg.height; radius: cardBg.radius }
            }

            Item {
                id: art
                width: root.wide ? parent.width * 0.3 : parent.width
                height: root.wide ? parent.height : units.gu(22)
                layer.enabled: true
                layer.effect: OpacityMask { maskSource: artMask }

                Image {
                    anchors.fill: parent
                    source: Qt.resolvedUrl("../../assets/no-cookie-bg.webp")
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                // Navy tint
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(11 / 255, 31 / 255, 75 / 255, 0.55) }
                        GradientStop { position: 1; color: Qt.rgba(11 / 255, 31 / 255, 75 / 255, 0.75) }
                    }
                }

                Item {
                    id: sign
                    readonly property real size: units.gu(15)
                    width: size; height: size
                    anchors.centerIn: parent

                    // Grayscale cookie, slow spin
                    Item {
                        id: cookie
                        anchors.centerIn: parent
                        width: sign.size * 0.72; height: width
                        RotationAnimation on rotation {
                            running: root.visible
                            from: 0; to: 360
                            duration: 12000
                            loops: Animation.Infinite
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "#B5B5B5"
                            border.width: units.dp(3)
                            border.color: "#8E8E8E"
                        }
                        Repeater {
                            // Chips: [x, y, size] as fractions
                            model: [[0.28, 0.25, 0.14], [0.58, 0.2, 0.11], [0.68, 0.5, 0.15],
                                    [0.22, 0.56, 0.12], [0.45, 0.45, 0.09], [0.45, 0.7, 0.13]]
                            delegate: Rectangle {
                                x: cookie.width * modelData[0]
                                y: cookie.height * modelData[1]
                                width: cookie.width * modelData[2]; height: width
                                radius: width * 0.35
                                rotation: index * 37
                                color: "#4A4A4A"
                            }
                        }
                    }

                    // "No" ring
                    Rectangle {
                        id: ring
                        anchors.centerIn: parent
                        width: sign.size * 1.1; height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: units.dp(8)
                        border.color: "#E0334B"
                        scale: 0
                    }
                    // Slash, grows from center
                    Rectangle {
                        id: slash
                        property real grow: 0
                        z: 1
                        anchors.centerIn: parent
                        width: (ring.width - units.dp(7)) * grow
                        height: units.dp(8)
                        radius: height / 2
                        color: "#E0334B"
                        rotation: -45
                    }
                }
            }

            // Text column
            Column {
                id: content
                x: root.wide ? art.width + units.gu(5) : units.gu(2.5)
                y: root.wide ? units.gu(2.75) : art.height + units.gu(2.5)
                width: root.wide ? parent.width - art.width - units.gu(8.5) : parent.width - units.gu(5)
                spacing: 0

                // Logo + title, one row
                Row {
                    width: parent.width
                    spacing: units.gu(1.5)

                    Image {
                        id: logo
                        source: Qt.resolvedUrl("../../assets/serey-logo.png")
                        height: units.gu(4.25)
                        width: height
                        fillMode: Image.PreserveAspectFit
                        sourceSize.height: height * 2
                    }

                    Label {
                        width: parent.width - logo.width - parent.spacing
                        anchors.verticalCenter: logo.verticalCenter
                        text: Lang.tr("We don't track you.")
                        font.pixelSize: Style.fontTitle * 0.95
                        font.weight: Font.Bold
                        font.family: Style.fontFor(text)
                        color: Style.dark ? Style.textTitle : "#0B1F4B"
                        wrapMode: Text.WordWrap
                    }
                }

                Item { width: 1; height: units.gu(1.75) }

                Label {
                    width: parent.width
                    text: Lang.tr("No tracking, no advertising, no data sold. Our statistics can't identify you.")
                    font.pixelSize: Style.fontLarge
                    font.family: Style.fontFor(text)
                    lineHeight: 1.3
                    color: Style.textSecondary
                    wrapMode: Text.WordWrap
                }

                Item { width: 1; height: units.gu(3.5) }

                // Bottom-right actions; stack when narrow
                Flow {
                    id: actions
                    width: parent.width
                    spacing: units.gu(1.5)
                    layoutDirection: Qt.RightToLeft

                    PrimaryButton {
                        width: Math.max(units.gu(10), implicitWidth)
                        text: Lang.tr("Close")
                        onClicked: root.close()
                    }
                    SecondaryButton {
                        width: Math.max(units.gu(10), implicitWidth)
                        text: Lang.tr("Read our privacy policy")
                        onClicked: { Qt.openUrlExternally(root.privacyUrl); root.close(); }
                    }
                }
            }

            // Close icon, top-right
            AbstractButton {
                anchors { top: parent.top; right: parent.right; margins: units.gu(2) }
                width: units.gu(4); height: width
                onClicked: root.close()
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    // Readable over art on phone
                    color: root.wide ? "transparent" : Qt.rgba(0, 0, 0, 0.35)
                }
                Icon {
                    anchors.centerIn: parent
                    width: units.gu(2.2); height: width
                    name: "close"
                    color: root.wide ? Style.textSecondary : "white"
                }
            }
        }
    }
}
