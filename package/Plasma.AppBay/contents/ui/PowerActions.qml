import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.private.sessions as Sessions
import org.kde.kirigami as Kirigami
import "Utils.js" as Utils

Row {
    id: actions

    property int iconsSize: 24
    spacing: 8

    function run(action) {
        if (action === "shutdown")
            sm.requestShutdown()
        else if (action === "restart")
            sm.requestRestart()
        else if (action === "lock")
            sessionsModel.startNewSession(sessionsModel.shouldLock)
        else if (action === "logout")
            sm.requestLogoutPrompt()
    }

    Sessions.SessionManagement {
        id: sm
    }

    Sessions.SessionsModel {
        id: sessionsModel
    }

    Repeater {
        model: [
            { icon: "system-shutdown", label: "Shut Down", action: "shutdown" },
            { icon: "system-reboot", label: "Restart", action: "restart" },
            { icon: "system-lock-screen", label: "Lock", action: "lock" },
            { icon: "system-log-out", label: "Log Out", action: "logout" }
        ]
        delegate: Kirigami.Icon {
            width: actions.iconsSize
            height: actions.iconsSize
            source: modelData.icon
            opacity: hover.containsMouse ? 1 : 0.75
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                onClicked: actions.run(modelData.action)
            }
            QQC2.ToolTip.visible: hover.containsMouse
            QQC2.ToolTip.text: Utils.tr(modelData.label)
        }
    }
}
