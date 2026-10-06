import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

PanelWindow {
    id: root

    anchors {
        top: true
        right: true
    }

    margins {
        top: 32
        right: 90
    }

    implicitWidth: 300
    implicitHeight: 126
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true

    HyprlandFocusGrab {
        windows: [root]
        active: true
        onCleared: Qt.quit()
    }

    Keys.onEscapePressed: Qt.quit()

    readonly property PwNode sink: Pipewire.defaultAudioSink

    readonly property real audioVolume:
        sink && sink.audio ? sink.audio.volume : 0

    readonly property int volumePercent:
        Math.round(audioVolume * 100)

    readonly property bool muted:
        sink && sink.audio ? sink.audio.muted : false

    readonly property color volumeColor:
        muted ? "#8a8a8a"
            : volumePercent > 100 ? "#ed8796"
            : "#ffffff"

    PwObjectTracker {
        objects: [root.sink]
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "#59080808"

        border.width: 1
        border.color: "#20ffffff"

        Column {
            anchors {
                fill: parent
                margins: 16
            }

            spacing: 12

            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    text: "Audio"
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    text: root.muted
                        ? "Muted"
                        : root.volumePercent + "%"

                    color: root.volumeColor
                    font.pixelSize: 14
                }
            }

            Row {
                width: parent.width
                height: 28
                spacing: 12

                Rectangle {
                    width: 28
                    height: 28
                    radius: 7

                    color: muteArea.containsMouse
                        ? "#18ffffff"
                        : "transparent"

                    Text {
                        anchors.centerIn: parent

                        text: root.muted
                            ? "󰝟"
                            : root.volumePercent < 34
                                ? ""
                                : root.volumePercent < 67
                                    ? ""
                                    : ""

                        color: root.volumeColor
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: muteArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (root.sink && root.sink.audio)
                                root.sink.audio.muted =
                                    !root.sink.audio.muted
                        }
                    }
                }

                Slider {
                    id: volumeSlider

                    width: parent.width - 40
                    height: 28

                    from: 0
                    to: 1.5
                    stepSize: 0.01
                    snapMode: Slider.SnapAlways

                    enabled: root.sink && root.sink.audio

                    readonly property real knobSize: 14

                    // Encaje suave alrededor del 100%.
                    readonly property int captureBand: 2
                    readonly property int releaseBand: 4

                    property bool detentEngaged: false
                    property bool keyboardInteraction: false

                    function syncFromAudio() {
                        value = Math.max(
                            from,
                            Math.min(to, root.audioVolume)
                        )
                    }

                    function adjustedVolume(candidate) {
                        let percent = Math.max(
                            0,
                            Math.min(150, Math.round(candidate * 100))
                        )

                        if (volumeSlider.pressed
                                && !volumeSlider.keyboardInteraction) {
                            const distance = Math.abs(percent - 100)

                            if (volumeSlider.detentEngaged
                                    && distance > volumeSlider.releaseBand)
                                volumeSlider.detentEngaged = false

                            if (!volumeSlider.detentEngaged
                                    && distance <= volumeSlider.captureBand)
                                volumeSlider.detentEngaged = true

                            if (volumeSlider.detentEngaged)
                                percent = 100
                        }

                        return percent / 100
                    }

                    Component.onCompleted: syncFromAudio()

                    // Sincronizar también los cambios hechos con teclas.
                    Connections {
                        target: root

                        function onAudioVolumeChanged() {
                            if (!volumeSlider.pressed)
                                volumeSlider.syncFromAudio()
                        }
                    }

                    onPressedChanged: {
                        if (!pressed) {
                            detentEngaged = false
                            keyboardInteraction = false
                            syncFromAudio()
                        }
                    }

                    // Las flechas evitan el encaje y permiten pasos de 1%.
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Left
                                || event.key === Qt.Key_Right) {
                            keyboardInteraction = true
                            detentEngaged = false
                        }

                        event.accepted = false
                    }

                    Keys.onReleased: function(event) {
                        keyboardInteraction = false
                        event.accepted = false
                    }

                    onMoved: {
                        if (!root.sink || !root.sink.audio)
                            return

                        const next = adjustedVolume(value)

                        value = next
                        root.sink.audio.volume = next

                        if (root.sink.audio.muted && next > 0)
                            root.sink.audio.muted = false
                    }

                    background: Item {
                        id: track

                        x: volumeSlider.leftPadding
                            + volumeSlider.knobSize / 2

                        y: volumeSlider.topPadding
                            + volumeSlider.availableHeight / 2
                            - height / 2

                        width: Math.max(
                            0,
                            volumeSlider.availableWidth
                                - volumeSlider.knobSize
                        )

                        height: 4

                        readonly property real hundredPosition:
                            width / volumeSlider.to

                        Rectangle {
                            anchors.fill: parent
                            radius: 2
                            color: "#20ffffff"
                        }

                        // Tramo lleno entre 0% y 100%.
                        Rectangle {
                            width: Math.min(volumeSlider.value, 1)
                                / volumeSlider.to * track.width

                            height: track.height
                            radius: 2
                            color: "#8aadf4"
                        }

                        // Solo el volumen adicional se pinta de rojo.
                        Rectangle {
                            x: track.hundredPosition

                            width: Math.max(0, volumeSlider.value - 1)
                                / volumeSlider.to * track.width

                            height: track.height
                            radius: 2
                            color: "#ed8796"
                        }

                        // Marca discreta del 100%.
                        Rectangle {
                            x: track.hundredPosition - width / 2
                            y: -3
                            width: 1
                            height: 10
                            color: "#70ffffff"
                        }
                    }

                    handle: Rectangle {
                        x: volumeSlider.leftPadding
                            + volumeSlider.visualPosition
                            * (volumeSlider.availableWidth - width)

                        y: volumeSlider.topPadding
                            + volumeSlider.availableHeight / 2
                            - height / 2

                        width: volumeSlider.knobSize
                        height: volumeSlider.knobSize
                        radius: width / 2

                        color: volumeSlider.value > 1
                            ? "#ed8796"
                            : "#ffffff"

                        border.width: 1
                        border.color: "#30000000"
                    }
                }
            }

            Text {
                width: parent.width

                text: root.sink
                    ? (
                        root.sink.description !== ""
                            ? root.sink.description
                            : root.sink.name
                      )
                    : "No audio output"

                color: "#a5adcb"
                font.pixelSize: 11

                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }
}
