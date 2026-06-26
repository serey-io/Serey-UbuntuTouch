import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../services/AccountService.js" as AccountService

/*
 * Username/password login. On success stores the JWT in Session and pops back
 * to Settings (which then loads the profile).
 */
Page {
    id: page

    property bool busy: false
    property string errorMsg: ""

    header: PageHeader {
        title: i18n.tr("Log in")
    }

    function submit() {
        if (busy) return;
        errorMsg = "";
        if (usernameField.text.length === 0 || passwordField.text.length === 0) {
            errorMsg = i18n.tr("Please enter your username and password.");
            return;
        }
        busy = true;
        AccountService.login(Config.baseUrl, usernameField.text, passwordField.text,
            function (auth) {
                busy = false;
                Session.setAuth(auth.token, usernameField.text);
                AccountService.profile(Config.baseUrl, usernameField.text, auth.token,
                    function (user) { Session.avatarUrl = user.profileUrl; },
                    function (err) { /* keep letter-fallback avatar */ });
                page.pageStack.pop();
            },
            function (err) {
                busy = false;
                page.errorMsg = err.message;
            });
    }

    Flickable {
        anchors { top: page.header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentWidth: width
        contentHeight: form.height + Style.spacingL * 2
        clip: true

        Column {
            id: form
            width: Math.min(parent.width - Style.spacingL * 2, units.gu(50))
            anchors.horizontalCenter: parent.horizontalCenter
            y: Style.spacingL
            spacing: Style.spacingM

            Label {
                width: parent.width
                text: i18n.tr("Sign in with your Serey account")
                textSize: Label.Large
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            TextField {
                id: usernameField
                width: parent.width
                placeholderText: i18n.tr("Username")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                onAccepted: passwordField.forceActiveFocus()
            }

            TextField {
                id: passwordField
                width: parent.width
                placeholderText: i18n.tr("Password")
                echoMode: TextInput.Password
                onAccepted: page.submit()
            }

            Label {
                width: parent.width
                text: page.errorMsg
                color: Style.danger
                wrapMode: Text.WordWrap
                visible: text.length > 0
            }

            Button {
                width: parent.width
                text: page.busy ? i18n.tr("Signing in…") : i18n.tr("Log in")
                color: Style.brand
                enabled: !page.busy
                onClicked: page.submit()
            }

            ActivityIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: page.busy
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                textSize: Label.Small
                color: Style.textSecondary
                wrapMode: Text.WordWrap
                linkColor: Style.brand
                text: i18n.tr("Don't have an account? <a href='https://signup.serey.io'>Sign up at serey.io</a>")
                onLinkActivated: Qt.openUrlExternally(link)
            }
        }
    }
}
