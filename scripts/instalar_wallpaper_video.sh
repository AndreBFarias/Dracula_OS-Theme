#!/usr/bin/env bash
# instalar_wallpaper_video.sh — instala o Hidamari (Flatpak) e configura um
# vídeo como wallpaper animado, com autostart no login. Idempotente, sem sudo.
# (SPRINT 21)
#
# Fluxo:
#   1. Garante o remote flathub (user) e instala/atualiza io.github.jeffshee.Hidamari.
#   2. Dá ao Flatpak acesso à pasta de vídeos (xdg-videos).
#   3. Copia o vídeo-fonte para <Vídeos>/Hidamari/ (idempotente via cmp -s).
#   4. Garante o config.json do Hidamari (gera no primeiro run se ausente).
#   5. Aplica via jq: mode=MODE_VIDEO + todos os data_source (por monitor) -> vídeo.
#   6. (Re)inicia o wallpaper em background e cria autostart em ~/.config/autostart.
#
# Variáveis:
#   DRACULA_DRY_RUN=1         imprime comandos com prefixo [dry-run]; não altera nada.
#   DRACULA_WALLPAPER_VIDEO   caminho do vídeo-fonte (default:
#                             assets/wallpapers/Only_god_is_real_art.mp4).
#
# Flags:
#   --revert            remove autostart, encerra o Hidamari e reseta o modo
#                       para MODE_NULL (some o vídeo). Não desinstala o Flatpak.
#   --full              (com --revert) também desinstala o Flatpak e remove o
#                       vídeo copiado para <Vídeos>/Hidamari/.
#   --apenas-detectar   imprime o estado (instalado? modo? vídeo?) e sai (exit 0).
#   --help|-h           mostra esta ajuda.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
REPO_ROOT="$(_repo_root "${BASH_SOURCE[0]}")"

HIDAMARI_APP="io.github.jeffshee.Hidamari"
CONFIG_JSON="$HOME/.var/app/$HIDAMARI_APP/config/hidamari/config.json"
AUTOSTART="$HOME/.config/autostart/dracula-hidamari.desktop"
DRY="${DRACULA_DRY_RUN:-0}"

VIDEO_SRC="${DRACULA_WALLPAPER_VIDEO:-$REPO_ROOT/assets/wallpapers/Only_god_is_real_art.mp4}"

VIDEOS_DIR="$(xdg-user-dir VIDEOS 2>/dev/null || true)"
[[ -z "$VIDEOS_DIR" || ! -d "$VIDEOS_DIR" ]] && VIDEOS_DIR="$HOME/Vídeos"
[[ -d "$VIDEOS_DIR" ]] || VIDEOS_DIR="$HOME/Videos"
VIDEO_DEST_DIR="$VIDEOS_DIR/Hidamari"
VIDEO_DEST="$VIDEO_DEST_DIR/$(basename "$VIDEO_SRC")"

REVERT=0
FULL=0
APENAS_DETECTAR=0
for arg in "$@"; do
    case "$arg" in
        --revert)          REVERT=1 ;;
        --full)            FULL=1 ;;
        --apenas-detectar) APENAS_DETECTAR=1 ;;
        -h|--help)
            sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) _warn "Argumento ignorado: $arg" ;;
    esac
done

_run() {
    if [[ "$DRY" == "1" ]]; then
        _dim "[dry-run] $*"
    else
        # callers passam uma string com aspas internas; eval é intencional
        # shellcheck disable=SC2294
        eval "$@"
    fi
}

# ─── Encerrar Hidamari com segurança (sem auto-matar a própria shell) ───
_parar_hidamari() {
    flatpak kill "$HIDAMARI_APP" 2>/dev/null || true
    pkill -x hidamari-server 2>/dev/null || true
    pkill -x hidamari 2>/dev/null || true
}

# ─── Detecção ───
_detectar() {
    if flatpak info "$HIDAMARI_APP" >/dev/null 2>&1; then
        _ok "Hidamari instalado: $(flatpak info "$HIDAMARI_APP" 2>/dev/null | awk -F': ' '/Version:/{print $2; exit}')"
    else
        _warn "Hidamari NÃO instalado"
    fi
    if [[ -f "$CONFIG_JSON" ]]; then
        _info "modo: $(jq -r '.mode' "$CONFIG_JSON" 2>/dev/null)"
        _info "vídeo (Default): $(jq -r '.data_source.Default // ""' "$CONFIG_JSON" 2>/dev/null)"
    else
        _info "sem config.json ainda"
    fi
    [[ -f "$AUTOSTART" ]] && _ok "autostart presente: $AUTOSTART" || _warn "sem autostart"
}

if [[ $APENAS_DETECTAR -eq 1 ]]; then
    _detectar
    exit 0
fi

# ─── Revert ───
if [[ $REVERT -eq 1 ]]; then
    _info "Revertendo wallpaper de vídeo (Hidamari)"
    if [[ -f "$AUTOSTART" ]]; then
        _run "rm -f '$AUTOSTART'" && _ok "autostart removido"
    fi
    _parar_hidamari
    if [[ -f "$CONFIG_JSON" ]]; then
        tmp="$(mktemp)"
        if [[ "$DRY" == "1" ]]; then
            _dim "[dry-run] jq .mode=MODE_NULL em $CONFIG_JSON"
        else
            jq '.mode = "MODE_NULL"' "$CONFIG_JSON" > "$tmp" && mv "$tmp" "$CONFIG_JSON"
            _ok "modo resetado para MODE_NULL"
        fi
    fi
    if [[ $FULL -eq 1 ]]; then
        _run "flatpak uninstall -y --user '$HIDAMARI_APP'" || _warn "uninstall do Hidamari falhou"
        [[ -f "$VIDEO_DEST" ]] && _run "rm -f '$VIDEO_DEST'" && _ok "vídeo copiado removido"
    fi
    _ok "Revertido"
    exit 0
