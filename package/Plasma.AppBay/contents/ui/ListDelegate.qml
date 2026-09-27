import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Effects
import org.kde.plasma.plasmoid
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami

Item {
    id: delegateRoot
    anchors.fill: parent
    property var iconSource
    property var name
    property int appIndex
    property bool dragActive: false
    property int sizeIcon
    property int itemIndex: index
    property var itemModel: model
    property bool elementsVisible: true
    property bool isGroup
    property var subModel

    property var parentItem

    property bool full: false

    // Señal para notificar cuando se suelta sobre otro elemento
    signal dropOnItem(
        int draggedIndex,
        string draggedName,
        string draggedIcon,
        int draggedAppIndex,
        int targetIndex,
        string targetName,
        string targetIcon,
        int targetAppIndex
    )

    signal dropOnItemGroup(
        int draggedIndex,
        string draggedName,
        string draggedIcon,
        int draggedAppIndex,
        int targetIndex
    )

    signal relocateGroup(int draggedIndex, int targetIndex)

    // soltar na borda de um ícone: inserir antes do índice targetIndex
    signal reorderDrop(int draggedIndex, int targetIndex)

    // centro do ícone = criar/entrar em pasta; bordas = reposicionar
    function inGroupZone(px, py) {
        return Math.abs(px - width / 2) < sizeIcon * 0.55 && Math.abs(py - height / 2) < sizeIcon * 0.55
    }

    signal openFolder
    signal closeFolder
    signal openGroup(var groupModel, int indexGroup)

    signal removeAppInGroup(int index, string value)

    // Efecto de aparición
    property real appearScale: 1.0


    transform: Scale {
        id: scaleEffect
        origin.x: delegateRoot.width / 2
        origin.y: delegateRoot.height / 2
        xScale: appearScale
        yScale: appearScale
    }



    SequentialAnimation {
        id: appearAnim
        PropertyAnimation {
            target: delegateRoot
            property: "appearScale"
            from: 0.0
            to: 1.0
            duration: activeAnimations ? 150 : 0
            easing.type: Easing.OutQuad
        }
    }

    Component.onCompleted: {
        if (!searchActive) {
            appearAnim.start()
        }
    }

    ContextMenu {
        id: contextMenu
        indexInAppsModel: model.index
        currentName: model.display
        isGruop: isGroup
    }


    Item {
        id: dragContainer
        width: parent.width
        height: parent.height
        x: 0
        y: 0

        // Configuración del sistema Drag - CLAVE: NO usar drag.target en MouseArea
        Drag.active: mouseArea.pressed && mouseArea.isDragging
        Drag.source: delegateRoot
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Rectangle {
            id: bgGroup
            visible: isGroup
            radius: 8
            width: sizeIcon
            height: sizeIcon
            color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.7)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            Flow {
                anchors.fill: parent

                Repeater {
                    anchors.fill: parent
                    model: subModel
                    delegate: Item {
                        width: bgGroup.active ? 256 : sizeIcon/2
                        height: bgGroup.active ? 256 : sizeIcon/2
                        visible: index < 4
                        Kirigami.Icon {
                            id: iconGroup
                            width: bgGroup.active ? sizeIcon : parent.width/2
                            height: width
                            source: model.decoration
                            anchors.centerIn: parent
                        }
                    }
                }
            }
        }


        Item {
            id: itemEffect
            anchors.fill: parent

            Kirigami.Icon {
                id: icon
                visible: !isGroup
                width: dragActive ? sizeIcon + 16 : sizeIcon
                height: width
                source: iconSource
                opacity: full ? 0 : 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter

                Behavior on width {
                    NumberAnimation {
                        //enabled: activeAnimations
                        duration: activeAnimations ? 200 : 0
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Kirigami.Heading {
                id: nameDisplay
                anchors.top: icon.bottom
                anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                text: name
                width: parent.width - 10
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                level: 5
                opacity: dragActive ? 0 : 1
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }


        MultiEffect {
            source: itemEffect
            anchors.fill: itemEffect
            //visible: false
            //shadowScale:  1.1
            shadowEnabled: Plasmoid.configuration.enabledShadow
            blurMultiplier: 2
            blurMax: 18
            shadowOpacity: 0.2
        }
    }

    // Área de drop para detectar cuando otro elemento se suelta aquí
    DropArea {
        anchors.fill: parent

        onEntered: function(drag) {
            dropHighlight.opacity = (drag.source !== delegateRoot && inGroupZone(drag.x, drag.y)) ? 0.3 : 0
        }

        onPositionChanged: function(drag) {
            dropHighlight.opacity = (drag.source !== delegateRoot && inGroupZone(drag.x, drag.y)) ? 0.3 : 0
        }

        onExited: {
            dropHighlight.opacity = 0
        }

        onDropped: function(drop) {
            dropHighlight.opacity = 0

            if (drop.source === delegateRoot)
                return

            if (!activeGroup && listGeneralActive && !inGroupZone(drop.x, drop.y)) {
                var t = drop.x < width / 2 ? delegateRoot.itemIndex : delegateRoot.itemIndex + 1
                delegateRoot.reorderDrop(drop.source.itemIndex, t)
                drop.accept()
                return
            }

            if (!activeGroup) {
                if (!drop.source.isGroup) {
                    if (isGroup) {
                        delegateRoot.dropOnItemGroup(
                            drop.itemIndex,
                            drop.source.name,
                            drop.source.iconSource,
                            drop.source.appIndex,
                            delegateRoot.itemIndex
                        )
                    } else {
                        delegateRoot.dropOnItem(
                            drop.itemIndex,
                            drop.source.name,
                            drop.source.iconSource,
                            drop.source.appIndex,
                            delegateRoot.itemIndex,
                            delegateRoot.name,
                            delegateRoot.iconSource,
                            delegateRoot.appIndex
                        )
                    }
                } else {
                    delegateRoot.relocateGroup(drop.source.itemIndex,delegateRoot.itemIndex)
                }
            } else {
                console.log("🟢 Elemento soltado dentro del grupo activo")
            }
        }
    }

    // Highlight visual para indicar zona de drop
    Rectangle {
        id: dropHighlight
        anchors.fill: parent
        color: Kirigami.Theme.highlightColor
        radius: 8
        opacity: 0
        z: -1

        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.InOutQuad
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent

        property bool changeGroup: false
        property bool isDragging: mode === 2
        property point startPos
        property int dragThreshold: 10

        property int mode: 0
        property point pressScene
        property double pressTime: 0
        property point lastScene

        pressAndHoldInterval: 400
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        function beginIconDrag() {
            mode = 2
            lastScene = pressScene
            delegateRoot.dragActive = true
            dragContainer.z = 9999
        }

        function updateDragPos() {
            var p = delegateRoot.mapFromItem(null, lastScene.x, lastScene.y)
            dragContainer.x = p.x - startPos.x
            dragContainer.y = p.y - startPos.y
        }

        // mantém o ícone sob o cursor enquanto a página desliza
        Timer {
            interval: 16
            repeat: true
            running: mouseArea.mode === 2
            onTriggered: mouseArea.updateDragPos()
        }

        // NO usar drag.target - manejamos el arrastre manualmente

        onPressed: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                contextMenu.open(mouse.x,mouse.y,model.appIndex)
                //contextMenu.x = mouse.x
                //contextMenu.y = mouse.y
                mouse.accepted = true
                return
            }
            startPos = Qt.point(mouse.x, mouse.y)
            pressScene = mapToItem(null, mouse.x, mouse.y)
            pressTime = Date.now()
            mode = 0
        }

        onPositionChanged: function(mouse) {
            if (!pressed)
                return
            var sp = mapToItem(null, mouse.x, mouse.y)

            if (mode === 0) {
                var dx = sp.x - pressScene.x
                var dy = sp.y - pressScene.y
                if (Math.sqrt(dx * dx + dy * dy) > dragThreshold) {
                    // clicar e arrastar para o lado = trocar de página (como no macOS);
                    // clicar e segurar = pegar o ícone
                    if (rootScope.canSwipe() && Math.abs(dx) >= Math.abs(dy)) {
                        mode = 1
                        rootScope.swipeStart(pressScene.x, pressTime)
                    } else {
                        beginIconDrag()
                    }
                }
            }

            if (mode === 1) {
                rootScope.swipeUpdate(sp.x)
            } else if (mode === 2) {
                lastScene = sp
                updateDragPos()
                rootScope.dragMovedTo(sp.x)
            }
        }

        onCanceled: {
            if (mode === 1)
                rootScope.swipeEnd(rootScope.swipeStartX)
            if (mode === 2) {
                rootScope.dragFinished()
                delegateRoot.dragActive = false
                dragContainer.z = 0
                returnAnimation.start()
                rootScope.dragCleanup()
            }
            mode = 0
        }

        onReleased: function(mouse) {
            if (mode === 1) {
                rootScope.swipeEnd(mapToItem(null, mouse.x, mouse.y).x)
                mode = 0
                return
            }
            if (mode === 2) {
                rootScope.dragFinished()
                var p0 = dragContainer.mapToItem(null, 0, 0)
                var oldIndex = delegateRoot.itemIndex

                if (activeGroup) {
                    // logica para determinar donde se solto el icono
                    var globalParentPos = parentItem.mapToGlobal(mouse.x, mouse.y)

                    var realx = globalParentPos.x + parent.width*(model.index%maxItemsPerRow-1)

                    var realY = mouse.y + dragContainer.height*((Math.floor(model.index/maxItemsPerRow)%maxItemsPerColumn))

                    if ((realx > parentItem.width || realY > parentItem.height ) || (realx < 0 || realY < 0)) {

                        removeAppInGroup(parentGroupIndex,model.display) // envia señal para procesar la eliminacion de los datos
                    }
                }


                dragContainer.Drag.drop()

                if (!changeGroup) {
                    if (delegateRoot.itemIndex >= 0 && delegateRoot.itemIndex !== oldIndex) {
                        // o item mudou de lugar: parte de onde foi solto até a nova célula
                        var p1 = delegateRoot.mapToItem(null, 0, 0)
                        dragContainer.x = p0.x - p1.x
                        dragContainer.y = p0.y - p1.y
                    }
                    returnAnimation.start()
                }

                dragContainer.z = 0
                delegateRoot.dragActive = false
                mode = 0
                rootScope.dragCleanup()

            } else {
                if (mouse.button === Qt.LeftButton) {
                    iconsAnamitaionInitialLoad = false
                    if (isGroup) {
                        openGroup(subModel,model.index)
                    } else if (listGeneralActive) {
                        openGridApp(model.appIndex)
                    } else {
                        var appGeneralModel = rootModel.modelForRow(0)
                        for (var g = 0; g < appGeneralModel.count; g++) {
                            var appIndexObj = appGeneralModel.index(g, 0)
                            var appName = appGeneralModel.data(appIndexObj, Qt.DisplayRole)
                            if (model.display === appName) {
                                openGridApp(g)
                                break;
                            }
                        }
                    }
                }
            }
        }


        onPressAndHold: function(mouse) {
            if (mouse.button === Qt.LeftButton && mode === 0) {
                beginIconDrag()
            }
        }
    }

    // Animación para regresar a la posición original
    ParallelAnimation {
        id: returnAnimation
        NumberAnimation {
            target: dragContainer
            property: "x"
            to: 0
            duration: 300
            easing.type: Easing.OutBack
        }
        NumberAnimation {
            target: dragContainer
            property: "y"
            to: 0
            duration: 300
            easing.type: Easing.OutBack
        }
    }
}
