#!/usr/bin/env bash
# uninstall.sh — remove tudo que install.sh instalou

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/scripts/lib/common.sh"

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
    alvo="$DEST_ICONS/$tema"
    if [[ -e "$alvo" ]]; then
        validar_path_destrutivo "$alvo" || { _err "Pulando $alvo por segurança"; continue; }
        $SUDO rm -rf "$alvo"
    fi
done
alvo="$DEST_THEMES/Dracula-standard-buttons"
if [[ -e "$alvo" ]]; then
    validar_path_destrutivo "$alvo" || _err "Pulando $alvo por segurança"
    [[ -e "$alvo" ]] && $SUDO rm -rf "$alvo"
fi
rm -f "$HOME/.local/share/applications/com.rtosta.zapzap.desktop" 2>/dev/null || true
rm -f "$HOME/.local/share/applications/whatsapp-linux-app_whatsapp-linux-app.desktop" 2>/dev/null || true

# Reverter Pop!_Shell dark.css se backup existir
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f /usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css.orig ]]; then
    echo "Revertendo Pop!_Shell dark.css (pede sudo)..."
    sudo "$REPO_ROOT/scripts/instalar_pop_shell_css.sh" --revert || true
fi

# Remover tema de som Pop instalado por --sounds
if [[ -d "$HOME/.local/share/sounds/Pop" ]] || [[ -d /usr/share/sounds/Pop ]]; then
    echo "Removendo tema de som Pop..."
    "$REPO_ROOT/scripts/instalar_sons.sh" "--$MODO" --revert 2>/dev/null || true
fi

echo "Desinstalação concluída. Reverta gsettings manualmente se necessário."

# "Memento mori." -- lembra-te que és mortal.