fi

# ─── 1. Flatpak + flathub ───
if ! command -v flatpak >/dev/null 2>&1; then
    _err "flatpak não encontrado. Instale: sudo apt install flatpak"
    exit 1
fi
if ! flatpak remotes --user 2>/dev/null | grep -q flathub; then
    _info "Adicionando remote flathub (user)"
    _run "flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo"
fi

# ─── 2. Instalar/atualizar Hidamari ───
if flatpak info "$HIDAMARI_APP" >/dev/null 2>&1; then
    _ok "Hidamari já instalado (mantendo; use flatpak update para atualizar)"
else
    _info "Instalando Hidamari (Flatpak)"
    _run "flatpak install -y --user flathub '$HIDAMARI_APP'" || { _err "Falha ao instalar Hidamari"; exit 1; }
fi

# ─── 3. Acesso do Flatpak à pasta de vídeos ───
_run "flatpak override --user --filesystem=xdg-videos '$HIDAMARI_APP'"

# ─── 4. Copiar vídeo-fonte (idempotente) ───
if [[ ! -f "$VIDEO_SRC" ]]; then
    _err "Vídeo-fonte não encontrado: $VIDEO_SRC"
    _err "Defina DRACULA_WALLPAPER_VIDEO ou coloque o arquivo em assets/wallpapers/."
    exit 1
fi
_run "mkdir -p '$VIDEO_DEST_DIR'"
if [[ -f "$VIDEO_DEST" ]] && cmp -s "$VIDEO_SRC" "$VIDEO_DEST"; then
    _dim "= vídeo já idêntico em $VIDEO_DEST"
else
    _run "cp -f '$VIDEO_SRC' '$VIDEO_DEST'" && _ok "vídeo copiado: $VIDEO_DEST"
fi

# ─── 5. Garantir config.json (gerar no primeiro run se ausente) ───
if [[ ! -f "$CONFIG_JSON" && "$DRY" != "1" ]]; then
    _info "Gerando config inicial do Hidamari (primeiro run)"
    nohup flatpak run "$HIDAMARI_APP" -b >/dev/null 2>&1 &
    for _ in $(seq 1 30); do
        [[ -f "$CONFIG_JSON" ]] && break
        sleep 0.5
    done
    _parar_hidamari
fi

# ─── 6. Aplicar vídeo na config (idempotente) ───
if [[ "$DRY" == "1" ]]; then
    _dim "[dry-run] jq .mode=MODE_VIDEO + data_source(todos)='$VIDEO_DEST' em $CONFIG_JSON"
elif [[ -f "$CONFIG_JSON" ]]; then
    ja_ok="$(jq -r --arg v "$VIDEO_DEST" '
        if (.mode == "MODE_VIDEO")
           and ([.data_source[]] | length > 0)
           and (all(.data_source[]; . == $v))
           and (.is_pause_when_maximized == false)
        then "sim" else "nao" end' "$CONFIG_JSON" 2>/dev/null || echo "nao")"
    if [[ "$ja_ok" == "sim" ]]; then
        _dim "= config já aponta para o vídeo (idempotente)"
    else
        tmp="$(mktemp)"
        # is_pause_when_maximized=false: anima sempre, mesmo com janela
        # maximizada (o default true fazia o vídeo "parar" no uso diário).
        jq --arg v "$VIDEO_DEST" '
            .mode = "MODE_VIDEO"
            | .is_first_time = false
            | .is_pause_when_maximized = false
            | .data_source = ((.data_source // {}) + {"Default": $v} | with_entries(.value = $v))
        ' "$CONFIG_JSON" > "$tmp" && mv "$tmp" "$CONFIG_JSON"
        _ok "config aplicada (MODE_VIDEO + data_source + anima sempre)"
        _parar_hidamari
        nohup flatpak run "$HIDAMARI_APP" -b >/dev/null 2>&1 &
        # picture-options=centered: preferência do usuário (vídeo retrato
        # centralizado, sem o zoom que corta/rola a imagem).
        gsettings set org.gnome.desktop.background picture-options 'centered' 2>/dev/null || true
        _ok "wallpaper de vídeo iniciado"
    fi
else
    _warn "config.json não disponível; abra o Hidamari uma vez e rode novamente"
fi

# ─── 7. Autostart no login (idempotente) ───
read -r -d '' AUTOSTART_CONTENT <<EOF || true
[Desktop Entry]
Type=Application
Name=Dracula_OS — Wallpaper de vídeo (Hidamari)
Comment=Inicia o wallpaper animado do Dracula_OS-Theme no login
Exec=flatpak run $HIDAMARI_APP -b
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
if [[ "$DRY" == "1" ]]; then
    _dim "[dry-run] escrever $AUTOSTART"
elif [[ -f "$AUTOSTART" ]] && [[ "$(cat "$AUTOSTART")" == "$AUTOSTART_CONTENT" ]]; then
    _dim "= autostart já idêntico"
else
    mkdir -p "$(dirname "$AUTOSTART")"
    printf '%s\n' "$AUTOSTART_CONTENT" > "$AUTOSTART"
    _ok "autostart criado: $AUTOSTART"
fi

_ok "Wallpaper de vídeo configurado. Se não aparecer, recarregue a sessão."
exit 0
