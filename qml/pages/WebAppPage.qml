import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"

/*
 * Hosts an embedded Serey web page (a creator/community "Homepage") in a
 * top-level WebView. Loading is lazy via a Loader reusing components/VideoWebView
 * (whose `embedUrl` accepts any URL), so a missing webview engine degrades to the
 * "Open in browser" fallback instead of breaking the app.
 *
 * NOTE: always pass a community subdomain (https://{dns}/), never bare serey.io
 * (which geo-redirects). Top-level WebView loads are not blocked by the web app's
 * X-Frame-Options / CSP frame-ancestors (those only block iframes).
 */
Page {
    id: page
    property string url: ""
    property string pageTitle: i18n.tr("Homepage")

    header: PageHeader {
        title: page.pageTitle
        trailingActionBar.actions: [
            Action {
                iconName: "reload"
                text: i18n.tr("Reload")
                onTriggered: { webLoader.active = false; webLoader.active = true; }
            },
            Action {
                iconName: "external-link"
                text: i18n.tr("Open in browser")
                onTriggered: Qt.openUrlExternally(page.url)
            }
        ]
    }

    Loader {
        id: webLoader
        anchors { top: page.header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        active: true
        source: Qt.resolvedUrl("../components/VideoWebView.qml")
        onItemChanged: if (item) item.embedUrl = page.url
        onStatusChanged: {
            if (status === Loader.Error)
                Qt.openUrlExternally(page.url);
        }
    }

    LomiriShape {
        anchors.fill: parent
        visible: webLoader.status === Loader.Error
        backgroundColor: Style.surface
        Label {
            anchors.centerIn: parent
            width: parent.width - Style.spacingL * 2
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: i18n.tr("Couldn't open the page in-app. Use \"Open in browser\".")
            color: Style.textSecondary
        }
    }
}
