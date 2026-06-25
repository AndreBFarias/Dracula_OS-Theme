#!/usr/bin/env bash
# instalar_wallpaper_video.sh — wallpaper de vídeo no GNOME/Mutter X11 via
# xwinwrap + mpv. (SPRINT 30 — substitui o backend Hidamari, que não renderiza
# de forma confiável nesta GPU AMD+NVIDIA sem VDPAU.)
#
# Compila o xwinwrap da fonte vendorizada (src/wallpaper/xwinwrap.c), instala
# um launcher por-monitor (~/.local/bin/dracula-video-wallpaper) + autostart, e
# inicia o wallpaper. Idempotente, sem sudo (mas exige pacotes apt abaixo).
#
# Pré-requisitos (apt — o script avisa se faltarem):
#   sudo apt install -y mpv libx11-dev libxext-dev libxrender-dev gcc
#
# Variáveis:
#   DRACULA_DRY_RUN=1          imprime e não altera nada.
#   DRACULA_WALLPAPER_VIDEO    vídeo-fonte (default assets/wallpapers/Only_god_is_real_art.mp4).
#   DRACULA_WALLPAPER_SCALE    keepaspect (centralizado, default) | panscan (preenche).
#
# Flags: --revert  --apenas-detectar  --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
REPO_ROOT="$(_repo_root "${BASH_SOURCE[0]}")"

XWINWRAP_SRC="$REPO_ROOT/src/wallpaper/xwinwrap.c"
XWINWRAP_BIN="$HOME/.local/bin/dracula-xwinwrap"
LAUNCHER_SRC="$SCRIPT_DIR/dracula_video_wallpaper.sh"
LAUNCHER_BIN="$HOME/.local/bin/dracula-video-wallpaper"
VIDEO_DEST_DIR="$HOME/.local/share/backgrounds/dracula-video"
AUTOSTART="$HOME/.config/autostart/dracula-video-wallpaper.desktop"
DRY="${DRACULA_DRY_RUN:-0}"

VIDEO_SRC="${DRACULA_WALLPAPER_VIDEO:-$REPO_ROOT/assets/wallpapers/Only_god_is_real_art.mp4}"
VIDEO_DEST="$VIDEO_DEST_DIR/$(basename "$VIDEO_SRC")"

REVERT=0
APENAS_DETECTAR=0
for arg in "$@"; do
    case "$arg" in
        --revert)          REVERT=1 ;;
        --apenas-detectar) APENAS_DETECTAR=1 ;;
        -h|--help) sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) _warn "Argumento ignorado: $arg" ;;
    esac
done

_run() {
    if [[ "$DRY" == "1" ]]; then
        _dim "[dry-run] $*"
    else
        # callers passam string com aspas internas; eval é intencional
        # shellcheck disable=SC2294
        eval "$@"
    fi
}

# ─── Detecção ───
if [[ $APENAS_DETECTAR -eq 1 ]]; then
    [[ -x "$XWINWRAP_BIN" ]] && _ok "xwinwrap: $XWINWRAP_BIN" || _warn "xwinwrap não compilado"
    [[ -x "$LAUNCHER_BIN" ]] && _ok "launcher: $LAUNCHER_BIN" || _warn "launcher ausente"
    [[ -f "$AUTOSTART" ]] && _ok "autostart presente" || _warn "sem autostart"
    command -v mpv >/dev/null && _ok "mpv: $(command -v mpv)" || _warn "mpv ausente"
    _info "instâncias rodando: $(pgrep -fc 'x11-name=dracula-wallpaper' 2>/dev/null || echo 0)"
    exit 0
fi

# ─── Revert ───
if [[ $REVERT -eq 1 ]]; then
    _info "Revertendo wallpaper de vídeo (xwinwrap+mpv)"
    [[ -x "$LAUNCHER_BIN" && "$DRY" != "1" ]] && "$LAUNCHER_BIN" --stop 2>/dev/null || true
    _run "pkill -f dracula-xwinwrap" || true
    for f in "$AUTOSTART" "$LAUNCHER_BIN" "$XWINWRAP_BIN"; do
        [[ -e "$f" ]] && _run "rm -f '$f'" && _dim "removido: $f"
    done
    if [[ -d "$VIDEO_DEST_DIR" ]] && validar_path_destrutivo "$VIDEO_DEST_DIR" >/dev/null 2>&1; then
        _run "rm -rf -- '$VIDEO_DEST_DIR'"
    fi
    # limpa também o autostart do antigo backend Hidamari, se existir
    _run "rm -f '$HOME/.config/autostart/dracula-hidamari.desktop'" || true
    _ok "Revertido"
    exit 0
fi

