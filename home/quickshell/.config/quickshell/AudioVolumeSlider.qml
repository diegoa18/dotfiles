import QtQuick
import QtQuick.Controls

Slider {
    id: slider

    property real audioVolume: 0
    property real maximumVolume: 1.5
    signal volumeRequested(real volume)

    implicitHeight: 28
    from: 0
    to: maximumVolume
    stepSize: 0.01
    snapMode: Slider.SnapAlways

    readonly property real knobSize: 14
    readonly property int captureBand: 2
    readonly property int releaseBand: 4
    property bool detentEngaged: false
    property bool keyboardInteraction: false

    function syncFromAudio() {
        value = Math.max(from, Math.min(to, audioVolume))
    }

    function adjustedVolume(candidate) {
        let percent = Math.max(0, Math.min(Math.round(to * 100), Math.round(candidate * 100)))

        if (slider.pressed && !slider.keyboardInteraction) {
            const distance = Math.abs(percent - 100)

            if (slider.detentEngaged && distance > slider.releaseBand)
                slider.detentEngaged = false

            if (!slider.detentEngaged && distance <= slider.captureBand)
                slider.detentEngaged = true

            if (slider.detentEngaged)
                percent = 100
        }

        return percent / 100
    }

    Component.onCompleted: syncFromAudio()

    onAudioVolumeChanged: {
        if (!pressed)
            syncFromAudio()
    }

    onEnabledChanged: {
        if (!pressed)
            syncFromAudio()
    }

    onPressedChanged: {
        if (!pressed) {
            detentEngaged = false
            keyboardInteraction = false
            syncFromAudio()
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
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
        const next = adjustedVolume(value)
        value = next
        volumeRequested(next)
    }

    background: Item {
        id: track

        x: slider.leftPadding + slider.knobSize / 2
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: Math.max(0, slider.availableWidth - slider.knobSize)
        height: 4

        readonly property real hundredPosition: width / slider.to

        Rectangle {
            anchors.fill: parent
            radius: 2
            color: "#20ffffff"
        }

        Rectangle {
            width: Math.min(slider.value, 1) / slider.to * track.width
            height: track.height
            radius: 2
            color: slider.enabled ? "#8aadf4" : "#408aadf4"
        }

        Rectangle {
            x: track.hundredPosition
            width: Math.max(0, slider.value - 1) / slider.to * track.width
            height: track.height
            radius: 2
            color: "#ed8796"
        }

        Rectangle {
            x: track.hundredPosition - width / 2
            y: -3
            width: 1
            height: 10
            color: "#70ffffff"
        }
    }

    handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.knobSize
        height: slider.knobSize
        radius: width / 2
        color: !slider.enabled ? "#8a8a8a" : slider.value > 1 ? "#ed8796" : "#ffffff"
        border.width: 1
        border.color: "#30000000"
    }
}
