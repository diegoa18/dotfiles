import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "FastfetchText.js" as FastfetchText

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
    }

    margins {
        top: 32
        left: 12
    }

    readonly property int padding: 16
    readonly property var availableScreen: root.screen ?? Quickshell.screens[0] ?? null
    readonly property real maximumWidth: availableScreen
        ? Math.max(1, availableScreen.width - 24)
        : consoleText.implicitWidth + padding * 2
    readonly property real maximumHeight: availableScreen
        ? Math.max(1, availableScreen.height - 64)
        : consoleText.implicitHeight + padding * 2

    implicitWidth: Math.ceil(Math.min(consoleText.implicitWidth + padding * 2, maximumWidth))
    implicitHeight: Math.ceil(Math.min(consoleText.implicitHeight + padding * 2, maximumHeight))

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true
    visible: !root.loading

    property bool loading: true
    property bool defaultsStarted: false
    property bool settingsStarted: false
    property bool fetchStarted: false
    property string defaultConfiguration: ""
    property var terminalSettings: FastfetchText.ghosttySettings("", "")
    property string output: FastfetchText.escapeHtml("Loading system information…")

    function showError(message) {
        root.output = FastfetchText.escapeHtml(message).replace(/\n/g, "<br>")
        root.loading = false
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.quit()
    }

    SystemPalette {
        id: systemPalette
        colorGroup: SystemPalette.Active
    }

    Process {
        id: defaultsProcess

        command: ["ghostty", "+show-config", "--default"]
        running: true
        onStarted: root.defaultsStarted = true

        stdout: StdioCollector {
            id: collectedDefaults
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 && exitStatus === 0)
                root.defaultConfiguration = collectedDefaults.text

            settingsProcess.running = true
        }

        onRunningChanged: {
            if (!running && !root.defaultsStarted)
                settingsProcess.running = true
        }
    }

    Process {
        id: settingsProcess

        command: ["ghostty", "+show-config", "--changes-only=false"]
        onStarted: root.settingsStarted = true

        stdout: StdioCollector {
            id: collectedSettings
        }

        onExited: function(exitCode, exitStatus) {
            const config = exitCode === 0 && exitStatus === 0 ? collectedSettings.text : ""
            root.terminalSettings = FastfetchText.ghosttySettings(config, root.defaultConfiguration)

            fetchProcess.running = true
        }

        onRunningChanged: {
            if (!running && !root.settingsStarted) {
                root.terminalSettings = FastfetchText.ghosttySettings("", root.defaultConfiguration)
                fetchProcess.running = true
            }
        }
    }

    Process {
        id: fetchProcess

        command: [
            "fastfetch",
            "--config", "none",
            "--pipe", "false",
            "--logo-type", "builtin",
            "--logo-position", "left",
            "--disable-linewrap", "false",
            "--hide-cursor", "false",
            "--structure",
            "Title:Separator:OS:Host:Kernel:Uptime:Shell:Display:WM:CPU:GPU:Memory:Swap:Disk"
        ]

        environment: ({ LC_ALL: "C.UTF-8" })

        onStarted: root.fetchStarted = true

        stdout: StdioCollector {
            id: collectedOutput
        }

        stderr: StdioCollector {
            id: collectedErrors
        }

        onExited: function(exitCode, exitStatus) {
            const foreground = String(consoleText.color)
            const result = FastfetchText.render(collectedOutput.text, root.terminalSettings, foreground)
            const errors = FastfetchText.render(collectedErrors.text, root.terminalSettings, foreground).plain

            if (exitCode === 0 && exitStatus === 0 && result.plain.length > 0) {
                root.output = result.styled
                root.loading = false
            } else {
                root.showError(errors.length > 0
                    ? "Fastfetch:\n" + errors
                    : "Unable to retrieve system information.")
            }
        }

        onRunningChanged: {
            if (!running && root.loading && !root.fetchStarted) {
                root.showError("Unable to start Fastfetch.")
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Qt.quit()

        radius: 10
        color: "#59080808"

        border.width: 1
        border.color: "#20ffffff"

        ScrollView {
            id: outputView

            anchors.fill: parent
            anchors.margins: root.padding

            clip: true
            contentWidth: consoleText.implicitWidth
            contentHeight: consoleText.implicitHeight

            ScrollBar.horizontal.policy: ScrollBar.AsNeeded
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Text {
                id: consoleText

                width: implicitWidth
                height: implicitHeight
                text: root.output
                textFormat: Text.StyledText
                wrapMode: Text.NoWrap

                font.family: root.terminalSettings.family || Qt.application.font.family
                font.pointSize: root.terminalSettings.pointSize > 0
                    ? root.terminalSettings.pointSize : Qt.application.font.pointSize

                color: root.terminalSettings.foreground || systemPalette.text
            }
        }
    }
}
