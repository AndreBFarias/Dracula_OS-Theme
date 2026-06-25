#!/usr/bin/env bash
# dracula_video_wallpaper.sh — inicia o wallpaper de vídeo (xwinwrap + mpv) em
# CADA monitor. Instalado em ~/.local/bin/dracula-video-wallpaper e chamado
# pelo autostart no login. Robusto no GNOME/Mutter X11 (onde o Hidamari não
# renderiza de forma confiável nesta GPU). (SPRINT 30)
#
# Variáveis:
#   DRACULA_XWINWRAP        binário do xwinwrap (default ~/.local/bin/dracula-xwinwrap)
#   DRACULA_VIDEO_DIR       pasta do vídeo (default ~/.local/share/backgrounds/dracula-video)
#   DRACULA_WALLPAPER_SCALE keepaspect (centralizado, default) | panscan (preenche cortando)
#
# Sem argumento: inicia. Com `--stop`: encerra as instâncias.

set -euo pipefail

XWINWRAP="${DRACULA_XWINWRAP:-$HOME/.local/bin/dracula-xwinwrap}"
VIDEO_DIR="${DRACULA_VIDEO_DIR:-$HOME/.local/share/backgrounds/dracula-video}"
SCALE="${DRACULA_WALLPAPER_SCALE:-keepaspect}"

# Encerra só as NOSSAS instâncias (marcadas por nome único).
_stop() {
    pkill -f "dracula-xwinwrap" 2>/dev/null || true
    pkill -f "x11-name=dracula-wallpaper" 2>/dev/null || true
}

if [[ "${1:-}" == "--stop" ]]; then
    _stop
    echo "wallpaper de vídeo encerrado"
    exit 0
fi

command -v mpv >/dev/null 2>&1 || { echo "ERRO: mpv não instalado (sudo apt install mpv)"; exit 1; }
command -v xrandr >/dev/null 2>&1 || { echo "ERRO: xrandr não disponível"; exit 1; }
[[ -x "$XWINWRAP" ]] || { echo "ERRO: xwinwrap não encontrado em $XWINWRAP (rode instalar_wallpaper_video.sh)"; exit 1; }

# Vídeo: primeiro arquivo de vídeo no diretório.
video=""
shopt -s nullglob
for ext in mp4 webm mkv mov; do
    for f in "$VIDEO_DIR"/*."$ext"; do video="$f"; break 2; done
done
shopt -u nullglob
[[ -z "$video" ]] && { echo "ERRO: nenhum vídeo em $VIDEO_DIR"; exit 1; }

# Escala: centralizado (keepaspect) ou preenche cortando (panscan).
if [[ "$SCALE" == "panscan" ]]; then
    scale_opts=(--keepaspect=yes --panscan=1.0)
else
    scale_opts=(--keepaspect=yes --panscan=0.0)
fi

_stop
sleep 0.3

# Um xwinwrap + mpv por monitor (geometria via xrandr --listmonitors).
n=0
while IFS= read -r line; do
    g="$(printf '%s\n' "$line" | grep -oE '[0-9]+/[0-9]+x[0-9]+/[0-9]+\+[0-9]+\+[0-9]+' | head -1)"
    [[ -z "$g" ]] && continue
    geo="$(printf '%s\n' "$g" | sed -E 's#([0-9]+)/[0-9]+x([0-9]+)/[0-9]+\+([0-9]+)\+([0-9]+)#\1x\2+\3+\4#')"
    [[ -z "$geo" ]] && continue
    nohup "$XWINWRAP" -g "$geo" -ni -s -nf -fdt -b -- \
        mpv -wid WID --x11-name=dracula-wallpaper --loop --no-audio \
            --hwdec=no --no-osc --no-input-default-bindings --really-quiet \
            "${scale_opts[@]}" "$video" >/dev/null 2>&1 &
    disown
    n=$((n + 1))
done < <(xrandr --listmonitors 2>/dev/null | tail -n +2)

echo "wallpaper de vídeo iniciado em $n monitor(es): $(basename "$video") [$SCALE]"
exit 0
