import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "AudioMixer.js" as AudioMixer

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

    property bool mixerExpanded: false
    property bool outputsExpanded: false
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var playbackNodes: AudioMixer.playbackNodes(Pipewire.nodes.values)
    readonly property var outputNodes: AudioMixer.outputNodes(Pipewire.nodes.values)
    readonly property var applicationGroups: mixerExpanded
        ? AudioMixer.applicationGroups(playbackNodes) : []
    readonly property var availableScreen: root.screen ?? Quickshell.screens[0] ?? null
    readonly property real maximumHeight: availableScreen
        ? Math.max(1, availableScreen.height - 64) : Number.POSITIVE_INFINITY

    implicitWidth: 300
    implicitHeight: Math.ceil(Math.min(maximumHeight, content.implicitHeight + 32))
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true

    function selectOutput(node) {
        if (!Pipewire.ready || !node || !node.ready || root.outputNodes.indexOf(node) === -1)
            return

        Pipewire.preferredDefaultAudioSink = node
        root.outputsExpanded = false
    }

    HyprlandFocusGrab {
        windows: [root]
        active: true
        onCleared: Qt.quit()
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
            .concat(root.mixerExpanded ? root.playbackNodes : [])
            .concat(root.outputsExpanded ? root.outputNodes : [])
            .filter(function(node, index, nodes) {
                return node && nodes.indexOf(node) === index
            })
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "#59080808"
        clip: true
        focus: true
        border.width: 1
        border.color: "#20ffffff"

        Keys.onEscapePressed: Qt.quit()

        Flickable {
            id: viewport
            anchors.fill: parent
            anchors.margins: 16
            contentWidth: width
            contentHeight: content.implicitHeight
            interactive: contentHeight > height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: content
                width: viewport.width
                spacing: 12

                AudioMixerRow {
                    id: outputControl
                    width: parent.width
                    title: "Audio"
                    titlePixelSize: 15
                    nodes: root.sink ? [root.sink] : []
                    subtitle: root.sink
                        ? AudioMixer.outputLabel(root.sink)
                        : Pipewire.ready ? "No audio output" : "Loading audio…"
                    showOutputButton: true
                    outputsExpanded: root.outputsExpanded
                    outputSelectionEnabled: Pipewire.ready
                    onOutputToggleRequested: root.outputsExpanded = !root.outputsExpanded
                    showMixerButton: true
                    mixerExpanded: root.mixerExpanded
                    onMixerToggleRequested: root.mixerExpanded = !root.mixerExpanded
                }

                AudioOutputSelector {
                    visible: root.outputsExpanded
                    width: parent.width
                    nodes: root.outputNodes
                    selectedNode: root.sink
                    enabled: Pipewire.ready
                    onOutputSelected: function(node) { root.selectOutput(node) }
                }

                Column {
                    id: mixer
                    visible: root.mixerExpanded
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#20ffffff"
                    }

                    AudioMixerRow {
                        id: microphoneControl
                        width: parent.width
                        title: "Microphone"
                        microphone: true
                        nodes: root.source ? [root.source] : []
                        subtitle: root.source
                            ? root.source.description || root.source.name : "No microphone"
                    }

                    Text {
                        id: applicationsHeading
                        width: parent.width
                        height: 18
                        text: "Applications"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: "#ffffff"
                    }

                    ScrollView {
                        id: applicationsView
                        width: parent.width
                        height: Math.min(applicationsContent.implicitHeight, 216)
                        clip: true
                        contentWidth: availableWidth
                        contentHeight: applicationsContent.implicitHeight
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        Column {
                            id: applicationsContent
                            width: applicationsView.availableWidth
                            spacing: 12

                            Repeater {
                                model: root.applicationGroups

                                delegate: AudioMixerRow {
                                    required property var modelData
                                    width: applicationsContent.width
                                    title: modelData.label
                                    nodes: modelData.nodes
                                }
                            }

                            Text {
                                visible: root.applicationGroups.length === 0
                                width: parent.width
                                text: Pipewire.ready ? "No apps playing audio" : "Loading audio…"
                                textFormat: Text.PlainText
                                wrapMode: Text.WordWrap
                                color: "#a5adcb"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }
}
