import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

PanelWindow {
    id: root

    anchors { top: true; right: true }
    margins { top: 32; right: 60 }

    implicitWidth: 340
    implicitHeight: Math.min(content.implicitHeight + 28,
        root.screen ? Math.max(0, root.screen.height - 64) : Number.POSITIVE_INFINITY)

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true

    HyprlandFocusGrab {
        windows: [root]
        active: !root.busy
        onCleared: {
            if (!root.busy) {
                root.cancelPassword()
                Qt.quit()
            }
        }
    }

    property var state: ({
        running: false, wifiEnabled: false, wifiHardwareEnabled: false,
        hasWifi: false, keyringReady: false, devices: [], networks: [], busy: false, scanning: false
    })
    property bool loaded: false
    property bool waiting: false
    property bool operationBusy: false
    property string operation: ""
    property string error: ""
    property string notice: ""
    property bool detailsExpanded: false
    property var passwordTarget: null
    property var lastNetwork: null
    property var openNetworkTarget: null

    readonly property bool ready: root.loaded && root.state.running
    readonly property bool busy: root.waiting || root.operationBusy || root.state.busy
    readonly property var wifiDevices: root.state.devices.filter(device => device.kind === "wifi")
    readonly property var detailDevice: root.state.devices[0] || null

    function send(request) {
        if (!root.ready || !backend.running || root.busy)
            return
        root.error = ""
        root.notice = ""
        root.waiting = true
        backend.write(JSON.stringify(request) + "\n")
    }

    function connectNetwork(network, password) {
        root.lastNetwork = network
        const request = { action: "connect", device: network.device, ap: network.ap }
        if (password !== undefined)
            request.password = password
        root.send(request)
    }

    function selectNetwork(network) {
        root.openNetworkTarget = null
        root.cancelPassword()
        if (network.security === "Open") {
            root.openNetworkTarget = network
            return
        }
        if (!network.saved && network.needsPassword) {
            root.passwordTarget = network
            passwordField.text = ""
            Qt.callLater(() => passwordField.forceActiveFocus())
        } else {
            root.connectNetwork(network)
        }
    }

    function submitPassword() {
        if (!root.passwordTarget || !passwordField.text || root.busy)
            return
        root.connectNetwork(root.passwordTarget, passwordField.text)
        passwordField.text = ""
    }

    function cancelPassword() {
        passwordField.text = ""
        root.passwordTarget = null
    }

    function toggleDetails() {
        if (!root.ready || !backend.running)
            return
        root.detailsExpanded = !root.detailsExpanded
        backend.write(JSON.stringify({action: "details", enabled: root.detailsExpanded}) + "\n")
        if (!root.detailsExpanded) {
            root.state = Object.assign({}, root.state, {
                devices: root.state.devices.map(device => Object.assign({}, device, {
                    addresses: [], gateway: "", dns: []
                }))
            })
        }
    }

    function receive(packet) {
        if (packet.type === "state") {
            root.state = packet
            root.loaded = true
            if (!packet.running)
                root.error = "NetworkManager is not running."
            if (root.passwordTarget) {
                const current = packet.networks.find(network => network.key === root.passwordTarget.key)
                if (current && current.active)
                    root.cancelPassword()
                else if (current)
                    root.passwordTarget = current
            }
            if (root.lastNetwork && packet.networks.some(network =>
                    network.key === root.lastNetwork.key && network.active))
                root.lastNetwork = null
        } else if (packet.type === "operation") {
            root.operationBusy = packet.busy
            root.operation = packet.message
        } else if (packet.type === "ack") {
            root.waiting = false
        } else if (packet.type === "error") {
            root.waiting = false
            root.error = packet.message
            if (root.lastNetwork && root.lastNetwork.needsPassword) {
                root.passwordTarget = root.lastNetwork
                passwordField.text = ""
                root.lastNetwork = null
                Qt.callLater(() => passwordField.forceActiveFocus())
            }
        }
    }

    function copy(value) {
        if (!value)
            return
        copyProcess.exec(["wl-copy", "--", value])
        root.notice = "Copied to clipboard"
    }

    Process {
        id: backend
        command: [
            "/usr/bin/env", "LANG=C.UTF-8", "LC_ALL=C.UTF-8",
            "/usr/bin/python3", "-I",
            Quickshell.env("HOME") + "/.local/bin/network-popup-service"
        ]
        stdinEnabled: true
        running: true

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.receive(JSON.parse(data))
                } catch (error) {
                    root.error = "Could not read network state."
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.waiting = false
            root.operationBusy = false
            if (!root.error)
                root.error = "Network service stopped. Reopen the popup."
        }
    }

    Process { id: copyProcess }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "#59080808"
        border.width: 1
        border.color: "#20ffffff"

        focus: true
        Keys.onEscapePressed: {
            if (root.passwordTarget)
                root.cancelPassword()
            else
                Qt.quit()
        }

        Flickable {
            id: viewport
            anchors.fill: parent
            anchors.margins: 14
            contentWidth: width
            contentHeight: content.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: content
                width: viewport.width
                spacing: 12

                Row {
                    width: parent.width
                    height: 32
                    spacing: 8

                    Text {
                        width: parent.width - 80
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Network"
                        color: "#ffffff"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    ToolButton {
                        id: wifiToggle
                        width: 32
                        height: 32
                        padding: 0
                        background: null
                        hoverEnabled: true
                        enabled: root.ready && root.state.hasWifi
                            && root.state.wifiHardwareEnabled && !root.busy
                        Accessible.name: root.state.wifiEnabled ? "Disable Wi-Fi" : "Enable Wi-Fi"

                        contentItem: Item {
                            Rectangle {
                                anchors.centerIn: parent
                                width: 30
                                height: 16
                                radius: 8
                                color: root.state.wifiEnabled ? "#8aadf4" : "#505050"
                                opacity: wifiToggle.enabled ? 1 : 0.4

                                Rectangle {
                                    x: root.state.wifiEnabled ? 16 : 2
                                    y: 2
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: "#ffffff"
                                }
                            }
                        }

                        ToolTip.visible: hovered
                        ToolTip.text: Accessible.name
                        ToolTip.delay: 400
                        onClicked: {
                            root.cancelPassword()
                            root.send({ action: "wifi", enabled: !root.state.wifiEnabled })
                        }
                    }

                    IconButton {
                        glyph: "\uf021"
                        hint: "Refresh networks"
                        enabled: root.ready && root.state.wifiEnabled && !root.busy && root.wifiDevices.length > 0
                        onClicked: root.send({ action: "scan", device: root.wifiDevices[0].path })
                    }
                }

                Repeater {
                    model: root.state.devices

                    delegate: Column {
                        required property var modelData
                        width: content.width
                        spacing: 4

                        Row {
                            width: parent.width
                            spacing: 8

                            Text {
                                width: 24
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.kind === "wifi" ? "\uf1eb" : "\udb80\ude00"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 18
                                color: modelData.connected ? "#8aadf4" : "#8a8a8a"
                            }

                            Column {
                                width: parent.width - 72
                                spacing: 3

                                Text {
                                    width: parent.width
                                    text: modelData.title
                                    textFormat: Text.PlainText
                                    color: "#ffffff"
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.state + " · " + modelData.interface
                                        + (modelData.signal !== null ? " · " + modelData.signal + "%" : "")
                                    textFormat: Text.PlainText
                                    color: "#8a8a8a"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            IconButton {
                                glyph: modelData.canDisconnect ? "\uf127" : "\uf0c1"
                                hint: modelData.canDisconnect ? "Disconnect" : "Connect"
                                visible: modelData.canDisconnect || modelData.canConnect
                                enabled: root.ready && !root.busy
                                onClicked: root.send({
                                    action: modelData.canDisconnect ? "disconnect" : "connect",
                                    device: modelData.path
                                })
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: !root.ready || !root.state.wifiEnabled || !root.state.wifiHardwareEnabled
                        || root.state.networks.length === 0
                    text: !root.loaded ? "Loading network state…"
                        : !root.state.running ? "NetworkManager unavailable"
                        : !root.state.hasWifi ? "No Wi-Fi adapter available"
                        : !root.state.wifiHardwareEnabled ? "Wi-Fi is blocked by the hardware switch"
                        : !root.state.wifiEnabled ? "Wi-Fi is off"
                        : root.state.scanning ? "Scanning…" : "No visible Wi-Fi networks"
                    wrapMode: Text.Wrap
                    color: "#8a8a8a"
                    font.pixelSize: 12
                }

                ListView {
                    id: networkList
                    width: parent.width
                    height: Math.min(root.state.networks.length * 56, 280)
                    visible: height > 0
                    model: root.state.networks
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: ToolButton {
                        id: networkButton
                        required property var modelData
                        width: networkList.width
                        height: 56
                        padding: 6
                        hoverEnabled: true
                        enabled: root.ready && !root.busy && modelData.canConnect && !modelData.active
                        Accessible.name: modelData.ssid

                        background: Rectangle {
                            color: networkButton.hovered || networkButton.activeFocus ? "#12ffffff" : "transparent"
                            radius: 6
                        }

                        contentItem: Row {
                            spacing: 8

                            Text {
                                width: 24
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\uf1eb"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 16
                                color: modelData.active ? "#8aadf4" : "#ffffff"
                            }

                            Column {
                                width: parent.width - 104
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    width: parent.width
                                    text: modelData.ssid
                                    textFormat: Text.PlainText
                                    font.pixelSize: 13
                                    color: modelData.active ? "#8aadf4" : "#ffffff"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.active ? "Connected"
                                        : modelData.saved ? "Saved · " + modelData.security
                                        : modelData.security
                                    color: "#8a8a8a"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                width: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.security === "Open" ? "" : "\uf023"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 11
                                color: "#8a8a8a"
                            }

                            Text {
                                width: 40
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.signal + "%"
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: 11
                                color: "#8a8a8a"
                            }
                        }

                        onClicked: root.selectNetwork(modelData)
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: root.openNetworkTarget !== null

                    Text {
                        width: parent.width
                        text: "This Wi-Fi network does not encrypt traffic. Connect anyway?"
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: "#ed8796"
                        font.pixelSize: 12
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 8
                        ActionButton {
                            text: "Cancel"
                            onClicked: root.openNetworkTarget = null
                        }
                        ActionButton {
                            text: "Connect"
                            enabled: !root.busy
                            onClicked: {
                                root.connectNetwork(root.openNetworkTarget)
                                root.openNetworkTarget = null
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    visible: root.passwordTarget !== null
                    spacing: 8

                    Text {
                        width: parent.width
                        text: root.passwordTarget ? "Password for " + root.passwordTarget.ssid : ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: "#ffffff"
                        font.pixelSize: 12
                    }

                    TextField {
                        id: passwordField
                        width: parent.width
                        echoMode: TextInput.Password
                        maximumLength: 256
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhHiddenText
                        placeholderText: "Password"
                        color: "#ffffff"
                        placeholderTextColor: "#8a8a8a"
                        font.pixelSize: 13
                        enabled: !root.busy
                        selectByMouse: false
                        onEnabledChanged: {
                            if (enabled && root.passwordTarget)
                                Qt.callLater(() => passwordField.forceActiveFocus())
                        }

                        background: Rectangle {
                            color: "#30000000"
                            radius: 6
                            border.width: 1
                            border.color: passwordField.activeFocus ? "#8aadf4" : "#20ffffff"
                        }

                        onAccepted: root.submitPassword()
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 8

                        ActionButton {
                            text: "Cancel"
                            enabled: !root.busy
                            onClicked: root.cancelPassword()
                        }

                        ActionButton {
                            text: "Connect"
                            enabled: !root.busy && root.state.keyringReady && passwordField.text.length > 0
                            onClicked: root.submitPassword()
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.state.networks.some(network => !network.canConnect)
                    text: "Enterprise and legacy WPA/WEP networks require a configured profile."
                    color: "#8a8a8a"
                    wrapMode: Text.Wrap
                    font.pixelSize: 11
                }

                Text {
                    width: parent.width
                    visible: root.operation !== "" || root.error !== "" || root.notice !== ""
                    text: root.error || root.operation || root.notice
                    textFormat: Text.PlainText
                    color: root.error ? "#ed8796" : "#8aadf4"
                    wrapMode: Text.Wrap
                    font.pixelSize: 12
                }

                ActionButton {
                    width: parent.width
                    visible: root.detailDevice !== null
                    text: root.detailsExpanded ? "Hide details" : "Show details"
                    enabled: root.ready && !root.busy
                    onClicked: root.toggleDetails()
                }

                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.detailsExpanded && root.detailDevice !== null

                    DetailRow { label: "Interface"; value: root.detailDevice ? root.detailDevice.interface : "" }
                    Repeater {
                        model: root.detailDevice ? root.detailDevice.addresses : []
                        delegate: DetailRow {
                            required property string modelData
                            label: modelData.indexOf(":") !== -1 ? "IPv6" : "IPv4"
                            value: modelData
                            copyValue: modelData.split("/")[0]
                        }
                    }
                    DetailRow { label: "Gateway"; value: root.detailDevice ? root.detailDevice.gateway : "" }
                    DetailRow { label: "DNS"; value: root.detailDevice ? root.detailDevice.dns.join("\n") : "" }
                    DetailRow { label: "Security"; value: root.detailDevice ? root.detailDevice.security : "" }
                    ActionButton {
                        width: parent.width
                        visible: root.detailDevice !== null && root.detailDevice.canSecurePassword === true
                        text: "Move saved password to keyring"
                        enabled: root.ready && root.state.keyringReady && !root.busy
                        onClicked: root.send({action: "secure", device: root.detailDevice.path})
                    }
                    DetailRow {
                        label: "Frequency"
                        value: root.detailDevice && root.detailDevice.frequency
                            ? (root.detailDevice.frequency / 1000).toFixed(3) + " GHz" : ""
                    }
                }
            }
        }
    }

    component IconButton: ToolButton {
        id: control
        required property string glyph
        required property string hint
        implicitWidth: 32
        implicitHeight: 32
        padding: 0
        background: null
        hoverEnabled: true
        Accessible.name: control.hint
        contentItem: Text {
            text: control.glyph
            font.family: "Symbols Nerd Font"
            font.pixelSize: 16
            color: !control.enabled ? "#505050" : control.hovered || control.activeFocus ? "#8aadf4" : "#ffffff"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        ToolTip.visible: control.hovered
        ToolTip.text: control.hint
        ToolTip.delay: 400
    }

    component ActionButton: ToolButton {
        id: control
        background: null
        hoverEnabled: true
        contentItem: Text {
            text: control.text
            font.pixelSize: 12
            color: !control.enabled ? "#505050" : control.hovered || control.activeFocus ? "#8aadf4" : "#ffffff"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    component DetailRow: ToolButton {
        id: control
        required property string label
        required property string value
        property string copyValue: control.value
        width: parent.width
        padding: 0
        background: null
        hoverEnabled: true
        visible: control.value !== ""
        Accessible.name: control.label + ": " + control.value
        contentItem: Row {
            spacing: 8
            Text {
                width: 72
                text: control.label
                color: "#8a8a8a"
                font.pixelSize: 11
            }
            Text {
                width: parent.width - 80
                text: control.value
                textFormat: Text.PlainText
                color: control.hovered || control.activeFocus ? "#8aadf4" : "#ffffff"
                font.pixelSize: 11
                wrapMode: Text.WrapAnywhere
            }
        }
        ToolTip.visible: control.hovered
        ToolTip.text: "Copy " + control.label.toLowerCase()
        ToolTip.delay: 400
        onClicked: root.copy(control.copyValue)
    }
}
