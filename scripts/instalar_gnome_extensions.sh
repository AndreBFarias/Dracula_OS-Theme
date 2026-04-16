#!/usr/bin/env bash
# instalar_gnome_extensions.sh — instala + configura extensões GNOME do manifesto
#
# Lê app-themes/gnome-extensions/extensions.json e para cada UUID:
#   1. Se já presente em ~/.local/share/gnome-shell/extensions/<uuid>/, pula download
#   2. Se o UUID está no EGO (extensions.gnome.org), usa gnome-extensions install
#   3. Fallback: clona o repo git (opcional: branch/subdir) e copia para
#      ~/.local/share/gnome-shell/extensions/<uuid>/
# Depois ativa via `gnome-extensions enable` e aplica dconf da config salva.
#
# Uso:
#   ./scripts/instalar_gnome_extensions.sh              # instala + ativa + aplica dconf
#   ./scripts/instalar_gnome_extensions.sh --only-dconf # só aplica dconf (já instaladas)
#   ./scripts/instalar_gnome_extensions.sh --revert     # desativa todas do manifesto

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFESTO="$REPO_ROOT/app-themes/gnome-extensions/extensions.json"
DCONF_DIR="$REPO_ROOT/app-themes/gnome-extensions/dconf"
DEST_EXT="$HOME/.local/share/gnome-shell/extensions"

ONLY_DCONF=0
REVERT=0
for arg in "$@"; do
    case "$arg" in
        --only-dconf) ONLY_DCONF=1 ;;
        --revert)     REVERT=1 ;;
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

command -v jq >/dev/null || _err "jq não encontrado. Instale: sudo apt install jq"
command -v gnome-extensions >/dev/null || _err "gnome-extensions CLI não disponível"
[[ -f "$MANIFESTO" ]] || _err "Manifesto não encontrado: $MANIFESTO"

mkdir -p "$DEST_EXT"

# Extrai UUIDs em array
mapfile -t UUIDS < <(jq -r '.extensions[].uuid' "$MANIFESTO")

if [[ $REVERT -eq 1 ]]; then
    _info "Desativando extensões do manifesto"
    for uuid in "${UUIDS[@]}"; do
        gnome-extensions disable "$uuid" 2>/dev/null && _ok "$uuid desativada" || _warn "$uuid não estava ativa"
    done
    exit 0
fi

# Instalar + ativar + aplicar dconf
for uuid in "${UUIDS[@]}"; do
    echo ""
    _info "Processando $uuid"

    repo=$(jq -r --arg u "$uuid" '.extensions[] | select(.uuid==$u) | .repo // ""' "$MANIFESTO")
    branch=$(jq -r --arg u "$uuid" '.extensions[] | select(.uuid==$u) | .repo_branch // ""' "$MANIFESTO")
    subdir=$(jq -r --arg u "$uuid" '.extensions[] | select(.uuid==$u) | .repo_subdir // ""' "$MANIFESTO")
    dconf_file=$(jq -r --arg u "$uuid" '.extensions[] | select(.uuid==$u) | .dconf // ""' "$MANIFESTO")

    if [[ $ONLY_DCONF -eq 0 ]]; then
        # 1. Já presente?
        if [[ -d "$DEST_EXT/$uuid" && -f "$DEST_EXT/$uuid/metadata.json" ]]; then
            _ok "já instalada"
        # 2. Tentar EGO
        elif gnome-extensions install --force "$uuid" 2>/dev/null; then
            _ok "instalada via EGO"
        # 3. Fallback git
        elif [[ -n "$repo" ]]; then
            _info "  clonando $repo"
            tmp=$(mktemp -d)
            clone_args=("--depth" "1")
            [[ -n "$branch" ]] && clone_args+=("-b" "$branch")
            if git clone "${clone_args[@]}" "$repo" "$tmp" 2>&1 | tail -2; then
                if [[ -n "$subdir" ]]; then
                    cp -r "$tmp/$subdir" "$DEST_EXT/$uuid"
                else
                    cp -r "$tmp" "$DEST_EXT/$uuid"
                fi
                rm -rf "$tmp"
                _ok "instalada via git"
            else
                rm -rf "$tmp"
                _warn "falha ao clonar — instale manualmente via extensions.gnome.org"
                continue
            fi
        else
            _warn "sem repo definido — instale manualmente"
            continue
        fi

        # Ativar
        gnome-extensions enable "$uuid" 2>/dev/null && _ok "ativada" || _warn "falha ao ativar (recarregar shell)"
    fi

    # Aplicar dconf se houver
    if [[ -n "$dconf_file" && -f "$DCONF_DIR/$dconf_file" ]]; then
        namespace_key="${dconf_file%.dconf}"
        dconf load "/org/gnome/shell/extensions/$namespace_key/" < "$DCONF_DIR/$dconf_file"
        _ok "dconf aplicado em /org/gnome/shell/extensions/$namespace_key/"
    fi
done

echo ""
_info "Recarregue o shell para ativar extensões recém-baixadas:"
_info "  X11: Alt+F2 → r → Enter"
_info "  Wayland: logout/login"

# "A verdadeira liberdade é a autonomia da vontade." -- Kant
