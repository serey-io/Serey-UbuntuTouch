import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItems
import "../Theme"
import "../Session"
import "../components"
import "../services/AccountService.js" as AccountService

/*
 * Settings: when signed in, shows the account profile and a logout action;
 * otherwise prompts to log in. Always shows app preferences (dev server) and
 * an About section.
 */
Page {
    id: page

    property var profile: null
    property bool loading: false
    property string errorMsg: ""

    header: PageHeader {
        title: i18n.tr("Settings")
    }

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
        anchors { top: page.header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentWidth: width
        contentHeight: col.height
        clip: true

        Column {
            id: col
            width: parent.width

            // ---- Account section --------------------------------------
            ListItems.Header { text: i18n.tr("Account") }

            // Signed-out prompt
            Column {
                width: parent.width
                visible: !Session.isLoggedIn
                spacing: Style.spacingM

                Item { width: 1; height: Style.spacingS }
                Label {
                    width: parent.width - Style.spacingM * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n.tr("Log in to your Serey account to view your profile and personalised feed.")
                    wrapMode: Text.WordWrap
                    color: Style.textSecondary
                }
                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
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

                Row {
                    width: parent.width - Style.spacingM * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: units.gu(10)
                    spacing: Style.spacingM
                    visible: page.profile !== null

                    LomiriShape {
                        width: units.gu(8)
                        height: units.gu(8)
                        anchors.verticalCenter: parent.verticalCenter
                        radius: "medium"
                        source: Image {
                            source: page.profile ? page.profile.profileUrl : ""
                            fillMode: Image.PreserveAspectCrop
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
                            text: page.profile ? page.profile.fullName : ""
                            textSize: Label.Large
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: page.profile ? ("@" + page.profile.username) : ""
                            textSize: Label.Small
                            color: Style.brand
                        }
                        Label {
                            text: page.profile ? page.profile.balance : ""
                            textSize: Label.Small
                            color: Style.textSecondary
                            visible: text.length > 0
                        }
                    }
                }

                ListItems.SingleValue {
                    text: i18n.tr("Posts")
                    value: page.profile ? page.profile.postCount : 0
                    visible: page.profile !== null
                }
                ListItems.SingleValue {
                    text: i18n.tr("Followers")
                    value: page.profile ? page.profile.followers : 0
                    visible: page.profile !== null
                }
                ListItems.SingleValue {
                    text: i18n.tr("Following")
                    value: page.profile ? page.profile.following : 0
                    visible: page.profile !== null
                }
                ListItems.SingleValue {
                    text: i18n.tr("Serey Power")
                    value: page.profile ? page.profile.sereyPower : ""
                    visible: page.profile !== null && page.profile.sereyPower.length > 0
                }

                ListItems.Standard {
                    text: i18n.tr("Log out")
                    onClicked: page.doLogout()
                }
            }

            // ---- Preferences ------------------------------------------
            ListItems.Header { text: i18n.tr("Preferences") }

            ListItems.Standard {
                text: i18n.tr("Use local dev server")
                control: Switch {
                    checked: Config.useLocalDev
                    onCheckedChanged: Config.useLocalDev = checked
                }
            }
            Label {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: Config.baseUrl
                textSize: Label.XSmall
                color: Style.textSecondary
                elide: Text.ElideRight
            }

            // ---- About ------------------------------------------------
            ListItems.Header { text: i18n.tr("About") }

            ListItems.SingleValue {
                text: i18n.tr("Version")
                value: "0.1.0"
            }
            ListItems.Standard {
                text: i18n.tr("Serey website")
                onClicked: Qt.openUrlExternally("https://serey.io")
            }

            Item { width: 1; height: Style.spacingL }
        }
    }

    LoadingState {
        anchors.centerIn: parent
        width: units.gu(20); height: units.gu(20)
        visible: page.loading && page.profile === null
    }
}
