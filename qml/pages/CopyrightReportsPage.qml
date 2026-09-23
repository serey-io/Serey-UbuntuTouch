import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3 as Popups
import "../Theme"
import "../Session"
import "../components"
import "../services/CopyrightService.js" as CopyrightService
import "../services/PostService.js" as PostService
import "../services/AccountService.js" as AccountService

// Owner review of copyright reports, same flow as web's ManageCopyrightReports
Page {
    id: page

    readonly property var filters: ["", "open", "resolved", "dismissed"]
    property int filterIndex: 0
    property var reports: []
    property bool loading: false
    property string errorMsg: ""

    header: PageHeader {
        title: Lang.tr("Copyright Reports")
        leadingActionBar.actions: [
            Action { iconName: "back"; text: Lang.tr("Back"); onTriggered: page.pageStack.pop() }
        ]
        trailingActionBar.actions: [
            Action { iconName: "reload"; text: Lang.tr("Refresh"); onTriggered: page.load() }
        ]
    }

    Component.onCompleted: load()

    function load() {
        page.loading = true;
        page.errorMsg = "";
        CopyrightService.adminList(Config.baseUrl, Session.token, page.filters[page.filterIndex],
            function (rows) { page.loading = false; page.reports = rows; },
            function (err) {
                page.loading = false;
                page.reports = [];
                page.errorMsg = (err && err.message) || Lang.tr("Couldn't load reports.");
            });
    }

    // Reporter avatars, fetched once per name
    property var avatars: ({})
    property var _avatarAsked: ({})
    function avatarFor(name) {
        if (!name) return "";
        if (!page._avatarAsked[name]) {
            page._avatarAsked[name] = true;
            AccountService.profile(Config.baseUrl, name, Session.token,
                function (u) {
                    var m = Object.assign({}, page.avatars);
                    m[name] = (u && u.profileUrl) || "";
                    page.avatars = m;
                }, function () {});
        }
        return page.avatars[name] || "";
    }

    function statusLabel(s) {
        return s === "open" ? Lang.tr("Open")
             : s === "resolved" ? Lang.tr("Resolved")
             : s === "dismissed" ? Lang.tr("Dismissed") : (s || "");
    }
    function statusColor(s) {
        return s === "open" ? Style.accentRed : s === "resolved" ? Style.success : Style.textSecondary;
    }

    SectionTabs {
        id: tabs
        anchors { left: parent.left; right: parent.right; top: page.header.bottom }
        model: [Lang.tr("All"), Lang.tr("Open"), Lang.tr("Resolved"), Lang.tr("Dismissed")]
        currentIndex: page.filterIndex
        onSelected: { page.filterIndex = index; page.load(); }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: tabs.bottom; bottom: parent.bottom }
        clip: true
        model: page.reports

        delegate: AbstractButton {
            width: list.width
            height: cardCol.height + Style.spacingM * 2
            onClicked: page.pageStack.push(detailComp, { report: modelData })

            Column {
                id: cardCol
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                          leftMargin: Style.spacingM; rightMargin: Style.spacingM }
                spacing: units.dp(4)

                // Reporter
                Row {
                    width: parent.width
                    spacing: Style.spacingS
                    ReporterAvatar {
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData.reporter_name || ""
                        source: page.avatarFor(modelData.reporter_name || "")
                        size: units.gu(4)
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - units.gu(4) - parent.spacing
                        text: modelData.reporter_name ? modelData.reporter_name : Lang.tr("Anonymous")
                        font.pixelSize: Style.fontSmall
                        font.weight: Font.DemiBold
                        font.family: Style.fontFor(text)
                        color: modelData.reporter_name ? Style.textPrimary : Style.textSecondary
                        elide: Text.ElideRight
                    }
                }

                Row {
                    width: parent.width
                    spacing: Style.spacingS
                    Label {
                        width: parent.width - statusPill.width - parent.spacing
                        text: modelData.message || ""
                        font.pixelSize: Style.fontRegular
                        font.weight: Font.DemiBold
                        font.family: Style.fontFor(text)
                        color: Style.textPrimary
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        id: statusPill
                        width: statusText.width + Style.spacingM
                        height: units.gu(2.6)
                        radius: Style.pillRadius
                        color: "transparent"
                        border.width: units.dp(1)
                        border.color: page.statusColor(modelData.status)
                        Label {
                            id: statusText
                            anchors.centerIn: parent
                            text: page.statusLabel(modelData.status)
                            font.pixelSize: Style.fontXSmall
                            font.weight: Font.DemiBold
                            color: page.statusColor(modelData.status)
                        }
                    }
                }
                Label {
                    width: parent.width
                    text: (modelData.community || "") + "  ·  " + Style.formatTimeAgo(modelData.created_at || "")
                    font.pixelSize: Style.fontXSmall
                    font.family: Style.fontFor(text)
                    color: Style.textSecondary
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: units.dp(1); color: Style.divider
            }
        }
    }

    ActivityIndicator { anchors.centerIn: list; running: page.loading; visible: running }

    Label {
        anchors.centerIn: list
        width: list.width - Style.spacingL * 2
        visible: !page.loading && page.reports.length === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: page.errorMsg || Lang.tr("No copyright reports match this filter.")
        font.pixelSize: Style.fontSmall
        color: Style.textSecondary
    }

    // --- Report detail ---
    Component {
        id: detailComp
        Page {
            id: dPage
            property var report: ({})
            property bool saving: false
            property bool deleting: false

            header: PageHeader {
                title: Lang.tr("Copyright report")
                leadingActionBar.actions: [
                    Action { iconName: "back"; text: Lang.tr("Back"); onTriggered: page.pageStack.pop() }
                ]
            }


            function openReporter() {
                page.pageStack.push(Qt.resolvedUrl("ProfileViewPage.qml"), { username: dPage.report.reporter_name })
            }

            function setStatus(status, okMsg) {
                dPage.saving = true;
                CopyrightService.adminUpdate(Config.baseUrl, Session.token, dPage.report.id, status,
                    function () {
                        dPage.saving = false;
                        Toast.success(okMsg || Lang.tr("Report updated."));
                        page.pageStack.pop();
                        page.load();
                    },
                    function (err) {
                        dPage.saving = false;
                        Toast.error((err && err.message) || Lang.tr("Couldn't update the report."));
                    });
            }

            // Resolved card id first; else manual link/id
            readonly property bool hasTarget: contentCard.found || postField.text.trim().length > 0
            function deletePost() {
                var raw = contentCard.found ? String(contentCard.postId) : postField.text.trim();
                if (!raw) return;
                dPage.deleting = true;
                function doDelete(id) {
                    PostService.adminDeletePost(Config.baseUrl, id, Session.token,
                        function () {
                            dPage.deleting = false;
                            dPage.setStatus("resolved", Lang.tr("Post deleted."));
                        },
                        function (err) {
                            dPage.deleting = false;
                            Toast.error((err && err.message) || Lang.tr("Couldn't delete the post."));
                        }, "POST", "Removed following a copyright report");
                }
                var parsed = CopyrightService.parseContentLink(raw);
                if (!parsed) { doDelete(raw); return; }
                PostService.detail(Config.baseUrl, parsed.author, parsed.permlink, Session.token,
                    function (res) {
                        var id = res && res.post ? res.post.id : null;
                        if (!id) {
                            dPage.deleting = false;
                            Toast.error(Lang.tr("Couldn't find that post, double check the link."));
                            return;
                        }
                        doDelete(id);
                    },
                    function () {
                        dPage.deleting = false;
                        Toast.error(Lang.tr("Couldn't find that post, double check the link."));
                    });
            }

            Component {
                id: confirmDelete
                Popups.Dialog {
                    id: cdlg
                    title: Lang.tr("Delete this post?")
                    text: Lang.tr("The post is removed for everyone and the report is marked resolved.")
                    Button {
                        text: Lang.tr("Delete")
                        color: Style.danger
                        onClicked: { Popups.PopupUtils.close(cdlg); dPage.deletePost(); }
                    }
                    Button {
                        text: Lang.tr("Cancel")
                        onClicked: Popups.PopupUtils.close(cdlg)
                    }
                }
            }

            KeyboardAwareFlickable {
                anchors { top: dPage.header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                contentWidth: width
                contentHeight: dCol.height + Style.spacingL * 2
                clip: true

                Column {
                    id: dCol
                    y: Style.spacingL
                    width: Math.min(parent.width - Style.spacingM * 2, units.gu(72))
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.spacingM

                    Column {
                        width: parent.width
                        Label {
                            text: dPage.report.community || ""
                            font.pixelSize: Style.fontMedium
                            font.weight: Font.DemiBold
                            font.family: Style.fontFor(text)
                            color: Style.textPrimary
                        }
                        Label {
                            text: Lang.tr("Submitted %1").arg(Style.formatTimeAgo(dPage.report.created_at || ""))
                                  + "  ·  " + page.statusLabel(dPage.report.status)
                            font.pixelSize: Style.fontXSmall
                            color: Style.textSecondary
                        }
                        // Reporter; tap -> profile
                        Item { width: 1; height: Style.spacingS }
                        Row {
                            spacing: Style.spacingS
                            ReporterAvatar {
                                anchors.verticalCenter: parent.verticalCenter
                                name: dPage.report.reporter_name || ""
                                source: page.avatarFor(dPage.report.reporter_name || "")
                                size: units.gu(3.5)
                                MouseArea { anchors.fill: parent; enabled: !!dPage.report.reporter_name; onClicked: dPage.openReporter() }
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: dPage.report.reporter_name
                                      ? Lang.tr("Reported by %1").arg("@" + dPage.report.reporter_name)
                                      : Lang.tr("Reported anonymously")
                                font.pixelSize: Style.fontSmall
                                font.family: Style.fontFor(text)
                                color: dPage.report.reporter_name ? Style.brand : Style.textSecondary
                                MouseArea { anchors.fill: parent; enabled: !!dPage.report.reporter_name; onClicked: dPage.openReporter() }
                            }
                        }
                    }

                    // Reported post: preview, opens in app
                    Column {
                        width: parent.width
                        spacing: units.dp(4)
                        Label {
                            text: Lang.tr("Content on Serey")
                            font.pixelSize: Style.fontXSmall
                            font.weight: Font.DemiBold
                            color: Style.textSecondary
                        }
                        ContentPreviewCard {
                            id: contentCard
                            width: parent.width
                            link: dPage.report.content_link || ""
                            stack: page.pageStack
                        }
                    }

                    // Original: preview if on Serey, else browser row
                    Column {
                        width: parent.width
                        spacing: units.dp(4)
                        visible: (dPage.report.original_content_link || "") !== ""
                        Label {
                            text: Lang.tr("Original content")
                            font.pixelSize: Style.fontXSmall
                            font.weight: Font.DemiBold
                            color: Style.textSecondary
                        }
                        ContentPreviewCard {
                            width: parent.width
                            link: dPage.report.original_content_link || ""
                            stack: page.pageStack
                        }
                    }

                    Repeater {
                        model: [
                            { label: Lang.tr("Message"), value: dPage.report.message || "", link: false },
                            { label: Lang.tr("Reporter email"), value: dPage.report.reporter_email || "", link: false }
                        ]
                        delegate: Column {
                            width: dCol.width
                            visible: modelData.value.length > 0
                            spacing: units.dp(2)
                            Label {
                                text: modelData.label
                                font.pixelSize: Style.fontXSmall
                                font.weight: Font.DemiBold
                                color: Style.textSecondary
                            }
                            Label {
                                width: parent.width
                                text: modelData.value
                                wrapMode: Text.WrapAnywhere
                                font.pixelSize: Style.fontRegular
                                font.family: Style.fontFor(text)
                                color: modelData.link ? Style.brand : Style.textPrimary
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: modelData.link
                                    onClicked: Qt.openUrlExternally(modelData.value)
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: units.dp(1); color: Style.divider }

                    Label {
                        text: Lang.tr("Delete the offending post")
                        font.pixelSize: Style.fontRegular
                        font.weight: Font.DemiBold
                        color: Style.textPrimary
                    }
                    Label {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: contentCard.found
                              ? Lang.tr("Removes the post shown above and marks this report resolved.")
                              : Lang.tr("The reported post couldn't be loaded. Paste its link or ID instead.")
                        font.pixelSize: Style.fontXSmall
                        color: Style.textSecondary
                    }
                    // Manual fallback only
                    FormField {
                        id: postField
                        visible: !contentCard.found && !contentCard.loading
                        placeholder: Lang.tr("Post link or ID")
                        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                    }
                    PrimaryButton {
                        width: parent.width
                        enabled: dPage.hasTarget && !dPage.saving
                        busy: dPage.deleting
                        danger: true
                        text: dPage.deleting ? Lang.tr("Deleting…") : Lang.tr("Delete post")
                        onClicked: Popups.PopupUtils.open(confirmDelete)
                    }

                    Row {
                        width: parent.width
                        spacing: Style.spacingS
                        SecondaryButton {
                            width: (parent.width - parent.spacing) / 2
                            enabled: !dPage.saving && !dPage.deleting
                            text: Lang.tr("Dismiss")
                            onClicked: dPage.setStatus("dismissed")
                        }
                        SecondaryButton {
                            width: (parent.width - parent.spacing) / 2
                            enabled: !dPage.saving && !dPage.deleting
                            busy: dPage.saving
                            text: Lang.tr("Mark resolved")
                            onClicked: dPage.setStatus("resolved")
                        }
                    }
                }
            }
        }
    }
}
