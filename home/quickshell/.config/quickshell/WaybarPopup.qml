import QtQuick
import Quickshell
import "PopupPosition.js" as PopupPosition

PanelWindow {
    id: popup

    property real preferredPopupWidth: 300
    property real preferredPopupHeight: 200
    readonly property var opening: PopupPosition.context(Quickshell.env("DOTFILES_POPUP_ANCHOR"))
    readonly property int popupGap: 8
    readonly property var popupScreen: Quickshell.screens.find(function(screen) {
        return screen.name === popup.opening.monitor
    }) ?? Quickshell.screens[0] ?? null
    readonly property real screenWidth: popupScreen ? popupScreen.width
        : PopupPosition.finite(opening.width, 1920)
    readonly property real screenHeight: popupScreen ? popupScreen.height
        : PopupPosition.finite(opening.height, 1080)
    readonly property real barBottom: Math.max(0, PopupPosition.finite(opening.barBottom, 24))
    readonly property real maximumPopupWidth: Math.max(1, screenWidth - popupGap * 2)
    readonly property real maximumPopupHeight: Math.max(1, screenHeight - popupTop - popupGap)
    readonly property real openingX: PopupPosition.finite(opening.x, screenWidth / 2)
    readonly property int popupTop: Math.round(Math.min(barBottom + popupGap, screenHeight - popupGap - 1))

    screen: popupScreen
    anchors { top: true; left: true }
    margins {
        top: popupTop
        left: PopupPosition.left(openingX, implicitWidth, screenWidth, popupGap)
    }
    implicitWidth: Math.ceil(Math.min(preferredPopupWidth, maximumPopupWidth))
    implicitHeight: Math.ceil(Math.min(preferredPopupHeight, maximumPopupHeight))
}
