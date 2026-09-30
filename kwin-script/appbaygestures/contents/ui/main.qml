import QtQuick
import org.kde.kwin

// Pinça de 4 dedos no touchpad, como no macOS: juntar os dedos abre o launcher,
// abrir os dedos fecha. O id do widget é gravado pelo instalar.sh em
// kwinrc [Script-appbaygestures] WidgetId.
Item {
    id: root

    readonly property int widgetId: KWin.readConfig("WidgetId", 0)

    // janela do launcher: tela cheia do plasmashell, sem borda
    function launcherOpen() {
        const list = Workspace.stackingOrder
        for (let i = 0; i < list.length; i++) {
            const w = list[i]
            if (w.resourceClass === "org.kde.plasmashell" && w.fullScreen && w.normalWindow && !w.minimized)
                return true
        }
        return false
    }

    function toggle() {
        if (root.widgetId > 0)
            launcherCall.call()
    }

    DBusCall {
        id: launcherCall
        service: "org.kde.kglobalaccel"
        path: "/component/plasmashell"
        dbusInterface: "org.kde.kglobalaccel.Component"
        method: "invokeShortcut"
        arguments: ["activate widget " + root.widgetId]
    }

    PinchGestureHandler {
        direction: PinchGestureHandler.Direction.Contracting
        fingerCount: 4
        onActivated: {
            if (!root.launcherOpen())
                root.toggle()
        }
    }

    PinchGestureHandler {
        direction: PinchGestureHandler.Direction.Expanding
        fingerCount: 4
        onActivated: {
            if (root.launcherOpen())
                root.toggle()
        }
    }
}
