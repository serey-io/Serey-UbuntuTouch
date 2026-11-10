pragma Singleton
import QtQuick 2.7
import QtWebEngine 1.10

// Podcast episodes run to hundreds of MB, far past any useful cache. Through VideoProfile's
// disk cache a reopened episode waited on the previous view's cache entry and never loaded.
WebEngineProfile {
    httpUserAgent: VideoProfile.mobileUA
    storageName: "SereyPodcast"
    offTheRecord: true
    httpCacheType: WebEngineProfile.NoCache
}
