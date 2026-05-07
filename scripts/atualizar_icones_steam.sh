#!/usr/bin/env bash
# atualizar_icones_steam.sh — patcher universal de ícones de jogos Steam.
#
# Propósito:
#   Materializar ícones em alta resolução (256x256) para jogos Steam nativos
#   instalados, lendo a arte de biblioteca já baixada pelo cliente Steam em
#   ~/.steam/debian-installation/appcache/librarycache/<APPID>/ e gerando o
#   PNG correspondente em
#   ~/.local/share/icons/hicolor/256x256/apps/steam_icon_<APPID>.png.
#
# Descoberta de APPIDs:
#   varredura de ~/.local/share/applications/*.desktop por linha
#   ^Icon=steam_icon_(<APPID numérico>).
#
# Idempotência:
#   pula APPID quando o destino é mais recente que a fonte primária.
#   Flag --force ignora a verificação e regenera.
#
# Variáveis de ambiente:
#   DRACULA_DRY_RUN=1 — não cria nem modifica arquivos; apenas loga ações.
#
# Saída:
#   exit 0 — OK (mesmo sem jogos detectados).
#   exit 1 — falha em pelo menos um APPID processado.
#   exit 2 — argumento inválido.
#   exit 3 — ImageMagick 'convert' ausente.
#
# Sem sudo. Não toca ~/.steam/, /usr/share/, /etc/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

readonly STEAM_LIBCACHE="$HOME/.steam/debian-installation/appcache/librarycache"
readonly DESKTOP_DIR="$HOME/.local/share/applications"
readonly ICONE_DEST_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
readonly ICONE_FALLBACK_DIR="$HOME/.local/share/icons/hicolor/32x32/apps"
readonly DRY_RUN="${DRACULA_DRY_RUN:-0}"

uso() {
    cat <<EOF
Uso: $(basename "$0") [--force] [-h|--help]

  --force      Regenera os PNGs mesmo quando o destino é mais novo que a fonte.
  -h, --help   Mostra esta mensagem.

Variáveis:
  DRACULA_DRY_RUN=1   Não cria/modifica arquivos; apenas loga.
EOF
}

FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force)   FORCE=1 ;;
        -h|--help) uso; exit 0 ;;
        *)         _err "Argumento desconhecido: $arg"; uso >&2; exit 2 ;;
    esac
done

if ! command -v convert >/dev/null 2>&1; then
    _err "ImageMagick 'convert' não encontrado. Instale com: sudo apt install imagemagick"
    exit 3
fi

if [[ "$DRY_RUN" != "1" ]]; then
    mkdir -p "$ICONE_DEST_DIR"
fi

declare -a APPIDS=()
if [[ -d "$DESKTOP_DIR" ]]; then
    shopt -s nullglob
    for desktop in "$DESKTOP_DIR"/*.desktop; do
        appid=$(grep -oE '^Icon=steam_icon_[0-9]+' "$desktop" 2>/dev/null \
                | head -n1 | sed -E 's/^Icon=steam_icon_//' || true)
        if [[ -n "$appid" ]]; then
            APPIDS+=("$appid")
        fi
    done
    shopt -u nullglob
fi

if [[ ${#APPIDS[@]} -gt 0 ]]; then
    mapfile -t APPIDS < <(printf '%s\n' "${APPIDS[@]}" | sort -u)
fi

_info "APPIDs detectados: ${#APPIDS[@]}"
if [[ ${#APPIDS[@]} -eq 0 ]]; then
    _ok "Nenhum jogo Steam encontrado em $DESKTOP_DIR — nada a fazer"
    exit 0
fi

processar_appid() {
    local appid="$1"
    local dest="$ICONE_DEST_DIR/steam_icon_${appid}.png"
    local libdir="$STEAM_LIBCACHE/$appid"
    local fallback="$ICONE_FALLBACK_DIR/steam_icon_${appid}.png"

    local src="" tipo=""
    if [[ -f "$libdir/library_600x900.jpg" ]]; then
        src="$libdir/library_600x900.jpg"; tipo="capsule"
    elif [[ -f "$libdir/library_header.jpg" ]]; then
        src="$libdir/library_header.jpg"; tipo="header"
    elif [[ -f "$fallback" ]]; then
        src="$fallback"; tipo="fallback32"
    fi

    if [[ -z "$src" ]]; then
        _warn "appid $appid: nenhuma fonte disponível, pulando"
        return 0
    fi

    if [[ "$FORCE" != "1" && -f "$dest" ]]; then
        local mt_dest mt_src
        mt_dest=$(stat -c %Y "$dest" 2>/dev/null || echo 0)
        mt_src=$(stat -c %Y "$src" 2>/dev/null || echo 0)
        if [[ "$mt_dest" -ge "$mt_src" ]]; then
            _dim "appid $appid: ícone atualizado ($tipo) — pulando"
            return 0
        fi
    fi

    local cmd
    case "$tipo" in
        capsule)    cmd=(convert "$src" -gravity center -extent 300x300 -resize 256x256 -strip "$dest") ;;
        header)     cmd=(convert "$src" -gravity center -extent 215x215 -resize 256x256 -strip "$dest") ;;
        fallback32) cmd=(convert "$src" -filter point -resize 256x256 -strip "$dest") ;;
    esac

    if [[ "$DRY_RUN" = "1" ]]; then
        _dim "[dry-run] ${cmd[*]}"
        return 0
    fi

    if "${cmd[@]}" 2>/dev/null; then
        local sz
        sz=$(stat -c %s "$dest" 2>/dev/null || echo 0)
        if [[ "$sz" -lt 1024 ]]; then
            _warn "appid $appid: PNG gerado < 1 KB ($sz bytes) — possivelmente corrompido"
            rm -f "$dest"
            return 1
        fi
        _ok "appid $appid: $tipo → 256x256 ($sz bytes)"
    else
        _warn "appid $appid: convert falhou"
        return 1
    fi
}

sucesso=0
falha=0
for appid in "${APPIDS[@]}"; do
    if processar_appid "$appid"; then
        sucesso=$((sucesso + 1))
    else
        falha=$((falha + 1))
    fi
done

if [[ "$DRY_RUN" != "1" && $sucesso -gt 0 ]]; then
    if gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null; then
        _ok "icon-theme.cache regenerado em ~/.local/share/icons/hicolor"
    else
        _dim "gtk-update-icon-cache falhou (não-fatal)"
    fi
fi

_info "Resumo: ${#APPIDS[@]} APPIDs, $sucesso processados, $falha com falha"
[[ $falha -eq 0 ]] && exit 0 || exit 1

# "O ícone certo no lugar certo." -- e o que o cliente Steam não entrega em
# alta resolução, o tema entrega via librarycache.
