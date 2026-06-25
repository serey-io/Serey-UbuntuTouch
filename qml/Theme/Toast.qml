pragma Singleton
import QtQuick 2.7

/*
 * App-wide transient notifications ("toasts"). Any page calls Toast.show(),
 * Toast.success() or Toast.error(); a single Toaster instance mounted in
 * Main.qml renders them. `seq` is bumped on every call so the Toaster can
 * (re)trigger its animation even when the same message repeats.
 */
QtObject {
    id: toast

    property string message: ""
    property bool isError: false
    property int seq: 0

    function show(msg) { message = msg; isError = false; seq++; }
    function success(msg) { message = msg; isError = false; seq++; }
    function error(msg) { message = msg; isError = true; seq++; }
}
