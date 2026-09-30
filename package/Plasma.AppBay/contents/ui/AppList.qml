import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "Utils.js" as Utils

// Grade do launcher. Três camadas independentes, para nada ser recriado ao buscar
// ou abrir pastas: a grade de apps (sempre montada, só a página visível é desenhada),
// os resultados da busca e a pasta aberta.
FocusScope {
    id: rootScope

    readonly property bool listGeneralActive: kicker.listActive === "generalList"
    readonly property var searchModel: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null

    // --- medidas da grade ---
    readonly property int gridColumns: kicker.gridColumns
    readonly property int gridRows: kicker.gridRows
    readonly property int itemsPerPage: gridColumns * gridRows
    readonly property int cellWidth: Math.max(1, Math.floor((width * 0.8) / gridColumns))
    readonly property int cellHeight: Math.max(1, Math.floor(height / (gridRows + 1)))
    readonly property int iconSize: Math.max(24, Math.min(Plasmoid.configuration.iconSize,
                                                         Math.floor(Math.min(cellWidth * 0.7, cellHeight * 0.62))))
    readonly property int marginPage: Math.floor((width - cellWidth * gridColumns) / 2)
    readonly property bool textShadow: Plasmoid.configuration.enabledShadow

    // --- páginas: quebras (isBreak) no appsModel separam as páginas ---
    property var slotMap: []
    property var pageStarts: [0]
    property int pageCount: 1
    property bool normalizing: false
    property int autoPage: -1
    readonly property int totalPages: pageCount

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
        if (kicker.currentPage > pageCount - 1)
            setPage(Math.max(0, pageCount - 1), false)
    }

    function pageLength(p) {
        var end = p < pageCount - 1 ? pageStarts[p + 1] - 1 : appsModel.count
        return end - pageStarts[p]
    }

    // no máximo uma página cheia; o excedente passa para a próxima (como no macOS)
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
                    appsModel.insert(i, kicker.breakItem(0))
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
    Connections {
        target: kicker
        function onModelRevisionChanged() {
            Qt.callLater(rootScope.normalizePages)
        }
    }
    onItemsPerPageChanged: Qt.callLater(normalizePages)
    Component.onCompleted: normalizePages()

    function addPageAfter(p) {
        var pos = p < pageCount - 1 ? pageStarts[p + 1] - 1 : appsModel.count
        appsModel.insert(pos, kicker.breakItem(0))
        normalizePages()
        kicker.saveOrder()
    }

    function removePage(p) {
        if (pageCount <= 1 || pageLength(p) > 0)
            return false
        var bi = p > 0 ? pageStarts[p] - 1 : pageStarts[1] - 1
        appsModel.remove(bi, 1)
        normalizePages()
        kicker.saveOrder()
        return true
    }

    // --- troca de página ---
    property real swipeOffset: 0
    property bool swiping: false
    property real swipeStartX: 0
    property double swipeStartTime: 0
    property bool pageAnimEnabled: true

    function setPage(p, animated) {
        pageAnimEnabled = animated
        kicker.currentPage = p
        pageAnimEnabled = true
    }

    function goToPage(p) {
        p = Math.max(0, Math.min(totalPages - 1, p))
        if (p !== kicker.currentPage)
            kicker.currentPage = p
    }

    function canSwipe() {
        return !kicker.activeGroup && listGeneralActive && totalPages > 1
    }

    // resistência elástica antes da primeira e depois da última página
    function rubber(dx) {
        if ((kicker.currentPage === 0 && dx > 0) || (kicker.currentPage >= totalPages - 1 && dx < 0))
            return dx * 0.3
        return dx
    }

    function swipeStart(sceneX, time) {
        swipeStartX = sceneX
        swipeStartTime = time
        swiping = true
    }

    function swipeUpdate(sceneX) {
        if (swiping)
            swipeOffset = rubber(sceneX - swipeStartX)
    }

    // termina o arrasto de página: decide pela distância ou pela velocidade (flick)
    function swipeFinish(dx, velocity) {
        var target = kicker.currentPage
        if (dx < -width * 0.12 || velocity < -0.5)
            target++
        else if (dx > width * 0.12 || velocity > 0.5)
            target--
        swiping = false
        swipeOffset = 0
        goToPage(target)
    }

    function swipeEnd(sceneX) {
        if (!swiping)
            return
        var dx = sceneX - swipeStartX
        var dt = Math.max(1, Date.now() - swipeStartTime)
        swipeFinish(dx, dt < 250 ? dx / dt : 0)
    }

    // touchpad: a página acompanha os dedos e encaixa ao soltar
    property real wheelVelocity: 0
    property double lastWheelTime: 0
    property real wheelAccum: 0
    property double lastWheelFlip: 0

    Timer {
        id: wheelEndTimer
        interval: 110
        onTriggered: rootScope.swipeFinish(rootScope.swipeOffset, rootScope.wheelVelocity)
    }

    function handleWheel(wheel) {
        wheel.accepted = true
        if (!canSwipe() || pointerMode === 2)
            return
        var px = wheel.pixelDelta
        if (px.x !== 0 || px.y !== 0) {
            var d = Math.abs(px.x) >= Math.abs(px.y) ? px.x : px.y
            var now = Date.now()
            if (!swiping) {
                swiping = true
                swipeStartX = 0
                wheelVelocity = 0
                lastWheelTime = now
            }
            var dt = Math.max(1, now - lastWheelTime)
            wheelVelocity = 0.6 * wheelVelocity + 0.4 * (d / dt)
            lastWheelTime = now
            swipeOffset = rubber(swipeOffset + d)
            wheelEndTimer.restart()
        } else {
            // roda do mouse: uma página por "clique" de roda
            var a = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y
            var t = Date.now()
            if (t - lastWheelFlip < 250) {
                wheelAccum = 0
            } else {
                wheelAccum += a
                if (Math.abs(wheelAccum) >= 120) {
                    goToPage(wheelAccum > 0 ? kicker.currentPage - 1 : kicker.currentPage + 1)
                    wheelAccum = 0
                    lastWheelFlip = t
                }
            }
        }
    }

    // páginas desenhadas: só a atual quando parado; durante o movimento, as vizinhas também
    readonly property int viewPage: width > 0 ? Math.floor(-pagesLayer.x / width + 0.001) : 0
    readonly property bool pagesMoving: swiping || pageAnim.running
    readonly property int visLo: pagesMoving ? Math.min(kicker.currentPage, viewPage) : kicker.currentPage
    readonly property int visHi: pagesMoving ? Math.max(kicker.currentPage, viewPage + 1) : kicker.currentPage

    // --- modo organizar (ícones tremendo) ---
    property real jigglePhase: 0
    readonly property bool jiggleOn: kicker.jiggle && dashboard.visible && !kicker.activeGroup

    SequentialAnimation {
        running: rootScope.jiggleOn
        loops: Animation.Infinite
        onStopped: rootScope.jigglePhase = 0
        NumberAnimation { target: rootScope; property: "jigglePhase"; from: -1; to: 1; duration: 130; easing.type: Easing.InOutSine }
        NumberAnimation { target: rootScope; property: "jigglePhase"; from: 1; to: -1; duration: 130; easing.type: Easing.InOutSine }
    }

    // --- pasta aberta ---
    property string folderName: ""
    property int folderPage: 0
    property bool folderFading: false   // arrastando um app para fora: a pasta some
    readonly property int folderCols: Math.max(1, Math.min(folderModel.count, gridColumns))
    readonly property int folderRows: Math.max(1, Math.min(Math.ceil(folderModel.count / folderCols), gridRows))
    readonly property int folderPerPage: folderCols * folderRows
    readonly property int folderPages: Math.max(1, Math.ceil(folderModel.count / folderPerPage))

    ListModel {
        id: folderModel
    }

    function openFolder(index) {
        var it = appsModel.get(index)
        if (!it || !it.isGroup)
            return
        var apps = kicker.groupApps(it.display)
        folderClearTimer.stop()
        folderModel.clear()
        var rows = []
        for (var i = 0; i < apps.length; i++)
            rows.push({ display: apps[i].display, decoration: apps[i].decoration, appIndex: apps[i].appIndex, favoriteId: apps[i].favoriteId })
        folderModel.append(rows)
        folderName = it.display
        folderTitle.text = it.display
        kicker.parentGroupIndex = index
        folderPage = 0
        folderFading = false
        kicker.activeGroup = true
    }

    function closeFolder() {
        if (folderTitle.activeFocus)
            searchEntry.forceActiveFocus()
        kicker.activeGroup = false
        folderFading = false
        kicker.parentGroupIndex = -1
        folderClearTimer.restart()
    }

    Timer {
        id: folderClearTimer
        interval: 250
        onTriggered: {
            if (!kicker.activeGroup && rootScope.dragIndex < 0 && rootScope.folderDragIndex < 0)
                folderModel.clear()
        }
    }

    function folderApps() {
        var out = []
        for (var i = 0; i < folderModel.count; i++) {
            var f = folderModel.get(i)
            out.push({ display: f.display, decoration: f.decoration, appIndex: f.appIndex, favoriteId: f.favoriteId })
        }
        return out
    }

    // --- abrir itens ---
    function launch(appIndex) {
        kicker.launchApp(appIndex)
        dashboard.visible = false
    }

    function activate(kind, index) {
        if (kind === "grid") {
            var it = appsModel.get(index)
            if (!it || it.isBreak === true)
                return false
            if (it.isGroup)
                openFolder(index)
            else if (!kicker.jiggle)
                launch(it.appIndex)
        } else if (kind === "folder") {
            if (!kicker.jiggle && index >= 0 && index < folderModel.count)
                launch(folderModel.get(index).appIndex)
        } else if (kind === "search") {
            if (searchModel && index >= 0 && index < searchModel.count) {
                // resultados do KRunner: apps, configurações, calculadora...
                searchModel.trigger(index, "", null)
                dashboard.visible = false
            }
        }
        return true
    }

    // --- mouse: clique, deslizar de página, segurar e arrastar ---
    property var pressCell: null
    property string pressKind: ""
    property int pressIndex: -1
    property point pressScene
    property double pressTime: 0
    property int pointerMode: 0   // 0 parado, 1 trocando de página, 2 arrastando ícone, 3 ignorar
    readonly property bool dragging: pointerMode === 2

    function cellPressed(cell, kind, index, sx, sy, button, lx, ly) {
        if (button === Qt.RightButton) {
            if (kind === "grid" && !dragging) {
                var it = appsModel.get(index)
                if (it)
                    contextMenu.openFor(cell, index, it.isGroup === true, lx, ly)
            }
            return
        }
        pressCell = cell
        pressKind = kind
        pressIndex = index
        pressScene = Qt.point(sx, sy)
        pressTime = Date.now()
        pointerMode = 0
    }

    function cellMoved(sx, sy) {
        if (pointerMode === 0) {
            var dx = sx - pressScene.x, dy = sy - pressScene.y
            if (dx * dx + dy * dy > 64) {
                if (kicker.jiggle && pressCell && pressKind !== "search") {
                    startDrag()
                } else if (canSwipe() && Math.abs(dx) >= Math.abs(dy) && pressKind !== "folder") {
                    pointerMode = 1
                    swipeStart(pressScene.x, pressTime)
                } else {
                    pointerMode = 3
                }
            }
        }
        if (pointerMode === 1)
            swipeUpdate(sx)
        else if (pointerMode === 2)
            dragMove(sx, sy)
    }

    function cellHeld() {
        if (pointerMode !== 0 || !pressCell || pressKind === "search")
            return
        kicker.jiggle = true
        startDrag()
    }

    function cellReleased(sx, sy) {
        var mode = pointerMode
        var cell = pressCell
        pointerMode = 0
        pressCell = null
        if (mode === 0) {
            if (cell)
                activate(pressKind, pressIndex)
            else
                backgroundClicked()
        } else if (mode === 1) {
            swipeEnd(sx)
        } else if (mode === 2) {
            dragEnd()
        }
    }

    function cellCanceled() {
        var mode = pointerMode
        pointerMode = 0
        pressCell = null
        if (mode === 1)
            swipeEnd(swipeStartX)
        else if (mode === 2)
            dragEnd()
    }

    function backgroundClicked() {
        if (kicker.jiggle)
            kicker.jiggle = false
        else if (kicker.activeGroup)
            closeFolder()
        else
            dashboard.toggle()
    }

    // --- arrastar ícones ---
    property int dragIndex: -1          // índice no appsModel do item arrastado (grade)
    property int folderDragIndex: -1    // índice no folderModel (arrasto dentro da pasta)
    property bool dragFromFolder: false
    property bool dragOutOfFolder: false
    property string dragKey: ""
    property int folderTargetIndex: -1
    property bool landing: false
    property bool reflowAnim: false
    property point grabOffset
    property int edgeDirection: 0
    property var pendingHover: null

    function keyOf(it) {
        return it.isGroup ? "group:" + it.display : (it.favoriteId ? it.favoriteId : it.display)
    }

    function findByKey(key) {
        for (var i = 0; i < appsModel.count; i++) {
            var it = appsModel.get(i)
            if (it.isBreak !== true && keyOf(it) === key)
                return i
        }
        return -1
    }

    function startDrag() {
        var cell = pressCell
        if (!cell)
            return
        landingAnim.stop()
        pointerMode = 2
        reflowAnim = true
        kbIndex = -1
        var iconScene = cell.mapToItem(null, cell.iconX, cell.iconY)
        grabOffset = Qt.point(pressScene.x - iconScene.x, pressScene.y - iconScene.y)
        ghost.isGroup = cell.isGroup
        ghost.source = cell.isGroup ? "" : cell.iconSource
        ghost.preview = cell.preview
        ghost.intoFolder = false
        ghost.opacity = 1
        if (pressKind === "grid") {
            dragFromFolder = false
            dragIndex = pressIndex
            dragKey = keyOf(appsModel.get(pressIndex))
        } else {
            dragFromFolder = true
            dragOutOfFolder = false
            folderDragIndex = pressIndex
        }
        placeGhost(pressScene.x, pressScene.y)
        ghost.scale = 1.12
    }

    function placeGhost(sx, sy) {
        var p = rootScope.mapFromItem(null, sx - grabOffset.x, sy - grabOffset.y)
        ghost.x = p.x
        ghost.y = p.y
    }

    function dragMove(sx, sy) {
        placeGhost(sx, sy)
        if (dragFromFolder && !dragOutOfFolder) {
            var fp = folderPanel.mapFromItem(null, sx, sy)
            var inside = fp.x >= -24 && fp.y >= -24 && fp.x <= folderPanel.width + 24 && fp.y <= folderPanel.height + 24
            if (inside) {
                leaveFolderTimer.stop()
                folderHover(fp.x - folderPanel.pad, fp.y - folderPanel.pad)
            } else if (!leaveFolderTimer.running) {
                scheduleHover(null)
                leaveFolderTimer.start()
            }
            return
        }
        // borda da tela: troca de página depois de um instante
        var x = rootScope.mapFromItem(null, sx, 0).x
        var zone = Math.max(48, marginPage * 0.6)
        var dir = x < zone ? -1 : (x > rootScope.width - zone ? 1 : 0)
        if (dir !== edgeDirection) {
            edgeDirection = dir
            if (dir !== 0)
                edgeTimer.restart()
            else
                edgeTimer.stop()
        }
        gridHover(sx, sy)
    }

    // decide o que acontece com o ícone parado sobre a grade
    function gridHover(sx, sy) {
        if (dragIndex < 0)
            return
        var lp = pagesLayer.mapFromItem(null, sx, sy)
        var page = Math.floor(lp.x / width)
        var lx = lp.x - page * width - marginPage
        var col = Math.floor(lx / cellWidth), row = Math.floor(lp.y / cellHeight)
        if (page !== kicker.currentPage || col < 0 || col >= gridColumns || row < 0 || row >= gridRows) {
            scheduleHover(null)
            return
        }
        var slot = row * gridColumns + col
        var len = pageLength(page)
        if (slot >= len) {
            // espaço vazio da página: vai para o fim dela
            var endIdx = pageStarts[page] + len
            var to = dragIndex < endIdx ? endIdx - 1 : endIdx
            scheduleHover(to === dragIndex ? null : { type: "move", to: to })
            return
        }
        var t = pageStarts[page] + slot
        if (t === dragIndex) {
            scheduleHover(null)
            return
        }
        var cx = lx - col * cellWidth - cellWidth / 2
        var cy = lp.y - row * cellHeight - (cellHeight / 2 - 12)
        var dragged = appsModel.get(dragIndex)
        var centerZone = Math.abs(cx) < iconSize * 0.36 && Math.abs(cy) < iconSize * 0.36
        if (centerZone && dragged && !dragged.isGroup)
            scheduleHover({ type: "folder", target: t })
        else
            scheduleHover({ type: "move", to: t })
    }

    function folderHover(px, py) {
        var col = Math.floor(px / cellWidth), row = Math.floor(py / cellHeight)
        if (col < 0 || col >= folderCols || row < 0 || row >= folderRows) {
            scheduleHover(null)
            return
        }
        var t = Math.min(folderModel.count - 1, folderPage * folderPerPage + row * folderCols + col)
        scheduleHover(t === folderDragIndex ? null : { type: "fmove", to: t })
    }

    function sameHover(a, b) {
        if (!a || !b)
            return a === b
        return a.type === b.type && a.to === b.to && a.target === b.target
    }

    function scheduleHover(h) {
        if (sameHover(h, pendingHover))
            return
        pendingHover = h
        if (!h || h.type !== "folder" || h.target !== folderTargetIndex)
            folderTargetIndex = -1
        if (h) {
            hoverTimer.interval = h.type === "folder" ? 320 : 170
            hoverTimer.restart()
        } else {
            hoverTimer.stop()
        }
    }

    Timer {
        id: hoverTimer
        onTriggered: {
            var h = rootScope.pendingHover
            if (!h || !rootScope.dragging)
                return
            if (h.type === "folder") {
                rootScope.folderTargetIndex = h.target
                return // continua pendente: sair do centro cancela o alvo
            }
            if (h.type === "move") {
                if (h.to !== rootScope.dragIndex && h.to >= 0 && h.to < appsModel.count) {
                    appsModel.move(rootScope.dragIndex, h.to, 1)
                    rootScope.normalizePages()
                    rootScope.dragIndex = rootScope.findByKey(rootScope.dragKey)
                }
            } else if (h.type === "fmove") {
                if (h.to !== rootScope.folderDragIndex && h.to >= 0 && h.to < folderModel.count) {
                    folderModel.move(rootScope.folderDragIndex, h.to, 1)
                    rootScope.folderDragIndex = h.to
                }
            }
            rootScope.pendingHover = null
        }
    }

    // arrastou para fora da pasta: o app sai dela e o arrasto continua na grade
    Timer {
        id: leaveFolderTimer
        interval: 280
        onTriggered: {
            if (!rootScope.dragging || !rootScope.dragFromFolder || rootScope.dragOutOfFolder)
                return
            var f = folderModel.get(rootScope.folderDragIndex)
            var a = { display: f.display, decoration: f.decoration, appIndex: f.appIndex, favoriteId: f.favoriteId }
            kicker.removeFromFolder(rootScope.folderName, a, -1)
            rootScope.normalizePages()
            rootScope.dragOutOfFolder = true
            rootScope.folderFading = true
            rootScope.dragKey = a.favoriteId ? a.favoriteId : a.display
            rootScope.dragIndex = rootScope.findByKey(rootScope.dragKey)
            var p = rootScope.slotMap[rootScope.dragIndex]
            if (p)
                rootScope.goToPage(p.page)
        }
    }

    Timer {
        id: edgeTimer
        interval: 600
        repeat: true
        onTriggered: {
            if (rootScope.edgeDirection === 0 || (rootScope.dragFromFolder && !rootScope.dragOutOfFolder))
                return
            if (rootScope.edgeDirection > 0 && kicker.currentPage === rootScope.totalPages - 1
                    && rootScope.pageLength(kicker.currentPage) > 0 && rootScope.autoPage < 0) {
                rootScope.addPageAfter(kicker.currentPage)
                rootScope.autoPage = kicker.currentPage + 1
            }
            rootScope.goToPage(kicker.currentPage + rootScope.edgeDirection)
        }
    }

    function dragEnd() {
        hoverTimer.stop()
        edgeTimer.stop()
        leaveFolderTimer.stop()
        edgeDirection = 0
        pendingHover = null

        var landIndex = -1, landKind = "grid"
        if (dragFromFolder && !dragOutOfFolder) {
            kicker.setFolderOrder(folderName, folderApps())
            landIndex = folderDragIndex
            landKind = "folder"
        } else if (folderTargetIndex >= 0 && folderTargetIndex !== dragIndex && dragIndex >= 0) {
            var target = appsModel.get(folderTargetIndex)
            var tKey = keyOf(target)
            if (target.isGroup) {
                kicker.addToFolder(folderTargetIndex, dragIndex)
                normalizePages()
                landIndex = findByKey(tKey)
            } else {
                landIndex = kicker.createFolder(folderTargetIndex, dragIndex)
                normalizePages()
            }
            dragIndex = -1
            ghost.intoFolder = true
        } else {
            normalizePages()
            kicker.saveOrder()
            dragIndex = findByKey(dragKey)
            landIndex = dragIndex
        }
        folderTargetIndex = -1
        cleanupAutoPage()
        if (dragOutOfFolder)
            Qt.callLater(closeFolder)
        dragFromFolder = false
        dragOutOfFolder = false
        land(landKind, landIndex)
    }

    // o fantasma volta para o lugar do item e só então o item reaparece
    function land(kind, index) {
        var item = null
        if (index >= 0)
            item = kind === "folder" ? folderRepeater.itemAt(index) : gridRepeater.itemAt(index)
        landing = true
        ghost.scale = 1
        if (item) {
            var p = item.mapToItem(rootScope, item.iconX, item.iconY)
            landX.to = p.x
            landY.to = p.y
        } else {
            landX.to = ghost.x
            landY.to = ghost.y
        }
        landOpacity.to = ghost.intoFolder ? 0 : 1
        landingAnim.restart()
    }

    ParallelAnimation {
        id: landingAnim
        NumberAnimation { id: landX; target: ghost; property: "x"; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { id: landY; target: ghost; property: "y"; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { id: landOpacity; target: ghost; property: "opacity"; duration: 200 }
        onFinished: {
            rootScope.landing = false
            rootScope.dragIndex = -1
            rootScope.folderDragIndex = -1
            ghost.intoFolder = false
            ghost.opacity = 1
            reflowOff.restart()
        }
    }

    Timer {
        id: reflowOff
        interval: 300
        onTriggered: rootScope.reflowAnim = rootScope.dragging
    }

    // página criada ao arrastar até a borda: some se ficou vazia
    function cleanupAutoPage() {
        if (autoPage >= 0 && autoPage < pageCount && pageLength(autoPage) === 0) {
            var wasOn = kicker.currentPage
            removePage(autoPage)
            if (wasOn >= autoPage)
                goToPage(Math.max(0, autoPage - 1))
        }
        autoPage = -1
    }

    function hideAt(index) {
        reflowAnim = true
        kicker.hideApp(index)
        normalizePages()
        reflowOff.restart()
    }

    // cancela qualquer gesto em andamento (o launcher fechou no meio dele)
    function resetPointer() {
        if (pointerMode === 2)
            dragEnd()
        else if (pointerMode === 1)
            swipeFinish(0, 0)
        pointerMode = 0
        pressCell = null
        landingAnim.complete()
    }

    // --- navegação pelo teclado: setas movem a seleção, Enter abre ---
    property int kbIndex: -1
    readonly property string kbLayer: kicker.activeGroup ? "folder" : (listGeneralActive ? "grid" : "search")
    onKbLayerChanged: kbIndex = kbLayer === "search" ? 0 : -1

    function kbCount() {
        if (kbLayer === "folder")
            return folderModel.count
        if (kbLayer === "search")
            return searchModel ? Math.min(searchModel.count, itemsPerPage) : 0
        return appsModel.count
    }

    function kbCols() {
        return kbLayer === "folder" ? folderCols : gridColumns
    }

    // página e posição do item i; null para quebras de página
    function kbPos(i) {
        if (i < 0 || i >= kbCount())
            return null
        if (kbLayer === "grid") {
            if (slotMap.length !== appsModel.count)
                relayout()
            var p = slotMap[i]
            return p && p.slot >= 0 ? p : null
        }
        if (kbLayer === "folder")
            return { page: Math.floor(i / folderPerPage), slot: i % folderPerPage }
        return { page: 0, slot: i }
    }

    function kbPageLength(p) {
        if (kbLayer === "grid")
            return p >= 0 && p < pageCount ? pageLength(p) : 0
        var per = kbLayer === "folder" ? folderPerPage : itemsPerPage
        return Math.max(0, Math.min(per, kbCount() - p * per))
    }

    function kbIndexAt(p, slot) {
        if (slot < 0 || slot >= kbPageLength(p))
            return -1
        if (kbLayer === "grid")
            return pageStarts[p] + slot
        return p * (kbLayer === "folder" ? folderPerPage : itemsPerPage) + slot
    }

    function moveKb(dx, dy) {
        var n = kbCount()
        if (n === 0)
            return
        var cur = kbPos(kbIndex)
        var cols = kbCols()
        if (!cur) {
            // primeira seta: seleciona o primeiro item da página visível
            var startPage = kbLayer === "folder" ? folderPage : (kbLayer === "grid" ? kicker.currentPage : 0)
            var first = kbIndexAt(startPage, 0)
            for (var f = 0; first < 0 && f < n; f++)
                if (kbPos(f)) first = f
            kbIndex = first
        } else if (dx !== 0) {
            // esquerda/direita seguem a ordem e passam de página
            var next = kbIndex + dx
            while (next >= 0 && next < n && !kbPos(next))
                next += dx
            if (next >= 0 && next < n)
                kbIndex = next
        } else {
            var slot = cur.slot + dy * cols
            var len = kbPageLength(cur.page)
            var target = kbIndexAt(cur.page, slot)
            // descendo para uma linha incompleta: vai para o último item dela
            if (target < 0 && dy > 0 && slot >= len && Math.floor(slot / cols) <= Math.floor((len - 1) / cols))
                target = kbIndexAt(cur.page, len - 1)
            if (target >= 0)
                kbIndex = target
        }
        var p = kbPos(kbIndex)
        if (p) {
            if (kbLayer === "grid" && p.page !== kicker.currentPage)
                goToPage(p.page)
            else if (kbLayer === "folder")
                folderPage = p.page
        }
    }

    function activateKb() {
        var n = kbCount()
        var i = kbIndex
        if (n === 0 || i < 0)
            return false
        if (i >= n)
            i = 0
        var layer = kbLayer
        var it = layer === "grid" ? appsModel.get(i) : null
        var wasGroup = it && it.isGroup
        activate(layer, i)
        if (wasGroup)
            kbIndex = 0
        return true
    }

    function handleNavKey(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            return activateKb()
        // Shift/Ctrl+setas continuam editando o texto da busca
        if (event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier))
            return false
        var dx = event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1 : 0
        var dy = event.key === Qt.Key_Up ? -1 : event.key === Qt.Key_Down ? 1 : 0
        if (dx === 0 && dy === 0)
            return false
        kicker.jiggle = false
        moveKb(dx, dy)
        return true
    }

    // ================= visual =================

    ContextMenu {
        id: contextMenu
        onHideApp: index => rootScope.hideAt(index)
        onAddToFavorites: index => kicker.addToFavorites(index)
        onRenameFolder: index => {
            rootScope.openFolder(index)
            Qt.callLater(function () { folderTitle.forceActiveFocus() })
        }
        onDeleteFolder: index => {
            rootScope.reflowAnim = true
            kicker.deleteFolder(index)
            rootScope.normalizePages()
            reflowOff.restart()
        }
        onEditLayout: kicker.jiggle = true
    }

    Item {
        id: gridRoot
        anchors.fill: parent

        // fundo: deslizar troca de página; clique fecha (ou sai do modo organizar)
        MouseArea {
            anchors.fill: parent
            onPressed: function (mouse) {
                var s = mapToItem(null, mouse.x, mouse.y)
                rootScope.cellPressed(null, "background", -1, s.x, s.y, mouse.button, mouse.x, mouse.y)
            }
            onPositionChanged: function (mouse) {
                var s = mapToItem(null, mouse.x, mouse.y)
                rootScope.cellMoved(s.x, s.y)
            }
            onReleased: function (mouse) {
                var s = mapToItem(null, mouse.x, mouse.y)
                rootScope.cellReleased(s.x, s.y)
            }
            onCanceled: rootScope.cellCanceled()
            onWheel: function (wheel) { rootScope.handleWheel(wheel) }
        }

        // ---- camada 1: grade de apps ----
        Item {
            id: pagesLayer
            x: -kicker.currentPage * rootScope.width + rootScope.swipeOffset
            width: Math.max(1, totalPages) * rootScope.width
            height: gridRows * cellHeight
            visible: listGeneralActive
            opacity: kicker.activeGroup && !folderFading ? 0.12 : 1

            Behavior on x {
                enabled: rootScope.pageAnimEnabled && !rootScope.swiping
                NumberAnimation { id: pageAnim; duration: 380; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Repeater {
                id: gridRepeater
                model: appsModel

                delegate: ListDelegate {
                    id: gridCell
                    readonly property var pos: index < rootScope.slotMap.length ? rootScope.slotMap[index] : null
                    readonly property int page: pos ? pos.page : Math.floor(index / rootScope.itemsPerPage)
                    readonly property int slot: pos ? Math.max(0, pos.slot) : index % rootScope.itemsPerPage
                    readonly property bool isDragged: index === rootScope.dragIndex

                    width: rootScope.cellWidth
                    height: rootScope.cellHeight
                    x: page * rootScope.width + rootScope.marginPage + (slot % rootScope.gridColumns) * rootScope.cellWidth
                    y: Math.floor(slot / rootScope.gridColumns) * rootScope.cellHeight
                    visible: model.isBreak !== true && ((page >= rootScope.visLo && page <= rootScope.visHi) || isDragged)
                    enabled: !kicker.activeGroup

                    Behavior on x {
                        enabled: rootScope.reflowAnim && !gridCell.isDragged
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        enabled: rootScope.reflowAnim && !gridCell.isDragged
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                    }

                    kind: "grid"
                    itemIndex: index
                    name: model.display || ""
                    iconSource: model.decoration
                    isGroup: model.isGroup === true
                    preview: model.modelGroup
                    iconSize: rootScope.iconSize
                    textShadow: rootScope.textShadow
                    selected: rootScope.kbLayer === "grid" && rootScope.kbIndex === index
                    placeholder: isDragged && (rootScope.dragging || rootScope.landing)
                    folderTarget: rootScope.folderTargetIndex === index
                    jiggleAngle: rootScope.jiggleOn && visible && !isDragged ? rootScope.jigglePhase * (index % 2 ? 1.6 : -1.6) : 0
                    showClose: rootScope.jiggleOn && visible && !isGroup && !isDragged

                    onPointerPressed: (c, sx, sy, b, lx, ly) => rootScope.cellPressed(c, "grid", index, sx, sy, b, lx, ly)
                    onPointerMoved: (sx, sy) => rootScope.cellMoved(sx, sy)
                    onPointerReleased: (sx, sy) => rootScope.cellReleased(sx, sy)
                    onPointerCanceled: rootScope.cellCanceled()
                    onPointerHeld: rootScope.cellHeld()
                    onCloseClicked: rootScope.hideAt(index)
                }
            }
        }

        // ---- camada 2: resultados da busca ----
        Item {
            id: searchLayer
            width: rootScope.width
            height: gridRows * cellHeight
            visible: !listGeneralActive

            Repeater {
                model: listGeneralActive ? null : rootScope.searchModel
                delegate: ListDelegate {
                    width: rootScope.cellWidth
                    height: rootScope.cellHeight
                    x: rootScope.marginPage + (index % rootScope.gridColumns) * rootScope.cellWidth
                    y: Math.floor(index / rootScope.gridColumns) * rootScope.cellHeight
                    visible: index < rootScope.itemsPerPage
                    kind: "search"
                    itemIndex: index
                    name: model.display || ""
                    iconSource: model.decoration
                    iconSize: rootScope.iconSize
                    textShadow: rootScope.textShadow
                    selected: rootScope.kbLayer === "search" && rootScope.kbIndex === index

                    onPointerPressed: (c, sx, sy, b, lx, ly) => rootScope.cellPressed(c, "search", index, sx, sy, b, lx, ly)
                    onPointerMoved: (sx, sy) => rootScope.cellMoved(sx, sy)
                    onPointerReleased: (sx, sy) => rootScope.cellReleased(sx, sy)
                    onPointerCanceled: rootScope.cellCanceled()
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: rootScope.cellHeight
                visible: kicker.searchActive && (!rootScope.searchModel || rootScope.searchModel.count === 0)
                text: Utils.tr("No results")
                color: Kirigami.Theme.textColor
                opacity: 0.6
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4
            }
        }

        // ---- camada 3: pasta aberta ----
        Item {
            id: folderLayer
            anchors.fill: parent
            opacity: kicker.activeGroup && !rootScope.folderFading ? 1 : 0
            visible: opacity > 0 || rootScope.folderDragIndex >= 0

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            // clique fora da pasta fecha
            MouseArea {
                anchors.fill: parent
                enabled: kicker.activeGroup && !rootScope.folderFading
                onClicked: {
                    if (kicker.jiggle)
                        kicker.jiggle = false
                    else
                        rootScope.closeFolder()
                }
                onWheel: function (wheel) {
                    var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                    if (d < 0 && rootScope.folderPage < rootScope.folderPages - 1)
                        rootScope.folderPage++
                    else if (d > 0 && rootScope.folderPage > 0)
                        rootScope.folderPage--
                    wheel.accepted = true
                }
            }

            Rectangle {
                id: folderPanel
                readonly property int pad: 24
                width: rootScope.folderCols * rootScope.cellWidth + pad * 2
                height: rootScope.folderRows * rootScope.cellHeight + pad * 2
                x: Math.round((rootScope.width - width) / 2)
                y: Math.max(64, Math.round((rootScope.gridRows * rootScope.cellHeight - height) / 2))
                radius: 28
                color: Qt.rgba(kicker.bgColor.r, kicker.bgColor.g, kicker.bgColor.b, 0.82)
                border.width: 1
                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)
                scale: kicker.activeGroup && !rootScope.folderFading ? 1 : 0.9

                Behavior on scale {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                // cliques dentro do painel não fecham a pasta
                MouseArea {
                    anchors.fill: parent
                    enabled: kicker.activeGroup
                }

                Repeater {
                    id: folderRepeater
                    model: folderModel
                    delegate: ListDelegate {
                        id: folderCell
                        readonly property int fPage: Math.floor(index / rootScope.folderPerPage)
                        readonly property int fSlot: index % rootScope.folderPerPage
                        readonly property bool isDragged: index === rootScope.folderDragIndex

                        width: rootScope.cellWidth
                        height: rootScope.cellHeight
                        x: folderPanel.pad + (fSlot % rootScope.folderCols) * rootScope.cellWidth
                        y: folderPanel.pad + Math.floor(fSlot / rootScope.folderCols) * rootScope.cellHeight
                        visible: fPage === rootScope.folderPage || isDragged

                        Behavior on x {
                            enabled: rootScope.reflowAnim && !folderCell.isDragged
                            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                        }
                        Behavior on y {
                            enabled: rootScope.reflowAnim && !folderCell.isDragged
                            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                        }

                        kind: "folder"
                        itemIndex: index
                        name: model.display || ""
                        iconSource: model.decoration
                        iconSize: rootScope.iconSize
                        textShadow: rootScope.textShadow
                        selected: rootScope.kbLayer === "folder" && rootScope.kbIndex === index
                        placeholder: isDragged && (rootScope.dragging || rootScope.landing)

                        onPointerPressed: (c, sx, sy, b, lx, ly) => rootScope.cellPressed(c, "folder", index, sx, sy, b, lx, ly)
                        onPointerMoved: (sx, sy) => rootScope.cellMoved(sx, sy)
                        onPointerReleased: (sx, sy) => rootScope.cellReleased(sx, sy)
                        onPointerCanceled: rootScope.cellCanceled()
                        onPointerHeld: rootScope.cellHeld()
                    }
                }
            }

            // bolinhas de página da pasta (só com muitos apps)
            QQC2.PageIndicator {
                id: folderIndicator
                visible: rootScope.folderPages > 1
                count: rootScope.folderPages
                currentIndex: rootScope.folderPage
                anchors.horizontalCenter: folderPanel.horizontalCenter
                anchors.top: folderPanel.bottom
                anchors.topMargin: 10
                MouseArea {
                    anchors.fill: parent
                    onClicked: mouse => rootScope.folderPage = Math.floor(mouse.x / (folderIndicator.width / folderIndicator.count))
                }
            }

            // nome da pasta em cima (como no macOS); clique para renomear
            QQC2.TextField {
                id: folderTitle
                width: Math.max(folderPanel.width, 360)
                anchors.bottom: folderPanel.top
                anchors.bottomMargin: 14
                anchors.horizontalCenter: folderPanel.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                leftPadding: 12
                rightPadding: 12
                font.pixelSize: 28
                font.weight: Font.Medium
                color: Kirigami.Theme.textColor
                selectByMouse: true
                maximumLength: 40
                enabled: kicker.activeGroup && !rootScope.folderFading
                background: Rectangle {
                    radius: 10
                    color: folderTitle.activeFocus ? Qt.rgba(kicker.bgColor.r, kicker.bgColor.g, kicker.bgColor.b, 0.7) : "transparent"
                    border.width: folderTitle.activeFocus ? 1 : 0
                    border.color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.7)
                }

                onActiveFocusChanged: {
                    if (activeFocus)
                        selectAll()
                }
                // Enter confirma; clicar fora ou fechar a pasta também
                onAccepted: searchEntry.forceActiveFocus()
                onEditingFinished: {
                    if (kicker.parentGroupIndex < 0)
                        return
                    if (kicker.renameFolder(kicker.parentGroupIndex, text))
                        rootScope.folderName = text.trim()
                    text = rootScope.folderName
                }
            }
        }

        // ---- bolinhas de página; + e − aparecem no modo organizar ----
        Item {
            id: pageControls
            y: rootScope.gridRows * rootScope.cellHeight + 16
            width: rootScope.width
            height: 28
            visible: listGeneralActive && !kicker.activeGroup && (totalPages > 1 || kicker.jiggle)

            QQC2.PageIndicator {
                id: pageIndicator
                anchors.centerIn: parent
                count: totalPages
                currentIndex: kicker.currentPage
                MouseArea {
                    anchors.fill: parent
                    onClicked: mouse => rootScope.goToPage(Math.floor(mouse.x / (pageIndicator.width / pageIndicator.count)))
                }
            }

            QQC2.ToolButton {
                visible: kicker.jiggle
                enabled: totalPages > 1 && rootScope.pageLength(kicker.currentPage) === 0
                icon.name: "list-remove"
                display: QQC2.AbstractButton.IconOnly
                flat: true
                width: 28
                height: 28
                opacity: enabled ? (hovered ? 1 : 0.7) : 0.25
                anchors.right: pageIndicator.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: rootScope.pageLength(kicker.currentPage) === 0 ? Utils.tr("Remove this page") : Utils.tr("Move the apps off this page to remove it")
                onClicked: {
                    var p = kicker.currentPage
                    if (rootScope.removePage(p))
                        rootScope.goToPage(Math.max(0, p - 1))
                }
            }

            QQC2.ToolButton {
                visible: kicker.jiggle
                icon.name: "list-add"
                display: QQC2.AbstractButton.IconOnly
                flat: true
                width: 28
                height: 28
                opacity: hovered ? 1 : 0.7
                anchors.left: pageIndicator.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: Utils.tr("Add page")
                onClicked: {
                    rootScope.addPageAfter(kicker.currentPage)
                    rootScope.goToPage(kicker.currentPage + 1)
                }
            }
        }

        // botão "Concluído" do modo organizar
        QQC2.Button {
            visible: kicker.jiggle && listGeneralActive && !kicker.activeGroup
            text: Utils.tr("Done")
            anchors.right: parent.right
            anchors.rightMargin: rootScope.marginPage
            y: rootScope.gridRows * rootScope.cellHeight + 12
            onClicked: kicker.jiggle = false
        }
    }

    // fantasma do ícone arrastado: segue o mouse por cima de tudo
    Item {
        id: ghost
        property bool isGroup: false
        property var source
        property var preview: null
        property bool intoFolder: false
        z: 1000
        width: rootScope.iconSize
        height: rootScope.iconSize
        visible: rootScope.dragging || rootScope.landing

        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Loader {
            active: ghost.visible && ghost.isGroup
            sourceComponent: FolderIcon {
                size: rootScope.iconSize
                preview: ghost.preview
            }
        }
        Kirigami.Icon {
            visible: !ghost.isGroup
            anchors.fill: parent
            source: ghost.visible && !ghost.isGroup ? ghost.source : ""
            animated: false
        }
    }
}
