pragma Singleton
import QtQuick 2.7

/*
 * App-wide configuration. Flip `useLocalDev` to point the whole app at a
 * locally-running serey-api instead of production. (A physical device cannot
 * reach `localhost` without `clickable` port-forwarding — see README.)
 *
 * Regional source: the app filters native feeds by a Serey community
 * (`community_id`, recursive incl. children). `sourceIndex` is the currently
 * selected source; it's read by News/Video and drives the Homepage WebView.
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

    // --- Regional sources (verified community IDs) -----------------------
    // Three communities. "Global" (id 0) applies no community filter, so its
    // News/Video feeds combine content from every community. Keep `sourceNames`
    // in the same order as `sources`.
    readonly property var sources: [
        { "name": "Global",        "id": 0,  "dns": "serey.io" },
        { "name": "Netherlands",   "id": 99, "dns": "netherlands.serey.io" },
        { "name": "United States", "id": 26, "dns": "us.serey.io" }
    ]
    readonly property var sourceNames: ["Global", "Netherlands", "United States"]

    property int sourceIndex: 0

    readonly property int communityId: sources[sourceIndex].id
    readonly property string communityDns: sources[sourceIndex].dns
    readonly property string communityName: sources[sourceIndex].name
}
