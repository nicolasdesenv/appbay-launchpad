/*****************************************************************************
 *   Copyright (C) 2013-2014 by Eike Hein <hein@kde.org>                     *
 *   Copyright (C) 2021 by Prateek SU <pankajsunal123@gmail.com>             *
 *   Copyright (C) 2022 by Friedrich Schriewer <friedrich.schriewer@gmx.net> *
 *                                                                           *
 *   This program is free software; you can redistribute it and/or modify    *
 *   it under the terms of the GNU General Public License as published by    *
 *   the Free Software Foundation; either version 2 of the License, or       *
 *   (at your option) any later version.                                     *
 *                                                                           *
 *   This program is distributed in the hope that it will be useful,         *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of          *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           *
 *   GNU General Public License for more details.                            *
 *                                                                           *
 *   You should have received a copy of the GNU General Public License       *
 *   along with this program; if not, write to the                           *
 *   Free Software Foundation, Inc.,                                         *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .          *
 ****************************************************************************/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.draganddrop 2.0 as DragDrop
import org.kde.kirigami 2.3 as Kirigami

import org.kde.ksvg 1.0 as KSvg
import org.kde.plasma.plasmoid
import org.kde.kcmutils as KCM

import org.kde.iconthemes as KIconThemes
import "Utils.js" as Utils


KCM.SimpleKCM {
    id: configGeneral

    QtObject {
        id: hiddenList
        property var apps: []
    }
    property var arrayHiddenApps
    property string cfg_icon: Plasmoid.configuration.icon
    property bool cfg_useCustomButtonImage: Plasmoid.configuration.useCustomButtonImage
    property string cfg_customButtonImage: Plasmoid.configuration.customButtonImage
    property alias cfg_dockF: dock.checked
    property alias cfg_iconSize: gridAndIcon.iconSize
    property alias cfg_gridColumns: gridColumns.value
    property alias cfg_gridRows: gridRows.value
    property alias cfg_enabledShadow: enabledShadow.checked
    property alias cfg_hiddenApps: hiddenList.apps
    property alias cfg_systemActionsButtons: systemActionsButtons.checked

    QtObject {
        id: gridAndIcon
        property int iconSize
    }

    Settings {
        id: appBaySettings
        category: "AppBay"
    }

    Kirigami.FormLayout {

        width: parent.width

        Button {
            id: iconButton

            Kirigami.FormData.label: Utils.tr("Icon:")

            implicitWidth: previewFrame.width + Kirigami.Units.smallSpacing * 2
            implicitHeight: previewFrame.height + Kirigami.Units.smallSpacing * 2

            // Just to provide some visual feedback when dragging;
            // cannot have checked without checkable enabled
            checkable: true
            checked: dropArea.containsAcceptableDrag

            onPressed: iconMenu.opened ? iconMenu.close() : iconMenu.open()

            DragDrop.DropArea {
                id: dropArea

                property bool containsAcceptableDrag: false

                anchors.fill: parent

                onDragEnter: {
                    // Cannot use string operations (e.g. indexOf()) on "url" basic type.
                    var urlString = event.mimeData.url.toString();

                    // This list is also hardcoded in KIconDialog.
                    var extensions = [".png", ".xpm", ".svg", ".svgz"];
                    containsAcceptableDrag = urlString.indexOf("file:///") === 0 && extensions.some(function (extension) {
                        return urlString.indexOf(extension) === urlString.length - extension.length; // "endsWith"
                    });

                    if (!containsAcceptableDrag) {
                        event.ignore();
                    }
                }
                onDragLeave: containsAcceptableDrag = false

                onDrop: {
                    if (containsAcceptableDrag) {
                        // Strip file:// prefix, we already verified in onDragEnter that we have only local URLs.
                        iconDialog.setCustomButtonImage(event.mimeData.url.toString().substr("file://".length));
                    }
                    containsAcceptableDrag = false;
                }
            }

            KIconThemes.IconDialog {
                id: iconDialog

                function setCustomButtonImage(image) {
                    configGeneral.cfg_customButtonImage = image || configGeneral.cfg_icon || "start-here-kde-symbolic"
                    configGeneral.cfg_useCustomButtonImage = true;
                }

                onIconNameChanged: setCustomButtonImage(iconName);
            }

            KSvg.FrameSvgItem {
                id: previewFrame
                anchors.centerIn: parent
                imagePath: Plasmoid.location === PlasmaCore.Types.Vertical || Plasmoid.location === PlasmaCore.Types.Horizontal
                ? "widgets/panel-background" : "widgets/background"
                width: Kirigami.Units.iconSizes.large + fixedMargins.left + fixedMargins.right
                height: Kirigami.Units.iconSizes.large + fixedMargins.top + fixedMargins.bottom

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.large
                    height: width
                    source: configGeneral.cfg_useCustomButtonImage ? configGeneral.cfg_customButtonImage : configGeneral.cfg_icon
                }
            }

            Menu {
                id: iconMenu

                // Appear below the button
                y: +parent.height

                onClosed: iconButton.checked = false;

                MenuItem {
                    text: Utils.tr("Choose…")
                    icon.name: "document-open-folder"
                    onClicked: iconDialog.open()
                }
                MenuItem {
                    text: Utils.tr("Clear Icon")
                    icon.name: "edit-clear"
                    onClicked: {
                        configGeneral.cfg_icon = "appbay-launchpad"
                        configGeneral.cfg_useCustomButtonImage = false
                    }
                }
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }
        CheckBox {
            id: dock
            Kirigami.FormData.label: Utils.tr("Favorites dock")
        }
        CheckBox {
            id: enabledShadow
            Kirigami.FormData.label: Utils.tr("Text shadow")
        }
        CheckBox {
            id: systemActionsButtons
            Kirigami.FormData.label: Utils.tr("System actions")
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Utils.tr("Grid and icons")
        }

        SpinBox {
            id: gridColumns
            Kirigami.FormData.label: Utils.tr("Columns:")
            from: 3
            to: 12
        }
        SpinBox {
            id: gridRows
            Kirigami.FormData.label: Utils.tr("Rows:")
            from: 2
            to: 8
        }

        ComboBox {
            id: iconSize
            Kirigami.FormData.label: Utils.tr("Icon size:")
            model: [48, 64, 72, 88, 96, 112, 128]
            onActivated: gridAndIcon.iconSize = currentValue
            Component.onCompleted: {
                var idx = model.indexOf(gridAndIcon.iconSize)
                currentIndex = idx >= 0 ? idx : 3
            }
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Utils.tr("Hidden apps")
        }

        Repeater {
            id: repeater
            model: hiddenList.apps

            delegate: Button {
                Kirigami.FormData.label: modelData
                id: restoreButton
                text: Utils.tr("Show")
                icon.name: "view-visible"
                onClicked: {
                    hiddenList.apps.splice(index,1)
                    hiddenList.apps = hiddenList.apps.slice() // força a atualização
                }
            }
        }
        Label {
            visible: hiddenList.apps.length === 0
            text: Utils.tr("No hidden apps")
            opacity: 0.7
        }

        Component.onCompleted: {
            var value = appBaySettings.value("configHiddenApps")
            if (typeof value === "string")
                hiddenList.apps = value ? [value] : []
            else
                hiddenList.apps = value ? value : []
        }
    }
}
