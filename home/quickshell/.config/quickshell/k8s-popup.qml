import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

WaybarPopup {
    id: root
    readonly property int padding: 16
    preferredPopupWidth: 320
    preferredPopupHeight: Math.min(layout.implicitHeight + padding * 2, 600)

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.quit()
    }

    property var contexts: []
    property var namespaces: []
    property string currentContext: "Cargando..."
    property string currentNamespace: "Cargando..."

    // Evaluamos ~ dinámicamente mediante la shell
    Process {
        id: loadData
        command: ["bash", "-c", "~/.local/bin/k8s-data"]
        running: true
        stdout: StdioCollector { id: dataOut }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                var parts = dataOut.text.trim().split("\n---\n");
                if (parts.length >= 4) {
                    root.currentContext = parts[0].trim() || "Ninguno";
                    root.currentNamespace = parts[1].trim() || "default";
                    
                    var ctxs = parts[2].trim().split("\n");
                    var nss = parts[3].trim().split("\n");
                    
                    root.contexts = ctxs.filter(function(e) { return e !== ""; });
                    root.namespaces = nss.filter(function(e) { return e !== ""; });
                }
            } else {
                root.currentContext = "Error de lectura";
                root.currentNamespace = "Error";
            }
        }
    }

    Process {
        id: execCommand
        property string cmd: ""
        command: ["bash", "-c", "export PATH=\"~/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH\"; " + cmd + " && pkill -RTMIN+8 waybar"]
        onExited: function() { Qt.quit(); }
    }

    Rectangle {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Qt.quit()
        
        radius: 10
        color: "#73080808"
        border.width: 1
        border.color: "#20ffffff"

        ScrollView {
            anchors.fill: parent
            anchors.margins: root.padding
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Column {
                id: layout
                width: parent.width
                spacing: 8

                Text {
                    text: "󱃾 Kubernetes"
                    font.pointSize: 12
                    font.bold: true
                    color: "#ffffff"
                    anchors.left: parent.left
                }

                Item { width: 1; height: 4 }
                Rectangle { width: parent.width; height: 1; color: "#40ffffff" }
                Item { width: 1; height: 4 }

                Text {
                    text: "󰒋 Clústeres"
                    font.pointSize: 10
                    color: "#a6adc8"
                }

                Repeater {
                    model: root.contexts
                    delegate: Rectangle {
                        width: parent.width
                        height: 32
                        radius: 6
                        color: mouseAreaCtx.containsMouse ? "#20ffffff" : "transparent"
                        
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            text: (modelData === root.currentContext ? "󰄬 " : "  ") + modelData
                            color: modelData === root.currentContext ? "#89b4fa" : "#ffffff"
                            font.bold: modelData === root.currentContext
                            font.pointSize: 10
                        }

                        MouseArea {
                            id: mouseAreaCtx
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                execCommand.cmd = "kubectl config use-context " + modelData;
                                execCommand.running = true;
                            }
                        }
                    }
                }

                Item { width: 1; height: 4 }
                Rectangle { width: parent.width; height: 1; color: "#40ffffff" }
                Item { width: 1; height: 4 }

                Text {
                    text: "󰋘 Namespaces (" + root.currentContext + ")"
                    font.pointSize: 10
                    color: "#a6adc8"
                }

                Repeater {
                    model: root.namespaces
                    delegate: Rectangle {
                        width: parent.width
                        height: 32
                        radius: 6
                        color: mouseAreaNs.containsMouse ? "#20ffffff" : "transparent"
                        
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            text: (modelData === root.currentNamespace ? "󰄬 " : "  ") + modelData
                            color: modelData === root.currentNamespace ? "#89b4fa" : "#ffffff"
                            font.bold: modelData === root.currentNamespace
                            font.pointSize: 10
                        }

                        MouseArea {
                            id: mouseAreaNs
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                execCommand.cmd = "kubectl config set-context --current --namespace=" + modelData;
                                execCommand.running = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
