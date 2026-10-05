import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Hyprland

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
        id: focusGrab

        windows: [root]
        active: true

        onCleared: Qt.quit()
    }

    readonly property PwNode sink: Pipewire.defaultAudioSink

    readonly property int volumePercent:
        sink && sink.audio
            ? Math.round(sink.audio.volume * 100)
            : 0

    readonly property bool muted:
        sink && sink.audio
            ? sink.audio.muted
            : false

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

                    color: root.muted
                        ? "#8a8a8a"
                        : "#ffffff"

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

                        color: root.muted
                            ? "#8a8a8a"
                            : "#ffffff"

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
                    to: 1
                    stepSize: 0.01

                    value: root.sink && root.sink.audio
                        ? root.sink.audio.volume
                        : 0

                    enabled: root.sink && root.sink.audio

                    onMoved: {
                        if (!root.sink || !root.sink.audio)
                            return

                        root.sink.audio.volume = value

                        if (root.sink.audio.muted && value > 0)
                            root.sink.audio.muted = false
                    }

                    background: Rectangle {
                        x: volumeSlider.leftPadding
                        y: volumeSlider.topPadding
                            + volumeSlider.availableHeight / 2
                            - height / 2

                        width: volumeSlider.availableWidth
                        height: 4

                        radius: 2
                        color: "#20ffffff"

                        Rectangle {
                            width: volumeSlider.visualPosition
                                * parent.width

                            height: parent.height

                            radius: 2
                            color: "#8aadf4"
                        }
                    }

                    handle: Rectangle {
                        x: volumeSlider.leftPadding
                            + volumeSlider.visualPosition
                            * (volumeSlider.availableWidth - width)

                        y: volumeSlider.topPadding
                            + volumeSlider.availableHeight / 2
                            - height / 2

                        width: 14
                        height: 14

                        radius: 7
                        color: "#ffffff"

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
