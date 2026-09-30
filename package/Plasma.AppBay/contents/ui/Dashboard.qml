import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker 0.1 as Kicker

Kicker.DashboardWindow {
    id: dashboard

    backgroundColor: "transparent"

    // Esc sai de uma coisa por vez: modo organizar, busca, pasta, launcher
    onKeyEscapePressed: {
        if (kicker.jiggle) {
            kicker.jiggle = false
        } else if (kicker.searchActive) {
            searchEntry.text = ""
        } else if (kicker.activeGroup) {
            appList.closeFolder()
        } else {
            toggle()
        }
    }

    onVisibleChanged: {
        // fechar e abrir de novo começa sem busca, fora de pastas e sem seleção.
        // A página em que você estava é mantida, como no macOS.
        appList.resetPointer()
        searchEntry.text = ""
        kicker.jiggle = false
        if (kicker.activeGroup)
            appList.closeFolder()
        appList.kbIndex = -1
        if (visible)
            Qt.callLater(function () { searchEntry.forceActiveFocus() })
    }

    Rectangle {
        id: background
        anchors.fill: parent
        // o efeito do KWin (Launchpad Zoom) cuida do zoom/fade de abrir e fechar
        color: Qt.rgba(kicker.bgColor.r, kicker.bgColor.g, kicker.bgColor.b, 0.6)

        SearchEntry {
            id: searchEntry
            height: 48
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: 30
            }
            width: Math.min(parent.width - 60, 400)
            onNavKey: (event) => {
                if (appList.handleNavKey(event))
                    event.accepted = true
            }
            // na busca, o primeiro resultado já vem selecionado (Enter abre)
            onTextChanged: appList.kbIndex = text === "" ? -1 : 0
        }

        PowerActions {
            id: powerActions
            anchors.verticalCenter: searchEntry.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 16
            visible: Plasmoid.configuration.systemActionsButtons
        }

        AppList {
            id: appList
            height: parent.height - searchEntry.height - 50
            width: parent.width
            anchors {
                top: searchEntry.bottom
                topMargin: 20
                horizontalCenter: parent.horizontalCenter
            }
        }

        Loader {
            active: Plasmoid.configuration.dockF
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !kicker.activeGroup
            sourceComponent: FavorirtesDock {
                sizeIconDock: 64
                spacingMargin: 8
                maxIconsInDock: 8
            }
        }
    }
}
