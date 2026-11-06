import QtQuick 2.7
import Lomiri.Components 1.3
import "../Theme"

// episode cover with default image
RoundedThumb {
    property var episode: null
    readonly property string fallback: "https://storage.serey.io/cdn/images/582J4F5WD0VGPXADVB4CRDFMMY.webp"

    source: (episode && (episode.localThumb || episode.thumbnail)) || fallback
}
