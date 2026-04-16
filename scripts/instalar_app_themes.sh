#!/usr/bin/env bash
# instalar_app_themes.sh — aplica os temas Dracula nos apps correspondentes
# Uso: ./scripts/instalar_app_themes.sh [--dry-run]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_THEMES="$REPO_ROOT/app-themes"
DRY_RUN=0

for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=1
done

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'
C_DIM='\033[2m'
C_RESET='\033[0m'

_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }
_warn() { echo -e "  ${C_YELLOW}!!${C_RESET} $*" >&2; }
_skip() { echo -e "  ${C_DIM}--${C_RESET} $*"; }
_run()  { if [[ $DRY_RUN -eq 1 ]]; then echo "  [dry-run] $*"; else eval "$@"; fi; }

# ─── kitty ───
aplicar_kitty() {
    local destino="$HOME/.config/kitty"
    local fonte_theme="$APP_THEMES/kitty/current-theme.conf"
    local fonte_conf="$APP_THEMES/kitty/kitty.conf.original"
    if [[ ! -d "$destino" ]]; then
        _skip "kitty não instalado ($destino não existe)"
        return 0
    fi
    if [[ -f "$fonte_theme" ]]; then
        _info "kitty: copiando current-theme.conf"
        _run "cp '$fonte_theme' '$destino/current-theme.conf'"
    fi
    # Garante include no kitty.conf do user
    if ! grep -q "include current-theme.conf" "$destino/kitty.conf" 2>/dev/null; then
        _info "kitty: adicionando include current-theme.conf"
        _run "echo '\ninclude current-theme.conf' >> '$destino/kitty.conf'"
    fi
    _ok "kitty atualizado"
}

# ─── qBittorrent ───
aplicar_qbittorrent() {
    local destino="$HOME/.themes/dracula.qbtheme"
    local fonte="$APP_THEMES/qbittorrent/dracula.qbtheme"
    if [[ ! -f "$fonte" ]]; then
        _warn "qbtheme não encontrado em $fonte"
        return 0
    fi
    _info "qBittorrent: instalando dracula.qbtheme em ~/.themes/"
    _run "mkdir -p '$HOME/.themes'"
    _run "cp '$fonte' '$destino'"
    # Garante que qBittorrent.conf aponta pro tema
    local conf="$HOME/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent/qBittorrent.conf"
    if [[ -f "$conf" ]]; then
        if ! grep -q "CustomUIThemePath=$destino" "$conf"; then
            _warn "qBittorrent.conf: CustomUIThemePath não aponta para $destino (ajuste manual)"
        fi
    fi
    _ok "qBittorrent atualizado"
}

# ─── GNOME Terminal (dconf) ───
aplicar_gnome_terminal() {
    local fonte="$APP_THEMES/gnome-terminal/dracula-profile.dconf"
    if [[ ! -f "$fonte" ]]; then
        _warn "dconf dump não encontrado em $fonte"
        return 0
    fi
    _info "GNOME Terminal: carregando perfil via dconf"
    _run "dconf load /org/gnome/terminal/legacy/profiles:/ < '$fonte'"
    _ok "GNOME Terminal atualizado"
}

# ─── Spicetify (chama spellbook-os) ───
aplicar_spicetify() {
    local setup="$HOME/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh"
    if [[ ! -x "$setup" ]]; then
        _skip "spicetify-setup.sh não encontrado em $setup"
        return 0
    fi
    _info "Spicetify: delegando para Spellbook-OS"
    _run "'$setup'"
    _ok "Spicetify aplicado via Spellbook-OS"
}

# ─── Obsidian (Flatpak) ───
aplicar_obsidian() {
    local base="$HOME/.var/app/md.obsidian.Obsidian/config/obsidian"
    local fonte_theme="$APP_THEMES/obsidian/theme.css"
    local fonte_manifest="$APP_THEMES/obsidian/manifest.json"
    [[ -f "$APP_THEMES/obsidian/Dracula.theme.css" ]] && fonte_theme="$APP_THEMES/obsidian/Dracula.theme.css"

    if [[ ! -d "$base" ]]; then
        _skip "Obsidian não configurado (sem vault aberto). Pule este passo ou abra o Obsidian uma vez."
        return 0
    fi
    # Obsidian busca temas em cada vault: <vault>/.obsidian/themes/Dracula/
    # Como não sabemos qual vault, colocamos como tema "default" na config global
    local temas_dir="$base/themes/Dracula"
    _info "Obsidian: copiando tema para $temas_dir (aplicar manualmente em cada vault)"
    _run "mkdir -p '$temas_dir'"
    _run "cp '$fonte_theme' '$temas_dir/theme.css'"
    [[ -f "$fonte_manifest" ]] && _run "cp '$fonte_manifest' '$temas_dir/manifest.json'"
    _warn "Obsidian: ative manualmente em Settings → Appearance → Themes"
}

# ─── Telegram ───
aplicar_telegram() {
    local fonte="$APP_THEMES/telegram/dracula.tdesktop-theme"
    if [[ ! -f "$fonte" ]]; then
        _warn "tema Telegram não encontrado"
        return 0
    fi
    local destino="$HOME/.cache/dracula-telegram/dracula.tdesktop-theme"
    _info "Telegram: salvando .tdesktop-theme em $destino (importar manualmente)"
    _run "mkdir -p '$(dirname "$destino")'"
    _run "cp '$fonte' '$destino'"
    _warn "Telegram: abra o arquivo $destino no Telegram (não há CLI para importar)"
}

# ─── Discord (BetterDiscord / Vesktop) ───
aplicar_discord() {
    local fonte="$APP_THEMES/discord-betterdiscord/Dracula.theme.css"
    if [[ ! -f "$fonte" ]]; then
        _warn "tema Discord não encontrado"
        return 0
    fi
    # BetterDiscord caminhos
    for d in "$HOME/.config/BetterDiscord/themes" \
             "$HOME/.var/app/com.discordapp.Discord/config/BetterDiscord/themes" \
             "$HOME/.config/vesktop/themes" \
             "$HOME/.config/Vencord/themes"; do
        if [[ -d "$d" ]]; then
            _info "Discord mod: copiando tema para $d"
            _run "cp '$fonte' '$d/Dracula.theme.css'"
        fi
    done
    if ! ls "$HOME/.config/BetterDiscord/themes" "$HOME/.var/app/com.discordapp.Discord/config/BetterDiscord/themes" "$HOME/.config/vesktop/themes" "$HOME/.config/Vencord/themes" &>/dev/null; then
        _skip "Nenhum BetterDiscord/Vesktop/Vencord detectado. Instale um antes ou copie manualmente o tema de $fonte"
    fi
}

# ─── OnlyOffice ───
aplicar_onlyoffice() {
    _info "OnlyOffice: dark mode built-in — configure em Preferências → Aparência → Tema: Dark"
    _skip "Nada a automatizar (sem CSS custom — veja app-themes/onlyoffice/README.md)"
}

main() {
    echo -e "${C_DIM}Dracula_OS-Theme — instalar app themes${C_RESET}"
    [[ $DRY_RUN -eq 1 ]] && echo -e "${C_YELLOW}[DRY RUN] nada será modificado${C_RESET}"
    echo ""
    aplicar_kitty
    aplicar_qbittorrent
    aplicar_gnome_terminal
    aplicar_spicetify
    aplicar_obsidian
    aplicar_telegram
    aplicar_discord
    aplicar_onlyoffice
    echo ""
    _ok "Instalação de app themes concluída"
}

main "$@"

# "Omnia munda mundis" -- tudo é puro para os puros.
