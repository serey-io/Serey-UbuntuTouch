import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"

/*
 * Homepage tab: the selected community's branded website, embedded as a mini web
 * app (WebAppView) with a forced mobile viewport and a JS bridge that hands the
 * site the native session token + API base, and lets it ask the shell to switch
 * community or open links externally.
 *
 * The community is chosen via the global AppHeader pill (Config.sourceIndex);
 * because `url` reads Config.communityDns, switching the source reloads the site.
 */
Page {
    id: page

    function siteUrl() { return "https://" + Config.communityDns + "/"; }

    // Zero-height header: the global AppHeader is the real top bar.
    header: Item { height: 0 }

    // Map a community id requested by the web side to one of our sources.
    function applyCommunity(communityId) {
        for (var i = 0; i < Config.sources.length; i++) {
            if (String(Config.sources[i].id) === String(communityId)) {
                Config.sourceIndex = i;
                return;
            }
        }
    }

    WebAppView {
        anchors.fill: parent
        url: page.siteUrl()
        authToken: Session.token
        username: Session.username
        apiBaseV2: Config.baseUrl
        communityId: String(Config.communityId)
        communityName: Config.communityName
        onOpenCommunityRequested: page.applyCommunity(communityId)
    }
}
