import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import "bt-data.js" as Data

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
        color: "#73080808"
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

            // Header (Título y Switch)
            Row {
                width: parent.width
                spacing: 12

                Text {
                    text: "󰂯"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 18
                    color: Data.isPowered ? "#8aadf4" : "#6c7086"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Bluetooth"
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 90
                }
                
                // Toggle simple para encender/apagar
                Rectangle {
                    width: 36
                    height: 20
                    radius: 10
                    color: Data.isPowered ? "#8aadf4" : "#313244"
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: Data.isPowered ? parent.width - width - 2 : 2
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            Quickshell.execDetached(["sh", "-c", "~/.local/bin/bt-manager toggle"])
                            Qt.quit()
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#20ffffff" }

            // Lista de Dispositivos (Solo si está encendido)
            Repeater {
                model: Data.devices
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
                            color: modelData.state === "Connected" ? "#8aadf4" : "#a6adc8"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: modelData.name
                                color: "#ffffff"
                                font.pixelSize: 13
                            }
                            Text {
                                text: modelData.state
                                color: "#a6adc8"
                                font.pixelSize: 11
                            }
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.state === "Connected") {
                                Quickshell.execDetached(["bluetoothctl", "disconnect", modelData.mac])
                            } else {
                                Quickshell.execDetached(["bluetoothctl", "connect", modelData.mac])
                            }
                            Qt.quit()
                        }
                    }
                }
            }

            // Mensaje vacío
            Text {
                visible: Data.devices.length === 0
                text: Data.isPowered ? "No saved devices" : "Bluetooth off"
                color: "#a6adc8"
                font.pixelSize: 13
                anchors.horizontalCenter: parent.horizontalCenter
                padding: 10
            }

            // Botón para emparejar/buscar (Abre terminal)
            Rectangle {
                width: parent.width
                height: 36
                radius: 8
                color: scanMouseArea.containsMouse ? "#12ffffff" : "transparent"
                visible: Data.isPowered
                
                Text {
                    text: "󰑄 Scan for devices..."
                    color: "#a6adc8"
                    font.pixelSize: 12
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: scanMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        Quickshell.execDetached(["blueman-manager"])
                        Qt.quit()
                    }
                }
            }
        }
    }
}
