import QtQuick 2.7
import Lomiri.Components 1.3
import "Theme"
import "Session"
import "components"
import "services/AccountService.js" as AccountService

/*
 * Application shell: a persistent bottom tab bar with one PageStack per tab so
 * each section keeps its own navigation history. On launch we validate any
 * stored auth token in the background.
 */
MainView {
    id: root
    objectName: "mainView"
    applicationName: "serey.tehenglay"
    automaticOrientation: true

    width: units.gu(45)
    height: units.gu(80)

    property int currentTab: 0

    Component.onCompleted: {
        if (Session.isLoggedIn) {
            AccountService.verify(Config.baseUrl, Session.token,
                function (account) { /* token still valid */ },
                function (err) { Session.clear(); });
        }
    }

    // --- Content area: four stacks, only the active one visible ----------
    Item {
        id: body
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: navBar.top
        }

        PageStack {
            id: homeStack
            anchors.fill: parent
            visible: root.currentTab === 0
            Component.onCompleted: push(Qt.resolvedUrl("pages/HomepagePage.qml"))
        }
        PageStack {
            id: newsStack
            anchors.fill: parent
            visible: root.currentTab === 1
            Component.onCompleted: push(Qt.resolvedUrl("pages/NewsPage.qml"))
        }
        PageStack {
            id: videoStack
            anchors.fill: parent
            visible: root.currentTab === 2
            Component.onCompleted: push(Qt.resolvedUrl("pages/VideoPage.qml"))
        }
        PageStack {
            id: settingsStack
            anchors.fill: parent
            visible: root.currentTab === 3
            Component.onCompleted: push(Qt.resolvedUrl("pages/SettingsPage.qml"))
        }
    }

    // --- Bottom navigation ------------------------------------------------
    Rectangle {
        id: navBar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: units.gu(7)
        color: Style.surface

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: units.dp(1)
            color: Style.divider
        }

        Row {
            anchors.fill: parent

            Repeater {
                model: [
                    { label: i18n.tr("Homepage"), icon: "home" },
                    { label: i18n.tr("News"),     icon: "stock_note" },
                    { label: i18n.tr("Video"),    icon: "camcorder" },
                    { label: i18n.tr("Settings"), icon: "settings" }
                ]
                delegate: AbstractButton {
                    width: navBar.width / 4
                    height: navBar.height
                    property bool active: root.currentTab === index

                    Column {
                        anchors.centerIn: parent
                        spacing: units.gu(0.5)
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: units.gu(2.8)
                            height: width
                            name: modelData.icon
                            color: active ? Style.brand : Style.textSecondary
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            textSize: Label.XSmall
                            color: active ? Style.brand : Style.textSecondary
                        }
                    }
                    onClicked: root.currentTab = index
                }
            }
        }
    }

    // --- Transient notifications (snackbar) overlay -----------------------
    Toaster { }
}
