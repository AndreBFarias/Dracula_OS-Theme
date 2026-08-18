#!/usr/bin/env bash
# reparar_hicolor_index.sh — mantém o index.theme do hicolor do usuário coerente
# com os diretórios que existem em disco.
#
# Problema que resolve:
#   ~/.local/share/icons/hicolor/index.theme costuma ser criado por instaladores
#   de terceiros declarando um punhado de tamanhos. A spec manda o GTK IGNORAR
#   qualquer diretório ausente de Directories=, então um ícone gravado em
#   64x64/apps ou 32x32/apps simplesmente não resolve — o arquivo existe, o
#   .desktop aponta certo, e Gtk.IconTheme.lookup_icon() devolve None. Pior:
#   gtk-update-icon-cache chega a indexar o arquivo, o que faz o cache parecer
#   correto e manda o diagnóstico para o lado errado.
#
#   Isto atinge este próprio repositório: atualizar_icones_steam.sh grava o
#   fallback em 32x32/apps.
#
# O que faz:
#   reescreve Directories= (e as seções correspondentes) a partir dos
#   diretórios <N>x<N>/apps, scalable/apps e symbolic/apps realmente presentes,
#   e regenera o cache.
#
# Idempotência:
#   recalcula sempre; só grava quando o conteúdo muda. Guarda index.theme.bak
#   na primeira alteração.
#
# Variáveis de ambiente:
#   DRACULA_DRY_RUN=1 — não grava; apenas informa o que mudaria.
#
# Saída:
#   exit 0 — OK (inclusive quando nada precisa mudar).
#   exit 1 — falha ao gravar o index.theme.
#
# Sem sudo. Toca apenas ~/.local/share/icons/hicolor/index.theme.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

readonly HICOLOR="$HOME/.local/share/icons/hicolor"
readonly INDEX="$HICOLOR/index.theme"
readonly DRY_RUN="${DRACULA_DRY_RUN:-0}"

if [[ ! -d "$HICOLOR" ]]; then
    _info "hicolor do usuário não existe; nada a reparar"
    exit 0
fi

# Tamanhos presentes, em ordem numérica; só conta o que tem apps/ dentro.
mapfile -t TAMANHOS < <(
    find "$HICOLOR" -maxdepth 1 -type d -regex '.*/[0-9]+x[0-9]+' -printf '%f\n' 2>/dev/null |
    cut -dx -f1 | sort -n
)

DIRS=()
for t in "${TAMANHOS[@]}"; do
    [[ -d "$HICOLOR/${t}x${t}/apps" ]] && DIRS+=("${t}x${t}/apps")
done
[[ -d "$HICOLOR/scalable/apps" ]] && DIRS+=("scalable/apps")
[[ -d "$HICOLOR/symbolic/apps" ]] && DIRS+=("symbolic/apps")

if [[ ${#DIRS[@]} -eq 0 ]]; then
    _info "hicolor do usuário sem diretórios apps/; nada a reparar"
    exit 0
fi

novo=$(
    printf '[Icon Theme]\nName=Hicolor\nComment=Fallback Icon Theme\nHidden=true\n'
    printf 'Directories=%s\n' "$(IFS=,; echo "${DIRS[*]}")"
    for d in "${DIRS[@]}"; do
        case "$d" in
            scalable/apps)
                printf '\n[scalable/apps]\nSize=48\nMinSize=8\nMaxSize=512\nContext=Applications\nType=Scalable\n' ;;
            symbolic/apps)
                printf '\n[symbolic/apps]\nSize=16\nMinSize=8\nMaxSize=512\nContext=Applications\nType=Scalable\n' ;;
            *)
                size="${d%x*}"
                printf '\n[%s]\nSize=%s\nContext=Applications\nType=Fixed\n' "$d" "$size" ;;
        esac
    done
)

if [[ -f "$INDEX" ]] && [[ "$novo" == "$(cat "$INDEX")" ]]; then
    _ok "index.theme do hicolor já declara os ${#DIRS[@]} diretórios existentes"
    exit 0
fi

if [[ "$DRY_RUN" == "1" ]]; then
    _info "[dry-run] index.theme passaria a declarar: ${DIRS[*]}"
    exit 0
fi

[[ -f "$INDEX" && ! -f "$INDEX.bak" ]] && cp "$INDEX" "$INDEX.bak"

if ! printf '%s\n' "$novo" > "$INDEX"; then
    _err "falha ao gravar $INDEX"
    exit 1
fi
_ok "index.theme do hicolor reparado (${#DIRS[@]} diretórios declarados)"

if command -v gtk-update-icon-cache &>/dev/null; then
    gtk-update-icon-cache -f -t "$HICOLOR" &>/dev/null && _ok "cache do hicolor regenerado" || true
fi
