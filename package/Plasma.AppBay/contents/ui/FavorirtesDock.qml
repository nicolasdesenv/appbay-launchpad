import QtQuick
import org.kde.kirigami as Kirigami

// Dock opcional com os favoritos (desligado por padrão)
Rectangle {
    id: dock

    property var favModel: kicker.globalFavorites
    property int sizeIconDock: 64
    property int spacingMargin: 8
    property int maxIconsInDock: 8
    readonly property int shown: favModel ? Math.min(favModel.count, maxIconsInDock) : 0

    visible: shown > 0
    width: shown * (sizeIconDock + spacingMargin) + spacingMargin
    height: sizeIconDock + spacingMargin * 2
    radius: 16
    color: Qt.rgba(kicker.bgColor.r, kicker.bgColor.g, kicker.bgColor.b, 0.6)

    Row {
        x: dock.spacingMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: dock.spacingMargin

        Repeater {
            model: dock.favModel
            delegate: Kirigami.Icon {
                visible: index < dock.maxIconsInDock
                width: dock.sizeIconDock
                height: dock.sizeIconDock
                source: model.decoration
                animated: false
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        dock.favModel.trigger(index, "", null)
                        dashboard.toggle()
                    }
                }
            }
        }
    }
}
