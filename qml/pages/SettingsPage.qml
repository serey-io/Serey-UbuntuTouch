import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/AccountService.js" as AccountService

/*
 * Settings: when signed in, shows the account profile (avatar, name, stats) and
 * a logout action; otherwise prompts to log in. Always shows app preferences
 * (dev server) and an About section. Styled with the app theme (no deprecated
 * Lomiri ListItems).
 */
Page {
    id: page

    property var profile: null
    property bool loading: false
    property string errorMsg: ""

    // Zero-height header: the global AppHeader is the real top bar.
    header: Item { height: 0 }

    function refreshProfile() {
        if (!Session.isLoggedIn) {
            profile = null;
            return;
        }
        loading = true;
        errorMsg = "";
        AccountService.profile(Config.baseUrl, Session.username, Session.token,
            function (user) {
                loading = false;
                page.profile = user;
            },
            function (err) {
                loading = false;
                page.errorMsg = err.message;
            });
    }

    function doLogout() {
        if (Session.token.length > 0)
            AccountService.logout(Config.baseUrl, Session.token, function () {}, function () {});
        Session.clear();
        page.profile = null;
    }

    Component.onCompleted: refreshProfile()

    Connections {
        target: Session
        function onTokenChanged() { page.refreshProfile(); }
    }

    // Reusable section header
    Component {
        id: sectionHeader
        Item {
            width: parent ? parent.width : 0
            height: units.gu(5)
            property string text: ""
            Label {
                anchors { left: parent.left; leftMargin: Style.spacingM; bottom: parent.bottom; bottomMargin: Style.spacingS }
                text: parent.text
                font.pixelSize: Style.fontSmall
                font.weight: Font.DemiBold
                color: Style.textSecondary
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.height
        clip: true

        Column {
            id: col
            width: parent.width

            // ---- Account ------------------------------------------------
            Loader { width: parent.width; height: units.gu(5); sourceComponent: sectionHeader; onLoaded: item.text = i18n.tr("Account") }

            // Signed-out prompt
            Column {
                width: parent.width - Style.spacingM * 2
                x: Style.spacingM
                visible: !Session.isLoggedIn
                spacing: Style.spacingM

                Item { width: 1; height: Style.spacingS }
                Label {
                    width: parent.width
                    text: i18n.tr("Log in to your Serey account to view your profile and personalised feed.")
                    wrapMode: Text.WordWrap
                    font.family: Style.fontFamily
                    color: Style.textSecondary
                }
                Button {
                    text: i18n.tr("Log in")
                    color: Style.brand
                    onClicked: page.pageStack.push(Qt.resolvedUrl("LoginPage.qml"))
                }
                Item { width: 1; height: Style.spacingS }
            }

            // Signed-in profile
            Column {
                width: parent.width
                visible: Session.isLoggedIn

                // Avatar + name
                Row {
                    x: Style.spacingM
                    width: parent.width - Style.spacingM * 2
                    height: units.gu(11)
                    spacing: Style.spacingM
                    visible: page.profile !== null

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(8); height: width
                        radius: width / 2
                        color: Style.iconBackground
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: page.profile ? page.profile.profileUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: !!(page.profile && page.profile.profileUrl)
                        }
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(4); height: width
                            name: "account"
                            color: Style.textSecondary
                            visible: !(page.profile && page.profile.profileUrl)
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.gu(0.5)
                        Label {
                            text: (page.profile && page.profile.fullName) ? page.profile.fullName : ""
                            font.pixelSize: Style.fontLarge
                            font.weight: Font.DemiBold
                            font.family: Style.fontFamily
                            color: Style.textPrimary
                        }
                        Label {
                            text: page.profile ? ("@" + page.profile.username) : ""
                            font.pixelSize: Style.fontSmall
                            color: Style.brand
                        }
                        Label {
                            text: page.profile ? page.profile.balance : ""
                            font.pixelSize: Style.fontSmall
                            color: Style.textSecondary
                            visible: text.length > 0
                        }
                    }
                }

                // Stats row
                Row {
                    x: Style.spacingM
                    width: parent.width - Style.spacingM * 2
                    visible: page.profile !== null
                    Repeater {
                        model: page.profile ? [
                            { label: i18n.tr("Posts"),     value: page.profile.postCount },
                            { label: i18n.tr("Followers"), value: page.profile.followers },
                            { label: i18n.tr("Following"), value: page.profile.following }
                        ] : []
                        delegate: Column {
                            width: (parent.width) / 3
                            spacing: units.dp(2)
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.value
                                font.pixelSize: Style.fontLarge
                                font.weight: Font.DemiBold
                                color: Style.textPrimary
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.pixelSize: Style.fontXSmall
                                color: Style.textSecondary
                            }
                        }
                    }
                }

                Item { width: 1; height: Style.spacingM }

                // Serey Power line
                Label {
                    x: Style.spacingM
                    text: i18n.tr("Serey Power: %1").arg(page.profile ? page.profile.sereyPower : "")
                    font.pixelSize: Style.fontSmall
                    color: Style.textSecondary
                    visible: page.profile !== null && (page.profile.sereyPower || "").length > 0
                }

                Item { width: 1; height: Style.spacingM }

                // Log out
                AbstractButton {
                    width: parent.width
                    height: units.gu(6)
                    onClicked: page.doLogout()
                    Rectangle { anchors.fill: parent; color: parent.pressed ? Style.pressed : "transparent" }
                    Label {
                        anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                        text: i18n.tr("Log out")
                        font.pixelSize: Style.fontRegular
                        color: Style.danger
                    }
                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: units.dp(1); color: Style.divider }
                }
            }

            // ---- Preferences --------------------------------------------
            Loader { width: parent.width; height: units.gu(5); sourceComponent: sectionHeader; onLoaded: item.text = i18n.tr("Preferences") }

            Item {
                width: parent.width
                height: units.gu(6)
                Label {
                    anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                    text: i18n.tr("Use local dev server")
                    font.pixelSize: Style.fontRegular
                    color: Style.textPrimary
                }
                Switch {
                    anchors { right: parent.right; rightMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                    checked: Config.useLocalDev
                    onCheckedChanged: Config.useLocalDev = checked
                }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: units.dp(1); color: Style.divider }
            }
            Label {
                x: Style.spacingM
                width: parent.width - Style.spacingM * 2
                text: Config.baseUrl
                font.pixelSize: Style.fontXSmall
                color: Style.textSecondary
                elide: Text.ElideRight
            }

            // ---- About --------------------------------------------------
            Loader { width: parent.width; height: units.gu(5); sourceComponent: sectionHeader; onLoaded: item.text = i18n.tr("About") }

            Item {
                width: parent.width
                height: units.gu(6)
                Label {
                    anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                    text: i18n.tr("Version")
                    font.pixelSize: Style.fontRegular
                    color: Style.textPrimary
                }
                Label {
                    anchors { right: parent.right; rightMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                    text: "0.1.0"
                    font.pixelSize: Style.fontRegular
                    color: Style.textSecondary
                }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: units.dp(1); color: Style.divider }
            }
            AbstractButton {
                width: parent.width
                height: units.gu(6)
                onClicked: Qt.openUrlExternally("https://serey.io")
                Rectangle { anchors.fill: parent; color: parent.pressed ? Style.pressed : "transparent" }
                Label {
                    anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                    text: i18n.tr("Serey website")
                    font.pixelSize: Style.fontRegular
                    color: Style.textPrimary
                }
                Icon {
                    anchors { right: parent.right; rightMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                    width: units.gu(2); height: width
                    name: "next"
                    color: Style.textSecondary
                }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: units.dp(1); color: Style.divider }
            }

            Item { width: 1; height: Style.spacingL }
        }
    }

    ActivityIndicator {
        anchors.centerIn: parent
        running: page.loading && page.profile === null
        visible: running
    }
}
