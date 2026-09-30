import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import "Utils.js" as Utils

Item {
    id: root

    property int entryHeight: 32
    property color entryColor: kicker.bgColor
    property color entryTextColor: Kirigami.Theme.textColor
    property alias text: searchText.text

    // setas e Enter para a grade; quem trata marca event.accepted
    signal navKey(var event)

    // ao abrir, o foco está aqui e não no campo: a primeira letra começa a busca
    Keys.onPressed: (event) => {
        navKey(event)
        if (event.accepted)
            return
        if (event.text !== "" && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            event.accepted = true
            searchText.text = event.text
            searchText.forceActiveFocus()
        }
    }

    Rectangle {
        id: background
        height: root.entryHeight
        width: 220
        anchors.centerIn: parent
        radius: height / 2
        color: Qt.rgba(root.entryColor.r, root.entryColor.g, root.entryColor.b, 0.3)
        border.width: 1
        border.color: Utils.isColorLight(root.entryColor) ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(1, 1, 1, 0.2)

        TextField {
            id: searchText
            anchors.fill: parent
            color: root.entryTextColor
            horizontalAlignment: Text.AlignHCenter
            // padding igual dos dois lados, senão o texto fica deslocado para a direita
            leftPadding: 28
            rightPadding: 28
            selectByMouse: true
            background: null

            Keys.onPressed: (event) => root.navKey(event)

            onTextChanged: {
                runnerModel.query = text
                kicker.searchActive = text !== ""
                kicker.listActive = text === "" ? "generalList" : "searchList"
            }
        }

        // placeholder: lupa + "Buscar", some quando o campo está em uso
        Row {
            anchors.centerIn: parent
            spacing: 6
            visible: searchText.text === "" && !searchText.activeFocus
            opacity: 0.7

            Kirigami.Icon {
                source: "edit-find"
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: root.entryTextColor
            }
            Text {
                text: Utils.tr("Search")
                color: root.entryTextColor
                font: searchText.font
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
