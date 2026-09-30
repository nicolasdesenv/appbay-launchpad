import QtQuick
import QtCore
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "Utils.js" as Utils

PlasmoidItem {
  id: kicker

  Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground
  preferredRepresentation: compactRepresentation

  // --- estado da interface (compartilhado com Dashboard/AppList) ---
  property bool searchActive: false
  property string listActive: "generalList" // "searchList"
  property bool activeGroup: false          // pasta aberta
  property int parentGroupIndex: -1         // índice da pasta aberta no appsModel
  property bool jiggle: false               // modo de organizar (ícones tremendo)
  property int currentPage: 0
  property int modelRevision: 0             // muda a cada generateModel()
  property color bgColor: Kirigami.Theme.backgroundColor
  property QtObject globalFavorites: rootModel.favoritesModel

  readonly property int gridColumns: Utils.clamp(Plasmoid.configuration.gridColumns || 7, 3, 12)
  readonly property int gridRows: Utils.clamp(Plasmoid.configuration.gridRows || 5, 2, 8)

  // --- dados salvos ---
  property var subModel: []      // pastas: [{displayGrupName, indexInModel, isGroup, elements: [{display, favoriteId, appIndex}]}]
  property var hiddenApps: []    // nomes dos apps ocultos
  property var appOrder: []      // ordem personalizada; vazia = alfabética
  property var hiddenAppsConfigs: Plasmoid.configuration.hiddenApps
  property bool changingHidden: false

  // apps atuais, por id (storageId) e por nome; categoria por id
  property var appById: ({})
  property var appByName: ({})
  property var appCategory: ({})

  // papel do modelo do Kicker com o id do .desktop (ex.: org.kde.konsole.desktop)
  readonly property int favoriteIdRole: Qt.UserRole + 3

  ListModel {
    id: appsModel
  }

  Settings {
    id: appBaySettings
    category: "AppBay"
    property var configHiddenApps: []
    // string declarada: gravar por setValue() numa chave que também é propriedade
    // fazia o Settings sobrescrever as pastas com o valor vazio ao fechar o Plasma
    property string configSubModelJson: ""
    property string configAppOrderJson: ""
  }

  // --- itens do appsModel ---

  // quebra de página (item invisível); permite páginas vazias ou com poucos apps
  function breakItem(id) {
    return { display: "", isGroup: false, isBreak: true, appIndex: -1, breakId: id, favoriteId: "" }
  }

  function appItem(a) {
    return { display: a.display, decoration: a.decoration, appIndex: a.appIndex, favoriteId: a.favoriteId, isGroup: false, isBreak: false }
  }

  // miniaturas da pasta (até 9, grade 3x3 como no macOS)
  function folderPreview(apps) {
    var p = []
    for (var i = 0; i < apps.length && i < 9; i++)
      p.push({ decoration: apps[i].decoration })
    return p
  }

  function groupItem(name, apps) {
    return { display: name, isGroup: true, isBreak: false, appIndex: -1, favoriteId: "", modelGroup: folderPreview(apps) }
  }

  function orderKey(item) {
    if (item.isBreak === true)
      return "break:" + item.breakId
    if (item.isGroup)
      return "group:" + item.display
    return item.favoriteId ? item.favoriteId : item.display
  }

  // app atual correspondente a um elemento salvo (pastas antigas só têm o nome)
  function resolveApp(el) {
    if (!el)
      return null
    if (el.favoriteId && appById[el.favoriteId])
      return appById[el.favoriteId]
    if (el.display && appByName[el.display])
      return appByName[el.display]
    if (el.favoriteId && appByName[el.favoriteId])
      return appByName[el.favoriteId]
    return null
  }

  function resolveGroup(g) {
    var out = []
    for (var e = 0; e < g.elements.length; e++) {
      var a = resolveApp(g.elements[e])
      if (a)
        out.push(a)
    }
    return out
  }

  function elementOf(a) {
    return { display: a.display, favoriteId: a.favoriteId, appIndex: a.appIndex }
  }

  // --- salvar ---

  function saveOrder() {
    var keys = []
    var nb = 0
    for (var i = 0; i < appsModel.count; i++) {
      if (appsModel.get(i).isBreak === true)
        appsModel.setProperty(i, "breakId", nb++)
      keys.push(orderKey(appsModel.get(i)))
    }
    appOrder = keys
    appBaySettings.configAppOrderJson = JSON.stringify(keys)
    appBaySettings.sync()
  }

  function saveSubModel() {
    appBaySettings.configSubModelJson = JSON.stringify(subModel)
    appBaySettings.sync()
  }

  function loadSettings() {
    try {
      var groups = appBaySettings.configSubModelJson
      subModel = groups ? JSON.parse(groups) : []
      if (!Array.isArray(subModel))
        subModel = []
    } catch (e) {
      subModel = []
    }
    for (var g = 0; g < subModel.length; g++)
      if (!Array.isArray(subModel[g].elements))
        subModel[g].elements = []

    var hidden = appBaySettings.value("configHiddenApps")
    if (hidden)
      hiddenApps = typeof hidden === "string" ? [hidden] : hidden

    try {
      var order = appBaySettings.configAppOrderJson
      appOrder = order ? JSON.parse(order) : []
    } catch (e) {
      appOrder = []
    }
  }

  // --- montar a lista (O(n log n); roda ao iniciar e quando apps mudam) ---

  function generateModel() {
    if (!rootModel || rootModel.count === 0)
      return
    var apps = rootModel.modelForRow(0)
    if (!apps)
      return

    var byId = {}, byName = {}, list = []
    for (var i = 0; i < apps.count; i++) {
      var ix = apps.index(i, 0)
      var a = {
        appIndex: i,
        display: apps.data(ix, Qt.DisplayRole),
        decoration: apps.data(ix, Qt.DecorationRole),
        favoriteId: String(apps.data(ix, favoriteIdRole) || "")
      }
      list.push(a)
      if (a.favoriteId)
        byId[a.favoriteId] = a
      if (!byName[a.display])
        byName[a.display] = a
    }
    appById = byId
    appByName = byName

    // categorias do menu (Jogos, Desenvolvimento...) para nomear pastas novas
    var cat = {}
    for (var r = 1; r < rootModel.count; r++) {
      var m = rootModel.modelForRow(r)
      if (!m || m.count === undefined)
        continue
      var cname = rootModel.data(rootModel.index(r, 0), Qt.DisplayRole)
      for (var j = 0; j < m.count; j++) {
        var id = String(m.data(m.index(j, 0), favoriteIdRole) || "")
        if (id && cat[id] === undefined)
          cat[id] = cname
      }
    }
    appCategory = cat

    var hidden = {}
    for (var h = 0; h < hiddenApps.length; h++)
      hidden[hiddenApps[h]] = true

    var grouped = {}, groups = []
    for (var g = 0; g < subModel.length; g++) {
      var members = resolveGroup(subModel[g])
      if (members.length === 0)
        continue
      for (var k = 0; k < members.length; k++)
        grouped[members[k].appIndex] = true
      groups.push({ pos: subModel[g].indexInModel || 0, item: groupItem(subModel[g].displayGrupName, members) })
    }

    var items = []
    for (var n = 0; n < list.length; n++) {
      if (hidden[list[n].display] || grouped[list[n].appIndex])
        continue
      items.push(appItem(list[n]))
    }
    for (var q = 0; q < groups.length; q++)
      items.splice(Math.min(groups[q].pos, items.length), 0, groups[q].item)

    if (appOrder.length > 0) {
      var rank = {}
      for (var o = 0; o < appOrder.length; o++) {
        var key = String(appOrder[o])
        rank[key] = o
        if (key.indexOf("break:") === 0)
          items.push(breakItem(parseInt(key.substring(6))))
      }
      // apps sem posição salva (instalados depois) vão para o final, como no macOS
      var big = appOrder.length + 100000
      for (var t = 0; t < items.length; t++) {
        var it = items[t]
        var rk = rank[orderKey(it)]
        if (rk === undefined && !it.isGroup && !it.isBreak)
          rk = rank[it.display] // ordem salva por versões antigas (pelo nome)
        it._rank = rk === undefined ? big + t : rk
      }
      items.sort(function (x, y) { return x._rank - y._rank })
      for (var c = 0; c < items.length; c++)
        delete items[c]._rank
    }

    appsModel.clear()
    appsModel.append(items)
    modelRevision++
  }

  // --- pastas ---

  function findGroup(name) {
    for (var i = 0; i < subModel.length; i++)
      if (subModel[i].displayGrupName === name)
        return i
    return -1
  }

  function groupApps(name) {
    var g = findGroup(name)
    return g < 0 ? [] : resolveGroup(subModel[g])
  }

  function appFromItem(it) {
    return { display: it.display, decoration: it.decoration, appIndex: it.appIndex, favoriteId: it.favoriteId }
  }

  function uniqueFolderName(base) {
    var name = base, n = 2
    while (findGroup(name) >= 0)
      name = base + " " + n++
    return name
  }

  // nome da pasta pela categoria dos apps (como o macOS faz)
  function autoFolderName(a, b) {
    var ca = appCategory[a.favoriteId], cb = appCategory[b.favoriteId]
    return ca || cb || Utils.tr("Folder")
  }

  function refreshFolderItem(index) {
    var it = appsModel.get(index)
    if (it && it.isGroup)
      appsModel.set(index, { modelGroup: folderPreview(groupApps(it.display)) })
  }

  // solta o app `dragged` no centro do app `target`: cria a pasta no lugar do alvo.
  // Devolve o índice final da pasta.
  function createFolder(targetIdx, draggedIdx) {
    var t = appsModel.get(targetIdx), d = appsModel.get(draggedIdx)
    if (!t || !d || t.isGroup || d.isGroup || t.isBreak || d.isBreak || targetIdx === draggedIdx)
      return -1
    var ta = appFromItem(t), da = appFromItem(d)
    var name = uniqueFolderName(autoFolderName(ta, da))
    var sm = subModel.slice()
    sm.push({ displayGrupName: name, indexInModel: targetIdx, isGroup: true, elements: [elementOf(ta), elementOf(da)] })
    subModel = sm
    appsModel.set(targetIdx, groupItem(name, [ta, da]))
    appsModel.remove(draggedIdx, 1)
    saveSubModel()
    saveOrder()
    return draggedIdx < targetIdx ? targetIdx - 1 : targetIdx
  }

  function addToFolder(groupIdx, draggedIdx) {
    var gItem = appsModel.get(groupIdx), d = appsModel.get(draggedIdx)
    if (!gItem || !d || !gItem.isGroup || d.isGroup || d.isBreak)
      return
    var g = findGroup(gItem.display)
    if (g < 0)
      return
    subModel[g].elements.push(elementOf(appFromItem(d)))
    refreshFolderItem(groupIdx)
    appsModel.remove(draggedIdx, 1)
    saveSubModel()
    saveOrder()
  }

  function sameApp(el, a) {
    return (el.favoriteId && el.favoriteId === a.favoriteId) || el.display === a.display
  }

  function groupIndexInModel(name) {
    for (var i = 0; i < appsModel.count; i++) {
      var it = appsModel.get(i)
      if (it.isGroup && it.display === name)
        return i
    }
    return -1
  }

  // tira o app `a` da pasta `name` e coloca na grade em `insertAt` (-1 = logo depois da pasta).
  // Pasta que fica com um app só vira esse app, como no macOS.
  function removeFromFolder(name, a, insertAt) {
    var g = findGroup(name)
    if (g < 0)
      return
    var els = subModel[g].elements
    for (var e = 0; e < els.length; e++) {
      if (sameApp(els[e], a)) {
        els.splice(e, 1)
        break
      }
    }
    var gIdx = groupIndexInModel(name)
    var left = resolveGroup(subModel[g])
    if (left.length <= 1) {
      var sm = subModel.slice()
      sm.splice(g, 1)
      subModel = sm
      if (gIdx >= 0) {
        if (left.length === 1)
          appsModel.set(gIdx, appItem(left[0]))
        else
          appsModel.remove(gIdx, 1)
      }
    } else if (gIdx >= 0) {
      refreshFolderItem(gIdx)
    }
    if (insertAt < 0 || insertAt > appsModel.count)
      insertAt = gIdx >= 0 ? Math.min(gIdx + 1, appsModel.count) : appsModel.count
    appsModel.insert(insertAt, appItem(a))
    saveSubModel()
    saveOrder()
  }

  // desfaz a pasta: os apps voltam para a grade no lugar dela
  function deleteFolder(index) {
    var it = appsModel.get(index)
    if (!it || !it.isGroup)
      return
    var name = it.display
    var members = groupApps(name)
    var g = findGroup(name)
    if (g >= 0) {
      var sm = subModel.slice()
      sm.splice(g, 1)
      subModel = sm
    }
    appsModel.remove(index, 1)
    var items = []
    for (var m = 0; m < members.length; m++)
      items.push(appItem(members[m]))
    if (items.length > 0)
      appsModel.insert(index, items)
    saveSubModel()
    saveOrder()
  }

  // as pastas são identificadas pelo nome: não aceita vazio nem nome repetido
  function renameFolder(index, newName) {
    var it = appsModel.get(index)
    newName = String(newName).trim()
    if (!it || !it.isGroup || newName === "" || newName === it.display || findGroup(newName) >= 0)
      return false
    var g = findGroup(it.display)
    if (g >= 0)
      subModel[g].displayGrupName = newName
    appsModel.setProperty(index, "display", newName)
    saveSubModel()
    saveOrder()
    return true
  }

  // ordem dos apps dentro da pasta (depois de arrastar lá dentro)
  function setFolderOrder(name, apps) {
    var g = findGroup(name)
    if (g < 0)
      return
    var els = []
    for (var i = 0; i < apps.length; i++)
      els.push(elementOf(apps[i]))
    subModel[g].elements = els
    var k = groupIndexInModel(name)
    if (k >= 0)
      refreshFolderItem(k)
    saveSubModel()
  }

  // --- apps ocultos ---

  function hideApp(index) {
    var it = appsModel.get(index)
    if (!it || it.isGroup || it.isBreak)
      return
    var list = hiddenApps.slice()
    if (list.indexOf(it.display) < 0)
      list.push(it.display)
    appsModel.remove(index, 1)
    hiddenApps = list
    changingHidden = true
    Plasmoid.configuration.hiddenApps = list
    changingHidden = false
    appBaySettings.configHiddenApps = list
    saveOrder()
  }

  // lista alterada nas configurações (mostrar app de novo): remonta a grade
  onHiddenAppsConfigsChanged: {
    if (changingHidden)
      return
    hiddenApps = hiddenAppsConfigs ? Array.prototype.slice.call(hiddenAppsConfigs) : []
    appBaySettings.configHiddenApps = hiddenApps
    Qt.callLater(generateModel)
  }

  function addToFavorites(index) {
    var it = appsModel.get(index)
    if (it && it.favoriteId && globalFavorites)
      globalFavorites.addFavorite("applications:" + it.favoriteId)
  }

  function launchApp(appIndex) {
    var apps = rootModel.modelForRow(0)
    if (apps && appIndex >= 0)
      apps.trigger(appIndex, "", null)
  }

  // --- modelos do Kicker ---
  Kicker.RootModel {
    id: rootModel
    // linha 0 = todos os apps; as outras linhas são as categorias
    autoPopulate: false
    appNameFormat: 0
    flat: true
    sorted: true
    showSeparators: false
    appletInterface: kicker
    showAllApps: true
    showRecentApps: false
    showRecentDocs: false
    showPowerSession: false

    // callLater junta as duas notificações numa montagem só
    onCountChanged: {
      if (count > 0)
        Qt.callLater(kicker.generateModel)
    }
    // apps instalados/removidos sem mudar o número de categorias
    onRefreshed: Qt.callLater(kicker.generateModel)

    Component.onCompleted: {
      favoritesModel.initForClient("org.kde.plasma.kicker.favorites.instance-" + Plasmoid.id)
    }
  }

  Kicker.RunnerModel {
    id: runnerModel
    appletInterface: kicker
    favoritesModel: globalFavorites
    runners: ["krunner_services", "krunner_systemsettings", "krunner_sessions",
      "krunner_powerdevil", "calculator", "unitconverter"]
  }

  compactRepresentation: CompactRepresentation {}

  fullRepresentation: compactRepresentation

  Component.onCompleted: {
    loadSettings()
    changingHidden = true
    Plasmoid.configuration.hiddenApps = hiddenApps
    changingHidden = false
    rootModel.refresh()
  }
}
