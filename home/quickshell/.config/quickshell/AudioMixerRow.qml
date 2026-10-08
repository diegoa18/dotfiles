import QtQuick
import QtQuick.Controls
import "AudioMixer.js" as AudioMixer

Item {
    id: control

    property var nodes: []
    property string title: ""
    property string subtitle: ""
    property bool microphone: false
    property bool showMixerButton: false
    property bool mixerExpanded: false
    property bool showOutputButton: false
    property bool outputsExpanded: false
    property bool outputSelectionEnabled: true
    property int titlePixelSize: 13
    property real maximumVolume: 1.5
    signal mixerToggleRequested()
    signal outputToggleRequested()

    readonly property var liveNodes: AudioMixer.availableNodes(nodes)
    readonly property real audioVolume: AudioMixer.maximumVolume(liveNodes)
    readonly property bool muted: AudioMixer.allMuted(liveNodes)
    readonly property int volumePercent: Math.round(audioVolume * 100)
    readonly property color volumeColor: liveNodes.length === 0 || muted
        ? "#c3c8d4" : volumePercent > 100 ? "#ed8796" : "#ffffff"

    implicitHeight: 64 + (subtitle.length > 0 ? 30 : 0)

    Item {
        id: header
        width: parent.width
        height: 24

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - headerControls.width - 8)
            text: control.title
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: "#ffffff"
            font.pixelSize: control.titlePixelSize
            font.weight: Font.Medium
        }

        Row {
            id: headerControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: control.liveNodes.length === 0 ? "Unavailable"
                    : control.microphone && control.muted ? control.volumePercent + "% · Muted"
                    : control.muted ? "Muted" : control.volumePercent + "%"
                color: control.volumeColor
                font.pixelSize: 14
            }

            ToolButton {
                id: mixerButton
                visible: control.showMixerButton
                width: 24
                height: 24
                padding: 0
                background: null

                contentItem: Text {
                    text: "\uf1de"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: control.mixerExpanded || mixerButton.hovered || mixerButton.activeFocus
                        ? "#8aadf4" : "#e2e5ed"
                }

                onClicked: control.mixerToggleRequested()
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: control.mixerExpanded ? "Hide mixer" : "Show mixer"

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    Row {
        anchors.top: header.bottom
        anchors.topMargin: 12
        width: parent.width
        height: 28
        spacing: 12

        ToolButton {
            id: muteButton
            width: 28
            height: 28
            padding: 0
            enabled: control.liveNodes.length > 0

            background: Rectangle {
                radius: 7
                color: muteButton.hovered || muteButton.activeFocus ? "#18ffffff" : "transparent"
            }

            contentItem: Text {
                text: control.microphone
                    ? (control.muted ? "󰍭" : "󰍬")
                    : control.muted ? "󰝟"
                    : control.volumePercent < 34 ? ""
                    : control.volumePercent < 67 ? "" : ""
                font.family: "Symbols Nerd Font"
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: control.volumeColor
            }

            onClicked: AudioMixer.toggleMute(control.liveNodes)
            ToolTip.visible: hovered
            ToolTip.delay: 500
            ToolTip.text: control.muted ? "Unmute" : "Mute"

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }

        AudioVolumeSlider {
            width: parent.width - 40
            height: 28
            enabled: control.liveNodes.length > 0
            audioVolume: control.audioVolume
            maximumVolume: control.maximumVolume

            onVolumeRequested: function(volume) {
                AudioMixer.setVolume(control.liveNodes, volume, control.maximumVolume, !control.microphone)
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 18
        visible: control.subtitle.length > 0 && !control.showOutputButton
        text: control.subtitle
        textFormat: Text.PlainText
        elide: Text.ElideRight
        maximumLineCount: 1
        color: "#e2e5ed"
        font.pixelSize: 11
    }

    ToolButton {
        id: outputButton
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 22
        padding: 0
        visible: control.showOutputButton
        enabled: control.outputSelectionEnabled
        Accessible.name: "Choose audio output: " + control.subtitle

        background: Rectangle {
            radius: 5
            color: outputButton.hovered || outputButton.activeFocus ? "#10ffffff" : "transparent"
        }

        contentItem: Item {
            Text {
                anchors.left: parent.left
                anchors.right: arrow.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: control.subtitle
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: control.outputsExpanded || outputButton.activeFocus ? "#8aadf4" : "#e2e5ed"
                font.pixelSize: 11
            }

            Text {
                id: arrow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                text: control.outputsExpanded ? "▴" : "▾"
                horizontalAlignment: Text.AlignHCenter
                color: control.outputsExpanded || outputButton.hovered || outputButton.activeFocus
                    ? "#8aadf4" : "#e2e5ed"
                font.pixelSize: 14
            }
        }

        onClicked: control.outputToggleRequested()
        ToolTip.visible: hovered
        ToolTip.delay: 500
        ToolTip.text: control.outputsExpanded ? "Hide outputs" : "Choose audio output"

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }
}
