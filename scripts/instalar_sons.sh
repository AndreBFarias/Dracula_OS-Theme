#!/usr/bin/env bash
# instalar_sons.sh — instala o tema de som Pop no sistema do usuário
#
# O tema Pop vem do upstream `pop-os/gtk-theme` (subpasta sounds/) e é
# empacotado no .deb pop-sound-theme do System76. Aqui o redistribuímos
# junto com o Dracula_OS-Theme para garantir som consistente em PCs onde
# o pacote não está instalado.
#
# Uso:
#   ./scripts/instalar_sons.sh              # user: ~/.local/share/sounds/Pop/
#   ./scripts/instalar_sons.sh --system     # system: /usr/share/sounds/Pop/ (sudo)
#   ./scripts/instalar_sons.sh --revert     # remove e reseta gsettings

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_SOUNDS="$REPO_ROOT/dist/sounds/Pop"
SRC_SOUNDS="$REPO_ROOT/src/sounds/Pop"

MODO="user"
REVERT=0
for arg in "$@"; do
    case "$arg" in
        --user)   MODO="user" ;;
        --system) MODO="system" ;;
        --revert) REVERT=1 ;;
    esac
done

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'
C_RESET='\033[0m'

_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }
_warn() { echo -e "  ${C_YELLOW}!!${C_RESET} $*" >&2; }
_err()  { echo -e "  ${C_RED}ERRO${C_RESET} $*" >&2; exit 1; }

case "$MODO" in
    user)
        DEST="$HOME/.local/share/sounds/Pop"
        SUDO=""
        ;;
    system)
        DEST="/usr/share/sounds/Pop"
        SUDO="sudo"
        ;;
esac

if [[ $REVERT -eq 1 ]]; then
    _info "Revertendo tema de som Pop"
    $SUDO rm -rf "$DEST"
    gsettings reset org.gnome.desktop.sound theme-name 2>/dev/null || true
    _ok "tema Pop removido + gsettings resetado"
    exit 0
fi

# Prefere dist/ (passou pelo build), cai para src/ como fallback
if [[ -d "$DIST_SOUNDS" ]]; then
    FONTE="$DIST_SOUNDS"
elif [[ -d "$SRC_SOUNDS" ]]; then
    FONTE="$SRC_SOUNDS"
else
    _err "Sons não encontrados em $DIST_SOUNDS nem $SRC_SOUNDS. Rode ./build.sh primeiro."
fi

_info "Instalando tema Pop em $DEST"
$SUDO mkdir -p "$(dirname "$DEST")"
$SUDO rm -rf "$DEST"
$SUDO cp -r "$FONTE" "$DEST"
_ok "26 arquivos copiados para $DEST"

# Ativar tema via gsettings (apenas no modo user; system precisa do user logar)
if [[ "$MODO" == "user" ]]; then
    gsettings set org.gnome.desktop.sound theme-name 'Pop'
    _ok "gsettings: theme-name='Pop'"
fi

# "O homem que não ouve a música do silêncio não ouve coisa nenhuma." -- Cecília Meireles
