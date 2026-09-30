<p align="center">
  <img src="docs/logo.png" width="160" alt="AppBay Launchpad">
</p>

<h1 align="center">AppBay Launchpad</h1>

<p align="center">
  Launcher em tela cheia estilo <b>Launchpad do macOS</b> para o <b>KDE Plasma 6</b>:<br>
  grade 7×5, páginas, pastas, arrastar para reorganizar e animação de zoom.
</p>

---

> [!IMPORTANT]
> **Este projeto é um fork do [AppBay](https://store.kde.org/p/2327339/), criado por **zayronxio**.**
> Todo o crédito pelo widget original é dele. Aqui estão só os ajustes feitos em cima da versão 0.2.7,
> distribuídos sob a mesma licença (GPL-3.0). Se gostou, apoie o autor original.

## Prints

<p align="center">
  <img src="docs/screenshot-grid.png" alt="Grade 7×5 com pastas, busca e controles de página">
</p>
<p align="center"><sub>Grade 7×5 com pastas (Audio, Comunicações, Jetbrains), busca no topo e as bolinhas de página com o botão <b>+</b>.</sub></p>

<p align="center">
  <img src="docs/screenshot-dock.png" alt="Ícone de foguete no dock">
</p>
<p align="center"><sub>O ícone de foguete como primeiro item do dock, no estilo dos ícones Colloid.</sub></p>

## O que mudou em relação ao AppBay original

**Correções para o Plasma 6.6**
- Cores do tema quebradas: a API `PlasmaCore.Theme` foi trocada por `Kirigami.Theme`.
- Erros no log ao abrir o launcher e as pastas.
- Contagem de páginas errada, que escondia o último app quando o total passava de um múltiplo de 35 (por exemplo, 36 apps).

**Leve e fluido**
- Só a página que está na tela é desenhada. Buscar, abrir pasta e fechar o launcher não recriam mais os ícones.
- Sem efeito de sombra por ícone e sem um menu de contexto criado para cada app.
- Com 237 apps, abrir e fechar gasta ~4x menos CPU que antes, e a parte do launcher em si ficou ~25x mais leve. O plasmashell usa metade da memória.
- Apps instalados ou removidos aparecem e somem sozinhos, sem reiniciar nada.

**Comportamento estilo macOS**
- Grade de **7 colunas × 5 linhas**, ajustável nas configurações. As células se adaptam à tela.
- **Trocar de página:** arraste para o lado, role o mouse ou deslize dois dedos no touchpad. A página acompanha os dedos e encaixa ao soltar.
- **Segure um ícone** para entrar no **modo organizar**: os ícones tremem e aparece um **×** para ocultar apps. Nesse modo:
  - arraste um app e os outros **abrem espaço** enquanto você arrasta;
  - pare no **centro** de outro app para criar uma pasta, ou em cima de uma pasta para colocar o app nela;
  - leve até a **borda** da tela para ir para outra página;
  - use os botões **+** e **−** ao lado das bolinhas para criar e remover páginas.
- **Pastas com nome automático** pela categoria dos apps (Jogos, Desenvolvimento, Internet...). O nome fica em cima quando a pasta está aberta, e um clique nele renomeia.
- **Arraste um app para fora da pasta** para tirá-lo de lá. Uma pasta que fica com um app só vira esse app.
- **Navegação pelo teclado:** setas para escolher o app e **Enter** para abrir, inclusive nas pastas e nos resultados da busca.
- **Gesto de pinça** com 4 dedos no touchpad: juntar os dedos abre, abrir os dedos fecha.
- A ordem dos apps, as páginas e as pastas ficam salvas, mesmo reiniciando o Plasma. Apps instalados depois vão para o final.
- O launcher abre na página em que você estava. A busca, a pasta aberta e o modo organizar são limpos ao fechar.
- Interface em português, espanhol ou inglês, seguindo o idioma do sistema.

**Extras**
- Sem a barra de favoritos por padrão, para não competir com o seu dock.
- Ícone de foguete novo, inspirado no Launchpad clássico. Uma versão em grade também vem incluída.
- Efeito do KWin (`launchpadzoom`) com a animação de zoom e fade ao abrir e fechar.
- Script do KWin (`appbaygestures`) para o gesto de pinça.
- Instalador que coloca o launcher no painel e liga a **tecla Meta** a ele.

## Requisitos

- **KDE Plasma 6.** Testado no Plasma 6.6, em Wayland.
- Nenhuma biblioteca extra. Versões antigas pediam o Qt5Compat; esta não precisa mais.

> [!WARNING]
> Distros que ainda usam **Plasma 5** não são suportadas. Isso inclui Ubuntu/Kubuntu 24.04 LTS e Debian 12.

## Instalação

### 1. Instale o git (se ainda não tiver)

| Distro | Comando |
|---|---|
| **Fedora KDE** (40 ou mais novo) | `sudo dnf install git` |
| **Kubuntu / Ubuntu** (25.04 ou mais novo), **KDE neon**, **Debian 13** | `sudo apt install git` |
| **Arch**, **Manjaro**, **EndeavourOS**, **CachyOS** | `sudo pacman -S --needed git` |
| **openSUSE Tumbleweed** | `sudo zypper install git` |

### 2. Baixe e instale

```bash
git clone https://github.com/nicolasdesenv/appbay-launchpad.git
cd appbay-launchpad
bash instalar.sh
```

Sem git: baixe o [ZIP](https://github.com/nicolasdesenv/appbay-launchpad/archive/refs/heads/main.zip) e extraia.
Depois, clique com o botão direito dentro da pasta, escolha **Abrir terminal aqui** e rode `bash instalar.sh`.

O instalador:
1. instala o widget, os ícones, o efeito de animação e o gesto de pinça na sua pasta de usuário (não precisa de `sudo`);
2. coloca o launcher como primeiro item do painel que tem a barra de tarefas ou o dock (numa atualização, usa o launcher que já existe);
3. faz a **tecla Meta** abrir o launcher (o menu padrão continua no **Alt+F1**);
4. reinicia o painel. A tela pisca por alguns segundos, e isso é normal.

<details>
<summary>Instalação manual (sem o script)</summary>

```bash
kpackagetool6 -t Plasma/Applet -i package/Plasma.AppBay
mkdir -p ~/.local/share/icons/hicolor/scalable/apps
cp icons/*.svg ~/.local/share/icons/hicolor/scalable/apps/
mkdir -p ~/.local/share/kwin/effects && cp -r kwin-effect/launchpadzoom ~/.local/share/kwin/effects/
mkdir -p ~/.local/share/kwin/scripts && cp -r kwin-script/appbaygestures ~/.local/share/kwin/scripts/
```

Depois:
- **Widget:** clique com o botão direito no painel → **Adicionar widgets** → **AppBay Launchpad**.
- **Animação:** Configurações do Sistema → Efeitos da área de trabalho → ative **Launchpad Zoom**.
- **Gesto de pinça:** Configurações do Sistema → Scripts do KWin → ative **AppBay Launchpad: gesto de pinça**. Ele precisa do número do widget em `kwinrc`, que o instalador grava sozinho.

</details>

## Como usar

| Ação | Como fazer |
|---|---|
| Abrir / fechar | Tecla **Meta**, clique no foguete do painel, pinça de 4 dedos no touchpad ou **Esc** |
| Buscar um app | Comece a digitar. **Enter** abre o primeiro resultado |
| Escolher um app pelo teclado | **Setas** para mover e **Enter** para abrir (em pastas também) |
| Trocar de página | Arraste para o lado, role o mouse, deslize no touchpad ou clique nas bolinhas |
| Organizar (modo "tremer") | **Segure** um ícone por meio segundo, ou botão direito → **Organizar apps** |
| Mudar de lugar | No modo organizar, arraste o app. Os outros abrem espaço |
| Criar pasta | Arraste um app e pare no **centro** de outro |
| Adicionar à pasta | Arraste o app e pare em cima da pasta |
| Tirar da pasta | Abra a pasta e arraste o app para fora dela |
| Levar para outra página | Arraste o app até a borda da tela |
| Criar / remover página | Botões **+** e **−** ao lado das bolinhas, no modo organizar |
| Ocultar app | **×** no modo organizar, ou botão direito → **Ocultar app** |
| Mostrar app oculto | Botão direito no foguete → **Configurar** → **Apps ocultos** |
| Renomear pasta | Abra a pasta e clique no nome em cima. **Enter** confirma |
| Desfazer pasta | Botão direito na pasta → **Desfazer pasta** |
| Sair do modo organizar | **Concluído**, **Esc** ou clique num espaço vazio |
| Mudar colunas, linhas e ícones | Botão direito no foguete → **Configurar** |

## Atualizar

Suas pastas, a ordem dos apps e as páginas são mantidas na atualização.

### 1. Atualize o sistema (recomendado)

O launcher depende do Plasma da sua distro. Deixe o sistema em dia antes de atualizar o widget:

| Distro | Comando |
|---|---|
| **Fedora KDE** | `sudo dnf upgrade --refresh` |
| **Kubuntu / Ubuntu**, **KDE neon**, **Debian 13** | `sudo apt update && sudo apt full-upgrade` (no **KDE neon**, prefira `sudo pkcon update`) |
| **Arch**, **EndeavourOS**, **CachyOS** | `sudo pacman -Syu` |
| **Manjaro** | `sudo pacman -Syu` ou `pamac upgrade` |
| **openSUSE Tumbleweed** | `sudo zypper dup` |

Se o sistema atualizou o Plasma, reinicie a sessão antes de seguir.

### 2. Baixe a versão nova e reinstale

É igual em todas as distros. Na pasta onde você clonou o projeto:

```bash
cd appbay-launchpad
git pull
bash instalar.sh
```

Instalou pelo ZIP? Baixe o [ZIP novo](https://github.com/nicolasdesenv/appbay-launchpad/archive/refs/heads/main.zip), extraia por cima da pasta antiga e rode `bash instalar.sh` de novo.

O instalador percebe que o widget já está instalado e só troca os arquivos. O painel reinicia e a tela pisca, como na primeira instalação.
Se você já tinha o gesto de pinça, a versão nova dele passa a valer depois de sair e entrar de novo na sessão.

Para ver a versão instalada:

```bash
kpackagetool6 -t Plasma/Applet -s Plasma.AppBay
```

> [!NOTE]
> Até a versão `0.2.7-launchpad.1`, as pastas sumiam quando o Plasma reiniciava ou quando você saía da sessão.
> Pastas que já sumiram não voltam com a atualização. Crie de novo uma vez, e a partir daí elas ficam salvas.
> As páginas que você criou também não se perdiam, só não apareciam ao abrir o launcher. Depois de atualizar elas voltam a aparecer. Se sobrar alguma vazia, apague no botão **−**.

## Desinstalar

```bash
bash desinstalar.sh
```

O script remove o widget, os ícones e a animação, e devolve a tecla Meta ao menu padrão.

## Limitações conhecidas

- Não atualize este widget pela loja do KDE (**Obter novos widgets**). A loja instala o AppBay original por cima e desfaz os ajustes. Para atualizar, veja [Atualizar](#atualizar).
- Só dá para remover páginas vazias. Tire os apps da página antes.

## Créditos e licença

- **Widget original:** [AppBay](https://store.kde.org/p/2327339/), de **zayronxio**, GPL-3.0.
- **Ajustes deste fork, ícones e efeito `launchpadzoom`:** [nicolasdesenv](https://github.com/nicolasdesenv).

Distribuído sob a **GNU General Public License v3.0**. O texto completo está em [LICENSE](LICENSE).
