#!/usr/bin/env bash
# AppBay Launchpad: instala o launcher estilo macOS no KDE Plasma 6.
# Fork do AppBay de zayronxio (https://store.kde.org/p/2327339/), GPL-3.0.
# Usa só gdbus, systemd e ferramentas do KDE, para funcionar em qualquer distro com Plasma 6.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
say()  { echo -e "\033[1;32m==>\033[0m $*"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*"; }

# executa um script de Plasma e devolve o texto impresso
plasma_eval() {
  gdbus call --session --dest org.kde.plasmashell --object-path /PlasmaShell \
    --method org.kde.PlasmaShell.evaluateScript "$1" | sed -e "s/^('//" -e "s/',)$//"
}

restart_plasma_with() {   # $1 = comando a rodar com o plasmashell parado
  if systemctl --user is-active --quiet plasma-plasmashell.service; then
    systemctl --user stop plasma-plasmashell.service; sleep 1
    eval "$1"
    systemctl --user start plasma-plasmashell.service
  else
    kquitapp6 plasmashell >/dev/null 2>&1 || true; sleep 2
    eval "$1"
    (setsid plasmashell >/dev/null 2>&1 &)
  fi
}

# --- verificações ---
if ! command -v plasmashell >/dev/null || ! plasmashell --version | grep -q ' 6\.'; then
  echo "Este instalador precisa do KDE Plasma 6."; exit 1
fi
for c in gdbus kpackagetool6 kwriteconfig6; do
  command -v $c >/dev/null || { echo "Falta o programa '$c'."; exit 1; }
done
has_qt5compat() {
  for d in /usr/lib*/qt6/qml/Qt5Compat/GraphicalEffects /usr/lib/*/qt6/qml/Qt5Compat/GraphicalEffects; do
    [ -d "$d" ] && return 0
  done
  return 1
}
if ! has_qt5compat; then
  warn "Falta a biblioteca Qt5Compat. Instale e rode este script de novo:"
  if command -v dnf >/dev/null; then echo "    sudo dnf install qt6-qt5compat"
  elif command -v apt >/dev/null; then echo "    sudo apt install qml6-module-qt5compat-graphicaleffects"
  else echo "    (pacote qt6-qt5compat da sua distribuição)"; fi
  exit 1
fi

say "Instalando o widget AppBay..."
LOCAL_PKG=~/.local/share/plasma/plasmoids/Plasma.AppBay
if kpackagetool6 -t Plasma/Applet -s Plasma.AppBay >/dev/null 2>&1; then
  # versões antigas (e a da loja) não têm KPackageStructure e o -u falha nelas;
  # aí trocamos a pasta do widget. As pastas e a ordem dos apps ficam em outro lugar.
  if ! kpackagetool6 -t Plasma/Applet -u "$DIR/package/Plasma.AppBay" >/dev/null 2>&1; then
    rm -rf "$LOCAL_PKG"
    kpackagetool6 -t Plasma/Applet -i "$DIR/package/Plasma.AppBay" >/dev/null
  fi
else
  kpackagetool6 -t Plasma/Applet -i "$DIR/package/Plasma.AppBay" >/dev/null
fi

say "Instalando o ícone..."
mkdir -p ~/.local/share/icons/hicolor/scalable/apps
cp "$DIR"/icons/*.svg ~/.local/share/icons/hicolor/scalable/apps/

say "Instalando a animação de abrir/fechar..."
for d in ~/.local/share/kwin/effects ~/.local/share/kwin-wayland/effects; do
  mkdir -p "$d"; rm -rf "$d/launchpadzoom"; cp -r "$DIR/kwin-effect/launchpadzoom" "$d/"
done
kwriteconfig6 --file kwinrc --group Plugins --key launchpadzoomEnabled true
gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.reconfigure >/dev/null 2>&1 || true
gdbus call --session --dest org.kde.KWin --object-path /Effects --method org.kde.kwin.Effects.loadEffect launchpadzoom >/dev/null 2>&1 || true

say "Liberando a tecla Meta (o menu antigo continua no Alt+F1)..."
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setForeignShortcut \
  "['plasmashell','activate application launcher','','']" "[150994992]" >/dev/null 2>&1 || true

say "Colocando o Launchpad no painel..."
RES=$(plasma_eval '
var ps = panels(), target = null;
for (var i = 0; i < ps.length && !target; i++) {
  var ws = ps[i].widgets();
  for (var j = 0; j < ws.length; j++)
    if (ws[j].type == "org.kde.plasma.icontasks" || ws[j].type == "org.kde.plasma.taskmanager") { target = ps[i]; break; }
}
if (!target && ps.length) target = ps[0];
if (target) {
  var ex = target.widgets("Plasma.AppBay");
  var a = ex.length ? ex[0] : target.addWidget("Plasma.AppBay");
  a.globalShortcut = "Meta";
  var order = [a.id];
  var ws = target.widgets();
  for (var k = 0; k < ws.length; k++) if (ws[k].id != a.id) order.push(ws[k].id);
  print(target.id + " " + order.join(";"));
} else { print("NONE"); }
')
if [ "$RES" != "NONE" ] && [ -n "$RES" ]; then
  PANEL=${RES%% *}; ORDER=${RES#* }
  sleep 2
  restart_plasma_with "kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group '$PANEL' --group General --key AppletOrder '$ORDER'"
  sleep 3
  say "Pronto! Aperte a tecla Meta (a do logo do Windows) ou clique no foguete no painel."
else
  say "Instalado, mas não achei um painel. Clique com o botão direito na área de trabalho > Adicionar widgets > procure \"AppBay\"."
fi
