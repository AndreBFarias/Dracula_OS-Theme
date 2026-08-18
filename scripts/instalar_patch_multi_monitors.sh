#!/usr/bin/env bash
# instalar_patch_multi_monitors.sh — põe o menu de sistema na tela secundária.
#
# Problema que resolve:
#   O GNOME Shell desenha um único painel, preso ao monitor primário
#   (ui/layout.js: panelBox.set_position(primaryMonitor...)). A extensão
#   multi-monitors-add-on@spin83 desenha um painel na tela secundária, mas ele
#   nasce sem o canto de gerenciamento: _ensureIndicator() não encontra
#   construtor para 'aggregateMenu' porque o mapa da extensão só registra
#   activities, appMenu e dateMenu.
#
#   Transferir não serve: transferIndicators() usa remove_child, o que tiraria
#   o menu do monitor primário. Aqui INSTANCIAMOS um menu próprio para a tela.
#
# O que faz (4 edições em mmpanel.js):
#   1. importa AccountsService, GLib e userWidget;
#   2. insere src/shell/mm-status-extras.js (replicação dos extras de outras
#      extensões — ver o cabeçalho daquele arquivo para o que dá e o que não dá);
#   3. registra 'aggregateMenu': Panel.AggregateMenu no mapa de construtores;
#   4. liga _addStatusExtras/_removeStatusExtras ao ciclo de vida do painel.
#
# Idempotência:
#   detecta _addStatusExtras no destino e sai sem tocar em nada.
#   Guarda mmpanel.js.dracula-orig na primeira aplicação (nome próprio, para não
#   pisar em .orig/.bak de outra ferramenta) junto da versão da extensão.
#   --reverter recusa restaurar sobre uma versão diferente da que gerou o backup:
#   um update da extensão apaga o patch, e restaurar o backup velho por cima
#   seria downgrade silencioso.
#
# Variáveis de ambiente:
#   DRACULA_DRY_RUN=1 — não grava; apenas informa o que faria.
#
# Saída:
#   exit 0 — aplicado, revertido ou já aplicado.
#   exit 1 — extensão ausente, arquivo inesperado, patch resultou em JS inválido
#            ou --reverter com backup de outra versão.
#   Sem node instalado o patch é aplicado sem validação de sintaxe, com aviso.
#   exit 2 — argumento inválido.
#
# Sem sudo. Após rodar, reinicie o Shell (X11: Alt+F2, r).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

readonly EXT_DIR="$HOME/.local/share/gnome-shell/extensions/multi-monitors-add-on@spin83"
readonly ALVO="$EXT_DIR/mmpanel.js"
readonly BACKUP="$ALVO.dracula-orig"
readonly BACKUP_VER="$ALVO.dracula-orig.version"
readonly FRAGMENTO="$REPO_ROOT/src/shell/mm-status-extras.js"
readonly DRY_RUN="${DRACULA_DRY_RUN:-0}"

uso() {
    cat <<EOF
Uso: $(basename "$0") [--reverter] [-h|--help]

  (sem argumento)  aplica o patch
  --reverter       restaura mmpanel.js.orig
EOF
}

ACAO="aplicar"
case "${1:-}" in
    "")            ;;
    --reverter)    ACAO="reverter" ;;
    -h|--help)     uso; exit 0 ;;
    *)             _err "argumento inválido: $1"; uso; exit 2 ;;
esac

if [[ ! -f "$ALVO" ]]; then
    _warn "multi-monitors-add-on@spin83 não instalado; nada a fazer"
    exit 0
fi

