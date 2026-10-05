import QtQuick
import Quickshell
import Quickshell.Hyprland

PanelWindow {
    id: root

    anchors {
        top: true
        right: true
    }

    margins {
        top: 32
        right: 10
    }

    implicitWidth: 170
    implicitHeight: 188

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

    Keys.onEscapePressed: {
        Qt.quit()
    }

    Rectangle {
        anchors.fill: parent

        radius: 10

        color: "#59080808"

        border.width: 1
        border.color: "#18ffffff"

        Column {
            anchors.fill: parent
            anchors.margins: 6

            spacing: 2

            Repeater {
                model: [
                    { label: "Suspend", command: "systemctl suspend" },
                    { label: "Logout", command: "loginctl terminate-user $USER" },
                    { label: "Reboot", command: "systemctl reboot" },
                    { label: "Shutdown", command: "systemctl poweroff" }
                ]

                delegate: Rectangle {
                    width: parent.width
                    height: 40

                    radius: 7

                    color: mouseArea.containsMouse
                        ? "#12ffffff"
                        : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter

                        text: modelData.label

                        color: "#ffffff"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: mouseArea

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            Quickshell.execDetached([
                                "sh",
                                "-c",
                                modelData.command
                            ])

                            Qt.quit()
                        }
                    }
                }
            }
        }
    }
}
