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
C_DIM='\033[2m'
C_RESET='\033[0m'

_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }
_warn() { echo -e "  ${C_YELLOW}!!${C_RESET} $*" >&2; }
_skip() { echo -e "  ${C_DIM}--${C_RESET} $*"; }
_run()  { if [[ $DRY_RUN -eq 1 ]]; then echo "  [dry-run] $*"; else eval "$*"; fi; }

# ─── kitty ───
aplicar_kitty() {
    local destino="$HOME/.config/kitty"
    local fonte_theme="$APP_THEMES/kitty/current-theme.conf"
    if [[ ! -d "$destino" ]]; then
        _skip "kitty não instalado ($destino não existe)"
        return 0
    fi
    if [[ -f "$fonte_theme" ]]; then
        # Avisa se vai sobrescrever tema custom do user
        if [[ -f "$destino/current-theme.conf" ]] && ! cmp -s "$fonte_theme" "$destino/current-theme.conf"; then
            _warn "kitty: current-theme.conf existente difere do repo — sobrescrevendo (backup em $destino/current-theme.conf.bak)"
            _run "cp '$destino/current-theme.conf' '$destino/current-theme.conf.bak'"
        fi
        _info "kitty: copiando current-theme.conf"
        _run "cp '$fonte_theme' '$destino/current-theme.conf'"
    fi
    # Garante include no kitty.conf do user (idempotente, match exato da linha inteira)
    local kitty_conf="$destino/kitty.conf"
    if [[ -f "$kitty_conf" ]] && grep -Fxq "include current-theme.conf" "$kitty_conf"; then
        :  # linha já existe exatamente — idempotente
    else
        _info "kitty: adicionando include current-theme.conf"
        if [[ $DRY_RUN -eq 0 ]]; then
            # Garante que termina com newline antes de anexar
            [[ -f "$kitty_conf" && -s "$kitty_conf" ]] && [[ "$(tail -c1 "$kitty_conf")" != "" ]] && printf '\n' >> "$kitty_conf"
            printf 'include current-theme.conf\n' >> "$kitty_conf"
        else
            echo "  [dry-run] append 'include current-theme.conf' em $kitty_conf"
        fi
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
# Busca spicetify-setup.sh em locais padrão (portabilidade SPRINT_07).
_buscar_spicetify_setup() {
    local repo_root
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local candidatos=(
        "$repo_root/../Spellbook-OS/scripts/spicetify-setup.sh"
        "$HOME/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh"
        "${XDG_DATA_HOME:-$HOME/.local/share}/Spellbook-OS/scripts/spicetify-setup.sh"
        "/opt/Spellbook-OS/scripts/spicetify-setup.sh"
    )
    local c
    for c in "${candidatos[@]}"; do
        if [[ -x "$c" ]]; then
            echo "$c"
            return 0
        fi
    done
    return 1
}

aplicar_spicetify() {
    local setup
    if ! setup="$(_buscar_spicetify_setup)"; then
        _skip "spicetify-setup.sh não encontrado em Spellbook-OS (procurado em \$REPO/../Spellbook-OS, \$HOME/Desenvolvimento/Spellbook-OS, \$XDG_DATA_HOME/Spellbook-OS, /opt/Spellbook-OS)"
        return 0
    fi
    _info "Spicetify: delegando para Spellbook-OS"
    # Spicetify pode falhar por incompatibilidade de versão do Spotify.
    # Nao e fatal para o tema geral do sistema — continuar.
    if [[ $DRY_RUN -eq 0 ]]; then
        if "$setup"; then
            _ok "Spicetify aplicado via Spellbook-OS"
        else
            _warn "Spicetify retornou erro (possível incompatibilidade de versão do Spotify — não fatal)"
        fi
    else
        echo "  [dry-run] $setup"
    fi
}

# ─── Obsidian (instala em cada vault detectado) ───
aplicar_obsidian() {
    local fonte_theme="$APP_THEMES/obsidian/Dracula.theme.css"
    [[ ! -f "$fonte_theme" ]] && fonte_theme="$APP_THEMES/obsidian/theme.css"
    local fonte_manifest="$APP_THEMES/obsidian/manifest.json"

    if [[ ! -f "$fonte_theme" ]]; then
        _skip "Obsidian: tema não encontrado em $APP_THEMES/obsidian/"
        return 0
    fi

    # Obsidian guarda lista de vaults em obsidian.json
    local obsidian_json
    for candidato in \
        "$HOME/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json" \
        "$HOME/.config/obsidian/obsidian.json"; do
        if [[ -f "$candidato" ]]; then
            obsidian_json="$candidato"
            break
        fi
    done

    if [[ -z "${obsidian_json:-}" ]]; then
        _skip "Obsidian: nenhum obsidian.json encontrado (abra o Obsidian uma vez). Tema em $fonte_theme para instalação manual."
        return 0
    fi

    # Extrai paths de vaults (objeto JSON "vaults" → lista de {"path": "..."}
    local vaults
    vaults=$(jq -r '.vaults[] .path' "$obsidian_json" 2>/dev/null || true)
    if [[ -z "$vaults" ]]; then
        _skip "Obsidian: nenhum vault configurado em $obsidian_json"
        return 0
    fi

    local count=0
    while IFS= read -r vault; do
        [[ -z "$vault" || ! -d "$vault" ]] && continue
        local temas_dir="$vault/.obsidian/themes/Dracula"
        _info "Obsidian: instalando tema em $vault"
        _run "mkdir -p '$temas_dir'"
        _run "cp '$fonte_theme' '$temas_dir/theme.css'"
        [[ -f "$fonte_manifest" ]] && _run "cp '$fonte_manifest' '$temas_dir/manifest.json'"
        count=$((count + 1))
    done <<< "$vaults"

    if [[ $count -eq 0 ]]; then
        _skip "Obsidian: vaults listados mas nenhum diretório acessível"
    else
        _ok "Obsidian: tema instalado em $count vault(s) — ative em Settings → Appearance"
    fi
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
