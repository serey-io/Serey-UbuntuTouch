import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/AccountService.js" as AccountService
import "../services/PostService.js" as PostService
import "../services/FollowService.js" as FollowService

/*
 * Public profile view for any user: a cover banner with an overlapping avatar,
 * name / @username / bio, follower stats, a Follow button, and the user's posts
 * (PostService.listByAuthor, paginated). Reachable by tapping a creator anywhere
 * in the blog, gallery, video and comment surfaces. Tapping a post opens its
 * detail page. The header scrolls with the list (ListView.header) so the whole
 * thing stays smooth and the post list virtualises.
 */
Page {
    id: page

    property string username: ""

    property var profile: null
    property bool profileLoading: false
    property bool isFollowing: false

    // Posts pagination (mirrors the feed pages' reqEpoch/offset pattern).
    property int offset: 0
    property bool loading: false
    property bool endReached: false
    property string errorMsg: ""
    property var inflight: null

    readonly property bool isSelf: Session.isLoggedIn && username === Session.username

    header: PageHeader {
        title: "@" + page.username
        leadingActionBar.actions: [
            Action { iconName: "back"; text: i18n.tr("Back"); onTriggered: page.pageStack.pop() }
        ]
    }

    ListModel { id: postsModel; dynamicRoles: true }

    function loadProfile() {
        profileLoading = true;
        AccountService.profile(Config.baseUrl, username, Session.token,
            function (user) { profileLoading = false; page.profile = user; },
            function (err) { profileLoading = false; /* header falls back to @username */ });
    }

    function loadFollow() {
        if (!Session.isLoggedIn || isSelf) return;
        FollowService.status(Config.baseUrl, Session.username, username,
            function (f) { page.isFollowing = f; }, function () {});
    }

    function toggleFollow() {
        if (!Session.isLoggedIn) { page.pageStack.push(Qt.resolvedUrl("LoginPage.qml")); return; }
        var was = page.isFollowing;
        page.isFollowing = !was;
        FollowService.toggle(Config.baseUrl, username, was, Session.token,
            function (now) { page.isFollowing = now; Toast.show(now ? i18n.tr("Following") : i18n.tr("Unfollowed")); },
            function (err) { page.isFollowing = was; Toast.error((err && err.message) ? err.message : i18n.tr("Action failed.")); });
    }

    function loadMore() {
        if (loading || endReached) return;
        loading = true;
        errorMsg = "";
        var params = { limit: Config.pageSize, offset: page.offset };
        inflight = PostService.listByAuthor(Config.baseUrl, username, params, Session.token,
            function (result, rawCount) {
                inflight = null; loading = false;
                for (var i = 0; i < result.length; i++) postsModel.append(result[i]);
                page.offset += rawCount;
                if (rawCount < Config.pageSize) page.endReached = true;
            },
            function (err) { inflight = null; loading = false; page.errorMsg = err.message; });
    }

    Component.onCompleted: { loadProfile(); loadFollow(); loadMore(); }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: postsModel
        cacheBuffer: units.gu(12)

        header: Item {
            width: list.width
            height: headerCol.height

            Column {
                id: headerCol
                width: parent.width

                // --- Cover banner ----------------------------------------
                Item {
                    width: parent.width
                    height: units.gu(20)
                    clip: true

                    Rectangle {           // brand fallback when no cover
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Style.brand }
                            GradientStop { position: 1.0; color: Style.brandDark }
                        }
                    }
                    Image {
                        anchors.fill: parent
                        source: page.profile && page.profile.coverUrl ? page.profile.coverUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        autoTransform: true
                        sourceSize.width: list.width
                        visible: status === Image.Ready
                    }
                }

                // --- Avatar (overlaps the cover) -------------------------
                Item {
                    width: parent.width
                    height: units.gu(6)            // reserves the avatar's lower half

                    Item {
                        id: avatarHolder
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -units.gu(5.8)
                        width: units.gu(11.6); height: width

                        Rectangle {                // white ring
                            anchors.fill: parent
                            radius: width / 2
                            color: Style.surface
                        }
                        Rectangle {                // letter fallback
                            anchors.fill: parent
                            anchors.margins: units.gu(0.3)
                            radius: width / 2
                            color: Style.avatarTint("")
                            visible: !(page.profile && page.profile.profileUrl)
                            Label {
                                anchors.centerIn: parent
                                text: (page.username || "?").charAt(0).toUpperCase()
                                font.pixelSize: units.gu(5)
                                font.bold: true
                                color: Style.brand
                            }
                        }
                        CircleImage {
                            anchors.fill: parent
                            anchors.margins: units.gu(0.3)
                            source: page.profile && page.profile.profileUrl ? page.profile.profileUrl : ""
                            decode: units.gu(23)
                            visible: !!(page.profile && page.profile.profileUrl)
                        }
                    }
                }

                Item { width: 1; height: Style.spacingS }

                // --- Name / @username / bio ------------------------------
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: page.profile && page.profile.fullName ? page.profile.fullName : page.username
                    font.pixelSize: Style.fontLarge
                    font.weight: Font.DemiBold
                    font.family: Style.fontFamily
                    color: Style.textTitle
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "@" + page.username
                    font.pixelSize: Style.fontSmall
                    font.family: Style.fontFamily
                    color: Style.brand
                }
                Item { width: 1; height: Style.spacingXs; visible: bioLabel.visible }
                Label {
                    id: bioLabel
                    width: Math.min(parent.width - Style.spacingL * 2, units.gu(50))
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: page.profile ? (page.profile.bio || "") : ""
                    visible: text.length > 0
                    font.pixelSize: Style.fontRegular
                    font.family: Style.fontFamily
                    color: Style.textSecondary
                    wrapMode: Text.WordWrap
                }

                Item { width: 1; height: Style.spacingM }

                // --- Stats -----------------------------------------------
                Row {
                    width: Math.min(parent.width, units.gu(45))
                    anchors.horizontalCenter: parent.horizontalCenter
                    Repeater {
                        model: page.profile ? [
                            { label: i18n.tr("Posts"),     value: "" + page.profile.postCount },
                            { label: i18n.tr("Followers"), value: "" + page.profile.followers },
                            { label: i18n.tr("Following"), value: "" + page.profile.following }
                        ] : []
                        delegate: Column {
                            width: parent.width / 3
                            spacing: units.dp(2)
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.value
                                font.pixelSize: Style.fontLarge
                                font.weight: Font.DemiBold
                                font.family: Style.fontFamily
                                color: Style.textPrimary
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.pixelSize: Style.fontXSmall
                                font.family: Style.fontFamily
                                color: Style.textSecondary
                            }
                        }
                    }
                }

                Item { width: 1; height: Style.spacingM }

                // --- Follow button (hidden on own profile) ---------------
                PrimaryButton {
                    visible: !page.isSelf
                    width: Math.min(parent.width - Style.spacingL * 2, units.gu(50))
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.isFollowing ? i18n.tr("Following") : i18n.tr("Follow")
                    onClicked: page.toggleFollow()
                }

                Item { width: 1; height: Style.spacingM }

                Rectangle { width: parent.width; height: units.dp(1); color: Style.divider }

                Item { width: 1; height: Style.spacingS }

                // Section label
                Label {
                    x: Style.spacingM
                    text: i18n.tr("Posts")
                    font.pixelSize: Style.fontMedium
                    font.weight: Font.DemiBold
                    font.family: Style.fontFamily
                    color: Style.textTitle
                }

                Item { width: 1; height: Style.spacingXs }
            }
        }

        delegate: PostCard {
            width: list.width
            post: postsModel.get(index)
            onClicked: {
                var p = postsModel.get(index);
                page.pageStack.push(Qt.resolvedUrl("PostDetailPage.qml"),
                    { author: p.author, permlink: p.permlink, title: p.title });
            }
            onRequireLogin: page.pageStack.push(Qt.resolvedUrl("LoginPage.qml"))
        }

        footer: Item {
            width: list.width
            height: units.gu(7)
            ActivityIndicator {
                anchors.centerIn: parent
                running: page.loading && postsModel.count > 0
                visible: running
            }
            Label {
                anchors.centerIn: parent
                visible: page.endReached && postsModel.count === 0 && !page.loading
                text: i18n.tr("No posts yet")
                font.family: Style.fontFamily
                color: Style.textSecondary
            }
        }

        onAtYEndChanged: {
            if (atYEnd && !page.loading && !page.endReached && postsModel.count > 0)
                page.loadMore();
        }
    }

    // Full-page spinner only until the header has its data.
    ActivityIndicator {
        anchors.centerIn: parent
        running: page.profileLoading && page.profile === null
        visible: running
    }
}
