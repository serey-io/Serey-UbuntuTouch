import QtQuick 2.7
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3 as Popups
import Lomiri.Content 1.3
import Serey.FileUtils 1.0 as FileUtils
import "../Theme"
import "../Session"
import "../components"
import "../services/Uploads.js" as Uploads
import "../services/PodcastService.js" as PodcastService

Page {
    id: page

    // set = edit mode
    property var editEpisode: null
    property int defaultSeason: 1

    readonly property bool isEdit: !!page.editEpisode
    readonly property real maxContentWidth: units.gu(60)

    property string fileName: ""
    property string contentUrl: page.isEdit ? page.editEpisode.contentUrl : ""
    property string contentType: page.isEdit ? page.editEpisode.contentType : "audio"
    property string mediaId: ""
    property string durationMin: page.isEdit ? String(page.editEpisode.duration || "").replace(/\D/g, "") : ""
    property string thumbUrl: page.isEdit ? page.editEpisode.thumbnail : ""
    property bool uploading: false
    property int uploadPercent: 0
    property bool submitting: false

    readonly property bool canSave: !page.submitting && !page.uploading && !coverUploader.uploading
                                    && page.contentUrl.length > 0
                                    && titleField.text.trim().length > 0
                                    && Config.communityId > 0

    signal saved(var body)

    header: PageHeader {
        title: page.isEdit ? Lang.tr("Edit Episode") : Lang.tr("New Episode")
        trailingActionBar.actions: [
            Action {
                iconName: "ok"
                text: Lang.tr("Save")
                enabled: page.canSave
                onTriggered: page.save()
            }
        ]
    }

    function pickMedia() {
        if (page.uploading) return;
        Popups.PopupUtils.open(mediaPickerComp);
    }

    function onMediaPicked(fileUrl) {
        page.fileName = decodeURIComponent(String(fileUrl).split("/").pop());
        page.uploading = true;
        page.uploadPercent = 0;
        page.contentUrl = "";
        var t = Uploads._videoType(fileUrl);
        page.contentType = t && !t.audio ? "video" : "audio";
        Uploads.uploadVideo(Config.storageCreateUploadUrl, Session.token, fileUrl,
            function (url, job) {
                page.uploading = false;
                page.contentUrl = url;
                page.mediaId = (job && job.id) ? job.id : "";
                if (job && job.duration_sec > 0) page.durationMin = String(Math.max(1, Math.round(job.duration_sec / 60)));
                if (!page.thumbUrl && job && job.thumbnail_url) page.thumbUrl = job.thumbnail_url;
                Toast.success(Lang.tr("File uploaded"));
            },
            function (err) {
                page.uploading = false;
                page.fileName = "";
                if (page.isEdit) page.contentUrl = page.editEpisode.contentUrl;
                Toast.error((err && err.message) || Lang.tr("Upload failed."));
            },
            function (pct) { page.uploadPercent = pct; });
    }

    function discardUpload() {
        Uploads.abort();
        if (page.mediaId)
            Uploads.deleteVideo(Config.storageDeleteUploadUrl, Session.token, page.mediaId,
                                page.contentType === "audio" ? "audio" : "videos");
        page.mediaId = "";
    }

    function save() {
        if (!page.canSave) return;
        page.submitting = true;
        var season = parseInt(String(seasonField.text).replace(/\D/g, ""), 10) || 1;
        // an edit that stays in its season keeps its own access
        if (page.isEdit && season === page.editEpisode.seasonNumber) {
            page._submit(page.editEpisode.accessType);
            return;
        }
        PodcastService.accessForSeason(Config.baseUrl, Config.communityId, season,
            function (access) { page._submit(access); },
            function (e) {
                page.submitting = false;
                Toast.error((e && e.message) || Lang.tr("Couldn't save episode."));
            });
    }

    function _submit(accessType) {
        var body = PodcastService.payload({
            title: titleField.text,
            description: descField.text,
            contentType: page.contentType,
            contentUrl: page.contentUrl,
            thumbnail: page.thumbUrl,
            duration: page.durationMin,
            episode: episodeField.text,
            season: seasonField.text,
            seasonTitle: page.isEdit ? page.editEpisode.seasonTitle : "",
            accessType: accessType
        }, Config.communityId);
        var ok = function () {
            page.submitting = false;
            page.mediaId = "";
            // the app hides premium, so say where it went
            if (accessType === 2) Toast.success(Lang.tr("Saved to a premium season. Premium episodes show on the web only."));
            else Toast.success(page.isEdit ? Lang.tr("Episode updated") : Lang.tr("Episode published!"));
            page.saved(body);
            if (!page.isEdit) page.pageStack.pop();
        };
        var err = function (e) {
            page.submitting = false;
            Toast.error((e && e.message) || Lang.tr("Couldn't save episode."));
        };
        if (page.isEdit) PodcastService.update(Config.baseUrl, page.editEpisode.id, body, Session.token, ok, err);
        else PodcastService.create(Config.baseUrl, body, Session.token, ok, err);
    }

    // drop unsaved upload on leave
    Component.onDestruction: if (page.uploading || page.mediaId) page.discardUpload()

    Timer {
        id: uploadDelayTimer
        repeat: false
        property var pending: null
        onTriggered: { var fn = pending; pending = null; if (fn) fn(); }
    }
    FileUtils.FileChunkReader { id: chunkReader }
    Settings {
        id: uploadResumeStore
        category: "PodcastUpload"
        property string pendingUpload: ""
    }
    Component.onCompleted: {
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

    Component {
        id: mediaPickerComp
        VideoPicker { pickType: ContentType.Music; onPicked: page.onMediaPicked(fileUrl) }
    }
    Component {
        id: photoPickerComp
        PhotoPicker { onPicked: coverUploader.upload(fileUrl) }
    }
    PhotoUploader {
        id: coverUploader
        onUploaded: page.thumbUrl = url
        onFailed: Toast.error(message)
    }

    Flickable {
        id: scroll
        anchors { top: page.header.bottom; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width: Math.min(parent.width, page.maxContentWidth)
        contentHeight: col.height + Style.spacingL * 2
        clip: true

        Column {
            id: col
            width: parent.width - Style.spacingM * 2
            x: Style.spacingM
            y: Style.spacingM
            spacing: Style.spacingM

            // platform gate
            Label {
                width: parent.width
                visible: Config.communityId <= 0
                text: Lang.tr("Pick your platform (not Global) from the top bar first.")
                wrapMode: Text.WordWrap
                color: Style.danger
                font.pixelSize: Style.fontSmall
            }

            Label { text: Lang.tr("Audio or video file"); font.pixelSize: Style.fontSmall; font.weight: Font.DemiBold; color: Style.textPrimary }

            AbstractButton {
                width: parent.width
                height: units.gu(10)
                enabled: !page.uploading
                onClicked: page.pickMedia()
                Rectangle {
                    anchors.fill: parent
                    radius: Style.cardRadius
                    color: Style.iconBackground
                }
                Row {
                    anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                    spacing: Style.spacingM
                    Item {
                        width: units.gu(4); height: width
                        anchors.verticalCenter: parent.verticalCenter
                        Icon {
                            anchors.fill: parent
                            visible: !page.uploading
                            name: page.contentUrl.length > 0 ? "tick" : "add"
                            color: page.contentUrl.length > 0 ? Style.positive : Style.brand
                        }
                        ActivityIndicator { anchors.centerIn: parent; running: page.uploading; visible: running }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: col.width - units.gu(9)
                        Label {
                            width: parent.width
                            text: page.uploading
                                  ? (page.uploadPercent >= 100 ? Lang.tr("Processing…") : Lang.tr("Uploading…") + " " + page.uploadPercent + "%")
                                  : (page.fileName || (page.contentUrl.length > 0 ? Lang.tr("Current file") : Lang.tr("Choose a file")))
                            font.pixelSize: Style.fontRegular
                            color: Style.textPrimary
                            elide: Text.ElideMiddle
                        }
                        Label {
                            width: parent.width
                            text: page.contentUrl.length > 0 && !page.uploading
                                  ? Lang.tr("Tap to replace")
                                  : Lang.tr("MP3, M4A, WAV, OGG, FLAC or MP4")
                            font.pixelSize: Style.fontXSmall
                            color: Style.textSecondary
                        }
                    }
                }
            }

            Label { text: Lang.tr("Cover"); font.pixelSize: Style.fontSmall; font.weight: Font.DemiBold; color: Style.textPrimary }

            AbstractButton {
                width: units.gu(14); height: width
                enabled: !coverUploader.uploading
                onClicked: Popups.PopupUtils.open(photoPickerComp)
                Rectangle { anchors.fill: parent; radius: Style.thumbRadius; color: Style.iconBackground }
                RoundedThumb { anchors.fill: parent; source: page.thumbUrl; visible: page.thumbUrl.length > 0 }
                Icon {
                    anchors.centerIn: parent
                    visible: page.thumbUrl.length === 0 && !coverUploader.uploading
                    width: units.gu(3); height: width
                    name: "insert-image"
                    color: Style.textSecondary
                }
                ActivityIndicator { anchors.centerIn: parent; running: coverUploader.uploading; visible: running }
            }

            FormField {
                id: titleField
                width: parent.width
                label: Lang.tr("Title")
                placeholder: Lang.tr("Episode title")
                text: page.isEdit ? page.editEpisode.title : ""
            }

            Label { text: Lang.tr("Description"); font.pixelSize: Style.fontSmall; font.weight: Font.DemiBold; color: Style.textPrimary }
            MultilineField {
                id: descField
                width: parent.width
                placeholder: Lang.tr("What is this episode about?")
                maximumLength: 5000
                text: page.isEdit ? page.editEpisode.description : ""
            }

            Row {
                width: parent.width
                spacing: Style.spacingM
                FormField {
                    id: seasonField
                    width: (parent.width - Style.spacingM * 2) / 3
                    label: Lang.tr("Season")
                    inputMethodHints: Qt.ImhDigitsOnly
                    text: String(page.isEdit ? page.editEpisode.seasonNumber : page.defaultSeason)
                }
                FormField {
                    id: episodeField
                    width: (parent.width - Style.spacingM * 2) / 3
                    label: Lang.tr("Episode")
                    inputMethodHints: Qt.ImhDigitsOnly
                    text: page.isEdit && page.editEpisode.episodeNumber ? String(page.editEpisode.episodeNumber) : ""
                }
                FormField {
                    width: (parent.width - Style.spacingM * 2) / 3
                    label: Lang.tr("Minutes")
                    inputMethodHints: Qt.ImhDigitsOnly
                    text: page.durationMin
                    onTextChanged: page.durationMin = text
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.3)
        visible: page.submitting
        z: 100
        MouseArea { anchors.fill: parent }
        ActivityIndicator { anchors.centerIn: parent; running: page.submitting }
    }
}
