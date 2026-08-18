#!/usr/bin/env bash
# install.sh — instala Dracula_OS-Theme em nível user ou system
#
# Uso:
#   ./install.sh --user              # copia para ~/.local/share/{icons,themes}/
#   ./install.sh --system            # copia para /usr/share/{icons,themes}/ (sudo)
#   ./install.sh --user --activate   # + ativa via gsettings
#   ./install.sh --user --app-themes # + aplica temas internos (kitty, qbittorrent, etc.)
#   ./install.sh --user --spicetify  # + instala/aplica somente Spicetify (SPRINT 18)
#   ./install.sh --user --gimp       # + instala GIMP (Flatpak) e aplica PhotoGIMP (SPRINT 20)
#   ./install.sh --user --video-wallpaper # + wallpaper de vídeo (xwinwrap + mpv, SPRINT 30)
#   ./install.sh --user --relatorio-mec   # + pipeline do Relatório MEC (fontes universais + scripts)
#   ./install.sh --user --fontes-design   # + fontes de design (JetBrains Mono + Fira Code; corrige export de SVG)
#   ./install.sh --user --all        # tudo acima
#   ./install.sh --user --apt-hook   # + instala hook que reaplica tema pós apt upgrade
#   ./install.sh --bootstrap         # checa ambiente, baixa upstreams, build, install --user --all, diagnóstico

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$REPO_ROOT/dist"

MODO=""
ATIVAR=0
APP_THEMES=0
SPICETIFY=0
POP_SHELL_CSS=0
SOUNDS=0
KEYBINDINGS=0
GNOME_EXT=0
APT_HOOK=0
GIMP=0
VIDEO_WALLPAPER=0
RELATORIO_MEC=0
FONTES_DESIGN=0
BOOTSTRAP=0

for arg in "$@"; do
    case "$arg" in
        --user)    MODO="user" ;;
        --system)  MODO="system" ;;
        --activate) ATIVAR=1 ;;
        --app-themes) APP_THEMES=1 ;;
        --spicetify) SPICETIFY=1 ;;
        --pop-shell-css) POP_SHELL_CSS=1 ;;
        --sounds) SOUNDS=1 ;;
        --keybindings) KEYBINDINGS=1 ;;
        --gnome-extensions) GNOME_EXT=1 ;;
        --apt-hook) APT_HOOK=1 ;;
        --gimp) GIMP=1 ;;
        --video-wallpaper) VIDEO_WALLPAPER=1 ;;
        --relatorio-mec) RELATORIO_MEC=1 ;;
        --fontes-design) FONTES_DESIGN=1 ;;
        --bootstrap) BOOTSTRAP=1 ;;
        # --all: SPICETIFY não é incluído porque APP_THEMES já chama
        # aplicar_spicetify() (que roda instalar_spicetify.sh). Evita duplicação.
        --all) ATIVAR=1; APP_THEMES=1; POP_SHELL_CSS=1; SOUNDS=1; KEYBINDINGS=1; GNOME_EXT=1; GIMP=1; VIDEO_WALLPAPER=1; APT_HOOK=1; RELATORIO_MEC=1; FONTES_DESIGN=1 ;;
    esac
done

# Bootstrap: rota completa ambiente → build → install --user --all → diagnóstico
if [[ $BOOTSTRAP -eq 1 ]]; then
    if ! "$REPO_ROOT/scripts/checar_ambiente.sh"; then
        echo ""
        echo "ERRO: ambiente incompleto. Instale as dependências acima e rode novamente."
        exit 1
    fi
    echo ""
    echo "=== Baixando upstreams ==="
    "$REPO_ROOT/scripts/baixar_upstreams.sh"
    echo ""
    echo "=== Build ==="
    "$REPO_ROOT/build.sh"
    echo ""
    echo "=== Install --user --all ==="
    exec "$REPO_ROOT/install.sh" --user --all
fi

