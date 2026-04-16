#!/usr/bin/env bash
# install.sh — instala Dracula_OS-Theme em nível user ou system
#
# Uso:
#   ./install.sh --user              # copia para ~/.local/share/{icons,themes}/
#   ./install.sh --system            # copia para /usr/share/{icons,themes}/ (sudo)
#   ./install.sh --user --activate   # + ativa via gsettings
#   ./install.sh --user --app-themes # + aplica temas internos (kitty, qbittorrent, etc.)
#   ./install.sh --user --all        # tudo acima

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$REPO_ROOT/dist"

MODO=""
ATIVAR=0
APP_THEMES=0
POP_SHELL_CSS=0

for arg in "$@"; do
    case "$arg" in
        --user)    MODO="user" ;;
        --system)  MODO="system" ;;
        --activate) ATIVAR=1 ;;
        --app-themes) APP_THEMES=1 ;;
        --pop-shell-css) POP_SHELL_CSS=1 ;;
        --all) ATIVAR=1; APP_THEMES=1; POP_SHELL_CSS=1 ;;
    esac
done

if [[ -z "$MODO" ]]; then
    echo "Uso: $0 --user|--system [--activate] [--app-themes] [--all]"
    exit 1
fi

if [[ ! -d "$DIST" ]] || [[ -z "$(ls -A "$DIST" 2>/dev/null)" ]]; then
    echo "ERRO: dist/ vazio. Rode ./build.sh primeiro."
    exit 1
fi

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_DIM='\033[2m'
C_RESET='\033[0m'

_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }
_warn() { echo -e "  ${C_YELLOW}!!${C_RESET} $*" >&2; }

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

echo -e "${C_DIM}Dracula_OS-Theme — install (modo: $MODO)${C_RESET}"
echo -e "${C_DIM}Destino ícones: $DEST_ICONS${C_RESET}"
echo -e "${C_DIM}Destino temas : $DEST_THEMES${C_RESET}"
echo ""

# ─── Ícones ───
_info "Instalando temas de ícones"
$SUDO mkdir -p "$DEST_ICONS"
for tema in Dracula-Icones dracula-icons-main dracula-icons-circle Dracula-Cursor; do
    if [[ -d "$DIST/icons/$tema" ]]; then
        _info "→ $tema"
        $SUDO cp -r "$DIST/icons/$tema" "$DEST_ICONS/"
        $SUDO gtk-update-icon-cache -f -t "$DEST_ICONS/$tema" 2>/dev/null || true
    fi
done
_ok "ícones instalados"

# ─── Temas GTK/Shell ───
_info "Instalando tema GTK + shell"
$SUDO mkdir -p "$DEST_THEMES"
if [[ -d "$DIST/themes/Dracula-standard-buttons" ]]; then
    $SUDO cp -r "$DIST/themes/Dracula-standard-buttons" "$DEST_THEMES/"
    _ok "Dracula-standard-buttons instalado"
else
    _warn "dist/themes/Dracula-standard-buttons não encontrado"
fi

# ─── Overrides (.desktop) ───
if [[ "$MODO" == "user" ]]; then
    _info "Aplicando overrides de .desktop"
    "$REPO_ROOT/scripts/aplicar_overrides.sh" || _warn "aplicar_overrides.sh falhou"
fi

# ─── Pop!_Shell dark.css (requer sudo) ───
if [[ $POP_SHELL_CSS -eq 1 ]]; then
    echo ""
    _info "Substituindo Pop!_Shell dark.css (pede sudo)"
    sudo "$REPO_ROOT/scripts/instalar_pop_shell_css.sh" install || _warn "Pop!_Shell CSS falhou"
fi

# ─── App themes ───
if [[ $APP_THEMES -eq 1 ]]; then
    echo ""
    _info "Aplicando app themes"
    "$REPO_ROOT/scripts/instalar_app_themes.sh"
fi

# ─── gsettings ativar ───
if [[ $ATIVAR -eq 1 && "$MODO" == "user" ]]; then
    echo ""
    _info "Ativando via gsettings"
    gsettings set org.gnome.desktop.interface icon-theme 'Dracula-Icones'
    gsettings set org.gnome.desktop.interface gtk-theme 'Dracula-standard-buttons'
    gsettings set org.gnome.desktop.interface cursor-theme 'Dracula-Cursor'
    if gsettings list-schemas | grep -q "org.gnome.shell.extensions.user-theme"; then
        gsettings set org.gnome.shell.extensions.user-theme name 'Dracula-standard-buttons' 2>/dev/null || true
    fi
    _ok "gsettings configurados"
fi

echo ""
_ok "Instalação concluída"
if [[ $ATIVAR -eq 0 ]]; then
    echo -e "${C_DIM}Para ativar, rode:${C_RESET}"
    echo "  gsettings set org.gnome.desktop.interface icon-theme 'Dracula-Icones'"
    echo "  gsettings set org.gnome.desktop.interface gtk-theme 'Dracula-standard-buttons'"
    echo "  gsettings set org.gnome.desktop.interface cursor-theme 'Dracula-Cursor'"
    echo "  gsettings set org.gnome.shell.extensions.user-theme name 'Dracula-standard-buttons'"
fi

# "Ad astra per aspera." -- aos astros, pelas dificuldades.
