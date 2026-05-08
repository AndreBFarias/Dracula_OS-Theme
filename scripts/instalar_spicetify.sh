#!/usr/bin/env bash
# instalar_spicetify.sh — instalador autônomo do Spicetify para o
# Dracula_OS-Theme. Detecta Spotify (Flatpak/snap/nativo), instala o
# binário Spicetify (via curl|sh oficial), clona spicetify/spicetify-themes,
# instala o Marketplace, configura prefs_path, aplica 13 chaves de
# config, extensions e custom_apps, executa restore + clear + backup
# apply, e valida. Idempotente. Sem sudo.
#
# Replica a lógica de Spellbook-OS/scripts/spicetify-setup.sh (277L)
# localmente para que o Dracula_OS-Theme não dependa de outro repo
# para configurar o Spotify (SPRINT 18).
#
# Variáveis:
#   DRACULA_DRY_RUN=1   imprime comandos com prefixo [dry-run] e não
#                       executa curl|sh, git clone, spicetify backup apply.
#
# Flags:
#   --apenas-detectar   imprime tipo de Spotify (flatpak/snap/nativo/
#                       nenhum) e sai com exit 0. Útil para diagnóstico.
#   --skip-marketplace  pula instalação do Marketplace (CI/offline).
#   --help|-h           mostra esta ajuda.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# --- Paths Spicetify ---
SPICETIFY_BIN="$HOME/.spicetify/spicetify"
SPICETIFY_DIR="$HOME/.spicetify"
THEMES_DIR="$HOME/.config/spicetify/Themes"
CUSTOM_APPS_DIR="$SPICETIFY_DIR/CustomApps"

# --- Configuração padrão ---
TEMA="Sleek"
ESQUEMA="Dracula"
EXTENSIONS="autoSkipExplicit.js|autoSkipVideo.js|bookmark.js|fullAppDisplay.js|keyboardShortcut.js|loopyLoop.js|popupLyrics.js|shuffle+.js|trashbin.js|webnowplaying.js"
CUSTOM_APPS="marketplace|lyrics-plus|reddit|new-releases"

# --- Flags ---
APENAS_DETECTAR=0
SKIP_MARKETPLACE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apenas-detectar) APENAS_DETECTAR=1; shift ;;
        --skip-marketplace) SKIP_MARKETPLACE=1; shift ;;
        --help|-h)
            cat <<'EOF'
Uso: instalar_spicetify.sh [--apenas-detectar] [--skip-marketplace]

Instalador autônomo do Spicetify (sem dependência do Spellbook-OS).

Flags:
  --apenas-detectar   imprime tipo de Spotify (flatpak/snap/nativo/nenhum)
                      e sai. Não instala nada.
  --skip-marketplace  pula a instalação do Marketplace custom app.

Variáveis:
  DRACULA_DRY_RUN=1   apenas loga, não executa curl|sh nem git clone.
EOF
            exit 0 ;;
        *) _warn "Argumento ignorado: $1"; shift ;;
    esac
done

# --- Detecção do Spotify ---
detectar_spotify() {
    if flatpak list 2>/dev/null | grep -q "com.spotify.Client"; then
        echo "flatpak"
    elif snap list 2>/dev/null | grep -q "spotify"; then
        echo "snap"
    elif command -v spotify &>/dev/null; then
        echo "nativo"
    elif [[ -d "/opt/spotify" ]]; then
        echo "nativo"
    else
        echo "nenhum"
    fi
}

# --- Instalar Spicetify ---
instalar_spicetify() {
    if [[ -x "$SPICETIFY_BIN" ]]; then
        local versao
        versao=$("$SPICETIFY_BIN" --version 2>/dev/null || echo "desconhecida")
        _ok "Spicetify já instalado (v${versao})"
        return 0
    fi
    _info "Instalando Spicetify (curl oficial)..."
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh"
        return 0
    fi
    curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh
    if [[ -x "$SPICETIFY_BIN" ]]; then
        _ok "Spicetify instalado ($("$SPICETIFY_BIN" --version))"
    else
        _err "Falha ao instalar Spicetify"
        exit 1
    fi
}

