import QtQuick
import org.kde.kirigami as Kirigami

// Ícone de pasta estilo macOS: quadrado arredondado translúcido com até 9 miniaturas (3x3)
Rectangle {
    id: folder

    property int size: 88
    property var preview: null   // lista de { decoration }

    width: size
    height: size
    radius: Math.round(size * 0.23)
    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.16)
    border.width: 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)

    readonly property int pad: Math.round(size * 0.12)
    readonly property int gap: Math.round(size * 0.05)
    readonly property int mini: Math.floor((size - pad * 2 - gap * 2) / 3)

    Grid {
        x: folder.pad
        y: folder.pad
        columns: 3
        spacing: folder.gap

        Repeater {
            model: folder.preview
            delegate: Kirigami.Icon {
                width: folder.mini
                height: folder.mini
                source: model.decoration !== undefined ? model.decoration : modelData.decoration
                animated: false
            }
        }
    }
}
