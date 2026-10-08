import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris

WaybarPopup {
    id: root

    preferredPopupWidth: 280
    preferredPopupHeight: content.implicitHeight + 28

    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true

    HyprlandFocusGrab {
        id: focusGrab

        windows: [root]
        active: true

        onCleared: Qt.quit()
    }

    readonly property var availablePlayers: Mpris.players.values
    property var player: null

    readonly property bool hasArtwork:
        root.player !== null && root.player.trackArtUrl !== ""

    // Keep the same player when it pauses, even if another player is playing.
    function selectPlayer() {
        const players = root.availablePlayers

        if (root.player && players.indexOf(root.player) !== -1)
            return

        root.player = players.find(p => p.isPlaying) || players[0] || null
    }

    onAvailablePlayersChanged: root.selectPlayer()
    Component.onCompleted: root.selectPlayer()

    function canRestartTrack(player) {
        if (!player || !player.positionSupported || !player.canSeek)
            return false

        const position = player.position
        return Number.isFinite(position) && position > 5
    }

    function keepOpen() {
        if (!popupHover.hovered)
            hideTimer.restart()
    }

    function previousOrRestart() {
        const player = root.player

        // Read the current position at click time, rather than a cached value.
        if (root.canRestartTrack(player))
            player.position = 0
        else if (player && player.canGoPrevious)
            player.previous()

        root.keepOpen()
    }

    function togglePlayback() {
        const player = root.player

        if (player && player.canTogglePlaying)
            player.togglePlaying()

        root.keepOpen()
    }

    function nextTrack() {
        const player = root.player

        if (player && player.canGoNext)
            player.next()

        root.keepOpen()
    }

    Timer {
        id: hideTimer

        interval: 3000
        repeat: false
        running: true

        onTriggered: Qt.quit()
    }

    // Position does not notify continuously. Refresh only while it is moving.
    Timer {
        interval: 1000
        repeat: true

        running: root.player !== null
            && root.player.positionSupported
            && root.player.isPlaying

        onTriggered: {
            if (root.player)
                root.player.positionChanged()
        }
    }

    Rectangle {
        anchors.fill: parent

        radius: 10
        color: "#59080808"

        border.width: 1
        border.color: "#20ffffff"

        focus: true
        Keys.onEscapePressed: Qt.quit()

        HoverHandler {
            id: popupHover

            onHoveredChanged: {
                if (hovered)
                    hideTimer.stop()
                else
                    hideTimer.restart()
            }
        }

        Column {
            id: content

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14

            spacing: 12

            Item {
                width: parent.width
                height: width

                Rectangle {
                    anchors.fill: parent

                    color: "#10000000"
                    radius: 8

                    border.width: 1
                    border.color: "#10ffffff"
                }

                Text {
                    anchors.centerIn: parent

                    visible: artwork.status !== Image.Ready

                    text: "♪"
                    color: "#e2e5ed"
                    font.family: "sans-serif"
                    font.pixelSize: 48
                }

                Image {
                    id: artwork

                    anchors.fill: parent

                    source: root.hasArtwork ? root.player.trackArtUrl : ""
                    visible: status === Image.Ready
                    fillMode: Image.PreserveAspectFit

                    asynchronous: true
                    cache: true
                }
            }

            Text {
                width: parent.width

                text: root.player
                    ? (root.player.trackTitle || "Unknown Title")
                    : "No active player"

                textFormat: Text.PlainText
                color: "#ffffff"

                font.pixelSize: 16
                font.bold: true

                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: root.player !== null

                text: root.player
                    ? (root.player.trackArtist || "Unknown Artist")
                    : ""

                textFormat: Text.PlainText
                color: "#ffffff"
                font.pixelSize: 13

                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                PlaybackButton {
                    glyph: "\uf048"
                    hint: root.canRestartTrack(root.player)
                        ? "Restart track" : "Previous track"

                    enabled: root.player !== null
                        && (root.player.canGoPrevious
                            || root.canRestartTrack(root.player))

                    onClicked: root.previousOrRestart()
                }

                PlaybackButton {
                    glyph: root.player && root.player.isPlaying
                        ? "\uf04c" : "\uf04b"
                    hint: root.player && root.player.isPlaying ? "Pause" : "Play"
                    iconSize: 24

                    enabled: root.player !== null && root.player.canTogglePlaying

                    onClicked: root.togglePlayback()
                }

                PlaybackButton {
                    glyph: "\uf051"
                    hint: "Next track"

                    enabled: root.player !== null && root.player.canGoNext

                    onClicked: root.nextTrack()
                }
            }
        }
    }

    component PlaybackButton: ToolButton {
        id: control

        required property string glyph
        required property string hint
        property int iconSize: 20

        implicitWidth: 40
        implicitHeight: 40

        padding: 0
        background: null
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus

        Accessible.name: control.hint

        contentItem: Text {
            text: control.glyph
            font.family: "Symbols Nerd Font"
            font.pixelSize: control.iconSize

            color: !control.enabled ? "#b9c0cc"
                : control.down || control.hovered || control.activeFocus
                    ? "#8aadf4" : "#ffffff"

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        ToolTip.visible: control.hovered
        ToolTip.delay: 400
        ToolTip.text: control.hint
    }
}
