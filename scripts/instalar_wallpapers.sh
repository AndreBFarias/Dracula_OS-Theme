#!/usr/bin/env bash
# instalar_wallpapers.sh — copia wallpapers Dracula para
# ~/.local/share/backgrounds/dracula/. NÃO troca o wallpaper atual a menos
# que `--apply <nome>` seja passado.
#
# Idempotente (cmp -s antes de copiar). Sem sudo.
#
# Variáveis:
#   DRACULA_DRY_RUN=1   imprime cópias com prefixo [dry-run] e não executa.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
REPO_ROOT="$(_repo_root "${BASH_SOURCE[0]}")"

ORIGEM="$REPO_ROOT/assets/wallpapers"
DESTINO="$HOME/.local/share/backgrounds/dracula"
APPLY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply) APPLY="${2:-}"; shift 2 ;;
        --help|-h)
            cat <<'EOF'
Uso: instalar_wallpapers.sh [--apply <nome>]

Copia assets/wallpapers/*.png para ~/.local/share/backgrounds/dracula/
(idempotente). Com --apply <nome>, troca o wallpaper atual via gsettings.

Variáveis:
  DRACULA_DRY_RUN=1   apenas loga, não executa.
EOF
            exit 0 ;;
        *) _warn "Argumento ignorado: $1"; shift ;;
    esac
done

if [[ ! -d "$ORIGEM" ]]; then
    _err "Origem não encontrada: $ORIGEM"
    exit 1
fi

if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
    _dim "[dry-run] mkdir -p $DESTINO"
else
    mkdir -p "$DESTINO"
fi

shopt -s nullglob
copiados=0
for src in "$ORIGEM"/*.png; do
    nome="$(basename "$src")"
    dst="$DESTINO/$nome"
    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        _dim "= $nome (já idêntico)"
        continue
    fi
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] cp $src $dst"
    else
        cp -f "$src" "$dst" && _ok "copiado: $nome"
        copiados=$((copiados+1))
    fi
done
shopt -u nullglob

if [[ -d "$DESTINO" ]]; then
    total=$(find "$DESTINO" -maxdepth 1 -name '*.png' -type f 2>/dev/null | wc -l)
    _info "Wallpapers em $DESTINO: $total"
fi

if [[ -n "$APPLY" ]]; then
    alvo="$DESTINO/$APPLY"
    [[ "$APPLY" != *.png ]] && alvo="${alvo}.png"
    if [[ ! -f "$alvo" ]]; then
        _err "--apply: arquivo não encontrado: $alvo"
        exit 1
    fi
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] gsettings set org.gnome.desktop.background picture-uri file://$alvo"
        _dim "[dry-run] gsettings set org.gnome.desktop.background picture-uri-dark file://$alvo"
    else
        gsettings set org.gnome.desktop.background picture-uri "file://$alvo" \
            && _ok "picture-uri = $alvo" || _warn "Falha ao setar picture-uri"
        gsettings set org.gnome.desktop.background picture-uri-dark "file://$alvo" \
            && _ok "picture-uri-dark = $alvo" || _warn "Falha ao setar picture-uri-dark"
    fi
fi

exit 0
