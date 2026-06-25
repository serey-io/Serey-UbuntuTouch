import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../components"
import "../services/CommunityService.js" as CommunityService

/*
 * Homepage tab: a directory of Serey communities / creator sites (the brief's
 * "overview of homepages"). Tapping a row opens that community's website in an
 * embedded WebView (WebAppPage). Grouped by source type via list sections.
 */
Page {
    id: page

    property bool loading: false
    property string errorMsg: ""

    header: PageHeader {
        title: i18n.tr("Homepage")
        trailingActionBar.actions: [
            Action {
                iconName: "reload"
                text: i18n.tr("Refresh")
                onTriggered: page.load()
            }
        ]
    }

    ListModel { id: communityModel; dynamicRoles: true }

    function siteUrl(c) {
        return (c.dns && c.dns.length > 0) ? ("https://" + c.dns + "/")
                                           : ("https://serey.io/community/" + c.id);
    }

    function load() {
        loading = true;
        errorMsg = "";
        communityModel.clear();
        CommunityService.getCommunities(Config.baseUrl,
            function (list) {
                loading = false;
                for (var i = 0; i < list.length; i++)
                    communityModel.append(list[i]);
            },
            function (err) {
                loading = false;
                page.errorMsg = err.message;
            });
    }

    Component.onCompleted: load()

    ListView {
        id: list
        anchors { top: page.header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        model: communityModel

        section.property: "group"
        section.criteria: ViewSection.FullString
        section.delegate: Rectangle {
            width: list.width
            height: units.gu(4)
            color: Style.divider
            Label {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Style.spacingM }
                text: section
                textSize: Label.Small
                font.weight: Font.DemiBold
                color: Style.textSecondary
            }
        }

        delegate: CommunityCard {
            width: list.width
            community: communityModel.get(index)
            onClicked: {
                var c = communityModel.get(index);
                page.pageStack.push(Qt.resolvedUrl("WebAppPage.qml"),
                    { url: page.siteUrl(c), pageTitle: c.title });
            }
        }
    }

    LoadingState {
        anchors.fill: list
        visible: page.loading && communityModel.count === 0
    }
    ErrorState {
        anchors.fill: list
        visible: page.errorMsg !== "" && communityModel.count === 0
        message: page.errorMsg
        onRetry: page.load()
    }
    EmptyState {
        anchors.fill: list
        visible: !page.loading && page.errorMsg === "" && communityModel.count === 0
        iconName: "view-grid-symbolic"
        message: i18n.tr("No communities found")
    }
}
