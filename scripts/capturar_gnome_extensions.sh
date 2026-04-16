#!/usr/bin/env bash
# capturar_gnome_extensions.sh — snapshot das configurações dconf das extensões
#
# Roda dconf dump em cada namespace conhecido abaixo de
# /org/gnome/shell/extensions/ e grava em app-themes/gnome-extensions/dconf/.
# Namespaces sem conteúdo são ignorados.
#
# O manifesto (extensions.json) deve ser atualizado manualmente quando o
# usuário instala uma nova extensão, incluindo o UUID e o repo upstream.
#
# Uso:
#   ./scripts/capturar_gnome_extensions.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$REPO_ROOT/app-themes/gnome-extensions/dconf"

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RESET='\033[0m'

_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }
_skip() { echo -e "  ${C_YELLOW}--${C_RESET} $*"; }

mkdir -p "$DIR"

_info "Capturando dconf das extensões em $DIR/"

total=0
pulados=0
for ns in $(dconf list /org/gnome/shell/extensions/ 2>/dev/null | sed 's:/$::'); do
    arquivo="$DIR/${ns}.dconf"
    conteudo=$(dconf dump "/org/gnome/shell/extensions/$ns/" 2>/dev/null)
    bytes=${#conteudo}

    if [[ $bytes -lt 10 ]]; then
        rm -f "$arquivo"
        _skip "$ns (sem customização)"
        pulados=$((pulados + 1))
        continue
    fi

    echo "$conteudo" > "$arquivo"
    _ok "$ns.dconf ($bytes bytes)"
    total=$((total + 1))
done

echo ""
_ok "Capturados: $total arquivos, pulados: $pulados"
_info "Lembre de atualizar app-themes/gnome-extensions/extensions.json se incluir nova extensão"

# "O verdadeiro rei é aquele que governa sobre si mesmo." -- Epicuro
