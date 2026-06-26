import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/AccountService.js" as AccountService

/*
 * Settings: when signed in, shows the account identity (avatar, name, stats) and
 * a logout action; otherwise invites the user to log in. Always shows app
 * preferences and an About section. Loose rows are grouped into rounded cards
 * (cardRadius + hairline divider border) to match the feed's design language;
 * the signed-out state reuses the auth pages' PrimaryButton for consistency.
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

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.height
        clip: true

        Column {
            id: col
            width: parent.width
            spacing: Style.spacingS

            Item { width: 1; height: Style.spacingM }

            // ---- Account -------------------------------------------------
            Label {
                x: Style.spacingM
                text: i18n.tr("Account")
                font.pixelSize: Style.fontSmall
                font.weight: Font.DemiBold
                font.family: Style.fontFamily
                color: Style.textSecondary
            }

            // Card: signed-out invite
            Rectangle {
                x: Style.spacingM
                width: parent.width - Style.spacingM * 2
                visible: !Session.isLoggedIn
                height: inviteCol.height + Style.spacingL * 2
                radius: Style.cardRadius
                color: Style.surface
                border.width: units.dp(1)
                border.color: Style.divider

                Column {
                    id: inviteCol
                    anchors {
                        left: parent.left; right: parent.right;
                        verticalCenter: parent.verticalCenter
                        leftMargin: Style.spacingM; rightMargin: Style.spacingM
                    }
                    spacing: Style.spacingM

                    PrimaryButton {
                        width: parent.width
                        text: i18n.tr("Log in")
                        onClicked: page.pageStack.push(Qt.resolvedUrl("LoginPage.qml"))
                    }
                    LinkButton {
                        width: parent.width
                        label: i18n.tr("Sign up")
                        onClicked: page.pageStack.push(Qt.resolvedUrl("SignupPage.qml"))
                    }
                }
            }

            // Card: signed-in identity
            Rectangle {
                x: Style.spacingM
                width: parent.width - Style.spacingM * 2
                visible: Session.isLoggedIn && page.profile !== null
                height: identityCol.height
                radius: Style.cardRadius
                color: Style.surface
                border.width: units.dp(1)
                border.color: Style.divider
                clip: true

                Column {
                    id: identityCol
                    width: parent.width

                    // Avatar + name
                    Row {
                        x: Style.spacingM
                        width: parent.width - Style.spacingM * 2
                        height: units.gu(11)
                        spacing: Style.spacingM

                        // Brand-tinted avatar with letter fallback (same language
                        // as the feed cards), or the profile photo when present.
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: units.gu(8); height: width

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Style.avatarTint(page.profile ? page.profile.username : "")
                                visible: !(page.profile && page.profile.profileUrl)
                                Label {
                                    anchors.centerIn: parent
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
                                decode: units.gu(16)
                                visible: !!(page.profile && page.profile.profileUrl)
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - units.gu(8) - Style.spacingM
                            spacing: units.dp(2)
                            Label {
                                width: parent.width
                                text: (page.profile && page.profile.fullName) ? page.profile.fullName
                                      : (page.profile ? page.profile.username : "")
                                font.pixelSize: Style.fontLarge
                                font.weight: Font.DemiBold
                                font.family: Style.fontFamily
                                color: Style.textPrimary
                                elide: Text.ElideRight
                            }
                            Label {
                                width: parent.width
                                text: page.profile ? ("@" + page.profile.username) : ""
                                font.pixelSize: Style.fontSmall
                                font.family: Style.fontFamily
                                color: Style.brand
                                elide: Text.ElideRight
                            }
                            Label {
                                width: parent.width
                                text: page.profile ? page.profile.balance : ""
                                font.pixelSize: Style.fontSmall
                                font.family: Style.fontFamily
                                color: Style.textSecondary
                                visible: text.length > 0
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        x: Style.spacingM
                        width: parent.width - Style.spacingM * 2
                        height: units.dp(1)
                        color: Style.divider
                    }

                    // Stats row
                    Row {
                        width: parent.width
                        height: units.gu(8)
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

                    // Serey Power footer line
                    Rectangle {
                        x: Style.spacingM
                        width: parent.width - Style.spacingM * 2
                        height: units.dp(1)
                        color: Style.divider
                        visible: page.profile !== null && (page.profile.sereyPower || "").length > 0
                    }
                    Item {
                        width: parent.width
                        height: units.gu(5)
                        visible: page.profile !== null && (page.profile.sereyPower || "").length > 0
                        Label {
                            anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                            text: i18n.tr("Serey Power")
                            font.pixelSize: Style.fontSmall
                            font.family: Style.fontFamily
                            color: Style.textSecondary
                        }
                        Label {
                            anchors { right: parent.right; rightMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                            text: page.profile ? page.profile.sereyPower : ""
                            font.pixelSize: Style.fontSmall
                            font.weight: Font.DemiBold
                            font.family: Style.fontFamily
                            color: Style.textPrimary
                        }
                    }
                }
            }

            // Card: log out (signed-in only)
            Rectangle {
                x: Style.spacingM
                width: parent.width - Style.spacingM * 2
                visible: Session.isLoggedIn
                height: units.gu(6.5)
                radius: Style.cardRadius
                color: Style.surface
                border.width: units.dp(1)
                border.color: Style.divider
                clip: true

                AbstractButton {
                    anchors.fill: parent
                    onClicked: page.doLogout()
                    Rectangle { anchors.fill: parent; radius: Style.cardRadius; color: parent.pressed ? Style.pressed : "transparent" }
                    Label {
                        anchors.centerIn: parent
                        text: i18n.tr("Log out")
                        font.pixelSize: Style.fontRegular
                        font.weight: Font.DemiBold
                        font.family: Style.fontFamily
                        color: Style.danger
                    }
                }
            }

            Item { width: 1; height: Style.spacingXs }

            // ---- Preferences ---------------------------------------------
            Label {
                x: Style.spacingM
                text: i18n.tr("Preferences")
                font.pixelSize: Style.fontSmall
                font.weight: Font.DemiBold
                font.family: Style.fontFamily
                color: Style.textSecondary
            }

            Rectangle {
                x: Style.spacingM
                width: parent.width - Style.spacingM * 2
                height: prefsCol.height
                radius: Style.cardRadius
                color: Style.surface
                border.width: units.dp(1)
                border.color: Style.divider
                clip: true

                Column {
                    id: prefsCol
                    width: parent.width

                    Item {
                        width: parent.width
                        height: units.gu(6.5)
                        Label {
                            anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                            text: i18n.tr("Use local dev server")
                            font.pixelSize: Style.fontRegular
                            font.family: Style.fontFamily
                            color: Style.textPrimary
                        }
                        Switch {
                            anchors { right: parent.right; rightMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                            checked: Config.useLocalDev
                            onCheckedChanged: Config.useLocalDev = checked
                        }
                    }
                    Rectangle {
                        x: Style.spacingM
                        width: parent.width - Style.spacingM * 2
                        height: units.dp(1)
                        color: Style.divider
                    }
                    Item {
                        width: parent.width
                        height: units.gu(5)
                        Label {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                      leftMargin: Style.spacingM; rightMargin: Style.spacingM }
                            text: Config.baseUrl
                            font.pixelSize: Style.fontXSmall
                            font.family: Style.fontFamily
                            color: Style.textSecondary
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Item { width: 1; height: Style.spacingXs }

            // ---- About ---------------------------------------------------
            Label {
                x: Style.spacingM
                text: i18n.tr("About")
                font.pixelSize: Style.fontSmall
                font.weight: Font.DemiBold
                font.family: Style.fontFamily
                color: Style.textSecondary
            }

            Rectangle {
                x: Style.spacingM
                width: parent.width - Style.spacingM * 2
                height: aboutCol.height
                radius: Style.cardRadius
                color: Style.surface
                border.width: units.dp(1)
                border.color: Style.divider
                clip: true

                Column {
                    id: aboutCol
                    width: parent.width

                    Item {
                        width: parent.width
                        height: units.gu(6.5)
                        Label {
                            anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                            text: i18n.tr("Version")
                            font.pixelSize: Style.fontRegular
                            font.family: Style.fontFamily
                            color: Style.textPrimary
                        }
                        Label {
                            anchors { right: parent.right; rightMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                            text: "0.1.0"
                            font.pixelSize: Style.fontRegular
                            font.family: Style.fontFamily
                            color: Style.textSecondary
                        }
                    }
                    Rectangle {
                        x: Style.spacingM
                        width: parent.width - Style.spacingM * 2
                        height: units.dp(1)
                        color: Style.divider
                    }
                    AbstractButton {
                        width: parent.width
                        height: units.gu(6.5)
                        onClicked: Qt.openUrlExternally("https://serey.io")
                        Rectangle { anchors.fill: parent; color: parent.pressed ? Style.pressed : "transparent" }
                        Label {
                            anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                            text: i18n.tr("Serey website")
                            font.pixelSize: Style.fontRegular
                            font.family: Style.fontFamily
                            color: Style.textPrimary
                        }
                        Icon {
                            anchors { right: parent.right; rightMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                            width: units.gu(2); height: width
                            name: "next"
                            color: Style.textSecondary
                        }
                    }
                }
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
