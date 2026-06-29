import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/NotificationService.js" as NotificationService

Page {
    id: page

    property int offset: 0
    property bool loading: false
    property bool endReached: false
    property int unreadCount: 0
    property string errorMsg: ""
    property var inflight: null

    header: PageHeader {
        title: i18n.tr("Notifications")
        leadingActionBar.actions: [
            Action { iconName: "back"; text: i18n.tr("Back"); onTriggered: page.pageStack.pop() }
        ]
        trailingActionBar.actions: [
            Action {
                iconName: "select"
                text: i18n.tr("Mark all read")
                enabled: page.unreadCount > 0
                onTriggered: page.markAllRead()
            }
        ]
    }

    ListModel { id: notifModel; dynamicRoles: true }

    function reload() {
        if (page.inflight) { page.inflight.abort(); page.inflight = null; }
        notifModel.clear()
        page.offset = 0
        page.endReached = false
        page.errorMsg = ""
        page.loadPage()
        page.fetchUnread()
    }

    function loadPage() {
        if (page.loading || page.endReached) return
        page.loading = true
        page.inflight = NotificationService.listSerey(
            Config.baseUrl, Session.token, 20, page.offset,
            function (items) {
                page.loading = false
                page.inflight = null
                if (items.length === 0) { page.endReached = true; return }
                for (var i = 0; i < items.length; i++) {
                    var n = items[i]
                    notifModel.append({
                        nid:        String(n.id || n._id || ""),
                        message:    n.message || n.content || n.description || "",
                        actorName:  n.actor_name || n.actor || n.from_user || "",
                        actorIcon:  n.actor_image_url || n.actor_image || n.from_user_image || "",
                        timeAgo:    Style.formatTimeAgo(n.created_at || n.createdAt || ""),
                        isRead:     !!(n.is_read || n.read || false),
                        ntype:      n.type || n.notification_type || ""
                    })
                }
                page.offset += items.length
            },
            function (err) {
                page.loading = false
                page.inflight = null
                page.errorMsg = err.message || i18n.tr("Failed to load notifications.")
            }
        )
    }

    function fetchUnread() {
        NotificationService.unreadCount(Config.baseUrl, Session.token,
            function (count) { page.unreadCount = count },
            function (err)   { /* silent */ })
    }

    function markAllRead() {
        NotificationService.markAllRead(Config.baseUrl, Session.token,
            function () {
                page.unreadCount = 0
                for (var i = 0; i < notifModel.count; i++)
                    notifModel.setProperty(i, "isRead", true)
                Toast.show(i18n.tr("All notifications marked as read"))
            },
            function (err) { Toast.show(err.message || i18n.tr("Failed to mark as read")) })
    }

    function markOneRead(index, nid) {
        if (notifModel.get(index).isRead) return
        NotificationService.markOneRead(Config.baseUrl, Session.token, nid,
            function () {
                notifModel.setProperty(index, "isRead", true)
                if (page.unreadCount > 0) page.unreadCount--
            },
            function (err) { /* silent */ })
    }

    Component.onCompleted: page.reload()

    // ── Content ──────────────────────────────────────────────────────────────
    ListView {
        id: list
        anchors { top: parent.header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        model: notifModel
        clip: true
        spacing: 0

        delegate: AbstractButton {
            width: list.width
            height: units.gu(8)
            onClicked: page.markOneRead(index, model.nid)

            // Unread background tint
            Rectangle {
                anchors.fill: parent
                color: model.isRead ? "transparent" : Qt.rgba(0, 0.51, 0.98, 0.05)
            }

            Row {
                anchors { fill: parent; leftMargin: Style.spacingM; rightMargin: Style.spacingM }
                spacing: Style.spacingM

                // Unread dot
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: units.gu(1); height: width; radius: width / 2
                    color: Style.brand
                    visible: !model.isRead
                }
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: units.gu(1); height: width
                    visible: model.isRead
                }

                // Actor avatar
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: units.gu(5); height: width; radius: width / 2
                    color: Style.iconBackground

                    CircleImage {
                        id: actorImg
                        anchors { fill: parent; margins: units.dp(2) }
                        source: model.actorIcon
                    }
                    Label {
                        anchors.centerIn: parent
                        text: model.actorName.length > 0 ? model.actorName.charAt(0).toUpperCase() : "?"
                        font.pixelSize: Style.fontMedium
                        font.bold: true
                        color: Style.brand
                        visible: !actorImg.loaded
                    }
                }

                // Message + time
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - units.gu(6) - units.gu(1) - Style.spacingM * 2
                    spacing: units.dp(3)

                    Label {
                        width: parent.width
                        text: model.message
                        font.pixelSize: Style.fontSmall
                        font.family: Style.fontFamily
                        font.weight: model.isRead ? Font.Normal : Font.DemiBold
                        color: model.isRead ? Style.textSecondary : Style.textPrimary
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Label {
                        text: model.timeAgo
                        font.pixelSize: Style.fontXSmall
                        font.family: Style.fontFamily
                        color: Style.textSecondary
                    }
                }
            }

            // Divider
            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: Style.spacingM }
                height: units.dp(1)
                color: Style.divider
            }
        }

        // Load more on scroll to bottom
        onAtYEndChanged: {
            if (atYEnd && !page.loading && !page.endReached)
                page.loadPage()
        }

        // Empty state
        Label {
            anchors.centerIn: parent
            visible: notifModel.count === 0 && !page.loading && page.errorMsg === ""
            text: i18n.tr("No notifications yet")
            font.pixelSize: Style.fontLarge
            font.family: Style.fontFamily
            color: Style.textSecondary
        }

        // Error state
        Column {
            anchors.centerIn: parent
            visible: page.errorMsg.length > 0 && notifModel.count === 0
            spacing: Style.spacingM

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.errorMsg
                font.pixelSize: Style.fontSmall
                font.family: Style.fontFamily
                color: Style.danger
                wrapMode: Text.WordWrap
                width: list.width - Style.spacingM * 2
                horizontalAlignment: Text.AlignHCenter
            }
            PrimaryButton {
                anchors.horizontalCenter: parent.horizontalCenter
                width: units.gu(20)
                text: i18n.tr("Retry")
                onClicked: page.reload()
            }
        }

        // Footer spinner
        footer: Item {
            width: list.width
            height: page.loading ? units.gu(6) : 0
            visible: page.loading
            ActivityIndicator {
                anchors.centerIn: parent
                running: page.loading
            }
        }
    }

    // Initial full-screen spinner
    ActivityIndicator {
        anchors.centerIn: parent
        running: page.loading && notifModel.count === 0
        visible: running
    }
}
