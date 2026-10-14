import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import "bright-data.js" as Data

WaybarPopup {
    id: root

    preferredPopupWidth: 320
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
            spacing: 16

            Text {
                text: "Screen"
                color: "#ffffff"
                font.pixelSize: 15
                font.bold: true
                padding: 4
            }

            Rectangle { width: parent.width; height: 1; color: "#20ffffff" }

            Column {
                width: parent.width
                spacing: 8

                Row {
                    width: parent.width
                    Text {
                        text: "󰃠"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: "#89b4fa"
                        width: 24
                    }
                    Text {
                        text: "Brightness"
                        color: "#ffffff"
                        font.pixelSize: 13
                        width: parent.width - 60
                    }
                    Text {
                        text: Math.round(brightSlider.value) + "%"
                        color: "#a1a1aa"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignRight
                    }
                }

                Slider {
                    id: brightSlider
                    width: parent.width
                    from: 1
                    to: 100
                    value: Data.currentBrightness
                    stepSize: 1

                    background: Rectangle {
                        x: brightSlider.leftPadding
                        y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 6
                        width: brightSlider.availableWidth
                        height: implicitHeight
                        radius: 3
                        color: "#313244"

                        Rectangle {
                            width: brightSlider.visualPosition * parent.width
                            height: parent.height
                            color: "#89b4fa"
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: brightSlider.leftPadding + brightSlider.visualPosition * (brightSlider.availableWidth - width)
                        y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
                        implicitWidth: 16
                        implicitHeight: 16
                        radius: 8
                        color: brightSlider.pressed ? "#f0f0f0" : "#ffffff"
                    }

                    onMoved: {
                        Quickshell.execDetached(["sh", "-c", "~/.local/bin/screen-manager set-brightness " + Math.round(value)])
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8

                Row {
                    width: parent.width
                    Text {
                        text: nightSlider.value < 6000 ? "󰖔" : "󰖨"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: nightSlider.value < 6000 ? "#fab387" : "#89b4fa"
                        width: 24
                    }
                    Text {
                        text: "Night Light"
                        color: "#ffffff"
                        font.pixelSize: 13
                        width: parent.width - 70
                    }
                    Text {
                        text: nightSlider.value < 6400 ? Math.round(nightSlider.value) + "K" : "Off"
                        color: "#a1a1aa"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignRight
                    }
                }

                Slider {
                    id: nightSlider
                    width: parent.width
                    from: 3000
                    to: 6500
                    value: Data.currentNightTemp
                    stepSize: 100

                    background: Rectangle {
                        x: nightSlider.leftPadding
                        y: nightSlider.topPadding + nightSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 6
                        width: nightSlider.availableWidth
                        height: implicitHeight
                        radius: 3
                        
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#fab387" }
                            GradientStop { position: 1.0; color: "#89b4fa" }
                        }
                    }

                    handle: Rectangle {
                        x: nightSlider.leftPadding + nightSlider.visualPosition * (nightSlider.availableWidth - width)
                        y: nightSlider.topPadding + nightSlider.availableHeight / 2 - height / 2
                        implicitWidth: 16
                        implicitHeight: 16
                        radius: 8
                        color: nightSlider.pressed ? "#f0f0f0" : "#ffffff"
                        border.color: "#1e1e2e"
                        border.width: 2
                    }

                    onPressedChanged: {
                        if (!pressed) {
                            var temp = Math.round(value);
                            var action = (temp >= 6400) ? "off" : temp;
                            Quickshell.execDetached(["sh", "-c", "~/.local/bin/screen-manager set-nightlight " + action])
                        }
                    }
                }
            }
        }
    }
}
