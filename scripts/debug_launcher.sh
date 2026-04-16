#!/usr/bin/env bash
# debug_launcher.sh — roda H1-H6 da SPRINT-TRANSPARENCIA e imprime resultado

set -u

echo "=== H1: extensões carregadas ==="
gnome-extensions list --enabled 2>/dev/null | grep -iE "pop|cosmic" || echo "  nenhuma"

echo ""
echo "=== H2/H5: display server + compositor ==="
echo "  XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
xprop -root _NET_WM_CM_S0 2>/dev/null | head -3
echo "  Depth(s): $(xdpyinfo 2>/dev/null | grep 'depth of root' | awk '{print $NF}')"

echo ""
echo "=== H3: setters programáticos em JS ==="
grep -nE "set_style|background_color|Clutter\.Color" \
    /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/*.js 2>/dev/null | head -10 \
    || echo "  nenhum setter óbvio"

echo ""
echo "=== H6: dconf keys relacionadas ==="
gsettings list-recursively 2>/dev/null | grep -iE "pop-cosmic|pop-shell|launcher.*opacity|blur" | head -10 \
    || echo "  nenhuma key com opacity/blur"

echo ""
echo "=== dark.css instalado ==="
if grep -q "Dracula_OS-Theme\|rgba(40" /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css 2>/dev/null; then
    echo "  Dracula CSS aplicado"
else
    echo "  dark.css NÃO é nosso (reverter ou reinstalar)"
fi
