import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"

// episode cover with default image
RoundedThumb {
    property var episode: null
    readonly property string fallback: "https://storage.serey.io/cdn/images/582J4F5WD0VGPXADVB4CRDFMMY.webp"

    readonly property string _thumb: (episode && (episode.localThumb || episode.thumbnail)) || ""
    // youtube maxres is ~10x the bytes; small covers use the 320px one
    source: _thumb.indexOf("i.ytimg.com/") >= 0 && decodeWidth <= units.gu(18)
            ? _thumb.replace(/\/(maxresdefault|sddefault|hqdefault)\.jpg/, "/mqdefault.jpg")
            : (_thumb || fallback)

    // loading pulse
    SkeletonRect {
        anchors.fill: parent
        radius: parent.radius
        baseColor: Style.skeletonCover
        loading: parent.loading
    }
}
