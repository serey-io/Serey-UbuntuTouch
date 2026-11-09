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
    // synced from an outside feed: the API ignores file, type and length edits
    readonly property bool isSynced: page.isEdit && !!page.editEpisode.sourceId
    property bool pickVideo: page.isEdit && page.editEpisode.contentType === "video"
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

    // season picker
    property int seasonNumber: page.isEdit ? page.editEpisode.seasonNumber : page.defaultSeason
    property var seasonList: [{ number: page.seasonNumber, title: page.isEdit ? page.editEpisode.seasonTitle : "" }]
    property var savedSeasons: []
    property var premiumSeasons: ({})
    property bool seasonsOpen: false
    property bool addingSeason: false
    property bool savingSeason: false
    property string seasonError: ""
    readonly property var currentSeason: {
        for (var i = 0; i < page.seasonList.length; i++)
            if (page.seasonList[i].number === page.seasonNumber) return page.seasonList[i];
        return { number: page.seasonNumber, title: "" };
    }

    // publish scope
    property var publishCeilingId: page.isEdit ? page.editEpisode.publishCeilingId : 0
    property bool scopeTouched: false
    readonly property int scopeCommunityId: page.isEdit && page.editEpisode.communityId > 0 ? page.editEpisode.communityId : Config.communityId
    readonly property bool targetIsGlobal: {
        if (!(page.scopeCommunityId > 0)) return true;
        var c = Config.communityInfoFor(page.scopeCommunityId);
        return !!c && (c.dns || "") === Config.sources[0].dns;
    }
    readonly property var scopeOptions: Config.scopeOptionsFor(page.scopeCommunityId, Lang.tr)
    // null = saved ceiling unknown, so the row stays hidden
    readonly property var scopeCurrent: {
        for (var i = 0; i < page.scopeOptions.length; i++)
            if (page.scopeOptions[i].id === page.publishCeilingId) return page.scopeOptions[i];
        return null;
    }

    readonly property bool canSave: !page.submitting && !page.uploading && !coverUploader.uploading
                                    && !page.savingSeason
                                    && page.contentUrl.length > 0
                                    && titleField.text.trim().length > 0
                                    && page.scopeCommunityId > 0

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
                if (page.isEdit) {
                    page.contentUrl = page.editEpisode.contentUrl;
                    page.contentType = page.editEpisode.contentType;
                }
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

    function seasonLabel(s) {
        var name = Lang.tr("Season") + " " + s.number;
        return s.title ? name + ": " + s.title : name;
    }

    function loadSeasons() {
        if (page.scopeCommunityId <= 0) return;
        PodcastService.loadSeasons(Config.baseUrl, page.scopeCommunityId,
            function (list, saved, premium) {
                page.savedSeasons = saved;
                page.premiumSeasons = premium;
                // new episodes never default into a hidden premium season
                if (!page.isEdit && premium[page.seasonNumber])
                    page.seasonNumber = list.length ? list[0].number : page.nextSeason();
                page.seasonList = PodcastService.mergeSeasons(list, [page.currentSeason]);
            },
            function () { Toast.error(Lang.tr("Couldn't load seasons.")); });
    }

    // first number above every season, hidden ones too
    function nextSeason() {
        var nums = page.seasonList.map(function (s) { return s.number; }).concat(Object.keys(page.premiumSeasons).map(Number));
        return Math.max.apply(null, [0].concat(nums)) + 1;
    }

    function startNewSeason() {
        newSeasonNumber.text = String(page.nextSeason());
        newSeasonTitle.text = "";
        page.seasonError = "";
        page.addingSeason = true;
    }

    function addSeason() {
        if (page.savingSeason) return;
        var n = parseInt(newSeasonNumber.text.replace(/\D/g, ""), 10);
        if (!(n >= 1 && n <= 999)) { page.seasonError = Lang.tr("Use a number from 1 to 999."); return; }
        if (page.premiumSeasons[n] || page.seasonList.some(function (s) { return s.number === n; })) {
            page.seasonError = Lang.tr("Season %1 already exists.").arg(n);
            return;
        }
        var season = { number: n, title: newSeasonTitle.text.trim().slice(0, 120) };
        page.seasonError = "";
        page.savingSeason = true;
        PodcastService.addSeason(Config.baseUrl, page.scopeCommunityId, Session.token, season, page.savedSeasons,
            function (saved) {
                page.savingSeason = false;
                page.savedSeasons = saved;
                page.seasonList = PodcastService.mergeSeasons(page.seasonList, [season]);
                page.seasonNumber = n;
                page.addingSeason = false;
                page.seasonsOpen = false;
                Toast.success(Lang.tr("Season added"));
            },
            function (e) {
                page.savingSeason = false;
                Toast.error((e && e.message) || Lang.tr("Couldn't save season."));
            });
    }

    function scopeSheetItems() {
        return page.scopeOptions.map(function (o) {
            return { text: o.label,
                     iconName: o.id === page.publishCeilingId ? "tick" : "",
                     onTriggered: function () { page.publishCeilingId = o.id; page.scopeTouched = true; } };
        });
    }

    function save() {
        if (!page.canSave) return;
        page.submitting = true;
        var season = page.seasonNumber;
        if (page.isEdit && season === page.editEpisode.seasonNumber) {
            page._submit(page.editEpisode.seasonTitle);
            return;
        }
        PodcastService.seasonTitle(Config.baseUrl, page.scopeCommunityId, season,
            // an empty season's title lives only in the saved list
            function (title) { page._submit(title || page.currentSeason.title); },
            function (e) {
                page.submitting = false;
                Toast.error((e && e.message) || Lang.tr("Couldn't save episode."));
            });
    }

    function _submit(seasonTitle) {
        var body = PodcastService.payload({
            title: titleField.text,
            description: descField.text,
            contentType: page.contentType,
            contentUrl: page.contentUrl,
            thumbnail: page.thumbUrl,
            duration: page.durationMin,
            episode: episodeField.text,
            season: page.seasonNumber,
            seasonTitle: seasonTitle,
            isEdit: page.isEdit,
            // edits only send a real change
            ceiling: page.isEdit && !page.scopeTouched ? undefined : (page.targetIsGlobal ? 0 : page.publishCeilingId)
        }, page.scopeCommunityId);
        var ok = function () {
            page.submitting = false;
            page.mediaId = "";
            Toast.success(page.isEdit ? Lang.tr("Episode updated") : Lang.tr("Episode published!"));
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
        page.loadSeasons();
    }

    Component {
        id: mediaPickerComp
        VideoPicker { pickType: page.pickVideo ? ContentType.Videos : ContentType.Music; onPicked: page.onMediaPicked(fileUrl) }
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

    KeyboardAwareFlickable {
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
                visible: page.scopeCommunityId <= 0
                text: Lang.tr("Pick your platform (not Global) from the top bar first.")
                wrapMode: Text.WordWrap
                color: Style.danger
                font.pixelSize: Style.fontSmall
            }

            Label { visible: !page.isSynced; text: Lang.tr("Audio or video file"); font.pixelSize: Style.fontSmall; font.weight: Font.DemiBold; color: Style.textPrimary }

            SectionTabs {
                width: parent.width
                visible: !page.isSynced
                model: [Lang.tr("Audio"), Lang.tr("Video")]
                currentIndex: page.pickVideo ? 1 : 0
                onSelected: page.pickVideo = index === 1
            }

            AbstractButton {
                width: parent.width
                height: units.gu(10)
                visible: !page.isSynced
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
                                  ? Lang.tr("Uploading…") + " " + page.uploadPercent + "%"
                                  : (page.fileName || (page.contentUrl.length > 0 ? Lang.tr("Current file") : Lang.tr("Choose a file")))
                            font.pixelSize: Style.fontRegular
                            color: Style.textPrimary
                            elide: Text.ElideMiddle
                        }
                        Label {
                            width: parent.width
                            text: page.contentUrl.length > 0 && !page.uploading
                                  ? Lang.tr("Tap to replace")
                                  : (page.pickVideo ? Lang.tr("MP4, MOV, WEBM or MKV") : Lang.tr("MP3, M4A, AAC or WAV"))
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

            Label { text: Lang.tr("Season"); font.pixelSize: Style.fontSmall; font.weight: Font.DemiBold; color: Style.textPrimary }

            // season picker
            Column {
                width: parent.width
                spacing: Style.spacingS

                AbstractButton {
                    width: parent.width
                    height: units.gu(5)
                    onClicked: page.seasonsOpen = !page.seasonsOpen
                    Rectangle {
                        anchors.fill: parent
                        radius: Style.cardRadius
                        color: Style.surface
                        border.width: units.dp(1)
                        border.color: page.seasonsOpen ? Style.brand : Style.divider
                    }
                    Label {
                        anchors { left: parent.left; right: seasonChevron.left; margins: Style.spacingM; verticalCenter: parent.verticalCenter }
                        text: page.seasonLabel(page.currentSeason)
                        font.pixelSize: Style.fontRegular
                        font.family: Style.fontFor(text)
                        color: Style.textPrimary
                        elide: Text.ElideRight
                    }
                    Icon {
                        id: seasonChevron
                        anchors { right: parent.right; rightMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                        width: units.gu(2); height: width
                        name: page.seasonsOpen ? "go-up" : "go-down"
                        color: Style.textSecondary
                    }
                }

                Repeater {
                    model: page.seasonsOpen ? page.seasonList : []
                    delegate: AbstractButton {
                        width: parent.width
                        height: units.gu(5)
                        onClicked: { page.seasonNumber = modelData.number; page.seasonsOpen = false; page.addingSeason = false; }
                        Label {
                            anchors { left: parent.left; right: seasonTick.left; margins: Style.spacingM; verticalCenter: parent.verticalCenter }
                            text: page.seasonLabel(modelData)
                            font.pixelSize: Style.fontRegular
                            font.family: Style.fontFor(text)
                            color: Style.textPrimary
                            elide: Text.ElideRight
                        }
                        Icon {
                            id: seasonTick
                            anchors { right: parent.right; rightMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                            width: units.gu(2); height: width
                            name: "tick"
                            color: Style.brand
                            visible: modelData.number === page.seasonNumber
                        }
                    }
                }

                AbstractButton {
                    width: parent.width
                    height: units.gu(5)
                    visible: page.seasonsOpen && !page.addingSeason
                    onClicked: page.startNewSeason()
                    Row {
                        anchors { left: parent.left; leftMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                        spacing: Style.spacingS
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: units.gu(2); height: width
                            name: "add"
                            color: Style.brand
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Lang.tr("New season")
                            font.pixelSize: Style.fontRegular
                            color: Style.brand
                        }
                    }
                }

                // new season form
                Column {
                    width: parent.width
                    spacing: Style.spacingS
                    visible: page.seasonsOpen && page.addingSeason

                    FormField {
                        id: newSeasonNumber
                        width: parent.width
                        label: Lang.tr("Season number")
                        inputMethodHints: Qt.ImhDigitsOnly
                        errorText: page.seasonError
                    }
                    FormField {
                        id: newSeasonTitle
                        width: parent.width
                        label: Lang.tr("Season title (optional)")
                    }
                    Row {
                        spacing: Style.spacingS
                        Button {
                            text: Lang.tr("Add season")
                            color: Style.brand
                            enabled: !page.savingSeason
                            onClicked: page.addSeason()
                        }
                        Button {
                            text: Lang.tr("Cancel")
                            enabled: !page.savingSeason
                            onClicked: page.addingSeason = false
                        }
                    }
                }
            }

            FormField {
                id: episodeField
                width: parent.width
                label: Lang.tr("Episode")
                inputMethodHints: Qt.ImhDigitsOnly
                text: page.isEdit && page.editEpisode.episodeNumber ? String(page.editEpisode.episodeNumber) : ""
            }

            // publish scope picker
            Column {
                width: parent.width
                spacing: Style.spacingS
                visible: !page.targetIsGlobal && !!page.scopeCurrent

                Label { text: Lang.tr("Publish to"); font.pixelSize: Style.fontSmall; font.weight: Font.DemiBold; color: Style.textPrimary }

                AbstractButton {
                    id: scopeRow
                    width: parent.width
                    height: units.gu(5)
                    onClicked: scopeSheet.show(page.scopeSheetItems(), scopeRow)
                    Rectangle {
                        anchors.fill: parent
                        radius: Style.cardRadius
                        color: Style.surface
                        border.width: units.dp(1)
                        border.color: Style.divider
                    }
                    Label {
                        anchors { left: parent.left; right: scopeChevron.left; margins: Style.spacingM; verticalCenter: parent.verticalCenter }
                        text: page.scopeCurrent ? page.scopeCurrent.label : ""
                        font.pixelSize: Style.fontRegular
                        font.family: Style.fontFor(text)
                        color: Style.textPrimary
                        elide: Text.ElideRight
                    }
                    Icon {
                        id: scopeChevron
                        anchors { right: parent.right; rightMargin: Style.spacingM; verticalCenter: parent.verticalCenter }
                        width: units.gu(2); height: width
                        name: "go-down"
                        color: Style.textSecondary
                    }
                }

                Label {
                    width: parent.width
                    text: page.scopeCurrent ? page.scopeCurrent.hint : ""
                    font.pixelSize: Style.fontXSmall
                    font.family: Style.fontFor(text)
                    color: Style.textSecondary
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    ActionBottomSheet { id: scopeSheet }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.3)
        visible: page.submitting
        z: 100
        MouseArea { anchors.fill: parent }
        ActivityIndicator { anchors.centerIn: parent; running: page.submitting }
    }
}
