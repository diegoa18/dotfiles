import QtQuick
import Quickshell
import Quickshell.Hyprland

WaybarPopup {
    id: root

    preferredPopupWidth: 320
    preferredPopupHeight: 300

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

    property date displayedDate: new Date()

    function monthName(month) {
        const months = [
            "January", "February", "March", "April",
            "May", "June", "July", "August",
            "September", "October", "November", "December"
        ]

        return months[month]
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate()
    }

    function firstDay(year, month) {
        return (new Date(year, month, 1).getDay() + 6) % 7
    }

    function previousMonth() {
        displayedDate = new Date(
            displayedDate.getFullYear(),
            displayedDate.getMonth() - 1,
            1
        )
    }

    function nextMonth() {
        displayedDate = new Date(
            displayedDate.getFullYear(),
            displayedDate.getMonth() + 1,
            1
        )
    }

    function today() {
        displayedDate = new Date()
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
            anchors.margins: 12
            spacing: 10

            Row {
                width: parent.width
                height: 32

                Text {
                    width: 32
                    height: parent.height

                    text: "‹"

                    color: "#ffffff"
                    font.pixelSize: 24

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    MouseArea {
                        anchors.fill: parent

                        onClicked: {
                            root.previousMonth()
                        }
                    }
                }

                Text {
                    width: parent.width - 64
                    height: parent.height

                    text:
                        root.monthName(root.displayedDate.getMonth())
                        + " "
                        + root.displayedDate.getFullYear()

                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    width: 32
                    height: parent.height

                    text: "›"

                    color: "#ffffff"
                    font.pixelSize: 24

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    MouseArea {
                        anchors.fill: parent

                        onClicked: {
                            root.nextMonth()
                        }
                    }
                }
            }

            Grid {
                width: parent.width
                columns: 7
                rows: 1

                Repeater {
                    model: [
                        "Su", "Mo", "Tu", "We", "Th",
                        "Fr", "Sa"
                    ]

                    delegate: Text {
                        width: parent.width / 7
                        height: 24

                        text: modelData

                        color: "#e2e5ed"
                        font.pixelSize: 11

                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Grid {
                id: calendarGrid

                width: parent.width
                height: 175

                columns: 7
                rows: 6

                property int days:
                    root.daysInMonth(
                        root.displayedDate.getFullYear(),
                        root.displayedDate.getMonth()
                    )

                property int start:
                    root.firstDay(
                        root.displayedDate.getFullYear(),
                        root.displayedDate.getMonth()
                    )

                Repeater {
                    model: 42

                    delegate: Rectangle {
                        width: calendarGrid.width / 7
                        height: calendarGrid.height / 6

                        radius: 7

                        property int dayIndex:
                            index - calendarGrid.start

                        property bool validDay:
                            dayIndex >= 1 &&
                            dayIndex <= calendarGrid.days

                        property bool isToday:
                            validDay &&
                            dayIndex === new Date().getDate() &&
                            root.displayedDate.getMonth() === new Date().getMonth() &&
                            root.displayedDate.getFullYear() === new Date().getFullYear()

                        color: mouseArea.containsMouse
                            ? "#0fffffff"
                            : isToday
                                ? "#148aadf4"
                                : "transparent"

                        Text {
                            anchors.fill: parent

                            text: validDay ? dayIndex : ""

                            color: isToday
                                ? "#8aadf4"
                                : "#ffffff"

                            font.pixelSize: 12

                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            id: mouseArea

                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }

            Text {
                width: parent.width
                height: 20

                text: "Esc to close"

                color: "#e2e5ed"
                font.pixelSize: 9

                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
