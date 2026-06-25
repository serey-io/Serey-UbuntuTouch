import QtQuick 2.7
import Morph.Web 0.1

/*
 * Thin wrapper around the Morph WebView for playing third-party embeds
 * (YouTube / TikTok / Facebook). The API returns `embed_video` as a player URL,
 * but pointing the WebView straight at it tends to render a black frame on
 * device (no document origin / referrer, embed refusals). So we wrap the URL in
 * a minimal full-bleed HTML document with an <iframe>, loaded with a real base
 * URL. If the engine is unavailable the Loader hosting this file fails and the
 * detail page's "Open in browser" fallback takes over.
 */
WebView {
    id: wv
    property string embedUrl: ""

    onEmbedUrlChanged: if (embedUrl.length > 0) _loadEmbed()
    Component.onCompleted: if (embedUrl.length > 0) _loadEmbed()

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

    function _loadEmbed() {
        if (typeof wv.loadHtml === "function") {
            wv.loadHtml(_html(), _baseUrl());
        } else {
            wv.url = "data:text/html;charset=utf-8," + encodeURIComponent(_html());
        }
    }
}
