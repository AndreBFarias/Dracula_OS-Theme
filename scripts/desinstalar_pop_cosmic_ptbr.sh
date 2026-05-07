#!/usr/bin/env bash
# desinstalar_pop_cosmic_ptbr.sh — remove cópia local pt-BR do pop-cosmic.

set -euo pipefail

USER_EXT="${POP_COSMIC_USER_DIR:-$HOME/.local/share/gnome-shell/extensions/pop-cosmic@system76.com}"

if [[ ! -d "$USER_EXT" ]]; then
    echo "OK: nada a desinstalar (pop-cosmic pt-BR não está em $USER_EXT)."
    exit 0
fi

rm -rf "$USER_EXT"
echo "OK: pop-cosmic pt-BR removido de $USER_EXT"
echo "    GNOME Shell volta a usar a versão original do sistema após reload (Alt+F2 r)."
