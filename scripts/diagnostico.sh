#!/usr/bin/env bash
# diagnostico.sh — health check read-only do Dracula_OS-Theme.
#
# Reporta o estado de cada componente crítico após reboot/upgrade, sem efeitos colaterais.
# Retorna exit code 0 quando tudo OK, 1 quando há ao menos uma regressão.
#
# Uso:
#   ./scripts/diagnostico.sh              # output colorido, exit code útil
#   ./scripts/diagnostico.sh --quiet      # só conta regressões (para scripts)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

REPO_ROOT="$(_repo_root "${BASH_SOURCE[0]}")"
MANIFESTO="$REPO_ROOT/app-themes/gnome-extensions/extensions.json"

QUIET=0
for arg in "$@"; do
    [[ "$arg" == "--quiet" ]] && QUIET=1
done

problemas=0
check() {
    local desc="$1" cmd="$2"
    if eval "$cmd" &>/dev/null; then
        [[ $QUIET -eq 0 ]] && echo -e "  ${C_GREEN}[OK]${C_RESET}    $desc"
    else
        [[ $QUIET -eq 0 ]] && echo -e "  ${C_RED}[FALHA]${C_RESET} $desc"
        problemas=$((problemas+1))
    fi
}

[[ $QUIET -eq 0 ]] && echo -e "${C_DIM}=== Dracula_OS-Theme — diagnóstico ===${C_RESET}"

# ─── gsettings ativo ───
check "Tema ícones ativo (Dracula-Icones)" \
    "[[ \"\$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null)\" == \"'Dracula-Icones'\" ]]"
check "Tema GTK ativo (Dracula-standard-buttons)" \
    "[[ \"\$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)\" == \"'Dracula-standard-buttons'\" ]]"
check "Cursor ativo (Dracula-Cursor)" \
    "[[ \"\$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null)\" == \"'Dracula-Cursor'\" ]]"

# ─── Arquivos instalados ───
check "Pasta Dracula-Icones em ~/.local/share/icons" \
    "[[ -d \"\$HOME/.local/share/icons/Dracula-Icones\" ]]"
check "Icon cache Dracula-Icones válido" \
    "gtk-update-icon-cache --validate \$HOME/.local/share/icons/Dracula-Icones"
check "Tema GTK Dracula-standard-buttons em ~/.local/share/themes" \
    "[[ -d \"\$HOME/.local/share/themes/Dracula-standard-buttons\" ]]"

# ─── Pop!_Shell / Pop!_Cosmic dark.css ───
check "Pop!_Shell dark.css Dracula aplicado" \
    "grep -q 'pop-shell-search.modal-dialog\\|bd93f9' /usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css 2>/dev/null"
check "Pop!_Cosmic dark.css Dracula aplicado" \
    "grep -q 'rgba(40,\\s*42,\\s*54' /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css 2>/dev/null"

# ─── Overrides .desktop ───
check "Override ZapZap→WhatsApp" \
    "grep -q '^Name=WhatsApp' \$HOME/.local/share/applications/com.rtosta.zapzap.desktop"
check ".desktop sem permissão 600 (GIMP-bug)" \
    "! find \$HOME/.local/share/applications -maxdepth 1 -name '*.desktop' -type f -perm 600 2>/dev/null | grep -q ."

# ─── App themes ───
check "kitty: include current-theme.conf" \
    "grep -Fxq 'include current-theme.conf' \$HOME/.config/kitty/kitty.conf"
check "qBittorrent: dracula.qbtheme" \
    "[[ -f \$HOME/.themes/dracula.qbtheme ]]"

# ─── Sons e keybindings ───
check "Tema som Pop ativo" \
    "[[ \"\$(gsettings get org.gnome.desktop.sound theme-name 2>/dev/null)\" == \"'Pop'\" ]]"
check "Pasta sons Pop instalada" \
    "[[ -d \$HOME/.local/share/sounds/Pop || -d /usr/share/sounds/Pop ]]"

# ─── Extensões GNOME (itera manifesto) ───
if command -v jq >/dev/null 2>&1 && [[ -f "$MANIFESTO" ]]; then
    while IFS= read -r uuid; do
        check "Extensão instalada: $uuid" \
            "[[ -d \$HOME/.local/share/gnome-shell/extensions/$uuid || -d /usr/share/gnome-shell/extensions/$uuid ]]"
    done < <(jq -r '.extensions[].uuid' "$MANIFESTO")

    check "user-theme habilitada (obrigatória para shell Dracula)" \
        "gnome-extensions list --enabled 2>/dev/null | grep -q 'user-theme@gnome-shell-extensions.gcampax.github.com'"
fi

echo ""
if [[ $problemas -eq 0 ]]; then
    [[ $QUIET -eq 0 ]] && echo -e "${C_GREEN}Tudo OK${C_RESET} — 0 regressões."
    exit 0
else
    [[ $QUIET -eq 0 ]] && echo -e "${C_YELLOW}$problemas regressões detectadas.${C_RESET} Rode: ${C_CYAN}./scripts/reaplicar_tema.sh${C_RESET}"
    exit 1
fi

# "Ignoti nulla cupido." -- não se deseja o que não se conhece.
