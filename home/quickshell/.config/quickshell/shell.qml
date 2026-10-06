import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

PanelWindow {
    id: root

    anchors {
        top: true
    }

    margins {
        top: 32
    }

    implicitWidth: 150
    implicitHeight: 72

    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    // Estado del OSD

    property bool visibleOsd: false
    property string osdType: ""
    property int brightnessValue: 0

    // PipeWire

    readonly property PwNode sink: Pipewire.defaultAudioSink

    readonly property int volumePercent:
        Math.round((root.sink?.audio?.volume ?? 0) * 100)

    readonly property color osdColor:
        root.osdType === "volume" && root.volumePercent > 100
            ? "#ed8796"
            : "#ffffff"

    PwObjectTracker {
        objects: [root.sink]
    }

    // Ocultar OSD

    Timer {
        id: hideTimer

        interval: 1200
        repeat: false

        onTriggered: {
            root.visibleOsd = false
        }
    }

    // Mostrar volumen

    function showVolumeOsd() {
        root.osdType = "volume"
        root.visibleOsd = true
        hideTimer.restart()
    }

    // IPC → brillo

    IpcHandler {
        target: "brightness"

        function show(value: int): void {
            root.brightnessValue = value
            root.osdType = "brightness"
            root.visibleOsd = true
            hideTimer.restart()
        }
    }

    // PipeWire → volumen

    Connections {
        target: root.sink?.audio ?? null

        function onVolumeChanged() {
            root.showVolumeOsd()
        }

        function onMutedChanged() {
            root.showVolumeOsd()
        }
    }

    // OSD

    visible: root.visibleOsd

    Rectangle {
        anchors.fill: parent

        radius: 10
        color: "#59080808"

        border.width: 1
        border.color: "#20ffffff"

        Row {
            anchors.centerIn: parent
            spacing: 8

            // Icono

            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: {
                    if (root.osdType === "brightness")
                        return "☀"

                    if (root.osdType !== "volume")
                        return ""

                    const audio = root.sink?.audio

                    if (!audio)
                        return ""

                    if (audio.muted)
                        return "󰝟"

                    const percent = Math.round(audio.volume * 100)

                    if (percent < 34)
                        return ""

                    if (percent < 67)
                        return ""

                    return ""
                }

                font.family: root.osdType === "volume"
                    ? "Symbols Nerd Font"
                    : "sans-serif"

                font.pixelSize: 16
                color: root.osdColor
            }

            // Porcentaje o estado

            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: {
                    if (root.osdType === "volume") {
                        if (!root.sink || !root.sink.audio)
                            return "Audio"

                        if (root.sink.audio.muted)
                            return "Muted"

                        return Math.round(root.sink.audio.volume * 100) + "%"
                    }

                    if (root.osdType === "brightness")
                        return root.brightnessValue + "%"

                    return ""
                }

                font.family: "sans-serif"
                font.pixelSize: 16
                color: root.osdColor
            }
        }
    }
}
