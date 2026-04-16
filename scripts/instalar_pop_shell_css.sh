#!/usr/bin/env bash
# instalar_pop_shell_css.sh — substitui o dark.css do Pop!_Shell com versao Dracula
#
# O Pop!_Shell carrega seu proprio CSS de /usr/share/gnome-shell/extensions/
# pop-shell@system76.com/dark.css, sobrepondo o que o tema shell define.
# Este script faz backup do original e instala a versao Dracula.
#
# Uso:
#   sudo ./scripts/instalar_pop_shell_css.sh           # instala
#   sudo ./scripts/instalar_pop_shell_css.sh --revert  # restaura backup

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FONTE="$REPO_ROOT/src/shell/pop-shell-dark.css"
DESTINO="/usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css"
BACKUP="${DESTINO}.orig"

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'
C_RESET='\033[0m'

_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }
_warn() { echo -e "  ${C_YELLOW}!!${C_RESET} $*" >&2; }
_err()  { echo -e "  ${C_RED}ERRO${C_RESET} $*" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then
    _err "Requer sudo: sudo $0 $*"
fi

if [[ ! -d "$(dirname "$DESTINO")" ]]; then
    _warn "Pop!_Shell extension nao encontrada em $(dirname "$DESTINO") — pulando"
    exit 0
fi

case "${1:-install}" in
    --revert|revert)
        if [[ ! -f "$BACKUP" ]]; then
            _err "Backup $BACKUP nao encontrado — nada a restaurar"
        fi
        cp "$BACKUP" "$DESTINO"
        _ok "dark.css original restaurado de $BACKUP"
        ;;
    install|*)
        if [[ ! -f "$FONTE" ]]; then
            _err "Fonte $FONTE nao encontrada"
        fi
        # Backup so na primeira execucao (preserva original real)
        if [[ ! -f "$BACKUP" ]]; then
            cp "$DESTINO" "$BACKUP"
            _ok "Backup criado em $BACKUP"
        else
            _info "Backup ja existe em $BACKUP (preservando)"
        fi
        cp "$FONTE" "$DESTINO"
        _ok "Pop!_Shell dark.css substituido (recarregue o shell: Alt+F2 r em X11)"
        ;;
esac

# "Suaviter in modo, fortiter in re." -- suave na forma, firme no fundo.
