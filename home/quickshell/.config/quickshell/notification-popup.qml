import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

WaybarPopup {
    id: root

    preferredPopupWidth: 360
    preferredPopupHeight: Math.min(content.implicitHeight + 28, 500)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true

    property var notifications: []
    property bool loading: true

    HyprlandFocusGrab {
        windows: [root]
        active: true
        onCleared: Qt.quit()
    }

    Process {
        id: dunstHistory
        command: ["dunstctl", "history"]
        running: true
        
        stdout: StdioCollector {
            id: historyCollector
        }
        
        onExited: {
            try {
                const json = JSON.parse(historyCollector.text);
                const notifs = json.data[0] || [];
                
                root.notifications = notifs.map(n => ({
                    id: n.id?.data || 0,
                    appname: n.appname?.data || "System",
                    summary: n.summary?.data || "",
                    body: (n.body?.data || "").replace(/<[^>]*>?/gm, ''),
                    timestamp: n.timestamp?.data || 0
                })).filter(n => {
                    const app = n.appname.toLowerCase();
                    const sum = n.summary;
                    
                    // 1. Filtro Multimedia Universal (Atrapa Glassymusic, Spotify, VLC, etc.)
                    if (app.includes("music") || app.includes("spotify") || app.includes("vlc") || app.includes("mpv") || app.includes("playerctl")) return false;
                    
                    // 2. Ignorar notificaciones utilitarias y efímeras
                    if (sum === "Wallpaper" || sum === "Screenshot" || sum === "Power profile") return false;
                    
                    return true;
                });
            } catch(e) {}
            root.loading = false;
        }
    }

    function clearHistory() {
        Quickshell.execDetached(["dunstctl", "history-clear"]);
        root.notifications = [];
    }

    function closeNotification(id) {
        Quickshell.execDetached(["dunstctl", "history-rm", id.toString()]);
        root.notifications = root.notifications.filter(n => n.id !== id);
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

            Row {
                width: parent.width
                height: 32
                Text {
                    text: "󰂚"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 18
                    color: "#89b4fa"
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                }
                Text {
                    text: "Notifications"
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 68
                }
                ToolButton {
                    width: 40
                    height: 32
                    padding: 0
                    visible: root.notifications.length > 0
                    background: null
                    contentItem: Text {
                        text: "󰎟"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 16
                        color: parent.hovered ? "#f38ba8" : "#a1a1aa"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: root.clearHistory()
                    ToolTip.text: "Clear all"
                    ToolTip.visible: hovered
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#20ffffff" }

            Text {
                visible: root.loading
                text: "Loading history..."
                color: "#a1a1aa"
                font.pixelSize: 13
                anchors.horizontalCenter: parent.horizontalCenter
                padding: 10
            }

            Text {
                visible: !root.loading && root.notifications.length === 0
                text: "No new notifications"
                color: "#a1a1aa"
                font.pixelSize: 13
                anchors.horizontalCenter: parent.horizontalCenter
                padding: 10
            }

            ListView {
                width: parent.width
                height: Math.min(contentItem.childrenRect.height, 420)
                visible: root.notifications.length > 0
                model: root.notifications
                spacing: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    width: ListView.view.width
                    height: col.implicitHeight + 20
                    radius: 8
                    color: mouseArea.containsMouse ? "#12ffffff" : "#08ffffff"
                    border.width: 1
                    border.color: "#10ffffff"

                    Column {
                        id: col
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        spacing: 4

                        Row {
                            width: parent.width
                            Text {
                                text: modelData.appname
                                color: "#a1a1aa"
                                font.pixelSize: 11
                                width: parent.width - 24
                                elide: Text.ElideRight
                            }
                            Text {
                                text: "󰅖"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 14
                                color: closeArea.containsMouse ? "#f38ba8" : "#6c7086"
                                MouseArea {
                                    id: closeArea
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    hoverEnabled: true
                                    onClicked: root.closeNotification(modelData.id)
                                }
                            }
                        }
                        Text {
                            text: modelData.summary
                            color: "#ffffff"
                            font.pixelSize: 13
                            font.bold: true
                            width: parent.width
                            wrapMode: Text.Wrap
                        }
                        Text {
                            visible: modelData.body !== ""
                            text: modelData.body
                            color: "#d4d4d8"
                            font.pixelSize: 12
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                    }
                }
            }
        }
    }
}
