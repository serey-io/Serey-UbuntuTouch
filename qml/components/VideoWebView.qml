import QtQuick 2.7
import Morph.Web 0.1

/*
 * Thin wrapper around the Morph WebView, kept in its own file so that
 * VideoDetailPage can load it lazily via a Loader. If the webview engine is
 * unavailable (e.g. some desktop preview setups), only this component fails to
 * load — the rest of the detail page keeps working and the "Open in browser"
 * fallback remains usable.
 */
WebView {
    property string embedUrl: ""
    url: embedUrl
}
