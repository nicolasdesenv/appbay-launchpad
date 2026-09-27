import QtQuick
import "Utils.js" as Utils
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as KIconThemes

FocusScope {
    id: rootScope

    property var mo: appsModel
    property var modelExe: rootModel.modelForRow(0)
    property var searchModel: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null
    property bool listGeneralActive: listActive === "generalList"

    readonly property var modelActive: activeGroup ? folderAppModel : listGeneralActive ? mo : searchModel

    property bool visibleApps: true

    signal openGridApp(int ID)


    // Configuración de la cuadrícula
    // Grade fixa 7x5 estilo macOS; as células se ajustam ao tamanho da tela
    readonly property int gridColumns: 7
    readonly property int gridRows: 5
    readonly property int maxItemsPerRow: gridColumns
    readonly property int maxItemsPerColumn: gridRows

    property real horizonBar: (!folderAppModel ? 0 : Math.ceil(folderAppModel.count/maxItemsPerRow) < 3 ? Math.ceil(folderAppModel.count/maxItemsPerRow) :3)

    readonly property int cellWidth: Math.max(1, Math.floor((width*.8)/gridColumns))
    readonly property int cellHeight: Math.max(1, Math.floor(height/(gridRows + 1)))
    readonly property int iconSize: Plasmoid.configuration.iconSize
    readonly property int marginPage: /*/activeGroup ? 0 :/*/ (width - (cellWidth*maxItemsPerRow))/2
    readonly property int itemsPerPage: maxItemsPerRow * maxItemsPerColumn


    property int totalItems: 0
    readonly property bool usePageLayout: listGeneralActive && !activeGroup
    readonly property int totalPages: usePageLayout ? pageCount : Math.max(1, Math.ceil((modelActive && modelActive.count !== undefined ? modelActive.count : 0)/itemsPerPage))

    // --- Páginas explícitas: quebras (isBreak) no appsModel separam as páginas ---
    property var slotMap: []
    property var pageStarts: [0]
    property int pageCount: 1
    property bool normalizing: false
    property int autoPage: -1

    function isBreakAt(i) {
        var it = appsModel.get(i)
        return it !== undefined && it !== null && it.isBreak === true
    }

    function relayout() {
        var map = [], starts = [0], page = 0, slot = 0
        for (var i = 0; i < appsModel.count; i++) {
            if (isBreakAt(i)) {
                map.push({ page: page, slot: -1 })
                page++
                slot = 0
                starts.push(i + 1)
            } else {
                map.push({ page: page, slot: slot })
                slot++
            }
        }
        pageStarts = starts
        pageCount = page + 1
        slotMap = map
        if (currentPage > totalPages - 1)
            currentPage = Math.max(0, totalPages - 1)
    }

    function pageLength(p) {
        var end = p < pageCount - 1 ? pageStarts[p + 1] - 1 : appsModel.count
        return end - pageStarts[p]
    }

    // no máximo 35 itens por página; o excedente passa para a próxima (como no macOS)
    function normalizePages() {
        if (normalizing)
            return
        normalizing = true
        var i = 0, inPage = 0
        while (i < appsModel.count) {
            if (isBreakAt(i)) {
                inPage = 0
                i++
                continue
            }
            inPage++
            if (inPage > itemsPerPage) {
                var b = -1
                for (var k = i + 1; k < appsModel.count; k++) {
                    if (isBreakAt(k)) { b = k; break }
                }
                if (b >= 0)
                    appsModel.move(b, i, 1)
                else
                    appsModel.insert(i, breakItem(0))
                inPage = 0
                i++
                continue
            }
            i++
        }
        normalizing = false
        relayout()
    }

    Connections {
        target: appsModel
        function onCountChanged() {
            Qt.callLater(rootScope.normalizePages)
        }
    }

    function addPageAfter(p) {
        var pos = p < pageCount - 1 ? pageStarts[p + 1] - 1 : appsModel.count
        appsModel.insert(pos, breakItem(0))
        normalizePages()
        saveOrder()
    }

    function removePage(p) {
        if (pageCount <= 1 || pageLength(p) > 0)
            return false
        var bi = p > 0 ? pageStarts[p] - 1 : pageStarts[1] - 1
        appsModel.remove(bi, 1)
        normalizePages()
        saveOrder()
        return true
    }

    // índice plano para "página p, posição slot" (limitado ao fim da página)
    function flatIndexFor(p, slot) {
        p = Math.max(0, Math.min(pageCount - 1, p))
        return pageStarts[p] + Math.min(slot, pageLength(p))
    }

    property string nameActiveGroup
    property int activeIndex

    property int marginMinimalGroup: activeGroup && folderAppModel ? folderAppModel.count < maxItemsPerRow ? ((maxItemsPerRow - folderAppModel.count)*cellWidth)/2 : 0 : 0

    // --- Gestos e reordenação estilo macOS ---
    property real swipeOffset: 0
    property bool swiping: false
    property real swipeStartX: 0
    property double swipeStartTime: 0
    property int edgeDirection: 0
    property real wheelAccum: 0
    property double lastWheelFlip: 0
    property bool reflowAnim: false

    function canSwipe() {
        return !activeGroup && totalPages > 1
    }

    function goToPage(p) {
        p = Math.max(0, Math.min(totalPages - 1, p))
        if (p === currentPage)
            return
        iconsAnamitaionInitialLoad = true
        currentPage = p
    }

    function swipeStart(sceneX, time) {
        swipeStartX = sceneX
        swipeStartTime = time
        iconsAnamitaionInitialLoad = false
        swiping = true
    }

    function swipeUpdate(sceneX) {
        if (!swiping)
            return
        var dx = sceneX - swipeStartX
        // resistência elástica na primeira e na última página
        if ((currentPage === 0 && dx > 0) || (currentPage >= totalPages - 1 && dx < 0))
            dx *= 0.3
        swipeOffset = dx
    }

    function swipeEnd(sceneX) {
        if (!swiping)
            return
        var dx = sceneX - swipeStartX
        var flick = (Date.now() - swipeStartTime) < 250 && Math.abs(dx) > 40
        var target = currentPage
        if (dx < -gridRoot.width * 0.12 || (flick && dx < 0))
            target++
        else if (dx > gridRoot.width * 0.12 || (flick && dx > 0))
            target--
        iconsAnamitaionInitialLoad = true
        swipeOffset = 0
        currentPage = Math.max(0, Math.min(totalPages - 1, target))
        swiping = false
    }

    // Arrastar um ícone até a borda troca de página
    Timer {
        id: edgeTimer
        interval: 600
        repeat: true
        onTriggered: {
            if (edgeDirection === 0)
                return
            if (edgeDirection > 0 && usePageLayout && currentPage === totalPages - 1
                    && pageLength(currentPage) > 0 && autoPage < 0) {
                addPageAfter(currentPage)
                autoPage = currentPage + 1
            }
            goToPage(currentPage + edgeDirection)
        }
    }

    function dragMovedTo(sceneX) {
        var dir = 0
        if (!activeGroup && listGeneralActive) {
            var x = rootScope.mapFromItem(null, sceneX, 0).x
            var zone = Math.max(48, marginPage * 0.6)
            dir = x < zone ? -1 : (x > rootScope.width - zone ? 1 : 0)
        }
        if (dir !== edgeDirection) {
            edgeDirection = dir
            if (dir !== 0)
                edgeTimer.restart()
            else
                edgeTimer.stop()
        }
    }

    function dragFinished() {
        edgeDirection = 0
        edgeTimer.stop()
    }

    // depois do drop: descarta a página criada pela borda se ficou vazia
    function dragCleanup() {
        if (autoPage >= 0 && autoPage < pageCount && pageLength(autoPage) === 0) {
            var wasOn = currentPage
            removePage(autoPage)
            if (wasOn >= autoPage)
                goToPage(Math.max(0, autoPage - 1))
        }
        autoPage = -1
    }

    Timer {
        id: reflowTimer
        interval: 320
        onTriggered: reflowAnim = false
    }

    function reorderItem(from, to) {
        if (activeGroup || !listGeneralActive)
            return false
        if (from < 0 || from >= appsModel.count)
            return false
        to = Math.max(0, Math.min(appsModel.count - 1, to))
        if (from === to)
            return false
        reflowAnim = true
        reflowTimer.restart()
        appsModel.move(from, to, 1)
        normalizePages()
        saveOrder()
        return true
    }

    // "inserir antes do índice t" -> índice final depois do move
    function insertBefore(from, t) {
        return from < t ? t - 1 : t
    }

    function indexAtWrapperPoint(x, y) {
        var W = gridRoot.width
        var page = Math.max(0, Math.floor(x / W))
        var col = Math.floor((x - page * W - marginPage) / cellWidth)
        col = Math.max(0, Math.min(maxItemsPerRow - 1, col))
        var row = Math.max(0, Math.min(maxItemsPerColumn - 1, Math.floor(y / cellHeight)))
        return page * itemsPerPage + row * maxItemsPerRow + col
    }

    onModelActiveChanged: {
        totalItems = 0
    }

    function handleCreateGroup(index, item1, item2) {
        var groupIndex = subModel ? subModel.length + 1 : 1
        var newGroupName = "Group " + groupIndex

        // Crear grupo para subModel
        var newGroup = {
            displayGrupName: newGroupName,
            indexInModel: index,
            isGroup: true,
            elements: [
                { display: item1.display, decoration: item1.decoration, appIndex: item1.appIndex },
                { display: item2.display, decoration: item2.decoration, appIndex: item2.appIndex }
            ]
        }

        subModel.push(newGroup)
        saveSubModel()

        Utils.removeByAppIndex(item1.appIndex)
        Utils.removeByAppIndex(item2.appIndex)

        // Crear array JS puro para modelGroup
        var groupArray = [
            { display: item1.display, decoration: item1.decoration, appIndex: item1.appIndex },
            { display: item2.display, decoration: item2.decoration, appIndex: item2.appIndex }
        ]

        // Insertar grupo “vacío” primero
        appsModel.insert(index, {
            display: newGroupName,
            decoration: "",
            isGroup: true,
            modelGroup: [] // vacío temporal
        })

        // Actualizar inmediatamente con array JS puro para forzar render
        appsModel.set(index, {
            display: newGroupName,
            decoration: "",
            isGroup: true,
            modelGroup: groupArray
        })
        activeAnimations = false
        activeGroup = !activeGroup
        activeGroup = !activeGroup
        activeAnimations = true
        saveOrderIfCustom()
    }







    function handleAddToGroup(targetIndex, draggedItem) {

        var target = appsModel.get(targetIndex)
        if (!target) {
            return
        }

        // Convertir a array real si es necesario
        var arrayModelGroup = Utils.toArray(target.modelGroup)

        arrayModelGroup.push({
            display: draggedItem.display,
            decoration: draggedItem.decoration,
            appIndex: draggedItem.appIndex
        })


        // ⚡ Actualizar subModel también
        for (var i = 0; i < subModel.length; i++) {
            if (subModel[i].displayGrupName === target.display) {
                subModel[i].elements = Utils.cloneToPureArray(arrayModelGroup)
                break
            }
        }

        // ⚡ Actualizar appsModel
        appsModel.set(targetIndex, {
            modelGroup: arrayModelGroup,
            display: target.display,
            isGroup: true
        })

        saveSubModel()

        Utils.removeByAppIndex(draggedItem.appIndex)
        saveOrderIfCustom()
    }

    Kirigami.PromptDialog {
        id: rename
        title: "Rename Group"
        subtitle: "Enter a new name for this group"
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        preferredWidth: 320
        //preferredHeight: 188

        TextField {
            id: nameField
            width: parent.width
            height: 48
            horizontalAlignment: Text.AlignHCenter
            placeholderText: nameActiveGroup
            anchors.horizontalCenter: parent.horizontalCenter
            //leftPadding: 28 // Espacio fijo para el icono
            focus: true
            selectByMouse: true // Permitir selección de texto con mouse

            background: Rectangle {
                color: entryDialogColor
                radius: height/2
                opacity: 0.3
            }
        }
        onAccepted: {
            if (nameField.text.trim() !== "") {
                nameActiveGroup = nameField.text.trim()
                Utils.renameGroup(activeIndex, nameActiveGroup)
            }
        }
    }

    Item {
        id: gridRoot
        width: parent.width
        height:  parent.height
        //Visible: visibleApps

        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true

            property point pressScene
            property double pressTime: 0
            property bool swiped: false

            onPressed: function(mouse) {
                pressScene = mapToItem(null, mouse.x, mouse.y)
                pressTime = Date.now()
                swiped = false
            }
            onPositionChanged: function(mouse) {
                var sp = mapToItem(null, mouse.x, mouse.y)
                if (!swiped && Math.abs(sp.x - pressScene.x) > 12 && canSwipe()) {
                    swiped = true
                    swipeStart(pressScene.x, pressTime)
                }
                if (swiped)
                    swipeUpdate(sp.x)
            }
            onReleased: function(mouse) {
                if (swiped)
                    swipeEnd(mapToItem(null, mouse.x, mouse.y).x)
            }
            onCanceled: {
                if (swiped)
                    swipeEnd(swipeStartX)
            }

            onWheel: function(wheel) {
                // aceita rolagem vertical (mouse) e horizontal (touchpad)
                var d = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y
                var now = Date.now()
                if (now - lastWheelFlip < 250) {
                    wheelAccum = 0
                } else {
                    wheelAccum += d
                    if (Math.abs(wheelAccum) >= 120) {
                        goToPage(wheelAccum > 0 ? currentPage - 1 : currentPage + 1)
                        wheelAccum = 0
                        lastWheelFlip = now
                    }
                }
                wheel.accepted = true
            }
            onClicked: {
                if (swiped)
                    return
                if (activeGroup) {
                    activeGroup = false
                    currentPage = oldPage
                } else {
                    // cuando se da click fuera del area de los iconos se cerrara el menu
                    dashboard.toggle()
                }

            }
        }


        Item {
            id: wrapper
            width: activeGroup && folderAppModel ? (folderAppModel.count < maxItemsPerRow) ? folderAppModel.count*cellWidth : maxItemsPerRow*cellWidth : parent.width

            height: activeGroup ? horizonBar*cellHeight : parent.height

            property int marginFirstPageGroup: activeGroup ? (gridRoot.width-width)/2 : 0

            Behavior on anchors.leftMargin {
                enabled: iconsAnamitaionInitialLoad
                NumberAnimation {
                    id: marginAnimation
                    duration: 200
                    easing.type: Easing.InOutQuad

                    onRunningChanged: {
                        if (!running) {
                            iconsAnamitaionInitialLoad = false
                        }
                    }
                }
            }

            anchors.left: parent.left
            anchors.leftMargin: ((parent.width - width)/2) - currentPage * gridRoot.width - marginFirstPageGroup + marginMinimalGroup + swipeOffset //activeGroup ? ((parent.width - width)/2) : ((parent.width - width)/2) - currentPage * gridRoot.width
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: bgGroup
                width: !activeGroup ? 0 : parent.width
                height: !activeGroup ? 0 :parent.height
                anchors.left: parent.left
                anchors.leftMargin: (gridRoot.width-width)/2 + (parent.width*currentPage) + (gridRoot.width-parent.width)*currentPage - marginMinimalGroup
                anchors.verticalCenter: parent.verticalCenter
                visible: activeGroup
                color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.7)
                radius: 12
                Behavior on width {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                }
                Behavior on height {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                }

            }



            // Soltar num espaço vazio (fim da página, margens) reposiciona o app
            DropArea {
                x: 0
                y: 0
                width: Math.max(1, totalPages) * gridRoot.width
                height: maxItemsPerColumn * cellHeight
                enabled: !activeGroup && listGeneralActive
                onDropped: function(drop) {
                    var src = drop.source
                    if (!src || src.itemIndex === undefined)
                        return
                    var idx = indexAtWrapperPoint(drop.x, drop.y)
                    var flat = flatIndexFor(Math.floor(idx / itemsPerPage), idx % itemsPerPage)
                    if (reorderItem(src.itemIndex, insertBefore(src.itemIndex, flat)))
                        drop.accept()
                }
            }

            Repeater {
                model: modelActive

                delegate: Item {
                    width: cellWidth
                    height: cellHeight
                    z: ld.dragActive ? 1000 : 0

                    Behavior on x {
                        enabled: reflowAnim && !ld.dragActive
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        enabled: reflowAnim && !ld.dragActive
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }

                    property var pos: usePageLayout && index < slotMap.length ? slotMap[index] : null
                    property int page: pos ? pos.page : Math.floor(index / itemsPerPage)
                    property int localIndex: pos ? Math.max(0, pos.slot) : index % itemsPerPage
                    visible: !(model.isBreak === true)
                    property int row: localIndex % maxItemsPerRow
                    property int column: Math.floor(localIndex / maxItemsPerRow)
                    property int extraPadding: page > 0 ? marginPage + (marginPage*page) : marginPage

                    x: (row * cellWidth) + (page * (maxItemsPerRow * cellWidth + marginPage)) + extraPadding
                    y: column * cellHeight

                    ListDelegate {
                        id: ld
                        anchors.fill: parent
                        iconSource: model.icon || model.decoration
                        name: model.name || model.display
                        isGroup: model.isGroup !== undefined ? model.isGroup : false
                        appIndex: model.appIndex !== undefined ? model.appIndex : -1
                        elementsVisible: visibleApps
                        dragActive: false
                        sizeIcon: iconSize
                        subModel: model.modelGroup
                        parentItem: bgGroup
                        onDropOnItem: function(
                            draggedIndex,
                            draggedName,
                            draggedIcon,
                            draggedAppIndex,
                            targetIndex,
                            targetName,
                            targetIcon,
                            targetAppIndex
                        ) {
                            var draggedItem = { display: draggedName, decoration: draggedIcon, appIndex: draggedAppIndex }
                            var targetItem  = { display: targetName, decoration: targetIcon, appIndex: targetAppIndex }
                            handleCreateGroup(targetIndex,draggedItem,targetItem)
                        }
                        onDropOnItemGroup: function (
                            draggedIndex,
                            draggedName,
                            draggedIcon,
                            draggedAppIndex,
                            targetIndex
                        ) {
                            var draggedItem = {
                                display: draggedName,
                                decoration: draggedIcon,
                                appIndex: draggedAppIndex
                            }

                            handleAddToGroup(targetIndex, draggedItem)
                        }

                        onOpenGroup: function (model,indexGroup){

                            folderAppModel = model
                            parentGroupIndex = indexGroup
                            oldPage = currentPage
                            currentPage = 0
                            activeGroup = true

                        }
                        onRelocateGroup: function (orignalIndex,idx) {
                            console.log(idx,orignalIndex)
                            var item = appsModel.get(orignalIndex)

                            appsModel.insert(idx,item)

                            var indexRemove = 0

                            if (orignalIndex > idx) {
                                indexRemove = orignalIndex + 1
                            } else {
                                 indexRemove = orignalIndex
                            }
                            appsModel.remove(indexRemove)

                            Utils.relocateGroup(idx)

                        }
                        onReorderDrop: function (from, t) {
                            reorderItem(from, insertBefore(from, t))
                        }
                        onRemoveAppInGroup: function (idx,nme) {
                            Utils.removeAppOfGroup(idx, nme)
                        }
                    }

                    Component.onCompleted: {
                        // ahora el conteo de los Items Activos es mas exacto
                        totalItems = listGeneralActive ? totalItems < model.index ? model.index : totalItems : model.index
                    }
                }
            }
        }

        PageIndicator {
            id: pageIndicator
            count: totalPages
            currentIndex: currentPage
            visible: usePageLayout || totalPages > 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: wrapper.top
            anchors.topMargin: cellHeight*maxItemsPerColumn + 16


            // Navegación por clic en los puntos
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    var clickedIndex = Math.floor(mouseX / (pageIndicator.width / pageIndicator.count))
                    if (clickedIndex >= 0 && clickedIndex < pageIndicator.count) {
                        goToPage(clickedIndex)
                    }
                }
            }
        }

        ToolButton {
            id: removePageButton
            visible: usePageLayout
            enabled: totalPages > 1 && pageLength(currentPage) === 0
            icon.name: "list-remove"
            display: AbstractButton.IconOnly
            flat: true
            width: 28
            height: 28
            opacity: enabled ? (hovered ? 1 : 0.6) : 0.25
            anchors.right: pageIndicator.left
            anchors.rightMargin: 8
            anchors.verticalCenter: pageIndicator.verticalCenter
            ToolTip.visible: hovered
            ToolTip.text: pageLength(currentPage) === 0 ? "Remover esta página" : "Tire os apps desta página para removê-la"
            onClicked: {
                var p = currentPage
                if (removePage(p))
                    goToPage(Math.max(0, p - 1))
            }
        }

        ToolButton {
            id: addPageButton
            visible: usePageLayout
            icon.name: "list-add"
            display: AbstractButton.IconOnly
            flat: true
            width: 28
            height: 28
            opacity: hovered ? 1 : 0.6
            anchors.left: pageIndicator.right
            anchors.leftMargin: 8
            anchors.verticalCenter: pageIndicator.verticalCenter
            ToolTip.visible: hovered
            ToolTip.text: "Adicionar página"
            onClicked: {
                addPageAfter(currentPage)
                goToPage(currentPage + 1)
            }
        }

    }
}

