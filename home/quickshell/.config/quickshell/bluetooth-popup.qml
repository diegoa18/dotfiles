import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

WaybarPopup {
    id: root

    preferredPopupWidth: 280
    preferredPopupHeight: content.implicitHeight + 28
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true

    property var state: ({ powered: false, devices: [] })

    function send(req) {
        if (backend.running) {
            backend.write(JSON.stringify(req) + "\n")
        }
    }

    HyprlandFocusGrab {
        windows: [root]
        active: true
        onCleared: Qt.quit()
    }

    Process {
        id: backend
        command: [
            "/usr/bin/env", "LANG=C.UTF-8", "LC_ALL=C.UTF-8",
            "/usr/bin/python3", "-I",
            Quickshell.env("HOME") + "/.local/bin/bluetooth-popup-service"
        ]
        stdinEnabled: true
        running: true

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.state = JSON.parse(data)
                } catch (error) {}
            }
        }
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

            // Header
            Row {
                width: parent.width
                spacing: 12

                Text {
                    text: "󰂯"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 18
                    color: root.state.powered ? "#89b4fa" : "#6c7086"
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

                // Toggle Switch Nativo
                Rectangle {
                    width: 36
                    height: 20
                    radius: 10
                    color: root.state.powered ? "#89b4fa" : "#313244"
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.state.powered ? parent.width - width - 2 : 2
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.send({action: "toggle"})
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#20ffffff" }

            // Devices
            Repeater {
                model: root.state.devices
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
                            text: modelData.connected ? "󰂱" : "󰂯"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 16
                            color: modelData.connected ? "#89b4fa" : "#a1a1aa"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40
                            Text {
                                text: modelData.name
                                color: "#ffffff"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: modelData.connected && modelData.battery !== null
                                      ? "Connected · " + modelData.battery + "%"
                                      : modelData.connected ? "Connected"
                                      : modelData.paired ? "Paired" : "Available"
                                color: "#a1a1aa"
                                font.pixelSize: 11
                            }
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.send({
                                action: modelData.connected ? "disconnect" : "connect",
                                path: modelData.path
                            })
                        }
                    }
                }
            }

            Text {
                visible: root.state.devices.length === 0
                text: root.state.powered ? "No saved devices" : "Bluetooth off"
                color: "#a1a1aa"
                font.pixelSize: 13
                anchors.horizontalCenter: parent.horizontalCenter
                padding: 10
            }

            // Blueman Fallback para emparejamientos complejos
            Rectangle {
                width: parent.width
                height: 36
                radius: 8
                color: scanMouseArea.containsMouse ? "#12ffffff" : "transparent"
                visible: root.state.powered

                Text {
                    text: "󰒓 Settings..."
                    color: "#a1a1aa"
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
