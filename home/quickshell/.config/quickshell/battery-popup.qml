import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower

WaybarPopup {
    id: root

    readonly property var batteries: UPower.devices.values.filter(function(device) {
        return device && device.ready && device.isLaptopBattery && device.isPresent
    })
    readonly property var battery: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery
        && batteries.length > 0 ? UPower.displayDevice : batteries[0] ?? null
    readonly property int percentage: battery
        ? Math.round(Math.max(0, Math.min(1, battery.percentage)) * 100) : 0
    readonly property color chargeColor: !UPower.onBattery ? "#a6da95"
        : percentage <= 15 ? "#ed8796" : percentage <= 30 ? "#eed49f" : "#8aadf4"

    preferredPopupWidth: 320
    preferredPopupHeight: content.implicitHeight + 32
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true

    function duration(seconds) {
        if (!Number.isFinite(seconds) || seconds <= 0)
            return "Estimating…"
        const minutes = Math.max(1, Math.round(seconds / 60))
        const hours = Math.floor(minutes / 60)
        return hours > 0 ? hours + "h" + (minutes % 60 ? " " + minutes % 60 + "m" : "")
            : minutes + "m"
    }

    function stateLabel(state) {
        switch (state) {
        case UPowerDeviceState.Charging: return "Charging"
        case UPowerDeviceState.Discharging: return "Discharging"
        case UPowerDeviceState.FullyCharged: return "Fully charged"
        case UPowerDeviceState.Empty: return "Empty"
        case UPowerDeviceState.PendingCharge: return "Waiting to charge"
        case UPowerDeviceState.PendingDischarge: return "Waiting to discharge"
        default: return "Status unavailable"
        }
    }

    HyprlandFocusGrab {
        windows: [root]
        active: true
        onCleared: Qt.quit()
    }

    component InfoRow: Item {
        property string label: ""
        property string value: ""
        implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight)
        Text {
            id: labelText
            width: parent.width * 0.55
            text: parent.label
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: "#a5adcb"
            font.pixelSize: 12
        }
        Text {
            id: valueText
            anchors.right: parent.right
            width: parent.width * 0.43
            text: parent.value
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignRight
            color: "#ffffff"
            font.pixelSize: 12
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "#59080808"
        border.width: 1
        border.color: "#20ffffff"
        focus: true
        Keys.onEscapePressed: Qt.quit()

        Flickable {
            id: viewport
            anchors.fill: parent
            anchors.margins: 16
            contentWidth: width
            contentHeight: content.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: content
                width: viewport.width
                spacing: 14

                Row {
                    width: parent.width
                    height: 28
                    Text {
                        width: parent.width - chargeText.width
                        text: "Battery & power"
                        color: "#ffffff"
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        id: chargeText
                        text: root.battery ? root.percentage + "%" : "—"
                        color: root.chargeColor
                        font.pixelSize: 24
                        font.weight: Font.Medium
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 5
                    radius: 3
                    color: "#252525"
                    Rectangle {
                        width: parent.width * root.percentage / 100
                        height: parent.height
                        radius: parent.radius
                        color: root.chargeColor
                    }
                }

                Column {
                    width: parent.width
                    spacing: 9
                    InfoRow {
                        width: parent.width
                        label: "Power source"
                        value: UPower.onBattery ? "Battery" : "AC power"
                    }
                    InfoRow {
                        width: parent.width
                        label: "Status"
                        value: root.battery ? root.stateLabel(root.battery.state)
                            : UPower.displayDevice.ready ? "No battery detected" : "Loading…"
                    }
                    InfoRow {
                        width: parent.width
                        visible: root.battery && (root.battery.state === UPowerDeviceState.Charging
                            || root.battery.state === UPowerDeviceState.Discharging)
                        label: root.battery && root.battery.state === UPowerDeviceState.Charging
                            ? "Time to full" : "Time remaining"
                        value: root.battery ? root.duration(root.battery.state === UPowerDeviceState.Charging
                            ? root.battery.timeToFull : root.battery.timeToEmpty) : ""
                    }
                    InfoRow {
                        width: parent.width
                        visible: root.battery && Number.isFinite(root.battery.changeRate)
                            && Math.abs(root.battery.changeRate) > 0
                        label: root.battery && root.battery.state === UPowerDeviceState.Charging
                            ? "Charge rate" : "Power draw"
                        value: root.battery ? Math.abs(root.battery.changeRate).toFixed(1) + " W" : ""
                    }
                    Repeater {
                        model: root.batteries
                        delegate: InfoRow {
                            required property var modelData
                            width: content.width
                            visible: modelData.healthSupported && Number.isFinite(modelData.healthPercentage)
                            label: root.batteries.length > 1
                                ? "Health · " + (modelData.model || modelData.nativePath) : "Battery health"
                            value: modelData.healthPercentage.toFixed(1) + "%"
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#20ffffff" }

                Column {
                    width: parent.width
                    spacing: 7
                    Text {
                        text: "Power profile"
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: "#ffffff"
                    }
                    Repeater {
                        model: [
                            { label: "Power saver", hint: "Lower power consumption", profile: PowerProfile.PowerSaver },
                            { label: "Balanced", hint: "Performance and battery life", profile: PowerProfile.Balanced },
                            { label: "Performance", hint: "Maximum performance", profile: PowerProfile.Performance }
                        ]
                        delegate: ToolButton {
                            id: profileButton
                            required property var modelData
                            readonly property bool current: PowerProfiles.profile === modelData.profile
                            width: content.width
                            height: 48
                            padding: 8
                            visible: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                            Accessible.name: modelData.label + (current ? " · Active" : "")
                            background: Rectangle {
                                radius: 7
                                color: profileButton.current ? "#188aadf4"
                                    : profileButton.hovered || profileButton.activeFocus ? "#18ffffff" : "transparent"
                            }
                            contentItem: Item {
                                Column {
                                    width: parent.width - 24
                                    spacing: 3
                                    Text {
                                        text: profileButton.modelData.label
                                        font.pixelSize: 12
                                        color: profileButton.current ? "#8aadf4" : "#ffffff"
                                    }
                                    Text {
                                        text: profileButton.modelData.hint
                                        font.pixelSize: 11
                                        color: "#a5adcb"
                                    }
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: profileButton.current ? "✓" : ""
                                    color: "#8aadf4"
                                    font.pixelSize: 14
                                }
                            }
                            onClicked: PowerProfiles.profile = modelData.profile
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                    Text {
                        width: parent.width
                        visible: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
                        text: PowerProfiles.degradationReason === PerformanceDegradationReason.HighTemperature
                            ? "Performance limited by temperature"
                            : PowerProfiles.degradationReason === PerformanceDegradationReason.LapDetected
                            ? "Performance limited by lap detection" : "Performance is limited"
                        wrapMode: Text.WordWrap
                        color: "#eed49f"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
