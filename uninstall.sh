#!/usr/bin/env bash
# uninstall.sh — remove tudo que install.sh instalou

set -euo pipefail

MODO=""
for arg in "$@"; do
    case "$arg" in
        --user)   MODO="user" ;;
        --system) MODO="system" ;;
    esac
done

if [[ -z "$MODO" ]]; then
    echo "Uso: $0 --user|--system"
    exit 1
fi

case "$MODO" in
    user)
        DEST_ICONS="$HOME/.local/share/icons"
        DEST_THEMES="$HOME/.local/share/themes"
        SUDO=""
        ;;
    system)
        DEST_ICONS="/usr/share/icons"
        DEST_THEMES="/usr/share/themes"
        SUDO="sudo"
        ;;
esac

echo "Removendo instalação ($MODO)..."
for tema in Dracula-Icones dracula-icons-main dracula-icons-circle Dracula-Cursor; do
    $SUDO rm -rf "$DEST_ICONS/$tema" 2>/dev/null || true
done
$SUDO rm -rf "$DEST_THEMES/Dracula-standard-buttons" 2>/dev/null || true
rm -f "$HOME/.local/share/applications/com.rtosta.zapzap.desktop" 2>/dev/null || true
rm -f "$HOME/.local/share/applications/whatsapp-linux-app_whatsapp-linux-app.desktop" 2>/dev/null || true

# Reverter Pop!_Shell dark.css se backup existir
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f /usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css.orig ]]; then
    echo "Revertendo Pop!_Shell dark.css (pede sudo)..."
    sudo "$REPO_ROOT/scripts/instalar_pop_shell_css.sh" --revert || true
fi

echo "Desinstalação concluída. Reverta gsettings manualmente se necessário."

# "Memento mori." -- lembra-te que és mortal.
