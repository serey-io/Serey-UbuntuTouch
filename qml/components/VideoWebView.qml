import QtQuick 2.7
import Morph.Web 0.1

/*
 * Morph WebView wrapper used in two modes:
 *  - Direct (wrap=false): load `embedUrl` as a top-level page. Used by the
 *    Homepage tab to show a community site (those sites set X-Frame-Options /
 *    frame-ancestors, so they MUST be loaded top-level, not iframed).
 *  - Wrapped (wrap=true): embed `embedUrl` inside a minimal full-bleed HTML
 *    <iframe> document. Used for third-party players (YouTube / TikTok /
 *    Facebook), which render a black frame when pointed at directly on device.
 *
 * If the engine is unavailable the Loader hosting this file fails and the
 * caller's "Open in browser" fallback takes over.
 */
WebView {
    id: wv
    property string embedUrl: ""
    property bool wrap: false

    onEmbedUrlChanged: _load()
    onWrapChanged: _load()
    Component.onCompleted: _load()

    function _baseUrl() {
        if (embedUrl.indexOf("youtube") >= 0) return "https://www.youtube.com/";
        if (embedUrl.indexOf("tiktok") >= 0)  return "https://www.tiktok.com/";
        if (embedUrl.indexOf("facebook") >= 0) return "https://www.facebook.com/";
        return "https://serey.io/";
    }

    function _html() {
        return '<!DOCTYPE html><html><head>' +
               '<meta name="viewport" content="width=device-width, initial-scale=1">' +
               '<style>html,body{margin:0;height:100%;background:#000;overflow:hidden}' +
               'iframe{border:0;width:100%;height:100%}</style></head>' +
               '<body><iframe src="' + embedUrl + '" ' +
               'allow="autoplay; encrypted-media; fullscreen; picture-in-picture" ' +
               'allowfullscreen></iframe></body></html>';
    }

    function _load() {
        if (embedUrl.length === 0)
            return;
        if (wrap) {
            if (typeof wv.loadHtml === "function")
                wv.loadHtml(_html(), _baseUrl());
            else
                wv.url = "data:text/html;charset=utf-8," + encodeURIComponent(_html());
        } else {
            wv.url = embedUrl;
        }
    }
}
