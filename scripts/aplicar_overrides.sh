#!/usr/bin/env bash
# aplicar_overrides.sh — copia overrides de .desktop para ~/.local/share/applications/
# (prioriza sobre versões do Flatpak/sistema)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERRIDES="$REPO_ROOT/overrides"
DESTINO="$HOME/.local/share/applications"
DRY_RUN=0

for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=1
done

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_RESET='\033[0m'

_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }

mkdir -p "$DESTINO"

for f in "$OVERRIDES"/*.desktop; do
    [[ ! -f "$f" ]] && continue
    _info "copiando $(basename "$f") → $DESTINO/"
    if [[ $DRY_RUN -eq 0 ]]; then
        cp "$f" "$DESTINO/"
    fi
done

# Atualiza cache de aplicativos (XDG)
if command -v update-desktop-database &>/dev/null && [[ $DRY_RUN -eq 0 ]]; then
    update-desktop-database "$DESTINO" 2>/dev/null || true
fi

_ok "Overrides aplicados"

# "O silêncio é argumento difícil de refutar." -- Josh Billings
