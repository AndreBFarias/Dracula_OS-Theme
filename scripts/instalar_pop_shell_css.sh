#!/usr/bin/env bash
# instalar_pop_shell_css.sh — substitui o dark.css do Pop!_Shell com versão Dracula
#
# O Pop!_Shell carrega seu próprio CSS de /usr/share/gnome-shell/extensions/
# pop-shell@system76.com/dark.css, sobrepondo o que o tema shell define.
# Este script faz backup do original e instala a versão Dracula.
#
# Uso:
#   sudo ./scripts/instalar_pop_shell_css.sh           # instala
#   sudo ./scripts/instalar_pop_shell_css.sh --revert  # restaura backup

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Lista de CSS a substituir: "fonte|destino"
declare -a ALVOS=(
    "$REPO_ROOT/src/shell/pop-shell-dark.css|/usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css"
    "$REPO_ROOT/src/shell/pop-cosmic-dark.css|/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css"
)

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

processar_um() {
    local fonte="$1" destino="$2" modo="$3"
    local backup="${destino}.orig"
    local nome
    nome="$(basename "$(dirname "$destino")")"

    if [[ ! -d "$(dirname "$destino")" ]]; then
        _warn "$nome: extensão não encontrada — pulando"
        return 0
    fi

    case "$modo" in
        revert)
            if [[ ! -f "$backup" ]]; then
                _warn "$nome: backup $backup não encontrado — pulando"
                return 0
            fi
            cp "$backup" "$destino"
            _ok "$nome: dark.css original restaurado"
            ;;
        install)
            if [[ ! -f "$fonte" ]]; then
                _warn "$nome: fonte $fonte não encontrada — pulando"
                return 0
            fi
            if [[ ! -f "$backup" ]]; then
                cp "$destino" "$backup"
                _ok "$nome: backup criado em $backup"
            fi
            cp "$fonte" "$destino"
            _ok "$nome: dark.css substituído"
            ;;
    esac
}

case "${1:-install}" in
    --revert|revert) MODO="revert" ;;
    install|*)       MODO="install" ;;
esac

for alvo in "${ALVOS[@]}"; do
    fonte="${alvo%%|*}"
    destino="${alvo#*|}"
    processar_um "$fonte" "$destino" "$MODO"
done

_info "Recarregue a sessão/shell (Alt+F2 r em X11 ou logout em Wayland) para aplicar"

# "Suaviter in modo, fortiter in re." -- suave na forma, firme no fundo.
