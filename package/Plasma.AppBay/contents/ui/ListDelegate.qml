import QtQuick
import org.kde.kirigami as Kirigami
import "Utils.js" as Utils

// Um ícone da grade (app, pasta ou resultado da busca). Só desenha e repassa o mouse;
// arrastar, trocar de página e criar pastas ficam no AppList.
Item {
    id: cell

    property string kind: "grid"      // "grid" | "folder" | "search"
    property int itemIndex: -1
    property string name
    property var iconSource
    property bool isGroup: false
    property var preview: null
    property int iconSize: 88

    property bool selected: false     // seleção do teclado
    property bool placeholder: false  // o "fantasma" do arrasto está no lugar dele
    property bool folderTarget: false // outro app está parado em cima: vai virar pasta
    property real jiggleAngle: 0
    property bool showClose: false
    property bool textShadow: false

    // posição do ícone dentro da célula (o fantasma do arrasto parte daqui)
    readonly property real iconX: (width - iconSize) / 2
    readonly property real iconY: Math.round(height / 2 - iconSize / 2 - 12)

    signal pointerPressed(var cell, real sceneX, real sceneY, int button, real localX, real localY)
    signal pointerMoved(real sceneX, real sceneY)
    signal pointerReleased(real sceneX, real sceneY)
    signal pointerCanceled()
    signal pointerHeld()
    signal closeClicked()

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        pressAndHoldInterval: 450
        preventStealing: true

        onPressed: function (mouse) {
            var s = mapToItem(null, mouse.x, mouse.y)
            cell.pointerPressed(cell, s.x, s.y, mouse.button, mouse.x, mouse.y)
        }
        onPositionChanged: function (mouse) {
            var s = mapToItem(null, mouse.x, mouse.y)
            cell.pointerMoved(s.x, s.y)
        }
        onReleased: function (mouse) {
            var s = mapToItem(null, mouse.x, mouse.y)
            cell.pointerReleased(s.x, s.y)
        }
        onCanceled: cell.pointerCanceled()
        onPressAndHold: function (mouse) {
            if (mouse.button === Qt.LeftButton)
                cell.pointerHeld()
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: cell.placeholder ? 0 : 1
        rotation: cell.jiggleAngle
        scale: cell.folderTarget ? 1.12 : (mouseArea.pressed && !cell.placeholder ? 0.94 : 1)

        Behavior on scale {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        // destaque da seleção pelo teclado
        Rectangle {
            visible: cell.selected
            width: Math.min(cell.width - 8, cell.iconSize + 56)
            height: cell.iconSize + 60
            x: (cell.width - width) / 2
            y: cell.iconY - 12
            radius: 14
            color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.3)
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.6)
        }

        // alvo de pasta: um quadrado claro atrás do ícone, como no macOS
        Rectangle {
            visible: cell.folderTarget
            width: cell.iconSize + 18
            height: width
            x: cell.iconX - 9
            y: cell.iconY - 9
            radius: Math.round(width * 0.24)
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.22)
        }

        Loader {
            active: cell.isGroup
            visible: active
            x: cell.iconX
            y: cell.iconY
            sourceComponent: FolderIcon {
                size: cell.iconSize
                preview: cell.preview
            }
        }

        Kirigami.Icon {
            visible: !cell.isGroup
            x: cell.iconX
            y: cell.iconY
            width: cell.iconSize
            height: cell.iconSize
            source: cell.isGroup ? "" : cell.iconSource
            animated: false
        }

        Text {
            x: 6
            y: cell.iconY + cell.iconSize + 10
            width: cell.width - 12
            text: cell.name
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            color: Kirigami.Theme.textColor
            font.pointSize: Kirigami.Theme.defaultFont.pointSize
            style: cell.textShadow ? Text.Raised : Text.Normal
            styleColor: Qt.rgba(0, 0, 0, 0.45)
        }

        // "x" do modo organizar: oculta o app
        Loader {
            active: cell.showClose
            x: cell.iconX - 8
            y: cell.iconY - 8
            sourceComponent: Rectangle {
                width: 24
                height: 24
                radius: 12
                color: Qt.rgba(0.25, 0.25, 0.25, 0.92)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.25)

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: "×"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: cell.closeClicked()
                }
            }
        }
    }
}
