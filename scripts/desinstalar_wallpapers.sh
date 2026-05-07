#!/usr/bin/env bash
# desinstalar_wallpapers.sh — remove ~/.local/share/backgrounds/dracula/
# com validar_path_destrutivo. Não-fatal se diretório não existe.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DESTINO="$HOME/.local/share/backgrounds/dracula"

if [[ ! -d "$DESTINO" ]]; then
    _info "Wallpapers Dracula não instalados em $DESTINO; nada a remover"
    exit 0
fi

if ! validar_path_destrutivo "$DESTINO"; then
    _err "Pulando $DESTINO por segurança"
    exit 1
fi

if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
    _dim "[dry-run] rm -rf -- $DESTINO"
else
    rm -rf -- "$DESTINO" && _ok "removido: $DESTINO"
fi

exit 0
