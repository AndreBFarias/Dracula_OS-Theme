#!/usr/bin/env bash
# baixar_upstreams.sh — baixa os temas upstream (dracula-icons-main e circle)
# para src/icons/upstream/. Os upstreams estão no .gitignore para evitar
# repositório gigante (~120MB). Este script deve ser rodado após clonar o repo
# e antes do primeiro build.sh.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="$REPO_ROOT/src/icons/upstream"

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_RESET='\033[0m'

_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }

mkdir -p "$UPSTREAM"

# Fontes conhecidas dos upstreams
declare -A FONTES=(
    ["dracula-icons-main"]="https://github.com/m4thewz/dracula-icons.git"
    ["dracula-icons-circle"]="https://github.com/m4thewz/dracula-icons-circle.git"
)

# Tenta primeiro: cache local do usuário (se já instalou antes)
for nome in "${!FONTES[@]}"; do
    destino="$UPSTREAM/$nome"
    if [[ -d "$destino" && -f "$destino/index.theme" ]]; then
        _ok "$nome já presente"
        continue
    fi

    _info "Baixando $nome"

    # 1. Tentar copiar de ~/.local/share/icons/ se existir
    local_cache="$HOME/.local/share/icons/$nome"
    if [[ -d "$local_cache" ]]; then
        _info "  usando cache local: $local_cache"
        cp -r "$local_cache" "$destino"
        _ok "$nome copiado do cache local"
        continue
    fi

    # 2. Clonar do upstream
    url="${FONTES[$nome]}"
    tmp_dir=$(mktemp -d)
    if git clone --depth 1 "$url" "$tmp_dir" 2>&1 | tail -3; then
        cp -r "$tmp_dir"/* "$destino/" 2>/dev/null || cp -r "$tmp_dir" "$destino"
        rm -rf "$tmp_dir"
        _ok "$nome clonado"
    else
        rm -rf "$tmp_dir"
        echo "ERRO: falha ao baixar $nome de $url"
        echo "Baixe manualmente e extraia em $destino"
        exit 1
    fi
done

_ok "Todos os upstreams prontos em $UPSTREAM"

# "Nanos gigantium humeris insidentes." -- anoes sobre ombros de gigantes.
