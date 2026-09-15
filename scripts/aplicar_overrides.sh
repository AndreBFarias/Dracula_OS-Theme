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

# [2026-09-15] Antes daqui saía um `cp` para cada arquivo de overrides/, sem
# perguntar nada. Quando um app é desinstalado, o override dele continua no repo
# e este laço o reinstalava no menu a CADA operação de apt (o hook
# DPkg::Post-Invoke do Aurora chama o bootstrap, que chega até aqui). O resultado
# eram lançadores de mpv, onboard, LinuxToys e Ghostty voltando sozinhos depois
# de removidos — e brigando com o aurora-menu-doctor, que os tirava de novo.
#
# Quem responde "esse app existe?" é o doctor, para a regra morar num lugar só.
# Sem ele, copia tudo como antes: um override a mais é menos grave do que o tema
# não ser aplicado.
DOCTOR="$HOME/.config/zsh/aurora/aurora-menu-doctor.py"

for f in "$OVERRIDES"/*.desktop; do
    [[ ! -f "$f" ]] && continue
    if [[ -x "$DOCTOR" ]] && ! "$DOCTOR" --alvo-vivo "$f" 2>/dev/null; then
        _info "pulando $(basename "$f") — o app não está instalado"
        continue
    fi
    _info "copiando $(basename "$f") → $DESTINO/"
    if [[ $DRY_RUN -eq 0 ]]; then
        cp "$f" "$DESTINO/"
        chmod 644 "$DESTINO/$(basename "$f")" 2>/dev/null || true
    fi
done

# Atualiza cache de aplicativos (XDG)
if command -v update-desktop-database &>/dev/null && [[ $DRY_RUN -eq 0 ]]; then
    update-desktop-database "$DESTINO" 2>/dev/null || true
fi

_ok "Overrides aplicados"

# "O silêncio é argumento difícil de refutar." -- Josh Billings
