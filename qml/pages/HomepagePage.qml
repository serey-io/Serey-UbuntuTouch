import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"

/*
 * Homepage tab: the selected community's branded website, embedded in a
 * top-level WebView. The community is chosen via the header Sections selector
 * (shared app-wide through Config.sourceIndex), so picking Netherlands here also
 * scopes the News/Video tabs. "Global" shows the main serey.io site.
 *
 * The WebView is loaded lazily (components/VideoWebView) so a missing webview
 * engine — e.g. on some desktop previews — degrades to "Open in browser"
 * instead of breaking the tab.
 */
Page {
    id: page

    function siteUrl() { return "https://" + Config.communityDns + "/"; }

    function reload() { webLoader.active = false; webLoader.active = true; }

    // Zero-height header: the global AppHeader is the real top bar; this keeps
    // the Page off Lomiri's deprecated Page.head path.
    header: Item { height: 0 }

    // Source switching lives in the global AppHeader community pill; reload the
    // embedded site when it changes.
    Connections {
        target: Config
        function onSourceIndexChanged() {
            page.reload();
        }
    }

    Loader {
        id: webLoader
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: parent.bottom }
        active: true
        source: Qt.resolvedUrl("../components/VideoWebView.qml")
        // wrap stays false → load the community site as a top-level page.
        onItemChanged: if (item) item.embedUrl = page.siteUrl()
        onStatusChanged: {
            if (status === Loader.Error)
                Qt.openUrlExternally(page.siteUrl());
        }
    }

    LomiriShape {
        anchors.fill: webLoader
        visible: webLoader.status === Loader.Error
        backgroundColor: Style.surface
        Label {
            anchors.centerIn: parent
            width: parent.width - Style.spacingL * 2
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: i18n.tr("Couldn't open %1 in-app. Use \"Open in browser\".").arg(Config.communityName)
            color: Style.textSecondary
        }
    }

}