# --- Instalar temas ---
instalar_temas() {
    if [[ -d "$THEMES_DIR/$TEMA" ]]; then
        _ok "Tema $TEMA já presente"
        return 0
    fi
    _info "Clonando repositório de temas..."
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] git clone --depth=1 https://github.com/spicetify/spicetify-themes.git \$tmp"
        _dim "[dry-run] cp -r \$tmp/* $THEMES_DIR/"
        return 0
    fi
    local tmp_dir
    tmp_dir=$(mktemp -d)
    git clone --depth=1 https://github.com/spicetify/spicetify-themes.git "$tmp_dir"
    mkdir -p "$THEMES_DIR"
    cp -r "$tmp_dir"/* "$THEMES_DIR/"
    rm -rf "$tmp_dir"
    if [[ -d "$THEMES_DIR/$TEMA" ]]; then
        _ok "Temas instalados (tema ativo: $TEMA)"
    else
        _warn "Clone concluído mas tema $TEMA não encontrado"
    fi
}

# --- Instalar Marketplace ---
instalar_marketplace() {
    if [[ $SKIP_MARKETPLACE -eq 1 ]]; then
        _info "Marketplace pulado (--skip-marketplace)"
        return 0
    fi
    if [[ -d "$CUSTOM_APPS_DIR/marketplace" ]]; then
        _ok "Marketplace já instalado"
        return 0
    fi
    _info "Instalando Marketplace custom app..."
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh"
        return 0
    fi
    curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh
    if [[ -d "$CUSTOM_APPS_DIR/marketplace" ]]; then
        _ok "Marketplace instalado"
    else
        _warn "Marketplace não encontrado após instalação"
    fi
}

# --- Configurar paths ---
# Diferenças vs Spellbook: dry-run guard; loop de geração de prefs reduzido
# para 10 iterações de 2s (max 20s) em vez de 15 (max 30s).
configurar_paths() {
    local tipo="$1"
    _info "Configurando paths para instalação $tipo..."
    case "$tipo" in
        flatpak)
            local flatpak_prefs="$HOME/.var/app/com.spotify.Client/config/spotify/prefs"
            if [[ -f "$flatpak_prefs" ]]; then
                if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
                    _dim "[dry-run] $SPICETIFY_BIN config prefs_path $flatpak_prefs"
                else
                    "$SPICETIFY_BIN" config prefs_path "$flatpak_prefs"
                    _ok "prefs_path configurado para Flatpak"
                fi
            else
                _warn "prefs do Flatpak não encontrado — abrindo Spotify para gerar"
                if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
                    _dim "[dry-run] flatpak run com.spotify.Client & ; sleep até 20s ; kill"
                    _dim "[dry-run] $SPICETIFY_BIN config prefs_path $flatpak_prefs"
                    return 0
                fi
                flatpak run com.spotify.Client &>/dev/null &
                local pid=$!
                local i
                for i in $(seq 1 10); do
                    [[ -f "$flatpak_prefs" ]] && break
                    sleep 2
                done
                kill "$pid" 2>/dev/null || true
                wait "$pid" 2>/dev/null || true
                if [[ -f "$flatpak_prefs" ]]; then
                    "$SPICETIFY_BIN" config prefs_path "$flatpak_prefs"
                    _ok "prefs_path configurado para Flatpak"
                else
                    _warn "Falha ao gerar prefs — configure prefs_path manualmente"
                fi
            fi
            ;;
        snap)
            local snap_prefs="$HOME/snap/spotify/current/.config/spotify/prefs"
            if [[ -f "$snap_prefs" ]]; then
                if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
                    _dim "[dry-run] $SPICETIFY_BIN config prefs_path $snap_prefs"
                else
                    "$SPICETIFY_BIN" config prefs_path "$snap_prefs"
                    _ok "prefs_path configurado para Snap"
                fi
            fi
            ;;
        nativo)
            _ok "prefs_path padrão para instalação nativa"
            ;;
    esac
}

# --- Aplicar configuração (13 chaves) ---
aplicar_config() {
    _info "Aplicando configuração..."
    local k v
    local pares=(
        "current_theme=$TEMA"
        "color_scheme=$ESQUEMA"
        "inject_css=1"
        "replace_colors=1"
        "overwrite_assets=1"
        "inject_theme_js=1"
        "sidebar_config=1"
        "experimental_features=1"
        "home_config=1"
        "expose_apis=1"
        "disable_sentry=1"
        "disable_ui_logging=1"
        "remove_rtl_rule=1"
    )
    for par in "${pares[@]}"; do
        k="${par%%=*}"; v="${par#*=}"
        if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
            _dim "[dry-run] $SPICETIFY_BIN config $k $v"
        else
            "$SPICETIFY_BIN" config "$k" "$v"
        fi
    done
    _ok "Configuração aplicada via CLI"
}

# --- Extensions e custom apps ---
aplicar_extensions() {
    _info "Configurando extensions e custom apps..."
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] $SPICETIFY_BIN config extensions $EXTENSIONS"
        _dim "[dry-run] $SPICETIFY_BIN config custom_apps $CUSTOM_APPS"
        return 0
    fi
    "$SPICETIFY_BIN" config extensions "$EXTENSIONS"
    "$SPICETIFY_BIN" config custom_apps "$CUSTOM_APPS"

    # Sanitização de 'custom_apps' espúrio na lista de extensions
    # (workaround conhecido do Spicetify CLI).
    local ext_atual
    ext_atual=$("$SPICETIFY_BIN" config extensions | tr '\n' '|' | sed 's/|$//')
    if echo "$ext_atual" | grep -q '|custom_apps|'; then
        ext_atual=$(echo "$ext_atual" | sed 's/|custom_apps|/|/g; s/^custom_apps|//; s/|custom_apps$//')
        local ini_file="$HOME/.config/spicetify/config-xpui.ini"
        if [[ -f "$ini_file" ]]; then
            sed -i "s|^extensions.*=.*|extensions            = ${ext_atual}|" "$ini_file"
        fi
    fi
    _ok "Extensions e custom apps configurados"
}

# --- Restaurar e aplicar ---
# Diferença vs Spellbook: validar_path_destrutivo antes de rm -rf cache.
restaurar_e_aplicar() {
    local tipo="$1"
    if [[ "$tipo" == "flatpak" ]]; then
        local cache_dir="$HOME/.var/app/com.spotify.Client/cache/spotify/Default/Cache"
        if [[ -d "$cache_dir" ]]; then
            if validar_path_destrutivo "$cache_dir" >/dev/null 2>&1; then
                if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
                    _dim "[dry-run] rm -rf -- $cache_dir/*"
                else
                    rm -rf "${cache_dir:?}/"*
                    _ok "Cache web do Flatpak limpo"
                fi
            else
                _warn "Cache fora da allowlist; pulando limpeza"
            fi
        fi
    fi
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] $SPICETIFY_BIN restore"
        _dim "[dry-run] $SPICETIFY_BIN clear"
        _dim "[dry-run] $SPICETIFY_BIN backup apply"
        _ok "[dry-run] Spicetify aplicado (simulação)"
        return 0
    fi
    _info "Restaurando Spotify ao estado original..."
    "$SPICETIFY_BIN" restore 2>/dev/null || true
    _info "Limpando backup anterior..."
    "$SPICETIFY_BIN" clear
    _info "Criando backup e aplicando customizações..."
    "$SPICETIFY_BIN" backup apply
    _ok "Spicetify aplicado com sucesso"
}

# --- Validação ---
validar() {
    local erros=0
    _info "Validando instalação..."
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _ok "[dry-run] Validação pulada"
        return 0
    fi
    if ! "$SPICETIFY_BIN" config extensions | grep -q "bookmark.js"; then
        _warn "Extensions não configuradas corretamente"
        erros=$((erros+1))
    fi
    if ! "$SPICETIFY_BIN" config custom_apps | grep -q "marketplace"; then
        _warn "Custom apps não configurados corretamente"
        erros=$((erros+1))
    fi
    local tema_atual
    tema_atual=$("$SPICETIFY_BIN" config current_theme 2>/dev/null || echo "")
    if [[ "$tema_atual" != "$TEMA" ]]; then
        _warn "Tema atual ($tema_atual) difere do esperado ($TEMA)"
        erros=$((erros+1))
    fi
    if [[ $erros -eq 0 ]]; then
        _ok "Validação completa: tudo OK"
    else
        _warn "$erros problema(s) detectado(s)"
        return 1
    fi
}

# --- Main ---
main() {
    local tipo_spotify
    tipo_spotify=$(detectar_spotify)

    if [[ $APENAS_DETECTAR -eq 1 ]]; then
        echo "$tipo_spotify"
        exit 0
    fi

    _info "Spotify detectado: $tipo_spotify"
    if [[ "$tipo_spotify" == "nenhum" ]]; then
        _err "Spotify não encontrado. Instale o Spotify primeiro."
        exit 1
    fi

    instalar_spicetify
    configurar_paths "$tipo_spotify"
    instalar_temas
    instalar_marketplace
    aplicar_config
    aplicar_extensions
    restaurar_e_aplicar "$tipo_spotify"
    validar

    _ok "Spicetify configurado com sucesso. Abra o Spotify para verificar."
}

main "$@"

# "A música acalma a fera." — adágio popular pt-BR
