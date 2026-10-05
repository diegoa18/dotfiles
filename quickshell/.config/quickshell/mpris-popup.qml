import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
    }

    margins {
        top: 32
        left: 70
    }

    implicitWidth: 280
    implicitHeight: 370

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

    property var player: {
        const players = Mpris.players.values

        if (players.length === 0)
            return null

        const playing = players.find(p => p.isPlaying)

        if (playing)
            return playing

        return players[0]
    }

    property bool hasArtwork:
        root.player !== null &&
        root.player.trackArtUrl !== ""

    Timer {
        id: hideTimer

        interval: 3000
        repeat: false

        running: true

        onTriggered: {
            Qt.quit()
        }
    }

    Component.onCompleted: {
        if (!root.hasArtwork)
            Qt.quit()
    }

    Keys.onEscapePressed: {
        Qt.quit()
    }

    Rectangle {
        anchors.fill: parent

        radius: 10

        color: "#59080808"

        border.width: 1
        border.color: "#20ffffff"

        Column {
            anchors.fill: parent
            anchors.margins: 14

            spacing: 12

            Image {
                width: parent.width
                height: width

                source: root.hasArtwork
                    ? root.player.trackArtUrl
                    : ""

                fillMode: Image.PreserveAspectFit

                asynchronous: true
                cache: true

                Rectangle {
                    anchors.fill: parent

                    color: "transparent"

                    border.width: 1
                    border.color: "#10ffffff"

                    radius: 8

                    z: 2
                }
            }

            Text {
                width: parent.width

                text: root.player
                    ? (root.player.trackTitle || "Unknown Title")
                    : "Unknown Title"

                color: "#ffffff"

                font.pixelSize: 16
                font.bold: true

                horizontalAlignment: Text.AlignHCenter

                elide: Text.ElideRight
            }

            Text {
                width: parent.width

                text: root.player
                    ? (root.player.trackArtist || "Unknown Artist")
                    : "Unknown Artist"

                color: "#ffffff"

                font.pixelSize: 13

                horizontalAlignment: Text.AlignHCenter

                elide: Text.ElideRight
            }
        }
    }
}
