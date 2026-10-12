import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland

WaybarPopup {
    id: root

    preferredPopupWidth: 280
    preferredPopupHeight: content.implicitHeight + 28
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true

    HyprlandFocusGrab {
        windows: [root]
        active: true
        onCleared: Qt.quit()
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "#59080808"
        border.width: 1
        border.color: "#20ffffff"

        focus: true
        Keys.onEscapePressed: Qt.quit()

        Column {
            id: content
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 14
            spacing: 8

            Text {
                text: "Control Center"
                color: "#ffffff"
                font.pixelSize: 15
                font.bold: true
                padding: 4
            }

            Rectangle { width: parent.width; height: 1; color: "#20ffffff" }

            Repeater {
                model: [
                    { name: "Network", module: "network", icon: "\uf1eb", action: "network-popup" },
                    { name: "Audio", module: "pulseaudio", icon: "\uf028", action: "audio-popup" },
                    { name: "Battery", module: "battery", icon: "\uf240", action: "battery-popup" }
                ]

                delegate: Rectangle {
                    width: parent.width
                    height: 48
                    radius: 8
                    color: mouseArea.containsMouse ? "#12ffffff" : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Text {
                            text: modelData.icon
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                            color: "#8aadf4"
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24
                        }

                        Text {
                            text: modelData.name
                            color: "#ffffff"
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80
                        }
                    }

                    // Botón de Anclaje (Pin)
                    ToolButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 40
                        background: null
                        
                        contentItem: Text {
                            text: "󰐃"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                            color: parent.hovered ? "#8aadf4" : "#e2e5ed"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            Quickshell.execDetached(["sh", "-c", "~/.local/bin/waybar-pin toggle " + modelData.module])
                        }
                    }

                    // Área clickeable para abrir el popup (Ignora el área del botón Pin)
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        anchors.rightMargin: 40 
                        hoverEnabled: true
                        onClicked: {
                            Quickshell.execDetached(["sh", "-c", "~/.local/bin/" + modelData.action])
                            Qt.quit()
                        }
                    }
                }
            }
        }
    }
}
