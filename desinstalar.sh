#!/usr/bin/env bash
# AppBay Launchpad: remove o widget, o ícone, a animação e o gesto de pinça, e devolve a tecla Meta ao menu padrão.
gdbus call --session --dest org.kde.plasmashell --object-path /PlasmaShell --method org.kde.PlasmaShell.evaluateScript '
var ps = panels(); for (var i = 0; i < ps.length; i++) { var w = ps[i].widgets("Plasma.AppBay"); for (var j = 0; j < w.length; j++) { w[j].globalShortcut = ""; w[j].remove(); } }' >/dev/null
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setForeignShortcut \
  "['plasmashell','activate application launcher','','']" "[16777250, 150994992]" >/dev/null 2>&1 || true
kpackagetool6 -t Plasma/Applet -r Plasma.AppBay >/dev/null 2>&1
kwriteconfig6 --file kwinrc --group Plugins --key launchpadzoomEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key appbaygesturesEnabled --delete
kwriteconfig6 --file kwinrc --group Script-appbaygestures --key WidgetId --delete
rm -rf ~/.local/share/kwin/scripts/appbaygestures
gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.reconfigure >/dev/null 2>&1 || true
gdbus call --session --dest org.kde.KWin --object-path /Effects --method org.kde.kwin.Effects.unloadEffect launchpadzoom >/dev/null 2>&1
rm -rf ~/.local/share/kwin/effects/launchpadzoom ~/.local/share/kwin-wayland/effects/launchpadzoom ~/.local/share/icons/hicolor/scalable/apps/appbay-launchpad.svg ~/.local/share/icons/hicolor/scalable/apps/appbay-launchpad-grid.svg
echo "Launchpad removido. A tecla Meta voltou a abrir o menu padrão."
