import QtQuick 2.7
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3 as Popups
import Serey.FileUtils 1.0 as FileUtils
import "../Theme"
import "../Session"
import "../services/PostService.js" as PostService
import "../services/Mappers.js" as Mappers
import "../services/Notes.js" as Notes
import "../services/Uploads.js" as Uploads

// Short post: text + one photo or video (link or upload)
Item {
    id: root

    // Set by host page
    property var editPost: null
    property int communityId: 0
    property string communityName: ""
    property int publishCeilingId: 0
    property real kbHeight: 0
    property real maxContentWidth: units.gu(72)

    readonly property bool isEdit: !!editPost
    property string imageUrl: ""
    property string videoUrl: ""
    property bool uploading: false
    property bool submitting: false

    readonly property int charsLeft: Notes.remaining(noteField.text)
    // Video upload state
    property bool videoUploading: false
    property int videoPercent: 0
    property string videoId: ""
    property string videoPoster: ""
    readonly property bool busy: root.uploading || root.videoUploading

    readonly property bool canPost: !root.submitting && !root.busy
        && noteField.text.trim().length > 0 && root.charsLeft >= 0

    signal saved(var data)

    // Edit prefill; re-runs on detail refetch until user types
    property bool _touched: false
    property bool _prefilling: false
    function _prefill() {
        if (!root.editPost || root._touched) return;
        root._prefilling = true;
        noteField.text = Mappers.noteText(root.editPost.body || "") || root.editPost.noteText || "";
        root.imageUrl = root.editPost.coverImage || "";
        root.videoUrl = root.editPost.noteVideo || "";
        root._prefilling = false;
    }
    onEditPostChanged: _prefill()
    Component.onCompleted: {
        _prefill();
        // Uploader hooks, same as CreateVideoPage
        Uploads.setDelayHook(function (ms, fn) {
            uploadDelayTimer.pending = fn;
            uploadDelayTimer.interval = ms;
            uploadDelayTimer.restart();
        });
        Uploads.setFileReader(chunkReader);
        Uploads.setUploadStore({
            get: function () { return uploadResumeStore.pendingUpload; },
            set: function (v) { uploadResumeStore.pendingUpload = v; }
        });
    }
    // Leaving unposted: drop orphan upload
    property bool _posted: false
    Component.onDestruction: {
        if (root.videoUploading) Uploads.abort();
        if (!root._posted && root.videoId)
            Uploads.deleteVideo(Config.storageDeleteUploadUrl, Session.token, root.videoId);
    }

    Timer {
        id: uploadDelayTimer
        repeat: false
        property var pending: null
        onTriggered: { var fn = pending; pending = null; if (fn) fn(); }
    }
    FileUtils.FileChunkReader { id: chunkReader }
    Settings {
        id: uploadResumeStore
        category: "NoteVideoUpload"
        property string pendingUpload: ""
    }

    function pickVideoFile() {
        if (!Session.isLoggedIn) { Toast.error(Lang.tr("Please log in first.")); return; }
        Popups.PopupUtils.open(videoPickerComp);
    }

    function _onVideoPicked(fileUrl) {
        root.clearVideo();
        root.imageUrl = "";
        root.videoUploading = true;
        root.videoPercent = 0;
        Uploads.uploadVideo(Config.storageCreateUploadUrl, Session.token, fileUrl,
            function (url, job) {
                root.videoUploading = false;
                root.videoId = (job && job.id) ? job.id : "";
                if (!root.videoPoster && job && job.thumbnail_url) root.videoPoster = job.thumbnail_url;
                root.videoUrl = url;
                // Length known late: recheck
                root._checkDuration();
                if (root.videoUrl) Toast.success(Lang.tr("Video uploaded"));
            },
            function (err) {
                root.clearVideo();
                Toast.error((err && err.message) ? err.message : Lang.tr("Video upload failed."));
            },
            function (percent) { root.videoPercent = percent; });
        // Local frame + length
        frameGrabber.grab(fileUrl);
    }

    // Over 1 min: cancel + delete
    function _checkDuration() {
        if (frameGrabber.duration <= Notes.MAX_VIDEO_SECONDS + 0.5) return;
        if (!root.videoUploading && !root.videoId && !root.videoUrl) return;
        root.clearVideo();
        Toast.error(Lang.tr("Video must be 1 minute or shorter."));
    }

    function clearVideo() {
        if (root.videoUploading) Uploads.abort();
        if (root.videoId)
            Uploads.deleteVideo(Config.storageDeleteUploadUrl, Session.token, root.videoId);
        root.videoUploading = false;
        root.videoPercent = 0;
        root.videoId = "";
        root.videoPoster = "";
        root.videoUrl = "";
    }

    Component {
        id: videoPickerComp
        VideoPicker { onPicked: root._onVideoPicked(fileUrl) }
    }

    VideoThumbnailGrabber {
        id: frameGrabber
        onGrabbed: root.videoPoster = dataUrl
        onDurationChanged: root._checkDuration()
    }

    // Pasted YouTube link -> video attachment
    function _absorbYouTube() {
        if (root.imageUrl.length > 0 || root.videoUrl.length > 0 || root.busy) return;
        Qt.inputMethod.commit();
        var hit = Notes.findYouTube(noteField.text);
        if (!hit) return;
        root.videoUrl = hit.url;
        noteField.text = Notes.removeText(noteField.text, hit.raw);
        noteField.cursorPosition = noteField.text.length;
        Toast.show(Lang.tr("Video added"));
    }

    function submit() {
        if (!Session.isLoggedIn) { Toast.error(Lang.tr("Please log in first.")); return; }
        Qt.inputMethod.commit();
        root.submitting = true;
        PostService.createNote(Config.baseUrl, {
            body: Notes.toBody(noteField.text),
            imageUrl: root.imageUrl,
            videoUrl: root.videoUrl,
            communityId: root.communityId,
            communityName: root.communityName,
            publishCeilingId: root.publishCeilingId,
            permlink: root.isEdit ? (root.editPost.permlink || "") : ""
        }, Session.token,
        function (data) { root.submitting = false; root._posted = true; root.saved(data); },
        function (err) {
            root.submitting = false;
            Toast.error((err && err.message) ? err.message
                        : (root.isEdit ? Lang.tr("Couldn't update note.") : Lang.tr("Couldn't post note.")));
        });
    }

    Component {
        id: pickerComp
        PhotoPicker { onPicked: imgUploader.upload(fileUrl) }
    }

    PhotoUploader {
        id: imgUploader
        onUploadingChanged: root.uploading = uploading
        onUploaded: { root.clearVideo(); root.imageUrl = url; }
        onFailed: Toast.error(message)
    }

    Component {
        id: videoDialog
        Popups.Dialog {
            id: vdlg
            title: Lang.tr("Add video")
            text: Lang.tr("Upload a clip up to 1 minute, or paste a YouTube, TikTok or Facebook link.")
            // White text on brand
            PrimaryButton {
                text: Lang.tr("Upload from device")
                onClicked: { Popups.PopupUtils.close(vdlg); root.pickVideoFile(); }
            }
            TextField {
                id: videoField
                placeholderText: "https://"
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                Component.onCompleted: videoField.forceActiveFocus()
            }
            Button {
                text: Lang.tr("Add link")
                onClicked: {
                    var url = videoField.text.trim();
                    if (!Notes.isVideoLink(url)) { Toast.error(Lang.tr("Please enter a valid video link.")); return; }
                    Popups.PopupUtils.close(vdlg);
                    root.clearVideo();
                    root.videoUrl = url;
                    root.imageUrl = "";
                }
            }
            Button {
                text: Lang.tr("Cancel")
                onClicked: Popups.PopupUtils.close(vdlg)
            }
        }
    }

    Flickable {
        id: scroll
        anchors { top: parent.top; bottom: bar.top; horizontalCenter: parent.horizontalCenter }
        width: Math.min(parent.width, root.maxContentWidth)
        contentHeight: col.height + Style.spacingL
        clip: true

        Column {
            id: col
            width: parent.width - Style.spacingM * 2
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.spacingM

            Item { width: 1; height: Style.spacingS }

            // Box + counter overlay
            Item {
                width: parent.width
                height: noteField.height

                TextArea {
                    id: noteField
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    // Grows with text, min height; room for counter
                    height: Math.max(units.gu(18), contentHeight + units.gu(2) + counter.height)
                    textFormat: TextEdit.PlainText
                    wrapMode: Text.Wrap
                    font.pixelSize: Style.fontLarge
                    font.family: Style.fontFor(text)
                    color: Style.textPrimary
                    selectByMouse: true
                    selectionColor: Style.brand
                    property int _prevLen: 0
                    onTextChanged: {
                        var grew = text.length - _prevLen;
                        _prevLen = text.length;
                        if (root._prefilling) return;
                        root._touched = true;
                        // Paste burst, not typing
                        if (grew >= 10) Qt.callLater(root._absorbYouTube);
                    }
                    placeholderText: Session.username
                                     ? Lang.tr("What's on your mind, %1?").arg(Session.username)
                                     : Lang.tr("What's on your mind?")
                }

                // Counter, bottom-right inside box
                Label {
                    id: counter
                    anchors { right: parent.right; bottom: parent.bottom; margins: Style.spacingS }
                    z: 1
                    text: root.charsLeft
                    font.pixelSize: Style.fontSmall
                    font.weight: root.charsLeft < 20 ? Font.DemiBold : Font.Normal
                    color: root.charsLeft < 0 ? Style.danger : root.charsLeft < 20 ? Style.accentRed : Style.textSecondary
                }
            }

            // Photo attachment
            Item {
                width: parent.width
                height: visible ? width * 0.56 : 0
                visible: root.imageUrl.length > 0

                RoundedThumb {
                    anchors.fill: parent
                    source: root.imageUrl
                    autoTransform: true
                }
                AbstractButton {
                    anchors { top: parent.top; right: parent.right; margins: Style.spacingS }
                    width: units.gu(3.5); height: width
                    onClicked: root.imageUrl = ""
                    Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.rgba(0, 0, 0, 0.6) }
                    Icon { anchors.centerIn: parent; width: units.gu(1.8); height: width; name: "close"; color: "white" }
                }
            }

            // YouTube: embed-style preview
            Item {
                id: ytPreview
                readonly property string thumb: Notes.videoThumb(root.videoUrl)
                width: parent.width
                height: visible ? width * 9 / 16 : 0
                visible: thumb.length > 0

                RoundedThumb {
                    anchors.fill: parent
                    source: ytPreview.thumb
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: units.gu(7); height: width
                    radius: width / 2
                    color: Qt.rgba(0, 0, 0, 0.55)
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(3.5); height: width
                        name: "media-playback-start"
                        color: "white"
                    }
                }
                AbstractButton {
                    anchors { top: parent.top; right: parent.right; margins: Style.spacingS }
                    width: units.gu(3.5); height: width
                    onClicked: root.clearVideo()
                    Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.rgba(0, 0, 0, 0.6) }
                    Icon { anchors.centerIn: parent; width: units.gu(1.8); height: width; name: "close"; color: "white" }
                }
            }

            // Uploaded clip: poster + progress
            Rectangle {
                id: filePreview
                width: parent.width
                height: visible ? width * 9 / 16 : 0
                visible: root.videoUploading || Notes.isDirectVideo(root.videoUrl)
                radius: Style.thumbRadius
                color: "black"

                RoundedThumb {
                    anchors.fill: parent
                    visible: root.videoPoster.length > 0
                    source: root.videoPoster
                }
                Rectangle {
                    anchors.centerIn: parent
                    visible: !root.videoUploading
                    width: units.gu(7); height: width
                    radius: width / 2
                    color: Qt.rgba(0, 0, 0, 0.55)
                    Icon {
                        anchors.centerIn: parent
                        width: units.gu(3.5); height: width
                        name: "media-playback-start"
                        color: "white"
                    }
                }
                // Upload progress
                Column {
                    anchors.centerIn: parent
                    visible: root.videoUploading
                    spacing: Style.spacingS
                    ActivityIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: parent.visible }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Lang.tr("Uploading… %1%").arg(root.videoPercent)
                        font.pixelSize: Style.fontSmall
                        color: "white"
                    }
                }
                Rectangle {
                    anchors { left: parent.left; bottom: parent.bottom }
                    visible: root.videoUploading
                    height: units.dp(3)
                    width: parent.width * root.videoPercent / 100
                    color: Style.brand
                }
                AbstractButton {
                    anchors { top: parent.top; right: parent.right; margins: Style.spacingS }
                    width: units.gu(3.5); height: width
                    onClicked: root.clearVideo()
                    Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.rgba(0, 0, 0, 0.6) }
                    Icon { anchors.centerIn: parent; width: units.gu(1.8); height: width; name: "close"; color: "white" }
                }
            }

            // Other video links
            Rectangle {
                width: parent.width
                height: visible ? videoRow.height + Style.spacingM * 2 : 0
                visible: root.videoUrl.length > 0 && !ytPreview.visible && !filePreview.visible
                radius: Style.thumbRadius
                color: "transparent"
                border.width: units.dp(1)
                border.color: Style.divider

                Row {
                    id: videoRow
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                              leftMargin: Style.spacingM; rightMargin: units.gu(5) }
                    spacing: Style.spacingM

                    RoundedThumb {
                        id: videoThumb
                        visible: source.length > 0
                        width: visible ? units.gu(10) : 0
                        height: units.gu(5.6)
                        source: Notes.videoThumb(root.videoUrl)
                        decodeWidth: units.gu(12)
                    }
                    Icon {
                        visible: !videoThumb.visible
                        anchors.verticalCenter: parent.verticalCenter
                        width: units.gu(2.5); height: width
                        name: "media-playback-start"
                        color: Style.textSecondary
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - (videoThumb.visible ? videoThumb.width : units.gu(2.5)) - parent.spacing
                        text: root.videoUrl
                        elide: Text.ElideMiddle
                        font.pixelSize: Style.fontSmall
                        color: Style.textSecondary
                    }
                }
                AbstractButton {
                    anchors { top: parent.top; right: parent.right; margins: Style.spacingS }
                    width: units.gu(3.5); height: width
                    onClicked: root.clearVideo()
                    Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.rgba(0, 0, 0, 0.6) }
                    Icon { anchors.centerIn: parent; width: units.gu(1.8); height: width; name: "close"; color: "white" }
                }
            }
        }
    }

    // Docked above OSK
    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.bottomMargin: root.kbHeight
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        height: units.gu(7)
        color: Style.surface

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: units.dp(1); color: Style.divider
        }

        Row {
            anchors { left: parent.left; leftMargin: Style.spacingS; verticalCenter: parent.verticalCenter }
            spacing: 0

            // One attachment max
            AbstractButton {
                width: units.gu(5); height: width
                enabled: !root.busy && root.videoUrl.length === 0
                opacity: enabled || root.uploading ? 1 : 0.35
                onClicked: { Qt.inputMethod.commit(); Popups.PopupUtils.open(pickerComp); }
                Icon {
                    anchors.centerIn: parent
                    visible: !root.uploading
                    width: units.gu(2.4); height: width
                    name: "image-x-generic-symbolic"
                    color: Style.textPrimary
                }
                ActivityIndicator { anchors.centerIn: parent; running: root.uploading; visible: running }
            }
            AbstractButton {
                width: units.gu(5); height: width
                enabled: root.imageUrl.length === 0 && root.videoUrl.length === 0 && !root.busy
                opacity: enabled ? 1 : 0.35
                onClicked: Popups.PopupUtils.open(videoDialog)
                Icon {
                    anchors.centerIn: parent
                    width: units.gu(2.4); height: width
                    name: "media-playback-start"
                    color: Style.textPrimary
                }
            }
        }

        SecondaryButton {
            id: previewBtn
            anchors { right: postBtn.left; rightMargin: Style.spacingS; verticalCenter: parent.verticalCenter }
            width: units.gu(11)
            enabled: noteField.text.trim().length > 0 || root.imageUrl.length > 0 || root.videoUrl.length > 0
            text: Lang.tr("Preview")
            onClicked: { Qt.inputMethod.commit(); Qt.inputMethod.hide(); root.previewOpen = true; }
        }

        PrimaryButton {
            id: postBtn
            anchors { right: parent.right; rightMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
            width: units.gu(12)
            enabled: root.canPost
            busy: root.submitting
            text: root.submitting ? (root.isEdit ? Lang.tr("Saving…") : Lang.tr("Posting…"))
                                  : (root.isEdit ? Lang.tr("Save") : Lang.tr("Post"))
            onClicked: root.submit()
        }
    }

    // --- Preview: note as its feed card ---
    property bool previewOpen: false
    readonly property string _previewThumb: root.imageUrl.length > 0 ? root.imageUrl
        : (Notes.videoThumb(root.videoUrl) || (Notes.isDirectVideo(root.videoUrl) ? root.videoPoster : ""))

    Rectangle {
        anchors.fill: parent
        visible: root.previewOpen
        color: Style.surface
        z: 150
        // Swallow taps behind
        MouseArea { anchors.fill: parent }

        Rectangle {
            id: pvHdr
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: units.gu(6)
            color: Style.surface
            AbstractButton {
                anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                width: units.gu(4); height: width
                onClicked: root.previewOpen = false
                Icon { anchors.centerIn: parent; width: units.gu(2.5); height: width; name: "close"; color: Style.textPrimary }
            }
            Label {
                anchors.centerIn: parent
                text: Lang.tr("Preview")
                font.pixelSize: Style.fontMedium
                font.weight: Font.DemiBold
                color: Style.textPrimary
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: units.dp(1); color: Style.divider
            }
        }

        Flickable {
            anchors { top: pvHdr.bottom; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            width: Math.min(parent.width, root.maxContentWidth)
            contentHeight: pvCol.height + Style.spacingL
            clip: true

            Column {
                id: pvCol
                width: parent.width
                spacing: Style.spacingS
                // Same indent as PostCard
                readonly property real indent: Style.spacingM + units.gu(4.25) + Style.spacingS

                Item { width: 1; height: Style.spacingS }

                // Avatar + name + time
                Row {
                    x: Style.spacingM
                    spacing: Style.spacingS
                    Item {
                        width: units.gu(4.25); height: width
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Style.avatarTint(Session.username)
                            visible: Session.avatarUrl.length === 0
                            Label {
                                anchors.centerIn: parent
                                text: Session.username.length > 0 ? Session.username.charAt(0).toUpperCase() : "?"
                                font.pixelSize: Style.fontMedium
                                font.bold: true
                                color: Style.brand
                            }
                        }
                        CircleImage {
                            anchors.fill: parent
                            visible: Session.avatarUrl.length > 0
                            source: Session.avatarUrl
                            decode: units.gu(9)
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Label {
                            text: Session.username
                            font.pixelSize: Style.fontSmall
                            font.weight: Font.DemiBold
                            font.family: Style.fontFor(text)
                            color: Style.textPrimary
                        }
                        Label {
                            text: Lang.tr("now") + (root.communityName ? "  · " + root.communityName : "")
                            font.pixelSize: Style.fontXSmall
                            font.family: Style.fontFor(text)
                            color: Style.textSecondary
                        }
                    }
                }

                Label {
                    x: pvCol.indent
                    width: pvCol.width - pvCol.indent - Style.spacingM
                    visible: noteField.text.trim().length > 0
                    text: Notes.linkifyPlain(noteField.text.trim(), Style.brand)
                    textFormat: Text.StyledText
                    font.pixelSize: Style.fontMedium
                    font.family: Style.fontFor(noteField.text)
                    color: Style.textPrimary
                    wrapMode: Text.Wrap
                    onLinkActivated: Qt.openUrlExternally(link)
                }

                // Media: square photo / 16:9 video
                Rectangle {
                    readonly property bool isVideo: root.videoUrl.length > 0
                    x: pvCol.indent
                    visible: root._previewThumb.length > 0 || Notes.isDirectVideo(root.videoUrl)
                    width: Math.min(pvCol.width - pvCol.indent - Style.spacingM, units.gu(40))
                    height: visible ? (isVideo ? width * 0.56 : width) : 0
                    radius: Style.thumbRadius
                    color: "black"
                    RoundedThumb {
                        anchors.fill: parent
                        visible: root._previewThumb.length > 0
                        source: root._previewThumb
                        autoTransform: true
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        visible: parent.isVideo
                        width: units.gu(6); height: width
                        radius: width / 2
                        color: Qt.rgba(0, 0, 0, 0.55)
                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(3); height: width
                            name: "media-playback-start"
                            color: "white"
                        }
                    }
                }

                // TikTok / Facebook link
                Label {
                    x: pvCol.indent
                    width: pvCol.width - pvCol.indent - Style.spacingM
                    visible: root.videoUrl.length > 0 && root._previewThumb.length === 0 && !Notes.isDirectVideo(root.videoUrl)
                    text: root.videoUrl
                    elide: Text.ElideMiddle
                    font.pixelSize: Style.fontSmall
                    color: Style.brand
                }
            }
        }
    }
}