if [[ -z "$MODO" ]]; then
    echo "Uso: $0 --user|--system [--activate] [--app-themes] [--spicetify] [--gimp] [--video-wallpaper] [--relatorio-mec] [--fontes-design] [--pop-shell-css] [--sounds] [--keybindings] [--gnome-extensions] [--apt-hook] [--all]"
    echo "     $0 --bootstrap  (rota completa para máquina limpa Pop!_OS)"
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

# Idempotência: dark.css do Pop!_Shell/Cosmic já idêntico ao fonte? (evita pedir sudo à toa)
_pop_css_ja_aplicado() {
    local ok=1 alvo
    local pares=(
        "src/shell/pop-shell-dark.css|/usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css"
        "src/shell/pop-cosmic-dark.css|/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css"
    )
    for alvo in "${pares[@]}"; do
        local src="$REPO_ROOT/${alvo%%|*}" dst="${alvo##*|}"
        [[ -f "$dst" ]] || continue          # extensão não instalada: nada a reaplicar
        cmp -s "$src" "$dst" || ok=0          # divergiu: precisa reaplicar
    done
    [[ $ok -eq 1 ]]
}

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

# ─── Índice do hicolor do usuário (não-fatal) ───
# Precisa vir ANTES de qualquer script que grave ícone em ~/.local/share/icons/
# hicolor: diretório fora de Directories= faz o GTK ignorar o arquivo, e é o
# caso de 32x32/apps, usado como fallback pelo atualizar_icones_steam.sh.
if [[ "$MODO" == "user" ]]; then
    _info "Conferindo índice do hicolor do usuário (não-fatal)"
    "$REPO_ROOT/scripts/reparar_hicolor_index.sh" || _warn "reparar_hicolor_index.sh falhou (não-fatal)"
fi

# ─── Ícones de jogos Steam (não-fatal) ───
if [[ "$MODO" == "user" ]]; then
    _info "Atualizando ícones de jogos Steam (não-fatal)"
    "$REPO_ROOT/scripts/atualizar_icones_steam.sh" || _warn "atualizar_icones_steam.sh falhou (não-fatal)"
fi

# ─── Wallpapers Dracula (não-fatal; user-only) ───
if [[ "$MODO" == "user" ]]; then
    _info "Instalando wallpapers Dracula (não-fatal)"
    "$REPO_ROOT/scripts/instalar_wallpapers.sh" || _warn "instalar_wallpapers.sh falhou (não-fatal)"
fi

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
    if _pop_css_ja_aplicado; then
        _ok "Pop!_Shell/Cosmic dark.css já idêntico ao fonte (skip — sem sudo)"
    else
        _info "Substituindo Pop!_Shell dark.css (pede sudo)"
        sudo "$REPO_ROOT/scripts/instalar_pop_shell_css.sh" install || _warn "Pop!_Shell CSS falhou"
    fi

    echo ""
    _info "Localizando launcher Pop!_Cosmic em pt-BR (cópia para ~/.local/share)"
    "$REPO_ROOT/scripts/instalar_pop_cosmic_ptbr.sh" || _warn "Localização pt-BR do pop-cosmic falhou (não-fatal)"

    echo ""
    _info "Higiene do app-grid Pop!_Cosmic (esconder gnome-session-properties + remover pasta Utilities)"
    "$REPO_ROOT/scripts/instalar_higiene_launcher.sh" || _warn "Higiene do launcher falhou (não-fatal)"

    echo ""
    _info "Menu de sistema na tela secundária (multi-monitors-add-on; não-fatal)"
    "$REPO_ROOT/scripts/instalar_patch_multi_monitors.sh" || _warn "Patch multi-monitors falhou (não-fatal)"
fi

# ─── Sons (tema Pop) ───
if [[ $SOUNDS -eq 1 ]]; then
    echo ""
    _info "Instalando tema de som Pop"
    "$REPO_ROOT/scripts/instalar_sons.sh" "--$MODO" || _warn "Instalação de sons falhou"
fi

# ─── App themes ───
if [[ $APP_THEMES -eq 1 ]]; then
    echo ""
    _info "Aplicando app themes"
    "$REPO_ROOT/scripts/instalar_app_themes.sh" || _warn "instalar_app_themes.sh falhou (não-fatal)"
