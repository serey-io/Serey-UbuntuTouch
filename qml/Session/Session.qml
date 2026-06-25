pragma Singleton
import QtQuick 2.7
import Qt.labs.settings 1.0

/*
 * Authentication state, persisted across launches via Qt.labs.settings.
 * `token` and `username` are mirrored into the settings store by the aliases
 * below, so they survive an app restart. UI binds to `isLoggedIn`.
 */
QtObject {
    id: session

    property string token: ""
    property string username: ""

    readonly property bool isLoggedIn: token.length > 0

    // Persistent backing store. Aliases bind storage <-> session properties.
    property Settings store: Settings {
        category: "auth"
        property alias token: session.token
        property alias username: session.username
    }

    function setAuth(newToken, newUsername) {
        token = newToken;
        username = newUsername;
    }

    function clear() {
        token = "";
        username = "";
    }
}
