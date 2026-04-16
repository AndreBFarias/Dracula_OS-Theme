#!/usr/bin/env bash
# instalar_keybindings.sh — aplica snapshots dconf de atalhos + silencia shutter
#
# Lê os arquivos em app-themes/keybindings/ e os carrega no dconf do usuário.
# Guarda backup do estado anterior em ~/.cache/dracula_os_backup_keybindings_<ts>/
# para permitir --revert.
#
# Uso:
#   ./scripts/instalar_keybindings.sh            # aplica todos os snapshots
#   ./scripts/instalar_keybindings.sh --revert   # restaura backup mais recente

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$REPO_ROOT/app-themes/keybindings"
TS=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.cache/dracula_os_backup_keybindings_$TS"

REVERT=0
for arg in "$@"; do
    case "$arg" in
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

# Mapeamento arquivo → namespace dconf
declare -A ALVOS=(
    ["media-keys.dconf"]="/org/gnome/settings-daemon/plugins/media-keys/"
    ["wm-keybindings.dconf"]="/org/gnome/desktop/wm/keybindings/"
    ["terminal.dconf"]="/org/gnome/terminal/legacy/keybindings/"
    ["sound.dconf"]="/org/gnome/desktop/sound/"
)

if [[ $REVERT -eq 1 ]]; then
    ultimo_backup=$(ls -dt "$HOME"/.cache/dracula_os_backup_keybindings_* 2>/dev/null | head -1)
    if [[ -z "$ultimo_backup" ]]; then
        _err "Nenhum backup encontrado em ~/.cache/dracula_os_backup_keybindings_*"
    fi
    _info "Restaurando backup: $ultimo_backup"
    for arquivo in "${!ALVOS[@]}"; do
        namespace="${ALVOS[$arquivo]}"
        origem="$ultimo_backup/$arquivo"
        if [[ -f "$origem" ]]; then
            dconf load "$namespace" < "$origem"
            _ok "$arquivo restaurado em $namespace"
        fi
    done
    exit 0
fi

if [[ ! -d "$DIR" ]]; then
    _err "Pasta $DIR não existe. Rode ./scripts/capturar_keybindings.sh primeiro."
fi

# Backup do estado atual antes de aplicar
mkdir -p "$BACKUP_DIR"
_info "Backup prévio em $BACKUP_DIR/"
for arquivo in "${!ALVOS[@]}"; do
    namespace="${ALVOS[$arquivo]}"
    dconf dump "$namespace" > "$BACKUP_DIR/$arquivo" 2>/dev/null || true
done
_ok "backup feito"

# Aplicar cada snapshot
for arquivo in "${!ALVOS[@]}"; do
    origem="$DIR/$arquivo"
    namespace="${ALVOS[$arquivo]}"
    if [[ ! -f "$origem" ]]; then
        _warn "$arquivo não existe em $DIR — pulando"
        continue
    fi
    dconf load "$namespace" < "$origem"
    _ok "$arquivo aplicado em $namespace"
done

_info "Som do PrintScreen desativado (event-sounds=false em org.gnome.desktop.sound)"
_info "Para recapturar novos atalhos após alterações: ./scripts/capturar_keybindings.sh"

# "A disciplina é a ponte entre metas e realizações." -- Jim Rohn
