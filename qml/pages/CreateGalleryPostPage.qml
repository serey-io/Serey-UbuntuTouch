import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../services/PostService.js" as PostService

/*
 * Compose a gallery post: caption/title + up to 10 images (no single
 * thumbnail). Matches the iOS gallery compose flow. Images are selected
 * via ContentHub (Ubuntu Touch's share/pick API); each slot shows a
 * preview with a remove button. The "+" button adds more images until
 * the 10-image cap is reached.
 *
 * TODO: wire real ContentHub image picking + upload to upload.serey.io.
 * For now the UI is fully laid out with placeholder tap handlers.
 */
Page {
    id: page

    property bool submitting: false
    property string selectedCategory: ""
    property var imageUrls: []
    readonly property int maxImages: 10

    header: Rectangle {
        height: units.gu(6)
        color: Style.surface

        AbstractButton {
            anchors {
                left: parent.left
                leftMargin: Style.spacingM
                verticalCenter: parent.verticalCenter
            }
            width: units.gu(3); height: width
            onClicked: page.pageStack.pop()

            Icon {
                anchors.centerIn: parent
                width: units.gu(2.5); height: width
                name: "close"
                color: Style.textPrimary
            }
        }

        Label {
            anchors.centerIn: parent
            text: i18n.tr("Post Gallery")
            font.pixelSize: Style.fontMedium
            font.weight: Font.DemiBold
            color: Style.textPrimary
        }

        AbstractButton {
            anchors {
                right: parent.right
                rightMargin: Style.spacingM
                verticalCenter: parent.verticalCenter
            }
            width: postLabel.implicitWidth + Style.spacingM
            height: units.gu(4)
            enabled: !page.submitting
                     && captionField.text.trim().length > 0
            onClicked: page.publish()

            Label {
                id: postLabel
                anchors.centerIn: parent
                text: page.submitting ? i18n.tr("Posting…") : i18n.tr("Post")
                font.pixelSize: Style.fontMedium
                font.weight: Font.Bold
                color: parent.enabled ? Style.brand : Style.textSecondary
            }
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: units.dp(1)
            color: Style.divider
        }
    }

    function publish() {
        if (!Session.isLoggedIn) {
            Toast.error(i18n.tr("Please log in first."));
            return;
        }
        page.submitting = true;
        PostService.createPost(Config.baseUrl, {
            title: captionField.text.trim(),
            body: captionField.text.trim(),
            communityId: Config.communityId,
            category: page.selectedCategory
        }, Session.token,
        function (data) {
            page.submitting = false;
            Toast.success(i18n.tr("Gallery post published!"));
            page.pageStack.pop();
        },
        function (err) {
            page.submitting = false;
            Toast.error((err && err.message) ? err.message : i18n.tr("Couldn't publish post."));
        });
    }

    function addImage() {
        if (page.imageUrls.length >= page.maxImages) {
            Toast.show(i18n.tr("Maximum %1 images allowed").arg(page.maxImages));
            return;
        }
        // TODO: open ContentHub image picker, append picked URL to imageUrls
        Toast.show(i18n.tr("Image picker coming soon"));
    }

    function removeImage(idx) {
        var copy = [];
        for (var i = 0; i < page.imageUrls.length; i++) {
            if (i !== idx) copy.push(page.imageUrls[i]);
        }
        page.imageUrls = copy;
    }

    Flickable {
        anchors {
            top: page.header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentHeight: col.height + Style.spacingL
        clip: true

        Column {
            id: col
            width: parent.width
            spacing: 0

            Item { width: 1; height: Style.spacingM }

            // Caption field
            TextArea {
                id: captionField
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                placeholderText: i18n.tr("Write a caption…")
                autoSize: true
                maximumLineCount: 10
                font.family: Style.fontFamily
                font.pixelSize: Style.fontRegular
            }

            Item { width: 1; height: Style.spacingM }

            Rectangle {
                width: parent.width
                height: units.dp(1)
                color: Style.divider
            }

            // Category selector
            AbstractButton {
                width: parent.width
                height: units.gu(6)
                onClicked: {
                    Toast.show(i18n.tr("Category picker coming soon"));
                }

                Row {
                    anchors {
                        left: parent.left; right: parent.right
                        leftMargin: Style.spacingM; rightMargin: Style.spacingM
                        verticalCenter: parent.verticalCenter
                    }

                    Label {
                        width: parent.width - catChevron.width
                        text: page.selectedCategory.length > 0
                            ? page.selectedCategory
                            : i18n.tr("Select category *")
                        font.pixelSize: Style.fontRegular
                        font.family: Style.fontFamily
                        color: page.selectedCategory.length > 0
                            ? Style.textPrimary : Style.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Icon {
                        id: catChevron
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(2); height: width
                        name: "next"
                        color: Style.textSecondary
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: units.dp(1)
                color: Style.divider
            }

            Item { width: 1; height: Style.spacingM }

            // Image count label
            Label {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                text: i18n.tr("Photos (%1/%2)").arg(page.imageUrls.length).arg(page.maxImages)
                font.pixelSize: Style.fontSmall
                font.weight: Font.DemiBold
                color: Style.textSecondary
            }

            Item { width: 1; height: Style.spacingS }

            // Image grid: existing images + add button
            Flow {
                width: parent.width - Style.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.spacingS

                Repeater {
                    model: page.imageUrls
                    delegate: Item {
                        width: (parent.width - Style.spacingS * 2) / 3
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            radius: Style.cardRadius
                            color: Style.iconBackground
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: modelData
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        // Remove button
                        AbstractButton {
                            anchors {
                                top: parent.top
                                right: parent.right
                                topMargin: units.dp(4)
                                rightMargin: units.dp(4)
                            }
                            width: units.gu(3); height: width
                            onClicked: page.removeImage(index)

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Qt.rgba(0, 0, 0, 0.5)
                            }
                            Icon {
                                anchors.centerIn: parent
                                width: units.gu(1.8); height: width
                                name: "close"
                                color: Style.textOnBrand
                            }
                        }
                    }
                }

                // Add image button (shown if under max)
                Item {
                    visible: page.imageUrls.length < page.maxImages
                    width: (parent.width - Style.spacingS * 2) / 3
                    height: width

                    Rectangle {
                        anchors.fill: parent
                        radius: Style.cardRadius
                        color: Style.iconBackground

                        AbstractButton {
                            anchors.fill: parent
                            onClicked: page.addImage()

                            Column {
                                anchors.centerIn: parent
                                spacing: Style.spacingXs

                                Icon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: units.gu(4); height: width
                                    name: "add"
                                    color: Style.brand
                                }
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: i18n.tr("Add photo")
                                    font.pixelSize: Style.fontXSmall
                                    color: Style.textSecondary
                                }
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: Style.spacingL }
        }
    }

    // Loading overlay
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(1, 1, 1, 0.7)
        visible: page.submitting
        z: 100

        ActivityIndicator {
            anchors.centerIn: parent
            running: page.submitting
        }
    }
}
