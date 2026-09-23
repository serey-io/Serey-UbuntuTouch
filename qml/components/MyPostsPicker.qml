import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../services/PostService.js" as PostService
import "../services/VideoService.js" as VideoService
import "../services/CopyrightService.js" as CopyrightService

// Full-screen picker: signed-in user's own posts/videos, searchable
Rectangle {
    id: root
    color: Style.surface
    visible: false
    z: 200

    signal picked(string url)

    // 0 = posts, 1 = videos
    property int tab: 0
    property var items: [[], []]
    property var offsets: [0, 0]
    property var ended: [false, false]
    property bool loading: false
    property int rev: 0
    // Safety cap per tab
    readonly property int maxItems: 500

    readonly property var shown: {
        var r = root.rev;
        var q = searchField.text.trim().toLowerCase();
        var list = root.items[root.tab] || [];
        if (!q) return list;
        return list.filter(function (it) {
            return String(it.title || "").toLowerCase().indexOf(q) >= 0;
        });
    }

    function open() {
        root.visible = true;
        searchField.text = "";
        if (!root.ended[root.tab] && (root.items[root.tab] || []).length === 0) root._loadNext();
    }
    function close() { Qt.inputMethod.hide(); root.visible = false; }

    // Page through everything so search covers all posts
    function _loadNext() {
        var t = root.tab;
        if (root.loading || root.ended[t] || !Session.isLoggedIn) return;
        root.loading = true;
        var params = { limit: Config.pageSize, offset: root.offsets[t] };
        function ok(rows, rawCount) {
            var list = root.items[t].concat(rows);
            var its = root.items.slice(); its[t] = list; root.items = its;
            var offs = root.offsets.slice(); offs[t] += rawCount; root.offsets = offs;
            var ends = root.ended.slice();
            ends[t] = rawCount < Config.pageSize || list.length >= root.maxItems;
            root.ended = ends;
            root.loading = false;
            root.rev++;
            if (!ends[t] && root.visible && root.tab === t) root._loadNext();
        }
        function err() {
            var ends = root.ended.slice(); ends[t] = true; root.ended = ends;
            root.loading = false;
            root.rev++;
        }
        if (t === 0)
            PostService.listByAuthor(Config.baseUrl, Session.username, params, Session.token, ok, err);
        else
            VideoService.listVideos(Config.baseUrl,
                { author: Session.username, limit: params.limit, offset: params.offset }, Session.token, ok, err);
    }

    // Swallow taps behind
    MouseArea { anchors.fill: parent }

    Rectangle {
        id: hdr
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: units.gu(6)
        color: Style.surface
        AbstractButton {
            anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
            width: units.gu(4); height: width
            onClicked: root.close()
            Icon { anchors.centerIn: parent; width: units.gu(2.5); height: width; name: "close"; color: Style.textPrimary }
        }
        Label {
            anchors.centerIn: parent
            text: Lang.tr("Choose your original")
            font.pixelSize: Style.fontMedium
            font.weight: Font.DemiBold
            color: Style.textPrimary
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: units.dp(1); color: Style.divider
        }
    }

    SectionTabs {
        id: tabs
        anchors { left: parent.left; right: parent.right; top: hdr.bottom }
        model: [Lang.tr("Posts"), Lang.tr("Video")]
        currentIndex: root.tab
        onSelected: { root.tab = index; root._loadNext(); }
    }

    TextField {
        id: searchField
        anchors { left: parent.left; right: parent.right; top: tabs.bottom; margins: Style.spacingM }
        placeholderText: Lang.tr("Search your posts")
        primaryItem: Icon { width: units.gu(2); height: width; name: "find" }
        inputMethodHints: Qt.ImhNoPredictiveText
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: searchField.bottom; bottom: parent.bottom; topMargin: Style.spacingS }
        clip: true
        model: root.shown

        delegate: AbstractButton {
            width: list.width
            height: units.gu(9)
            onClicked: {
                var url = CopyrightService.contentUrl(modelData, root.tab === 1 ? "video" : "blog");
                root.close();
                if (url) root.picked(url);
            }
            Row {
                anchors { fill: parent; leftMargin: Style.spacingM; rightMargin: Style.spacingM }
                spacing: Style.spacingM
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: units.gu(10); height: units.gu(6.5)
                    Rectangle { anchors.fill: parent; radius: Style.thumbRadius; color: Style.iconBackground }
                    RoundedThumb {
                        anchors.fill: parent
                        visible: (modelData.thumbnail || "") !== ""
                        source: modelData.thumbnail || ""
                        decodeWidth: units.gu(12)
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - units.gu(10) - Style.spacingM
                    spacing: units.dp(2)
                    Label {
                        width: parent.width
                        text: modelData.title || ""
                        font.pixelSize: Style.fontRegular
                        font.weight: Font.DemiBold
                        font.family: Style.fontFor(text)
                        color: Style.textPrimary
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Label {
                        text: Style.formatTimeAgo(modelData.date || "")
                        font.pixelSize: Style.fontXSmall
                        color: Style.textSecondary
                    }
                }
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: Style.spacingM }
                height: units.dp(1); color: Style.divider
            }
        }

        footer: Item {
            width: list.width
            height: root.loading ? units.gu(6) : 0
            ActivityIndicator { anchors.centerIn: parent; running: root.loading; visible: running }
        }
    }

    Label {
        anchors.centerIn: list
        visible: !root.loading && root.shown.length === 0
        width: list.width - Style.spacingL * 2
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: !Session.isLoggedIn ? Lang.tr("Log in to choose from your posts.")
              : searchField.text.trim().length > 0 ? Lang.tr("No posts match your search.")
              : Lang.tr("You haven't posted anything yet.")
        font.pixelSize: Style.fontSmall
        color: Style.textSecondary
    }
}
