.pragma library

// Textos da interface. A chave é o texto em inglês; o idioma segue o do sistema
// (português e espanhol traduzidos, o resto fica em inglês).
var strings = {
    "Search": { pt: "Buscar", es: "Buscar" },
    "Folder": { pt: "Pasta", es: "Carpeta" },
    "Hide App": { pt: "Ocultar app", es: "Ocultar app" },
    "Add to Favorites": { pt: "Adicionar aos favoritos", es: "Añadir a favoritos" },
    "Rename Folder": { pt: "Renomear pasta", es: "Renombrar carpeta" },
    "Delete Folder": { pt: "Desfazer pasta", es: "Deshacer carpeta" },
    "Edit Layout": { pt: "Organizar apps", es: "Organizar apps" },
    "Done": { pt: "Concluído", es: "Listo" },
    "Add page": { pt: "Adicionar página", es: "Añadir página" },
    "Remove this page": { pt: "Remover esta página", es: "Quitar esta página" },
    "Move the apps off this page to remove it": { pt: "Tire os apps desta página para removê-la", es: "Quita las apps de esta página para eliminarla" },
    "Shut Down": { pt: "Desligar", es: "Apagar" },
    "Restart": { pt: "Reiniciar", es: "Reiniciar" },
    "Lock": { pt: "Bloquear", es: "Bloquear" },
    "Log Out": { pt: "Sair da sessão", es: "Cerrar sesión" },
    "No results": { pt: "Nenhum resultado", es: "Sin resultados" },
    // configurações
    "Icon:": { pt: "Ícone:", es: "Icono:" },
    "Choose…": { pt: "Escolher…", es: "Elegir…" },
    "Clear Icon": { pt: "Limpar ícone", es: "Quitar icono" },
    "Favorites dock": { pt: "Dock de favoritos", es: "Dock de favoritos" },
    "Text shadow": { pt: "Sombra no nome dos apps", es: "Sombra en el nombre de las apps" },
    "System actions": { pt: "Botões de desligar e sessão", es: "Botones de apagado y sesión" },
    "Grid and icons": { pt: "Grade e ícones", es: "Cuadrícula e iconos" },
    "Columns:": { pt: "Colunas:", es: "Columnas:" },
    "Rows:": { pt: "Linhas:", es: "Filas:" },
    "Icon size:": { pt: "Tamanho dos ícones:", es: "Tamaño de los iconos:" },
    "Hidden apps": { pt: "Apps ocultos", es: "Apps ocultas" },
    "Show": { pt: "Mostrar", es: "Mostrar" },
    "No hidden apps": { pt: "Nenhum app oculto", es: "Ninguna app oculta" }
}

var lang = (Qt.locale().name || "en").substring(0, 2)

function tr(text) {
    var t = strings[text]
    return t && t[lang] ? t[lang] : text
}

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v))
}

function isColorLight(c) {
    return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b > 0.5
}
