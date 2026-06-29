import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtGraphicalEffects 1.0
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

    property bool searching: false
    property bool searchOpen: false
    property var searchResults: []

    function doSearch(query) {
        var q = query.trim()
        if (q.length < 2) {
            page.searchResults = []
            page.searchOpen = false
            return
        }
        page.searching = true
        page.searchOpen = true
        console.log("Searching for:", q)
        AccountService.searchUser(Config.baseUrl, q,
            function (users) {
                page.searching = false
                console.log("Search results count:", users.length)
                if (users.length > 0)
                    console.log("First result keys:", JSON.stringify(Object.keys(users[0])))
                page.searchResults = users
                page.searchOpen = true
            },
            function (err) {
                page.searching = false
                page.searchResults = []
                console.log("Search error:", err.message)
            })
    }

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
        FollowStore.reset();
        page.profile = null;
    }

    Component.onCompleted: refreshProfile()

    // Re-fetch every time the Settings tab becomes active. The profile (incl. the
    // following/followers counts) is held in memory, and following someone happens
    // on another tab — so without this the count stays stale until something else
    // (token change, sub-page pop) forces a refresh. The backend invalidates the
    // profile cache on follow, so this re-fetch returns the up-to-date counts.
    onVisibleChanged: if (visible) refreshProfile()

    Connections {
        target: Session
        function onTokenChanged() { page.refreshProfile(); }
    }

    // Re-fetch when returning from a pushed sub-page (e.g. Edit profile) so the
    // header avatar/name reflect any just-saved changes.
    Connections {
        target: page.pageStack
        function onDepthChanged() {
            if (page.pageStack && page.pageStack.depth === 1)
                page.refreshProfile();
        }
    }

    // Confirm before logging out (logout is otherwise instant and unannounced).
    Component {
        id: logoutDialog
        Dialog {
            id: dlg
            title: i18n.tr("Log out?")
            text: i18n.tr("You'll need to sign in again to vote, comment, or follow.")

            Button {
                text: i18n.tr("Log out")
                color: Style.danger
                onClicked: { PopupUtils.close(dlg); page.doLogout(); }
            }
            Button {
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dlg)
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

            // ===== Search bar =================================================
            Item {
                id: searchBarContainer
                width: parent.width
                height: units.gu(7)

                Rectangle {
                    anchors {
                        fill: parent
                        leftMargin: Style.spacingM
                        rightMargin: Style.spacingM
                        topMargin: Style.spacingS
                        bottomMargin: Style.spacingS
                    }
                    radius: units.gu(1)
                    color: Style.inputBackground || "#F2F2F7"

                    Row {
                        anchors { fill: parent; leftMargin: Style.spacingS; rightMargin: Style.spacingS }
                        spacing: Style.spacingS

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "find"
                            width: units.gu(2.2); height: width
                            color: Style.textSecondary
                        }

                        TextField {
                            id: searchField
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - units.gu(2.2) - Style.spacingS
                            placeholderText: i18n.tr("Search users...")
                            font.pixelSize: Style.fontRegular
                            font.family: Style.fontFamily
                            hasClearButton: true
                            onTextChanged: {
                                if (searchField.text.trim().length < 2) {
                                    page.searchOpen = false
                                    page.searchResults = []
                                }
                                searchDebounce.restart()
                            }
                            Keys.onReturnPressed: {
                                searchDebounce.stop()
                                page.doSearch(searchField.text.trim())
                            }
                        }
                    }
                }

                // Debounce timer — waits 350 ms after last keystroke before searching
                Timer {
                    id: searchDebounce
                    interval: 350
                    onTriggered: page.doSearch(searchField.text.trim())
                }
            }

            // ===== Profile card row (signed-in) / Welcome row (signed-out) =====
            Item {
                width: parent.width
                height: units.gu(10)

                // Signed-in: tappable profile card → ProfileViewPage
                AbstractButton {
                    anchors.fill: parent
                    visible: Session.isLoggedIn
                    onClicked: page.pageStack.push(Qt.resolvedUrl("ProfileViewPage.qml"),
                                                   { username: Session.username })

                    Rectangle {
                        anchors.fill: parent
                        color: profileCardMouse.containsMouse ? Style.divider : "transparent"
                    }

                    MouseArea {
                        id: profileCardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: false
                    }

                    Row {
                        anchors {
                            left: parent.left; right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: Style.spacingM; rightMargin: Style.spacingM
                        }
                        spacing: Style.spacingM

                        // Avatar: rounded square with initial or photo
                        Item {
                            id: avatarBox
                            anchors.verticalCenter: parent.verticalCenter
                            width: units.gu(6.5); height: width

                            // Brand-colour background + initial letter
                            Rectangle {
                                anchors.fill: parent
                                radius: units.gu(1.2)
                                color: Style.brand

                                Label {
                                    anchors.centerIn: parent
                                    text: (page.profile && page.profile.username
                                           ? page.profile.username : Session.username).charAt(0).toUpperCase()
                                    font.pixelSize: Style.fontTitle
                                    font.bold: true
                                    color: Style.textOnBrand
                                    visible: !(page.profile && page.profile.profileUrl)
                                }
                            }

                            // Profile photo clipped to rounded square via OpacityMask
                            Image {
                                id: avatarImg
                                anchors.fill: parent
                                source: page.profile && page.profile.profileUrl ? page.profile.profileUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                autoTransform: true
                                visible: !!(page.profile && page.profile.profileUrl)
                                layer.enabled: true
                                layer.effect: OpacityMask { maskSource: avatarMask }
                            }

                            Rectangle {
                                id: avatarMask
                                anchors.fill: parent
                                radius: units.gu(1.2)
                                visible: false
                            }
                        }

                        // Name + "See your profile"
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - avatarBox.width - chevronIcon.width - Style.spacingM * 2
                            spacing: units.dp(3)

                            Label {
                                width: parent.width
                                text: (page.profile && page.profile.fullName) ? page.profile.fullName
                                      : Session.username
                                font.pixelSize: Style.fontLarge
                                font.weight: Font.DemiBold
                                font.family: Style.fontFamily
                                color: Style.textTitle
                                elide: Text.ElideRight
                            }
                            Label {
                                width: parent.width
                                text: i18n.tr("See your profile")
                                font.pixelSize: Style.fontSmall
                                font.family: Style.fontFamily
                                color: Style.textSecondary
                                elide: Text.ElideRight
                            }
                        }

                        // Chevron
                        Icon {
                            id: chevronIcon
                            anchors.verticalCenter: parent.verticalCenter
                            name: "go-next"
                            width: units.gu(2); height: width
                            color: Style.textSecondary
                        }
                    }
                }

                // Signed-out: simple welcome row
                Row {
                    visible: !Session.isLoggedIn
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Style.spacingM; rightMargin: Style.spacingM
                    }
                    spacing: Style.spacingM

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(7); height: width
                        radius: Style.cardRadius
                        color: Style.brand
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(3.5); height: width
                            name: "account"
                            color: Style.textOnBrand
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: units.dp(3)
                        Label {
                            text: i18n.tr("Welcome to Serey")
                            font.pixelSize: Style.fontLarge
                            font.weight: Font.DemiBold
                            font.family: Style.fontFamily
                            color: Style.textTitle
                        }
                        Row {
                            spacing: Style.spacingS
                            AbstractButton {
                                width: loginLbl.width; height: loginLbl.height
                                onClicked: page.pageStack.push(Qt.resolvedUrl("LoginPage.qml"))
                                Label {
                                    id: loginLbl
                                    text: i18n.tr("Log in")
                                    font.pixelSize: Style.fontRegular
                                    font.weight: Font.DemiBold
                                    color: Style.brand
                                }
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "·"
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
                                    color: Style.brand
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: units.dp(1); color: Style.divider }

            // ===== Preferences (dev-only, hidden in production) ===========
            SettingsSectionHeader { text: i18n.tr("Preferences"); visible: Config.showDevOptions }

            SettingsRow {
                visible: Config.showDevOptions
                iconName: "settings"
                label: i18n.tr("Use local dev server")
                showSwitch: true
                switchChecked: Config.useLocalDev
                onSwitchToggled: Config.useLocalDev = checked
            }
            Item {
                visible: Config.showDevOptions
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

            // ===== Account ================================================
            SettingsSectionHeader { text: i18n.tr("Account"); visible: Session.isLoggedIn }
            SettingsRow {
                visible: Session.isLoggedIn
                iconName: "edit"
                label: i18n.tr("Edit profile")
                showChevron: true
                onClicked: page.pageStack.push(Qt.resolvedUrl("EditProfilePage.qml"), { initial: page.profile })
            }
            SettingsRow {
                visible: Session.isLoggedIn
                iconName: "system-lock-screen"
                label: i18n.tr("Password & Security")
                showChevron: true
                onClicked: page.pageStack.push(Qt.resolvedUrl("ChangePasswordPage.qml"))
            }
            SettingsRow {
                visible: Session.isLoggedIn
                iconName: "notification"
                label: i18n.tr("Notifications")
                showChevron: true
                onClicked: page.pageStack.push(Qt.resolvedUrl("NotificationsPage.qml"))
            }
            SettingsRow {
                visible: Session.isLoggedIn
                iconName: "system-log-out"
                label: i18n.tr("Log out")
                danger: true
                onClicked: PopupUtils.open(logoutDialog)
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

            Item { width: 1; height: Style.spacingL }
        }
    }

    ActivityIndicator {
        anchors.centerIn: parent
        running: page.loading && page.profile === null
        visible: running
    }

    // ── Search results overlay ────────────────────────────────────────────────
    Rectangle {
        id: searchOverlay
        visible: page.searchOpen && (page.searchResults.length > 0 || page.searching)
        anchors {
            top: parent.top
            topMargin: units.gu(7)
            left: parent.left
            right: parent.right
            leftMargin: Style.spacingM
            rightMargin: Style.spacingM
        }
        height: Math.min(resultsCol.height, units.gu(40))
        radius: units.gu(1)
        color: Style.surface
        clip: true
        z: 200

        // Drop shadow effect
        Rectangle {
            anchors { fill: parent; margins: -units.dp(1) }
            radius: parent.radius + units.dp(1)
            color: "transparent"
            border.width: units.dp(1)
            border.color: Style.divider
            z: -1
        }

        ActivityIndicator {
            anchors.centerIn: parent
            running: page.searching && page.searchResults.length === 0
            visible: running
        }

        Flickable {
            anchors.fill: parent
            contentHeight: resultsCol.height
            contentWidth: width
            clip: true

            Column {
                id: resultsCol
                width: searchOverlay.width

                Repeater {
                    model: page.searchResults

                    delegate: AbstractButton {
                        width: resultsCol.width
                        height: units.gu(7.5)
                        onClicked: {
                            searchField.text = ""
                            page.searchResults = []
                            page.searchOpen = false
                            page.pageStack.push(Qt.resolvedUrl("ProfileViewPage.qml"),
                                                { username: modelData.name || modelData.username || "" })
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: parent.pressed ? Style.pressed : "transparent"
                        }

                        Row {
                            anchors { fill: parent; leftMargin: Style.spacingM; rightMargin: Style.spacingM }
                            spacing: Style.spacingM

                            // Avatar
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: units.gu(5); height: width; radius: width / 2
                                color: Style.iconBackground

                                CircleImage {
                                    id: resultAvatar
                                    anchors { fill: parent; margins: units.dp(2) }
                                    source: modelData.profile_url || modelData.avatar_url || modelData.profile_image || ""
                                }
                                Label {
                                    anchors.centerIn: parent
                                    text: (modelData.name || modelData.username || "?").charAt(0).toUpperCase()
                                    font.pixelSize: Style.fontMedium
                                    font.bold: true
                                    color: Style.brand
                                    visible: !resultAvatar.loaded
                                }
                            }

                            // Name + @username
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: units.dp(2)

                                Label {
                                    text: modelData.full_name || modelData.name || modelData.username || ""
                                    font.pixelSize: Style.fontRegular
                                    font.weight: Font.DemiBold
                                    font.family: Style.fontFamily
                                    color: Style.textPrimary
                                }
                                Label {
                                    text: "@" + (modelData.name || modelData.username || "")
                                    font.pixelSize: Style.fontSmall
                                    font.family: Style.fontFamily
                                    color: Style.textSecondary
                                }
                            }
                        }

                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: units.gu(8) }
                            height: units.dp(1); color: Style.divider
                            visible: index < page.searchResults.length - 1
                        }
                    }
                }
            }
        }
    }

    // Dismiss results when tapping outside the search area
    MouseArea {
        anchors.fill: parent
        enabled: searchOverlay.visible
        z: 199
        propagateComposedEvents: true
        onClicked: {
            searchField.focus = false
            page.searchResults = []
            page.searchOpen = false
            mouse.accepted = false
        }
    }
}
