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

# Reverter localização pt-BR do pop-cosmic se cópia local existir
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$HOME/.local/share/gnome-shell/extensions/pop-cosmic@system76.com" ]]; then
    echo "Removendo cópia pt-BR local do launcher Pop!_Cosmic..."
    "$REPO_ROOT/scripts/desinstalar_pop_cosmic_ptbr.sh" || true
fi

# Reverter higiene do launcher (esconder gnome-session-properties + pasta Utilities)
if [[ -x "$REPO_ROOT/scripts/desinstalar_higiene_launcher.sh" ]]; then
    echo "Revertendo higiene do app-grid Pop!_Cosmic..."
    "$REPO_ROOT/scripts/desinstalar_higiene_launcher.sh" || true
fi

# Reverter Pop!_Shell dark.css se backup existir
if [[ -f /usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css.orig ]]; then
    echo "Revertendo Pop!_Shell dark.css (pede sudo)..."
    sudo "$REPO_ROOT/scripts/instalar_pop_shell_css.sh" --revert || true
fi

# Remover temas de som instalados por --sounds (Dracula default + Pop legado)
for tema_som in Dracula Pop; do
    if [[ -d "$HOME/.local/share/sounds/$tema_som" ]] || [[ -d "/usr/share/sounds/$tema_som" ]]; then
        echo "Removendo tema de som $tema_som..."
        "$REPO_ROOT/scripts/instalar_sons.sh" "--$MODO" --theme "$tema_som" --revert 2>/dev/null || true
    fi
done

# Reverter wallpapers Dracula (se instalados)
if [[ -d "$HOME/.local/share/backgrounds/dracula" ]]; then
    echo "Removendo wallpapers Dracula..."
    "$REPO_ROOT/scripts/desinstalar_wallpapers.sh" || true
fi

# Reverter wallpaper de vídeo (Hidamari). DRACULA_HIDAMARI_FULL=1 também
# desinstala o Flatpak e remove o vídeo copiado; sem a flag, apenas remove o
# autostart e reseta o modo do Hidamari (some o vídeo, app permanece).
if [[ "$MODO" == "user" ]]; then
    if [[ -f "$HOME/.config/autostart/dracula-hidamari.desktop" ]] \
       || flatpak info io.github.jeffshee.Hidamari >/dev/null 2>&1; then
        echo "Revertendo wallpaper de vídeo (Hidamari)..."
        if [[ "${DRACULA_HIDAMARI_FULL:-0}" == "1" ]]; then
            "$REPO_ROOT/scripts/instalar_wallpaper_video.sh" --revert --full || true
        else
            "$REPO_ROOT/scripts/instalar_wallpaper_video.sh" --revert || true
        fi
    fi
fi

# Reverter Spicetify (SPRINT 18). DRACULA_SPICETIFY_FULL=1 remove
# ~/.spicetify e ~/.config/spicetify; sem a flag, apenas restaura o
# Spotify ao estado original (preservando configs do Spicetify).
if [[ -x "$HOME/.spicetify/spicetify" ]] || [[ -d "$HOME/.spicetify" ]]; then
    echo "Revertendo Spicetify..."
    if [[ "${DRACULA_SPICETIFY_FULL:-0}" == "1" ]]; then
        "$REPO_ROOT/scripts/desinstalar_spicetify.sh" --full || true
    else
        "$REPO_ROOT/scripts/desinstalar_spicetify.sh" || true
    fi
fi

# Reverter APT hook (requer sudo; remove o gatilho pós apt upgrade)
if [[ -f /etc/apt/apt.conf.d/99-dracula-os-theme ]]; then
    echo "Removendo APT hook (pede sudo)..."
    sudo "$REPO_ROOT/scripts/instalar_apt_hook.sh" --revert || true
fi

# Reverter extensões GNOME do manifesto (desativa via gnome-extensions disable)
if [[ "$MODO" == "user" ]] && command -v gnome-extensions >/dev/null 2>&1; then
    echo "Desativando extensões GNOME do manifesto..."
    "$REPO_ROOT/scripts/instalar_gnome_extensions.sh" --revert || true
fi

# Reverter atalhos de teclado (restaura backup mais recente do dconf)
if [[ "$MODO" == "user" ]]; then
    if compgen -G "$HOME/.cache/dracula_os_backup/keybindings_*" >/dev/null 2>&1 \
       || compgen -G "$HOME/.cache/dracula_os_backup_keybindings_*" >/dev/null 2>&1; then
        echo "Restaurando atalhos de teclado anteriores..."
        "$REPO_ROOT/scripts/instalar_keybindings.sh" --revert || true
    fi
fi

# Reverter ícones de jogos Steam patcheados (PNGs em hicolor/{256x256,32x32}/apps)
if [[ "$MODO" == "user" ]]; then
    removidos=0
    for tamanho in 256x256 32x32; do
        dir="$HOME/.local/share/icons/hicolor/$tamanho/apps"
        [[ -d "$dir" ]] || continue
        if validar_path_destrutivo "$dir" >/dev/null 2>&1; then
            shopt -s nullglob
            for png in "$dir"/steam_icon_*.png; do
                rm -f "$png" && removidos=$((removidos+1))
            done
            shopt -u nullglob
        fi
    done
    if [[ $removidos -gt 0 ]]; then
        echo "Removidos $removidos ícone(s) Steam patcheado(s)."
    fi
fi

echo "Desinstalação concluída. Reverta gsettings manualmente se necessário."

# "Memento mori." -- lembra-te que és mortal.
