import QtQuick
import org.kde.plasma.extras as PlasmaExtras
import "Utils.js" as Utils

// Menu do botão direito. Um só para a grade inteira, criado no primeiro uso
// (antes cada ícone criava o seu, o que pesava ao montar a grade).
Item {
    id: root

    property int targetIndex: -1
    property bool targetIsGroup: false
    property var menu: null

    signal hideApp(int index)
    signal addToFavorites(int index)
    signal renameFolder(int index)
    signal deleteFolder(int index)
    signal editLayout()

    function openFor(item, index, isGroup, x, y) {
        targetIndex = index
        targetIsGroup = isGroup
        if (!menu)
            menu = menuComponent.createObject(root)
        menu.visualParent = item
        menu.open(x, y)
    }

    Component {
        id: menuComponent

        PlasmaExtras.Menu {
            PlasmaExtras.MenuItem {
                text: Utils.tr("Hide App")
                icon: "view-hidden-symbolic"
                visible: !root.targetIsGroup
                onClicked: root.hideApp(root.targetIndex)
            }
            PlasmaExtras.MenuItem {
                text: Utils.tr("Add to Favorites")
                icon: "favorite"
                visible: !root.targetIsGroup
                onClicked: root.addToFavorites(root.targetIndex)
            }
            PlasmaExtras.MenuItem {
                text: Utils.tr("Rename Folder")
                icon: "entry-edit-symbolic"
                visible: root.targetIsGroup
                onClicked: root.renameFolder(root.targetIndex)
            }
            PlasmaExtras.MenuItem {
                text: Utils.tr("Delete Folder")
                icon: "folder-open-symbolic"
                visible: root.targetIsGroup
                onClicked: root.deleteFolder(root.targetIndex)
            }
            PlasmaExtras.MenuItem {
                separator: true
            }
            PlasmaExtras.MenuItem {
                text: Utils.tr("Edit Layout")
                icon: "transform-move"
                onClicked: root.editLayout()
            }
        }
    }
}
