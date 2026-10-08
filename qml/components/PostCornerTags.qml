import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"

// Category + platform tags, cover top-right
Row {
    id: root

    property var post: ({})
    readonly property var p: post ? post : ({})
    // Breaking news = notched banner (web)
    readonly property bool ribbon: /breaking/i.test(p.primaryCategory || "")
    // Host draws the ribbon itself
    property bool hideRibbon: false

    signal platformClicked()

    spacing: Style.spacingXs

    BreakingRibbon {
        visible: root.ribbon && !root.hideRibbon
    }

    Rectangle {
        id: catTag
        // categories is ListModel-wrapped here; use the mapper's scalar copy instead.
        visible: (root.p.primaryCategory || "") !== "" && !root.ribbon
        width: catLabel.width + Style.spacingM
        height: units.gu(3)
        radius: Style.pillRadius
        color: Style.accentRed
        Label {
            id: catLabel
            anchors.centerIn: parent
            text: root.p.primaryCategory || ""
            font.pixelSize: Style.fontSmall
            font.weight: Font.DemiBold
            color: Style.textOnBrand
        }

        // Shine sweep, looped
        ShineSweep {
            anchors.fill: parent
            visible: catTag.visible
            mask: shineMask
        }
        Rectangle {
            id: shineMask
            anchors.fill: parent
            radius: catTag.radius
            visible: false
        }
    }

    // Platform tag
    Rectangle {
        id: platformTag
        readonly property var communityInfo: root.p.communityId > 0 ? Config.communityInfoFor(root.p.communityId) : null
        // Global uses the bundled globe icon
        readonly property string iconUrl: {
            if (!platformTag.communityInfo) return "";
            if (platformTag.communityInfo.dns === Config.sources[0].dns)
                return Config.communityIcon(platformTag.communityInfo.dns);
            return platformTag.communityInfo.icon || "";
        }
        visible: (root.p.community || "") !== ""
        width: platformRow.width + Style.spacingM
        height: units.gu(3)
        radius: Style.pillRadius
        color: "black"

        Row {
            id: platformRow
            anchors.centerIn: parent
            spacing: units.dp(4)

            Item {
                visible: platformTag.iconUrl !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? units.gu(1.8) : 0
                height: units.gu(1.8)
                CircleImage {
                    anchors.fill: parent
                    source: platformTag.iconUrl
                    fillMode: Image.PreserveAspectFit
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, units.gu(16))
                elide: Text.ElideRight
                text: root.p.community || ""
                font.pixelSize: Style.fontSmall
                font.weight: Font.DemiBold
                font.family: Style.fontFor(text)
                color: "white"
            }
        }
        // Own tap target
        MouseArea { anchors.fill: parent; onClicked: root.platformClicked() }
    }
}
