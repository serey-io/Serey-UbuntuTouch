import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/AccountService.js" as AccountService

/*
 * Standard (custodial) account signup, mirroring the web's email flow:
 *   step 0 — choose a username (checked for availability)
 *   step 1 — enter email + password (sends an OTP)
 *   step 2 — enter the OTP to create the account
 * On success the account is created and auto-logged-in, then we pop back.
 * Styled with the shared design tokens (logo hero, FormField, PrimaryButton).
 */
Page {
    id: page

    property int step: 0
    property bool busy: false
    property string errorMsg: ""

    // Carried across steps.
    property string username: ""
    property string email: ""
    property string password: ""

    header: PageHeader {
        title: i18n.tr("Create account")
    }

    function fail(err) { busy = false; page.errorMsg = err.message; }

    // step 0 -> 1: validate the format locally, then confirm with the backend
    // that the username isn't already taken before collecting contact details.
    function checkUsername() {
        if (busy) return;
        errorMsg = "";
        if (!AccountService.isValidUsername(usernameField.text)) {
            errorMsg = i18n.tr("Username must be 5–30 characters: lowercase letters, numbers or hyphens.");
            return;
        }
        busy = true;
        AccountService.checkUsernameAvailable(Config.baseUrl, usernameField.text,
            function () { busy = false; username = usernameField.text; step = 1; },
            fail);
    }

    // step 1 -> 2: validate, then request the OTP.
    function sendOtp() {
        if (busy) return;
        errorMsg = "";
        if (emailField.text.indexOf("@") < 0) {
            errorMsg = i18n.tr("Please enter a valid email address.");
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
        email = emailField.text;
        password = passwordField.text;
        busy = true;
        AccountService.sendSignupOtp(Config.baseUrl, username, email,
            function () { busy = false; step = 2; },
            fail);
    }

    // step 2: create the account (auto-logs in on success).
    function createAccount() {
        if (busy) return;
        errorMsg = "";
        if (otpField.text.length === 0) {
            errorMsg = i18n.tr("Please enter the verification code.");
            return;
        }
        busy = true;
        AccountService.createStandardAccount(Config.baseUrl, username, email,
            otpField.text, password,
            function (auth) {
                busy = false;
                Session.setAuth(auth.token, username);
                Toast.success(i18n.tr("Welcome to Serey!"));
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

            // Step indicator dots (3 steps)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.spacingS
                Repeater {
                    model: 3
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
                text: page.step === 0 ? i18n.tr("Choose a username")
                    : page.step === 1 ? i18n.tr("Set your email and password")
                    : i18n.tr("Enter the code we emailed you")
                font.pixelSize: Style.fontTitle
                font.weight: Font.DemiBold
                color: Style.textTitle
                wrapMode: Text.WordWrap
            }

            Item { width: 1; height: Style.spacingXs }

            // --- Step 0: username -------------------------------------------
            FormField {
                id: usernameField
                visible: page.step === 0
                width: parent.width
                placeholder: i18n.tr("Username")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                onAccepted: page.checkUsername()
            }

            // --- Step 1: email + password -----------------------------------
            FormField {
                id: emailField
                visible: page.step === 1
                width: parent.width
                placeholder: i18n.tr("Email")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhEmailCharactersOnly
            }
            FormField {
                id: passwordField
                visible: page.step === 1
                width: parent.width
                placeholder: i18n.tr("Password")
                echoMode: TextInput.Password
            }
            FormField {
                id: confirmField
                visible: page.step === 1
                width: parent.width
                placeholder: i18n.tr("Confirm password")
                echoMode: TextInput.Password
                onAccepted: page.sendOtp()
            }
            PasswordChecklist {
                visible: page.step === 1
                width: parent.width
                password: passwordField.text
            }

            // --- Step 2: OTP ------------------------------------------------
            Label {
                visible: page.step === 2
                width: parent.width
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSmall
                color: Style.textSecondary
                wrapMode: Text.WordWrap
                text: i18n.tr("We sent a verification code to %1.").arg(page.email)
            }
            FormField {
                id: otpField
                visible: page.step === 2
                width: parent.width
                placeholder: i18n.tr("Verification code")
                inputMethodHints: Qt.ImhDigitsOnly
                onAccepted: page.createAccount()
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
                    : page.step === 0 ? i18n.tr("Continue")
                    : page.step === 1 ? i18n.tr("Send code")
                    : i18n.tr("Create account")
                onClicked: {
                    if (page.step === 0) page.checkUsername();
                    else if (page.step === 1) page.sendOtp();
                    else page.createAccount();
                }
            }
        }
    }
}