if [[ "$ACAO" == "reverter" ]]; then
    if [[ ! -f "$BACKUP" ]]; then
        _warn "sem $(basename "$BACKUP"); nada a reverter"
        exit 0
    fi
    ver_atual=$(jq -r '.version // empty' "$EXT_DIR/metadata.json" 2>/dev/null || true)
    ver_backup=$(cat "$BACKUP_VER" 2>/dev/null || true)
    if [[ -n "$ver_backup" && -n "$ver_atual" && "$ver_backup" != "$ver_atual" ]]; then
        _err "backup é da versão $ver_backup e a extensão está na $ver_atual"
        _err "restaurar seria downgrade; apague $(basename "$BACKUP") se quiser mesmo"
        exit 1
    fi
    [[ "$DRY_RUN" == "1" ]] && { _info "[dry-run] restauraria $ALVO"; exit 0; }
    mv "$BACKUP" "$ALVO"
    rm -f "$BACKUP_VER"
    _ok "mmpanel.js restaurado — reinicie o Shell (Alt+F2, r)"
    exit 0
fi

if grep -q "_addStatusExtras" "$ALVO"; then
    _ok "patch do menu de sistema já aplicado"
    exit 0
fi

if [[ ! -f "$FRAGMENTO" ]]; then
    _err "fragmento ausente: $FRAGMENTO"
    exit 1
fi

if [[ "$DRY_RUN" == "1" ]]; then
    _info "[dry-run] aplicaria o patch do menu de sistema em $ALVO"
    exit 0
fi

if [[ -e "$BACKUP" ]]; then
    _warn "$(basename "$BACKUP") já existe; preservando o backup mais antigo"
else
    cp "$ALVO" "$BACKUP"
    jq -r '.version // empty' "$EXT_DIR/metadata.json" 2>/dev/null > "$BACKUP_VER" || true
fi

if ! /usr/bin/python3 - "$ALVO" "$FRAGMENTO" <<'PY'
import sys, pathlib

alvo, fragmento = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
s = alvo.read_text()
extras = fragmento.read_text()

def troca(antes, depois):
    global s
    if antes not in s:
        print(f"anchor ausente: {antes[:60]!r}", file=sys.stderr)
        sys.exit(1)
    s = s.replace(antes, depois, 1)

troca("const { St, Shell, Meta, Atk, Clutter, GObject } = imports.gi;",
      "const { St, Shell, Meta, Atk, Clutter, GObject, AccountsService, GLib } = imports.gi;")

troca("const MMCalendar = CE.imports.mmcalendar;",
      "const MMCalendar = CE.imports.mmcalendar;\nconst UserWidget = imports.ui.userWidget;\n\n" + extras)

troca("    'dateMenu': MMCalendar.MultiMonitorsDateMenuButton,\n};",
      "    'dateMenu': MMCalendar.MultiMonitorsDateMenuButton,\n"
      "    // Instância própria do menu de sistema (som, rede, bateria, desligar)\n"
      "    // para esta tela. Instanciar em vez de transferir é deliberado:\n"
      "    // transferIndicators() usa remove_child e tiraria o menu do primário.\n"
      "    'aggregateMenu': Panel.AggregateMenu,\n};")

troca("            indicator = new constructor(this);\n            this.statusArea[role] = indicator;\n        }",
      "            indicator = new constructor(this);\n            this.statusArea[role] = indicator;\n"
      "            if (role === 'aggregateMenu')\n"
      "                this._statusExtras = _addStatusExtras(indicator);\n        }")

troca("    _onDestroy() {\n        global.display.disconnect(this._workareasChangedId);",
      "    _onDestroy() {\n        _removeStatusExtras(this._statusExtras);\n        this._statusExtras = null;\n\n"
      "        global.display.disconnect(this._workareasChangedId);")

alvo.write_text(s)
PY
then
    _err "falha ao aplicar o patch; restaurando original"
    cp "$BACKUP" "$ALVO"
    exit 1
fi

# node só valida sintaxe; não roda o arquivo (ele depende do runtime do Shell).
if command -v node &>/dev/null; then
    if ! node --check "$ALVO" &>/dev/null; then
        _err "patch gerou JS inválido; restaurando original"
        cp "$BACKUP" "$ALVO"
        exit 1
    fi
else
    _warn "node ausente: sintaxe do patch NÃO validada"
fi

_ok "menu de sistema replicado na tela secundária — reinicie o Shell (Alt+F2, r)"