fi

# ─── Spicetify (atalho dedicado; se --app-themes já rodou, é no-op idempotente) ───
if [[ $SPICETIFY -eq 1 && "$MODO" == "user" ]]; then
    echo ""
    _info "Aplicando Spicetify (autônomo, SPRINT 18)"
    "$REPO_ROOT/scripts/instalar_spicetify.sh" || _warn "instalar_spicetify.sh falhou (não-fatal)"
fi

# ─── GIMP + PhotoGIMP (Flatpak + config estilo Photoshop) ───
if [[ $GIMP -eq 1 && "$MODO" == "user" ]]; then
    echo ""
    _info "Instalando/atualizando GIMP (Flatpak) + aplicando PhotoGIMP"
    "$REPO_ROOT/scripts/instalar_gimp.sh" || _warn "instalar_gimp.sh falhou (não-fatal)"
fi

# ─── Wallpaper de vídeo (xwinwrap + mpv + autostart) ───
if [[ $VIDEO_WALLPAPER -eq 1 && "$MODO" == "user" ]]; then
    echo ""
    _info "Configurando wallpaper de vídeo (xwinwrap + mpv, SPRINT 30)"
    "$REPO_ROOT/scripts/instalar_wallpaper_video.sh" || _warn "instalar_wallpaper_video.sh falhou (não-fatal)"
fi

# ─── Pipeline Relatório MEC (fontes universais + scripts; auto-cura) ───
if [[ $RELATORIO_MEC -eq 1 && "$MODO" == "user" ]]; then
    echo ""
    _info "Verificando pipeline do Relatório MEC (fontes + fontconfig + scripts)"
    "$REPO_ROOT/scripts/instalar_relatorio_mec.sh" || _warn "instalar_relatorio_mec.sh falhou (não-fatal)"
fi

# ─── Fontes de design (JetBrains Mono + Fira Code; corrige export de SVG) ───
if [[ $FONTES_DESIGN -eq 1 && "$MODO" == "user" ]]; then
    echo ""
    _info "Instalando fontes de design (JetBrains Mono + Fira Code)"
    "$REPO_ROOT/scripts/instalar_fontes_design.sh" || _warn "instalar_fontes_design.sh falhou (não-fatal)"
fi

# ─── Extensões GNOME ───
if [[ $GNOME_EXT -eq 1 && "$MODO" == "user" ]]; then
    echo ""
    _info "Instalando + configurando extensões GNOME do manifesto"
    "$REPO_ROOT/scripts/instalar_gnome_extensions.sh" || _warn "Instalação de extensões falhou"
fi

# ─── Keybindings ───
if [[ $KEYBINDINGS -eq 1 && "$MODO" == "user" ]]; then
    echo ""
    _info "Aplicando atalhos de teclado + desativando som do shutter"
    "$REPO_ROOT/scripts/instalar_keybindings.sh" || _warn "Instalação de keybindings falhou"
fi

# ─── APT hook (requer sudo; reaplica tema após apt upgrade) ───
if [[ $APT_HOOK -eq 1 ]]; then
    echo ""
    if [[ -f /etc/apt/apt.conf.d/99-dracula-os-theme ]]; then
        _ok "APT hook já instalado (skip — sem sudo)"
    else
        _info "Instalando APT hook para reaplicação automática pós-upgrade (pede sudo)"
        sudo "$REPO_ROOT/scripts/instalar_apt_hook.sh" install || _warn "Instalação do APT hook falhou"
    fi
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

# ─── Resumo: verificação final do estado instalado (não-fatal) ───
if [[ "$MODO" == "user" && -x "$REPO_ROOT/scripts/diagnostico.sh" ]]; then
    echo ""
    echo -e "${C_DIM}── Verificação final (diagnóstico) ──${C_RESET}"
    "$REPO_ROOT/scripts/diagnostico.sh" || true
fi

# "Ad astra per aspera." -- aos astros, pelas dificuldades.
