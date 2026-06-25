pragma Singleton
import QtQuick 2.7

/*
 * App-wide configuration. Flip `useLocalDev` to point the whole app at a
 * locally-running serey-api instead of production. (A physical device cannot
 * reach `localhost` without `clickable` port-forwarding — see README.)
 */
QtObject {
    id: config

    readonly property string prodBase: "https://global-api.serey.io/api/v2"
    readonly property string devBase: "http://localhost:5050/api/v2"

    property bool useLocalDev: false

    readonly property string baseUrl: useLocalDev ? devBase : prodBase

    // Default page size for paginated lists.
    readonly property int pageSize: 10

    // Upstream media host used to normalise some relative asset paths.
    readonly property string uploadHost: "https://upload.serey.io"
}
