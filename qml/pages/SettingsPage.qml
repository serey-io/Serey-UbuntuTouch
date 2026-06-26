import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/AccountService.js" as AccountService

/*
 * Settings, in the iOS Serey app's grouped style: a welcome/identity header, then
 * sections (Account · Preferences · About) of rows, each with a circular icon
 * badge, label, and a trailing control/value/chevron. Signed out shows Log in /
 * Sign up; signed in shows the profile identity + stats and a Log out row.
 */
Page {
    id: page

    property var profile: null
    property bool loading: false
    property string errorMsg: ""

    // Zero-height header: the global AppHeader is the real top bar.
    header: Item { height: 0 }

    function refreshProfile() {
        if (!Session.isLoggedIn) { profile = null; return; }
        loading = true;
        errorMsg = "";
        AccountService.profile(Config.baseUrl, Session.username, Session.token,
            function (user) { loading = false; page.profile = user; },
            function (err) { loading = false; page.errorMsg = err.message; });
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

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.height
        clip: true

        Column {
            id: col
            width: parent.width

            // ===== Welcome / identity header ==============================
            Item {
                width: parent.width
                height: units.gu(13)

                Row {
                    anchors {
                        left: parent.left; right: parent.right;
                        verticalCenter: parent.verticalCenter
                        leftMargin: Style.spacingM; rightMargin: Style.spacingM
                    }
                    spacing: Style.spacingM

                    // Avatar: rounded-square brand badge when signed out, the
                    // profile photo (or letter) when signed in.
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(7); height: width

                        Rectangle {
                            anchors.fill: parent
                            radius: Session.isLoggedIn ? width / 2 : Style.cardRadius
                            color: (page.profile && page.profile.profileUrl)
                                   ? Style.iconBackground
                                   : (Session.isLoggedIn ? Style.avatarTint("") : Style.brand)
                            Icon {
                                anchors.centerIn: parent
                                width: units.gu(3.5); height: width
                                name: "account"
                                color: Style.textOnBrand
                                visible: !Session.isLoggedIn
                            }
                            Label {
                                anchors.centerIn: parent
                                visible: Session.isLoggedIn && !(page.profile && page.profile.profileUrl)
                                text: (page.profile && page.profile.username
                                       ? page.profile.username : "?").charAt(0).toUpperCase()
                                font.pixelSize: Style.fontTitle
                                font.bold: true
                                color: Style.brand
                            }
                        }
                        CircleImage {
                            anchors.fill: parent
                            source: page.profile && page.profile.profileUrl ? page.profile.profileUrl : ""
                            decode: units.gu(14)
                            visible: !!(page.profile && page.profile.profileUrl)
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - units.gu(7) - Style.spacingM
                        spacing: units.dp(3)

                        Label {
                            width: parent.width
                            text: Session.isLoggedIn
                                  ? ((page.profile && page.profile.fullName) ? page.profile.fullName
                                     : (page.profile ? page.profile.username : Session.username))
                                  : i18n.tr("Welcome to Serey")
                            font.pixelSize: Style.fontLarge
                            font.weight: Font.DemiBold
                            font.family: Style.fontFamily
                            color: Style.textTitle
                            elide: Text.ElideRight
                        }

                        // Signed in: @username. Signed out: Log in · Sign up.
                        Label {
                            visible: Session.isLoggedIn
                            width: parent.width
                            text: page.profile ? ("@" + page.profile.username) : ("@" + Session.username)
                            font.pixelSize: Style.fontSmall
                            font.family: Style.fontFamily
                            color: Style.brand
                            elide: Text.ElideRight
                        }
                        Row {
                            visible: !Session.isLoggedIn
                            spacing: Style.spacingS
                            AbstractButton {
                                width: loginLbl.width; height: loginLbl.height
                                onClicked: page.pageStack.push(Qt.resolvedUrl("LoginPage.qml"))
                                Label {
                                    id: loginLbl
                                    text: i18n.tr("Log in")
                                    font.pixelSize: Style.fontRegular
                                    font.weight: Font.DemiBold
                                    font.family: Style.fontFamily
                                    color: Style.brand
                                }
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "·"
                                font.pixelSize: Style.fontRegular
                                color: Style.textSecondary
                            }
                            AbstractButton {
                                width: signupLbl.width; height: signupLbl.height
                                onClicked: page.pageStack.push(Qt.resolvedUrl("CreateAccountPage.qml"))
                                Label {
                                    id: signupLbl
                                    text: i18n.tr("Sign up")
                                    font.pixelSize: Style.fontRegular
                                    font.weight: Font.DemiBold
                                    font.family: Style.fontFamily
                                    color: Style.brand
                                }
                            }
                        }
                    }
                }
            }

            // Signed-in stats strip
            Rectangle { width: parent.width; height: units.dp(1); color: Style.divider; visible: Session.isLoggedIn && page.profile !== null }
            Row {
                width: parent.width
                height: units.gu(8)
                visible: Session.isLoggedIn && page.profile !== null
                Repeater {
                    model: page.profile ? [
                        { label: i18n.tr("Posts"),     value: "" + page.profile.postCount },
                        { label: i18n.tr("Followers"), value: "" + page.profile.followers },
                        { label: i18n.tr("Following"), value: "" + page.profile.following }
                    ] : []
                    delegate: Column {
                        width: parent.width / 3
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.dp(2)
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.value
                            font.pixelSize: Style.fontLarge
                            font.weight: Font.DemiBold
                            font.family: Style.fontFamily
                            color: Style.textPrimary
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            font.pixelSize: Style.fontXSmall
                            font.family: Style.fontFamily
                            color: Style.textSecondary
                        }
                    }
                }
            }

            // ===== Preferences ============================================
            SettingsSectionHeader { text: i18n.tr("Preferences") }

            SettingsRow {
                iconName: "settings"
                label: i18n.tr("Use local dev server")
                showSwitch: true
                switchChecked: Config.useLocalDev
                onSwitchToggled: Config.useLocalDev = checked
            }
            Item {
                width: parent.width
                height: units.gu(4)
                Label {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: units.gu(8); rightMargin: Style.spacingM }
                    text: Config.baseUrl
                    font.pixelSize: Style.fontXSmall
                    font.family: Style.fontFamily
                    color: Style.textSecondary
                    elide: Text.ElideRight
                }
            }

            // ===== About ==================================================
            SettingsSectionHeader { text: i18n.tr("About") }

            SettingsRow {
                iconName: "info"
                label: i18n.tr("Version")
                valueText: "0.1.0"
            }
            SettingsRow {
                iconName: "external-link"
                label: i18n.tr("Serey website")
                showChevron: true
                onClicked: Qt.openUrlExternally("https://serey.io")
            }

            // ===== Account (log out) ======================================
            SettingsSectionHeader { text: i18n.tr("Account"); visible: Session.isLoggedIn }
            SettingsRow {
                visible: Session.isLoggedIn
                iconName: "system-log-out"
                label: i18n.tr("Log out")
                danger: true
                onClicked: page.doLogout()
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
