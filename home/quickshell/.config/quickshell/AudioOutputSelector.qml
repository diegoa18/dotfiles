import QtQuick
import QtQuick.Controls
import "AudioMixer.js" as AudioMixer

Column {
    id: selector

    property var nodes: []
    property var selectedNode: null
    property real maximumListHeight: 180
    signal outputSelected(var node)

    spacing: 6

    Text {
        width: parent.width
        text: "Output device"
        color: "#ffffff"
        font.pixelSize: 13
        font.weight: Font.Medium
    }

    ScrollView {
        id: outputsView
        width: parent.width
        height: Math.min(outputsContent.implicitHeight, Math.max(0, selector.maximumListHeight))
        clip: true
        contentWidth: availableWidth
        contentHeight: outputsContent.implicitHeight
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Column {
            id: outputsContent
            width: outputsView.availableWidth
            spacing: 4

            Repeater {
                model: selector.nodes

                delegate: ToolButton {
                    id: output
                    required property var modelData
                    readonly property bool current: selector.selectedNode === modelData
                    width: outputsContent.width
                    height: Math.max(36, label.implicitHeight + 16)
                    leftPadding: 8
                    rightPadding: 8
                    topPadding: 8
                    bottomPadding: 8
                    enabled: selector.enabled && modelData !== null && modelData.ready
                    Accessible.name: AudioMixer.outputLabel(modelData)
                        + (current ? " · Current output" : "")

                    background: Rectangle {
                        radius: 7
                        color: output.current ? "#188aadf4"
                            : output.hovered || output.activeFocus ? "#18ffffff" : "transparent"
                    }

                    contentItem: Item {
                        Text {
                            id: label
                            anchors.left: parent.left
                            anchors.right: check.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: AudioMixer.outputLabel(output.modelData)
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            color: !output.enabled ? "#b9c0cc"
                                : output.current ? "#8aadf4" : "#ffffff"
                            font.pixelSize: 12
                        }

                        Text {
                            id: check
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            text: output.current ? "✓" : ""
                            color: "#8aadf4"
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    onClicked: selector.outputSelected(modelData)
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: current ? "Current output" : "Set as default output"

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            Text {
                visible: selector.nodes.length === 0
                width: parent.width
                text: selector.enabled ? "No audio outputs" : "Loading audio…"
                color: "#e2e5ed"
                font.pixelSize: 12
            }
        }
    }
}
