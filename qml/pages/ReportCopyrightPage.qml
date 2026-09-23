import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"
import "../Session"
import "../components"
import "../services/CopyrightService.js" as CopyrightService

// Copyright report, same fields as web's ReportCopyrightModal
Page {
    id: page

    // Prefill from the reported post
    property var post: null
    property string kind: "blog"

    property bool submitting: false
    // Errors show only after first submit try
    property bool _tried: false

    readonly property string linkError: !page._tried ? ""
        : (contentField.text.trim().length === 0 ? Lang.tr("Link to the content on Serey is required")
           : !CopyrightService.isUrl(contentField.text) ? Lang.tr("Please provide a valid link to the content on Serey") : "")
    readonly property string communityError: page._tried && communityField.text.trim().length === 0
        ? Lang.tr("Please choose the community where it was posted") : ""
    readonly property string messageError: page._tried && messageField.text.trim().length === 0
        ? Lang.tr("Please describe the copyright issue") : ""
    readonly property string originalError: !page._tried ? ""
        : (originalField.text.trim().length === 0 ? Lang.tr("Link to the original content is required")
           : !CopyrightService.isUrl(originalField.text) ? Lang.tr("Please provide a valid link to the original content") : "")
    readonly property string emailError: page._tried && emailField.text.trim().length > 0
        && !CopyrightService.isEmail(emailField.text) ? Lang.tr("Invalid email") : ""

    header: PageHeader {
        title: Lang.tr("Report copyright")
        leadingActionBar.actions: [
            Action { iconName: "back"; text: Lang.tr("Back"); onTriggered: page.pageStack.pop() }
        ]
    }

    Component.onCompleted: {
        contentField.text = CopyrightService.contentUrl(page.post, page.kind);
        communityField.text = (page.post && (page.post.community || page.post.communityTitle)) || "";
    }

    function submit() {
        page._tried = true;
        Qt.inputMethod.commit();
        if (page.linkError || page.communityError || page.messageError
                || page.originalError || page.emailError) {
            Toast.error(Lang.tr("Please fix the highlighted fields."));
            return;
        }
        page.submitting = true;
        CopyrightService.submit({
            contentLink: contentField.text.trim(),
            community: communityField.text.trim(),
            communityId: page.post ? Number(page.post.communityId || 0) : 0,
            message: messageField.text.trim(),
            originalLink: originalField.text.trim(),
            email: emailField.text.trim(),
            reporterUsername: Session.isLoggedIn ? Session.username : ""
        }, function (msg) {
            page.submitting = false;
            Toast.success(msg || Lang.tr("Your report has been submitted. Thank you."));
            page.pageStack.pop();
        }, function (err) {
            page.submitting = false;
            Toast.error((err && err.message) ? err.message : Lang.tr("Couldn't send the report."));
        }, Session.isLoggedIn ? Session.token : "");
    }

    KeyboardAwareFlickable {
        id: scroll
        anchors { top: page.header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentWidth: width
        contentHeight: form.height + Style.spacingL * 2
        clip: true

        Column {
            id: form
            y: Style.spacingL
            width: Math.min(parent.width - Style.spacingM * 2, units.gu(72))
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.spacingM

            Label {
                width: parent.width
                text: Lang.tr("Tell us which post copies your work and where the original is. The platform owner reviews every report.")
                wrapMode: Text.WordWrap
                font.pixelSize: Style.fontSmall
                font.family: Style.fontFor(text)
                color: Style.textSecondary
            }

            // Reported post as a card, not a URL
            Column {
                width: parent.width
                visible: !!page.post
                spacing: units.gu(0.75)
                Label {
                    text: Lang.tr("Content you're reporting")
                    font.pixelSize: Style.fontSmall
                    font.weight: Font.DemiBold
                    color: Style.textPrimary
                }
                ContentPreviewCard {
                    width: parent.width
                    link: contentField.text
                    stack: page.pageStack
                }
            }

            FormField {
                id: contentField
                visible: !page.post
                label: Lang.tr("Link to the content on Serey")
                placeholder: "https://serey.io/..."
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                errorText: page.linkError
            }

            FormField {
                id: communityField
                label: Lang.tr("Community where it's posted")
                placeholder: Lang.tr("Community name")
                errorText: page.communityError
            }

            Column {
                width: parent.width
                spacing: units.gu(0.75)
                Label {
                    text: Lang.tr("Message")
                    font.pixelSize: Style.fontSmall
                    font.weight: Font.DemiBold
                    color: Style.textPrimary
                }
                MultilineField {
                    id: messageField
                    width: parent.width
                    height: Math.max(units.gu(14), messageField.input.contentHeight + Style.spacingM * 2)
                    placeholder: Lang.tr("Briefly describe why this content infringes your copyright")
                    border.color: page.messageError ? Style.danger
                                  : (messageField.input.activeFocus ? Style.brand : Style.divider)
                }
                Label {
                    visible: page.messageError.length > 0
                    text: page.messageError
                    font.pixelSize: Style.fontXSmall
                    color: Style.danger
                }
            }

            FormField {
                id: originalField
                label: Lang.tr("Link to the original content")
                placeholder: "https://..."
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                errorText: page.originalError
            }

            // Picked/pasted Serey post as a card
            ContentPreviewCard {
                width: parent.width
                visible: CopyrightService.parseContentLink(originalField.text) !== null
                link: visible ? originalField.text.trim() : ""
                stack: page.pageStack
            }

            // Pick from own posts instead of pasting
            SecondaryButton {
                width: parent.width
                visible: Session.isLoggedIn
                text: Lang.tr("Choose from my posts")
                onClicked: { Qt.inputMethod.hide(); picker.open(); }
            }

            FormField {
                id: emailField
                label: Lang.tr("Your email (optional, so we can follow up)")
                placeholder: "you@example.com"
                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoPredictiveText
                errorText: page.emailError
            }

            PrimaryButton {
                width: parent.width
                text: page.submitting ? Lang.tr("Sending…") : Lang.tr("Submit report")
                busy: page.submitting
                onClicked: page.submit()
            }
        }
    }

    MyPostsPicker {
        id: picker
        anchors.fill: parent
        onPicked: originalField.text = url
    }
}
