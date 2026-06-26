import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../components"
import "../services/AccountService.js" as AccountService

/*
 * Password reset for standard (custodial) accounts, mirroring the web flow:
 *   step 0 — username + email (backend checks they match, sends an OTP)
 *   step 1 — OTP + new password
 * On success we toast and pop back to the login page. Styled with the shared
 * design tokens (logo hero, FormField, PrimaryButton).
 */
Page {
    id: page

    property int step: 0
    property bool busy: false
    property string errorMsg: ""

    property string username: ""
    property string email: ""

    header: PageHeader {
        title: i18n.tr("Reset password")
    }

    function fail(err) { busy = false; page.errorMsg = err.message; }

    // step 0 -> 1: request the OTP.
    function requestOtp() {
        if (busy) return;
        errorMsg = "";
        if (usernameField.text.length === 0 || emailField.text.indexOf("@") < 0) {
            errorMsg = i18n.tr("Please enter your username and the email on your account.");
            return;
        }
        username = usernameField.text;
        email = emailField.text;
        busy = true;
        AccountService.requestPasswordReset(Config.baseUrl, username, email,
            function () { busy = false; step = 1; },
            fail);
    }

    // step 1: verify the OTP and set the new password.
    function submitReset() {
        if (busy) return;
        errorMsg = "";
        if (otpField.text.length === 0) {
            errorMsg = i18n.tr("Please enter the verification code.");
            return;
        }
        if (!AccountService.isValidPassword(passwordField.text)) {
            errorMsg = i18n.tr("Password must be 8–16 characters and include an uppercase letter, a lowercase letter and a number.");
            return;
        }
        if (passwordField.text !== confirmField.text) {
            errorMsg = i18n.tr("Passwords do not match.");
            return;
        }
        busy = true;
        AccountService.resetPassword(Config.baseUrl, username, otpField.text, passwordField.text,
            function () {
                busy = false;
                Toast.success(i18n.tr("Password reset. Please log in."));
                page.pageStack.pop();
            },
            fail);
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

            // Logo hero
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: units.gu(9); height: width
                source: Qt.resolvedUrl("../../assets/serey-logo.png")
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            // Step indicator dots (2 steps)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.spacingS
                Repeater {
                    model: 2
                    delegate: Rectangle {
                        width: units.gu(1); height: units.gu(1); radius: width / 2
                        color: index <= page.step ? Style.brand : Style.dotInactive
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
            }

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.family: Style.fontFamily
                text: page.step === 0 ? i18n.tr("Verify your identity")
                                      : i18n.tr("Enter the code and your new password")
                font.pixelSize: Style.fontTitle
                font.weight: Font.DemiBold
                color: Style.textTitle
                wrapMode: Text.WordWrap
            }

            Item { width: 1; height: Style.spacingXs }

            // --- Step 0: username + email -----------------------------------
            FormField {
                id: usernameField
                visible: page.step === 0
                width: parent.width
                placeholder: i18n.tr("Username")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            }
            FormField {
                id: emailField
                visible: page.step === 0
                width: parent.width
                placeholder: i18n.tr("Email on your account")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhEmailCharactersOnly
                onAccepted: page.requestOtp()
            }

            // --- Step 1: OTP + new password ---------------------------------
            Label {
                visible: page.step === 1
                width: parent.width
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSmall
                color: Style.textSecondary
                wrapMode: Text.WordWrap
                text: i18n.tr("We sent a verification code to %1.").arg(page.email)
            }
            FormField {
                id: otpField
                visible: page.step === 1
                width: parent.width
                placeholder: i18n.tr("Verification code")
                inputMethodHints: Qt.ImhDigitsOnly
            }
            FormField {
                id: passwordField
                visible: page.step === 1
                width: parent.width
                placeholder: i18n.tr("New password")
                echoMode: TextInput.Password
            }
            PasswordChecklist {
                visible: page.step === 1
                width: parent.width
                password: passwordField.text
            }
            FormField {
                id: confirmField
                visible: page.step === 1
                width: parent.width
                placeholder: i18n.tr("Confirm new password")
                echoMode: TextInput.Password
                onAccepted: page.submitReset()
            }

            Label {
                width: parent.width
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSmall
                text: page.errorMsg
                color: Style.danger
                wrapMode: Text.WordWrap
                visible: text.length > 0
            }

            PrimaryButton {
                width: parent.width
                busy: page.busy
                text: page.busy ? i18n.tr("Please wait…")
                    : page.step === 0 ? i18n.tr("Send code")
                    : i18n.tr("Reset password")
                onClicked: page.step === 0 ? page.requestOtp() : page.submitReset()
            }
        }
    }
}
