import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/AnonymousInviteService.js" as InviteService

Page {
    id: page

    // Go straight to the resolved route; `/` redirect cost a remount + bridge wait
    function siteUrl() {
        return Config.homeLandingPageUrl + "/" + Config.communityId
             + "?community_id=" + Config.communityId;
    }
    // "" keeps WebAppView from loading at all. This tab still hosts My Feed and
    // notification pushes for a community whose Homepage is hidden, so the page
    // exists but must not fetch a landing page nobody is going to see.
    function loadUrl() {
        return Config.homepageTabState === 1 ? siteUrl() : "";
    }

    // Zero-height header: the global AppHeader is the real top bar.
    header: Item { height: 0 }

    // never split
    readonly property bool neverSplitOverride: true

    // Keyboard parity on arrival (see NewsPage): hand focus to web view when shown
    property Item keyboardFocusItem: webApp
    onVisibleChanged: {
        if (!visible) return;
        webApp.forceActiveFocus();
        // Back from My Feed (pushed on this tab) after a reconnect: don't wait out the 20s
        // backstop on the offline panel, reload now. Deferred path: frozen views can't reload.
        if (Net.online && webApp.loadFailed && !webApp.loading) {
            page._quietRetries = 0;
            page._gaveUp = false;
            webApp._deferredNav = true;
            webApp._applyDeferredNav();
        }
    }
    // Web view load is itself deferred; grabbing focus from onCompleted lands on nothing
    Component.onCompleted: if (visible) Qt.callLater(webApp.forceActiveFocus)

    // Adopt a community the web side moved to; re-points siteUrl() for bridge-only requests
    function applyCommunity(communityId) {
        if (String(communityId) === String(Config.communityId)) return;
        Config.selectCommunityById(communityId);
    }

    WebAppView {
        id: webApp
        anchors.fill: parent
        // Freeze this Chromium renderer while another tab is showing so it doesn't compete for GPU/shared memory with the video player's WebView.
        suspended: Config.currentTab !== 0
        url: page.loadUrl()
        authToken: Session.token
        username: Session.username
        apiBaseV2: Config.baseUrl
        communityId: String(Config.communityId)
        communityName: Config.communityName
        onOpenCommunityRequested: page.applyCommunity(communityId)
        onOpenPostRequested: Nav.openPost(params)
        // Ignoring the already-selected community stops our own siteUrl() hops from looping
        onSiteNavigated: page.applyCommunity(Config.communityIdForUrl(url))

        // Buy-plan: bridge calls and Stripe redirects both land in the native payment flow
        onBuyPlanRequested: {
            if (params.method === "crypto") Payments.openCrypto(params.subscription_plan_id);
            else Payments.openStripe(params.subscription_plan_id);
        }
        onStripeCheckoutIntercepted: Payments.openStripeUrl(url)
        // Invite link tapped in the mini app: redeem it natively.
        onInviteRedeemIntercepted: {
            var code = InviteService.codeFromUrl(url);
            if (code.length > 0) Nav.redeemInvite(code);
        }
    }

    // Online but the site didn't load: the first load after a reconnect often fails on a cold
    // connection, so retry quietly behind the loading spinner before showing the offline panel.
    property int _quietRetries: 0
    property bool _gaveUp: false
    function _afterLoad() {
        if (webApp.loading) return;
        if (!webApp.loadFailed) { page._quietRetries = 0; page._gaveUp = false; return; }
        if (Net.online && page._quietRetries < 2) {
            page._quietRetries++;
            quietRetry.restart();
            return;
        }
        page._gaveUp = true;
    }
    Connections {
        target: webApp
        // Later: a successful load clears `loading` before `loadFailed`.
        function onLoadingChanged() { Qt.callLater(page._afterLoad); }
        function onLoadFailedChanged() { Qt.callLater(page._afterLoad); }
    }
    Timer {
        id: quietRetry
        interval: 1500
        // Deferred path: it waits if the tab got frozen meanwhile.
        onTriggered: { webApp._deferredNav = true; webApp._applyDeferredNav(); }
    }

    // Two offline signals: the site failing to load (Chromium's own error page), and Net
    // knowing we're down. The second matters because a route change the site accepted while
    // offline leaves its own spinner turning forever with no load failure to catch.
    // A failed load only shows the panel once the quiet retries are spent; until then a
    // spinner covers Chromium's error page (WebAppView's own spinner covers the reloads).
    Rectangle {
        id: retryCover
        anchors.fill: parent
        visible: Net.online && !Net.justReconnected && webApp.loadFailed
                 && !webApp.loading && !page._gaveUp
        color: Style.surface
        ActivityIndicator { anchors.centerIn: parent; running: retryCover.visible }
        // Safety net: never spin forever if no reload comes; hand over to Try again.
        Timer {
            interval: 8000
            running: retryCover.visible
            onTriggered: page._gaveUp = true
        }
    }

    Rectangle {
        id: offlineCover
        anchors.fill: parent
        // Backdrop cuts in, content fades: same as the News/Video covers.
        visible: !Net.online || Net.justReconnected || (webApp.loadFailed && page._gaveUp)
        color: Style.surface

        OfflineState {
            anchors.fill: parent
            opacity: offlineCover.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
            reloading: webApp.loading
            onRetry: {
                page._quietRetries = 0;
                page._gaveUp = false;
                webApp.reload();
            }
        }
    }

    // The first reload after a reconnect often fails on the cold connection; tapping
    // "Press to connect" retries it right away instead of leaving the user on "Try again".
    Connections {
        target: Net
        // Back online: a fresh round of quiet retries for the reload WebAppView kicks off.
        function onOnlineChanged() {
            if (!Net.online) return;
            page._quietRetries = 0;
            page._gaveUp = false;
        }
        function onJustReconnectedChanged() {
            // Via the deferred path: reloading the frozen (hidden-tab) view crashes Chromium.
            if (!Net.justReconnected && Net.online && webApp.loadFailed && !webApp.loading) {
                webApp._deferredNav = true;
                webApp._applyDeferredNav();
            }
        }
    }

    // Backstop for a site that is down while the network is fine; a real outage is picked up
    // by WebAppView the moment Net flips back. The cover hides the reload either way.
    Timer {
        interval: 20000
        repeat: true
        running: offlineCover.visible && Net.online && Config.currentTab === 0
        onTriggered: webApp.reload()
    }

    // After a confirmed payment, reload the site so it reflects the new plan.
    Connections {
        target: Payments
        function onPaymentSucceeded() { webApp.reload(); }
    }

    // Persistent cookies otherwise survive a native logout/account switch
    Connections {
        target: Session
        function onTokenChanged() {
            webApp.clearSession();
            webApp.reload();
        }
    }
}
