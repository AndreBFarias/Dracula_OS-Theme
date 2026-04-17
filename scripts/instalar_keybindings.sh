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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

REPO_ROOT="$(_repo_root "${BASH_SOURCE[0]}")"
DIR="$REPO_ROOT/app-themes/keybindings"
TS=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.cache/dracula_os_backup/keybindings_$TS"

REVERT=0
for arg in "$@"; do
    case "$arg" in
        --revert) REVERT=1 ;;
    esac
done

# Trap de cleanup: se interrompido no meio da aplicação, restaura o backup
_estado_aplicacao="pendente"
_cleanup_keybindings() {
    local exit_code="${1:-0}"
    if [[ "$_estado_aplicacao" == "em-progresso" && $exit_code -ne 0 ]]; then
        _warn "Interrompido durante aplicação — restaurando backup de $BACKUP_DIR"
        for arquivo in "${!ALVOS[@]}"; do
            local origem="$BACKUP_DIR/$arquivo"
            local namespace="${ALVOS[$arquivo]}"
            [[ -f "$origem" ]] && dconf load "$namespace" < "$origem" 2>/dev/null || true
        done
    fi
}
trap_cleanup_init _cleanup_keybindings

# Mapeamento arquivo → namespace dconf
declare -A ALVOS=(
    ["media-keys.dconf"]="/org/gnome/settings-daemon/plugins/media-keys/"
    ["wm-keybindings.dconf"]="/org/gnome/desktop/wm/keybindings/"
    ["terminal.dconf"]="/org/gnome/terminal/legacy/keybindings/"
    ["sound.dconf"]="/org/gnome/desktop/sound/"
)

if [[ $REVERT -eq 1 ]]; then
    ultimo_backup=$(ls -dt "$HOME"/.cache/dracula_os_backup/keybindings_* "$HOME"/.cache/dracula_os_backup_keybindings_* 2>/dev/null | head -1)
    if [[ -z "$ultimo_backup" ]]; then
        _err "Nenhum backup de keybindings encontrado em ~/.cache/dracula_os_backup/"
        exit 1
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
    exit 1
fi

# Backup do estado atual antes de aplicar
mkdir -p "$BACKUP_DIR"
_info "Backup prévio em $BACKUP_DIR/"
for arquivo in "${!ALVOS[@]}"; do
    namespace="${ALVOS[$arquivo]}"
    dconf dump "$namespace" > "$BACKUP_DIR/$arquivo" 2>/dev/null || true
done
_ok "backup feito"

# Aplicar cada snapshot — marca estado para o trap de cleanup
_estado_aplicacao="em-progresso"
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
_estado_aplicacao="concluido"

_info "Som do PrintScreen desativado (event-sounds=false em org.gnome.desktop.sound)"
_info "Para recapturar novos atalhos após alterações: ./scripts/capturar_keybindings.sh"

# "A disciplina é a ponte entre metas e realizações." -- Jim Rohn
