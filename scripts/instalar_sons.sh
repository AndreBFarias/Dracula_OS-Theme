#!/usr/bin/env bash
# instalar_sons.sh — instala um tema de som no sistema do usuário.
#
# Default: tema "Dracula" (sci-fi/cyberpunk sutil, curado do pacote Kenney
# Sci-fi Sounds CC0 — SPRINT 25). O tema "Pop" (upstream pop-os/gtk-theme)
# continua disponível via `--theme Pop`.
#
# Uso:
#   ./scripts/instalar_sons.sh                    # user: ~/.local/share/sounds/Dracula/
#   ./scripts/instalar_sons.sh --system           # system: /usr/share/sounds/Dracula/ (sudo)
#   ./scripts/instalar_sons.sh --theme Pop        # instala o tema Pop
#   ./scripts/instalar_sons.sh --revert           # remove o tema e reseta gsettings

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MODO="user"
REVERT=0
TEMA="Dracula"
args=("$@")
i=0
while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
        --user)   MODO="user" ;;
        --system) MODO="system" ;;
        --revert) REVERT=1 ;;
        --theme)  i=$((i+1)); TEMA="${args[$i]:-Dracula}" ;;
    esac
    i=$((i+1))
done

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'
C_DIM='\033[2m'
C_RESET='\033[0m'

_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }
_warn() { echo -e "  ${C_YELLOW}!!${C_RESET} $*" >&2; }
_dim()  { echo -e "${C_DIM}$*${C_RESET}"; }
_err()  { echo -e "  ${C_RED}ERRO${C_RESET} $*" >&2; exit 1; }

DIST_SOUNDS="$REPO_ROOT/dist/sounds/$TEMA"
SRC_SOUNDS="$REPO_ROOT/src/sounds/$TEMA"

case "$MODO" in
    user)
        DEST="$HOME/.local/share/sounds/$TEMA"
        SUDO=""
        ;;
    system)
        DEST="/usr/share/sounds/$TEMA"
        SUDO="sudo"
        ;;
esac

if [[ $REVERT -eq 1 ]]; then
    _info "Revertendo tema de som $TEMA"
    $SUDO rm -rf "$DEST"
    gsettings reset org.gnome.desktop.sound theme-name 2>/dev/null || true
    _ok "tema $TEMA removido + gsettings resetado"
    exit 0
fi

# Prefere dist/ (passou pelo build), cai para src/ como fallback
if [[ -d "$DIST_SOUNDS" ]]; then
    FONTE="$DIST_SOUNDS"
elif [[ -d "$SRC_SOUNDS" ]]; then
    FONTE="$SRC_SOUNDS"
else
    _err "Sons do tema '$TEMA' não encontrados em $DIST_SOUNDS nem $SRC_SOUNDS. Rode ./build.sh primeiro."
fi

# Idempotência (SPRINT 25): se o destino já é idêntico à fonte, não toca.
if [[ -d "$DEST" ]] && diff -rq "$FONTE" "$DEST" >/dev/null 2>&1; then
    _dim "= tema $TEMA já idêntico em $DEST"
else
    _info "Instalando tema $TEMA em $DEST"
    $SUDO mkdir -p "$(dirname "$DEST")"
    $SUDO rm -rf "$DEST"
    $SUDO cp -r "$FONTE" "$DEST"
    total=$(find "$DEST" -name '*.oga' | wc -l)
    _ok "$total sons copiados para $DEST"
fi

# Ativar tema via gsettings (apenas no modo user; system precisa do user logar)
if [[ "$MODO" == "user" ]]; then
    atual="$(gsettings get org.gnome.desktop.sound theme-name 2>/dev/null || echo '')"
    if [[ "$atual" != "'$TEMA'" ]]; then
        gsettings set org.gnome.desktop.sound theme-name "$TEMA"
        _ok "gsettings: theme-name='$TEMA'"
    else
        _dim "= gsettings já em '$TEMA'"
    fi
fi

# "O homem que não ouve a música do silêncio não ouve coisa nenhuma." -- Cecília Meireles
