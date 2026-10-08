import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/AccountService.js" as AccountService
import "../services/FollowService.js" as FollowService

Page {
    id: page

    property bool loading: false
    property string errorMsg: ""
    readonly property real maxContentWidth: units.gu(60)

    header: PageHeader {
        title: Lang.tr("Following")
        leadingActionBar.actions: [
            Action { iconName: "back"; text: Lang.tr("Back"); onTriggered: page.pageStack.pop() }
        ]
    }

    ListModel { id: followModel; dynamicRoles: true }

    // Name + avatar, after list loads
    function _fetchProfile(index, username) {
        AccountService.profile(Config.baseUrl, username, Session.token,
            function (user) {
                if (!page || index >= followModel.count || followModel.get(index).username !== username) return;
                followModel.setProperty(index, "avatarUrl", user.profileUrl || "");
                followModel.setProperty(index, "displayName", user.fullName || "");
            },
            function (err) { /* letter avatar */ })
    }

    function load() {
        page.loading = true
        page.errorMsg = ""
        followModel.clear()
        FollowService.listFollowings(Config.baseUrl, Session.token,
            function (list) {
                if (!page) return;
                page.loading = false
                for (var i = 0; i < list.length; i++) {
                    FollowStore.set(list[i], true)
                    followModel.append({ username: list[i], avatarUrl: "", displayName: "" })
                    page._fetchProfile(followModel.count - 1, list[i])
                }
            },
            function (err) {
                if (!page) return;
                page.loading = false
                page.errorMsg = (err && err.message) || Lang.tr("Failed to load following.")
            })
    }

    function toggleFollow(username) {
        var now = FollowStore.toggle(Config.baseUrl, username, Session.token)
        Toast.show(now ? Lang.tr("Following") : Lang.tr("Unfollowed"))
    }

    Component.onCompleted: page.load()

    property Item keyboardFocusItem: list
    onVisibleChanged: if (visible) { list.kbEngaged = false; list.forceActiveFocus(); }

    ListView {
        id: list
        anchors { top: parent.header.bottom; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width: Math.min(parent.width, page.maxContentWidth)
        model: followModel
        clip: true
        property bool kbEngaged: false
        Keys.onPressed: list.kbEngaged = true
        Keys.onEscapePressed: page.pageStack.pop()
        Keys.onReturnPressed: {
            var it = followModel.get(list.currentIndex);
            if (it) page.pageStack.push(Qt.resolvedUrl("ProfileViewPage.qml"), { username: it.username });
        }
        highlight: Rectangle {
            z: 5
            width: list.width
            height: list.currentItem ? list.currentItem.height : 0
            visible: list.activeFocus && list.kbEngaged
            color: "transparent"
            border.width: units.dp(2)
            border.color: Style.brand
            radius: units.gu(0.5)
        }
        highlightMoveDuration: 0

        delegate: Item {
            width: list.width
            height: units.gu(9)
            readonly property int btnWidth: units.gu(11)
            readonly property bool following: FollowStore.isFollowing(model.username)

            MouseArea {
                id: rowPress
                anchors.fill: parent
                onClicked: page.pageStack.push(Qt.resolvedUrl("ProfileViewPage.qml"),
                               { username: model.username })
            }

            Rectangle {
                anchors.fill: parent
                color: rowPress.pressed ? Style.pressed : "transparent"
                z: 1
            }

            Item {
                id: rowAvatar
                anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                width: units.gu(6); height: width

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Style.avatarTint ? Style.avatarTint(model.username || "") : Style.brand
                    visible: (model.avatarUrl || "") === ""
                }
                Label {
                    anchors.centerIn: parent
                    visible: (model.avatarUrl || "") === ""
                    text: (model.username || "?").charAt(0).toUpperCase()
                    font.pixelSize: Style.fontLarge
                    font.bold: true
                    color: "white"
                }
                CircleImage {
                    anchors.fill: parent
                    source: model.avatarUrl || ""
                    decode: units.gu(12)
                    visible: (model.avatarUrl || "") !== ""
                }
            }

            Column {
                anchors {
                    left: rowAvatar.right; leftMargin: Style.spacingM
                    right: parent.right; rightMargin: Style.spacingM + btnWidth + Style.spacingS
                    verticalCenter: parent.verticalCenter
                }
                spacing: units.dp(3)

                Label {
                    text: model.displayName || model.username || ""
                    font.pixelSize: Style.fontRegular
                    font.weight: Font.DemiBold
                    font.family: Style.fontFor(text)
                    color: Style.textPrimary
                    elide: Text.ElideRight
                    width: parent.width
                }
                Label {
                    text: "@" + (model.username || "")
                    font.pixelSize: Style.fontSmall
                    font.family: Style.fontFor(text)
                    color: Style.textSecondary
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            Item {
                anchors { right: parent.right; rightMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                width: btnWidth; height: units.gu(4.5)
                z: 2

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: following ? "transparent" : Style.brand
                    border.width: units.dp(1.5)
                    border.color: Style.brand
                }
                Label {
                    anchors.centerIn: parent
                    text: following ? Lang.tr("Unfollow") : Lang.tr("Follow")
                    font.pixelSize: Style.fontSmall
                    font.weight: Font.DemiBold
                    font.family: Style.fontFor(text)
                    color: following ? Style.brand : "white"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: page.toggleFollow(model.username)
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: units.dp(1)
                color: Style.divider
            }
        }
    }

    ActivityIndicator {
        anchors.centerIn: parent
        running: page.loading
        visible: running
    }

    EmptyState {
        anchors { top: parent.header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        visible: !page.loading && page.errorMsg === "" && followModel.count === 0
        iconName: "contact"
        message: Lang.tr("Not following anyone yet")
    }

    ErrorState {
        anchors { top: parent.header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        visible: page.errorMsg !== "" && followModel.count === 0
        message: page.errorMsg
        onRetry: page.load()
    }
}