# ─── 1. Pré-requisitos (instala via apt automaticamente se faltarem) ───
PKGS_APT=(mpv libx11-dev libxext-dev libxrender-dev gcc x11-xserver-utils)
precisa_apt=0
command -v mpv    >/dev/null 2>&1 || precisa_apt=1
command -v gcc    >/dev/null 2>&1 || precisa_apt=1
command -v xrandr >/dev/null 2>&1 || precisa_apt=1
[[ -f /usr/include/X11/Xlib.h ]]                  || precisa_apt=1
[[ -f /usr/include/X11/extensions/Xrender.h ]]    || precisa_apt=1
[[ -f /usr/include/X11/extensions/shape.h ]]      || precisa_apt=1
if [[ $precisa_apt -eq 1 ]]; then
    _info "Instalando pré-requisitos via apt (pede sudo): ${PKGS_APT[*]}"
    if [[ "$DRY" == "1" ]]; then
        _dim "[dry-run] sudo apt-get install -y ${PKGS_APT[*]}"
    elif sudo apt-get install -y "${PKGS_APT[@]}"; then
        _ok "pré-requisitos instalados"
    else
        _err "Falha no apt. Rode manualmente: sudo apt install -y ${PKGS_APT[*]}"
        exit 1
    fi
else
    _dim "= pré-requisitos já presentes"
fi

# ─── 2. Compilar xwinwrap (idempotente: só se ausente ou fonte mais nova) ───
[[ -f "$XWINWRAP_SRC" ]] || _err "Fonte do xwinwrap ausente: $XWINWRAP_SRC"
if [[ -x "$XWINWRAP_BIN" && "$XWINWRAP_BIN" -nt "$XWINWRAP_SRC" ]]; then
    _dim "= xwinwrap já compilado"
else
    _info "Compilando xwinwrap"
    _run "mkdir -p '$HOME/.local/bin'"
    if [[ "$DRY" == "1" ]]; then
        _dim "[dry-run] gcc $XWINWRAP_SRC -lX11 -lXext -lXrender -o $XWINWRAP_BIN"
    elif gcc "$XWINWRAP_SRC" -L/usr/lib/x86_64-linux-gnu -lX11 -lXext -lXrender -o "$XWINWRAP_BIN" 2>/tmp/xwinwrap_build.log; then
        _ok "xwinwrap compilado: $XWINWRAP_BIN"
    else
        _err "Falha ao compilar xwinwrap (faltam libs?). Instale: sudo apt install -y libx11-dev libxext-dev libxrender-dev"
        head -5 /tmp/xwinwrap_build.log >&2
        exit 1
    fi
fi

# ─── 3. Copiar vídeo (idempotente) ───
[[ -f "$VIDEO_SRC" ]] || _err "Vídeo-fonte não encontrado: $VIDEO_SRC"
_run "mkdir -p '$VIDEO_DEST_DIR'"
if [[ -f "$VIDEO_DEST" ]] && cmp -s "$VIDEO_SRC" "$VIDEO_DEST"; then
    _dim "= vídeo já idêntico em $VIDEO_DEST"
else
    _run "cp -f '$VIDEO_SRC' '$VIDEO_DEST'" && _ok "vídeo copiado: $VIDEO_DEST"
fi

# ─── 4. Instalar launcher (idempotente) ───
if [[ -f "$LAUNCHER_BIN" ]] && cmp -s "$LAUNCHER_SRC" "$LAUNCHER_BIN"; then
    _dim "= launcher já idêntico"
else
    _run "install -m 0755 '$LAUNCHER_SRC' '$LAUNCHER_BIN'" && _ok "launcher: $LAUNCHER_BIN"
fi

# ─── 5. Autostart (idempotente) ───
read -r -d '' AUTOSTART_CONTENT <<EOF || true
[Desktop Entry]
Type=Application
Name=Dracula_OS — Wallpaper de vídeo
Comment=Inicia o wallpaper de vídeo (xwinwrap+mpv) no login
Exec=$LAUNCHER_BIN
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

# Remove o antigo backend Hidamari (autostart + Flatpak), substituído por este.
[[ -f "$HOME/.config/autostart/dracula-hidamari.desktop" ]] && _run "rm -f '$HOME/.config/autostart/dracula-hidamari.desktop'"
if command -v flatpak >/dev/null 2>&1 && flatpak info io.github.jeffshee.Hidamari >/dev/null 2>&1; then
    _info "Removendo backend antigo Hidamari (Flatpak)"
    _run "flatpak uninstall --user -y io.github.jeffshee.Hidamari" || _warn "uninstall do Hidamari falhou (não-fatal)"
fi

# ─── 6. Iniciar agora ───
if [[ "$DRY" == "1" ]]; then
    _dim "[dry-run] $LAUNCHER_BIN"
else
    "$LAUNCHER_BIN" || _warn "launcher retornou erro (veja a saída)"
fi

_ok "Wallpaper de vídeo (xwinwrap+mpv) pronto. Centralizado por padrão; DRACULA_WALLPAPER_SCALE=panscan para preencher."
exit 0
