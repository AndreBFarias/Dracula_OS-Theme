#!/usr/bin/env bash
# reaplicar_tema.sh — reaplicação idempotente do Dracula_OS-Theme após upgrades.
#
# Pode rodar múltiplas vezes sem efeito colateral. Projetado para ser chamado:
#   - manualmente após um apt full-upgrade ou flatpak update;
#   - automaticamente via APT hook (ver scripts/instalar_apt_hook.sh);
#   - a partir do Spellbook-OS atualizar_tudo.
#
# NÃO faz rebuild do dist/ (caro). Se dist/ estiver ausente, orienta rodar build.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

REPO_ROOT="$(_repo_root "${BASH_SOURCE[0]}")"
LOG_FILE="$(_log_file "reaplicar_tema")"

# Toda saída também vai para o log
exec > >(tee -a "$LOG_FILE") 2>&1

_dim "=== reaplicar_tema.sh — início ($(date -Iseconds)) ==="
_dim "REPO_ROOT: $REPO_ROOT"
_dim "LOG: $LOG_FILE"

cd "$REPO_ROOT" || { _err "Falha ao cd para $REPO_ROOT"; exit 1; }

# ─── 1. Verifica pré-requisitos mínimos ───
if [[ ! -d "$HOME/.local/share/icons/Dracula-Icones" ]]; then
    _warn "Tema de ícones não encontrado em ~/.local/share/icons/Dracula-Icones."
    _warn "Rode: ./build.sh && ./install.sh --user --all"
    exit 2
fi

# ─── 2. Pop!_Shell e Pop!_Cosmic dark.css (se regrediram) ───
pop_shell_ok=1
for ext in pop-shell pop-cosmic; do
    base="/usr/share/gnome-shell/extensions/${ext}@system76.com"
    if [[ -f "$base/dark.css" ]]; then
        # Detecta marca Dracula no conteúdo atual
        if ! grep -qE 'bd93f9|rgba\(40,\s*42,\s*54|pop-shell-search.modal-dialog' "$base/dark.css" 2>/dev/null; then
            _info "$ext dark.css regrediu — reaplicando"
            sudo "$REPO_ROOT/scripts/instalar_pop_shell_css.sh" install || _warn "Falha ao reaplicar $ext"
            pop_shell_ok=0
        fi
    fi
done
[[ $pop_shell_ok -eq 1 ]] && _ok "Pop!_Shell/Pop!_Cosmic dark.css preservados"

# ─── 3. Overrides .desktop (ZapZap/WhatsApp Snap) ───
_info "Reaplicando overrides .desktop"
"$REPO_ROOT/scripts/aplicar_overrides.sh" || _warn "aplicar_overrides.sh falhou"

# ─── 4. Permissões dos .desktop (GIMP-bug: Flatpak cria 600) ───
corrigidos=$(find "$HOME/.local/share/applications" -maxdepth 1 -name "*.desktop" -type f ! -perm 644 2>/dev/null | wc -l)
if [[ $corrigidos -gt 0 ]]; then
    _info "Corrigindo $corrigidos .desktop com permissão ≠ 644"
    find "$HOME/.local/share/applications" -maxdepth 1 -name "*.desktop" -type f ! -perm 644 \
        -exec chmod 644 {} + 2>/dev/null || true
fi

# ─── 5. Normaliza Icon= absoluto (Flatpak regenera após update) ───
_info "Normalizando Icon= absoluto em .desktop"
"$REPO_ROOT/scripts/normalizar_desktops.sh" || _warn "normalizar_desktops.sh falhou"

# ─── 6. Tema de som Pop (gsettings costuma regredir com upgrade do GNOME) ───
sound_atual="$(gsettings get org.gnome.desktop.sound theme-name 2>/dev/null || echo '')"
if [[ "$sound_atual" != "'Pop'" ]]; then
    if [[ -d "$HOME/.local/share/sounds/Pop" || -d /usr/share/sounds/Pop ]]; then
        _info "Tema som regrediu ($sound_atual) — reativando via gsettings"
        gsettings set org.gnome.desktop.sound theme-name 'Pop' && _ok "theme-name='Pop' restaurado"
    else
        _warn "Tema som Pop não instalado. Rode: ./scripts/instalar_sons.sh"
    fi
fi

# ─── 7. App themes (idempotentes: kitty include, qbittorrent, etc.) ───
_info "Reaplicando app themes"
"$REPO_ROOT/scripts/instalar_app_themes.sh" || _warn "instalar_app_themes.sh falhou"

# ─── 8. Rebuild caches ───
_info "Regenerando caches"
gtk-update-icon-cache -f "$HOME/.local/share/icons/Dracula-Icones" 2>/dev/null || true
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
_ok "Caches regenerados"

# ─── 9. Verificação final ───
echo ""
_dim "=== Executando diagnóstico final ==="
if "$REPO_ROOT/scripts/diagnostico.sh" --quiet; then
    _ok "Dracula_OS-Theme reaplicado sem regressões restantes."
    exit 0
else
    _warn "Algumas regressões persistem. Rode ./scripts/diagnostico.sh para detalhes."
    exit 1
fi

# "Repetitio est mater studiorum." -- a repetição é a mãe do aprendizado (e da idempotência).
