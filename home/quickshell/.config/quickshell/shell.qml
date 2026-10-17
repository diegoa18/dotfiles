import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

PanelWindow {
    id: root

    anchors {
        top: true
    }

    margins {
        top: 32
    }

    // Tamaño dinámico según el tipo de OSD
    implicitWidth: root.osdType === "media" ? 340 : 150
    implicitHeight: root.osdType === "media" ? 90 : 64

    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    // Estado del OSD
    property bool visibleOsd: false
    property string osdType: ""
    property int brightnessValue: 0

    // ----------------------------------------------------
    // PIPEWIRE (Volumen)
    // ----------------------------------------------------
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property int volumePercent: Math.round((root.sink?.audio?.volume ?? 0) * 100)
    readonly property color osdColor: root.osdType === "volume" && root.volumePercent > 100 ? "#f38ba8" : "#ffffff"

    PwObjectTracker {
        objects: [root.sink]
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.showVolumeOsd() }
        function onMutedChanged() { root.showVolumeOsd() }
    }

    function showVolumeOsd() {
        root.osdType = "volume"
        root.visibleOsd = true
        hideTimer.restart()
    }

    // ----------------------------------------------------
    // IPC (Brillo)
    // ----------------------------------------------------
    IpcHandler {
        target: "brightness"
        function show(value: int): void {
            root.brightnessValue = value
            root.osdType = "brightness"
            root.visibleOsd = true
            hideTimer.restart()
        }
    }

    // ----------------------------------------------------
    // MPRIS (Multimedia)
    // ----------------------------------------------------
    property var activePlayer: null
    readonly property var players: Mpris.players.values

    function updatePlayer() {
        activePlayer = players.find(p => p.isPlaying) || players[0] || null;
    }

    onPlayersChanged: updatePlayer()

    Connections {
        target: root.activePlayer
        function onTrackTitleChanged() {
            if (root.activePlayer && root.activePlayer.isPlaying) {
                root.showMediaOsd()
            }
        }
    }

    function showMediaOsd() {
        root.osdType = "media"
        root.visibleOsd = true
        hideTimer.restart()
    }

    // ----------------------------------------------------
    // TIMERS Y RENDERIZADO
    // ----------------------------------------------------
    Timer {
        id: hideTimer
        // Le damos 2.5 segundos a la música para leer, 1.5s al brillo/volumen
        interval: root.osdType === "media" ? 2500 : 1500
        repeat: false
        onTriggered: root.visibleOsd = false
    }

    visible: root.visibleOsd

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "#73080808"
        border.width: 1
        border.color: "#20ffffff"

        // Layout para Volumen y Brillo (Compacto)
        Row {
            anchors.centerIn: parent
            spacing: 8
            visible: root.osdType !== "media"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (root.osdType === "brightness") return "☀"
                    if (root.osdType !== "volume") return ""
                    const audio = root.sink?.audio
                    if (!audio) return ""
                    if (audio.muted) return "󰝟"
                    const percent = Math.round(audio.volume * 100)
                    if (percent < 34) return ""
                    if (percent < 67) return ""
                    return ""
                }
                font.family: root.osdType === "volume" ? "Symbols Nerd Font" : "sans-serif"
                font.pixelSize: 18
                color: root.osdColor
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (root.osdType === "volume") {
                        if (!root.sink || !root.sink.audio) return "Audio"
                        if (root.sink.audio.muted) return "Muted"
                        return Math.round(root.sink.audio.volume * 100) + "%"
                    }
                    if (root.osdType === "brightness") return root.brightnessValue + "%"
                    return ""
                }
                font.family: "sans-serif"
                font.pixelSize: 16
                font.weight: Font.Medium
                color: root.osdColor
            }
        }

        // Layout para Media (Expandido)
        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            visible: root.osdType === "media"

            Item {
                width: 64
                height: 64
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    color: "#10000000"
                    radius: 6
                    border.width: 1
                    border.color: "#10ffffff"
                }

                Text {
                    anchors.centerIn: parent
                    visible: mediaArt.status !== Image.Ready
                    text: "♪"
                    color: "#ffffff"
                    font.family: "sans-serif"
                    font.pixelSize: 24
                }

                Image {
                    id: mediaArt
                    anchors.fill: parent
                    source: root.activePlayer ? root.activePlayer.trackArtUrl : ""
                    visible: status === Image.Ready
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: mediaArt.width
                            height: mediaArt.height
                            radius: 6
                        }
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 88
                spacing: 4

                Text {
                    text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown Title") : ""
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    text: root.activePlayer ? (root.activePlayer.trackArtist || "Unknown Artist") : ""
                    color: "#a1a1aa"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }
    }
}
