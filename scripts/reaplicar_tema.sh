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

# ─── 1.5 Temas de ícones: ressincroniza a partir do dist/ ───
# O install.sh copia dist/icons/* para ~/.local/share/icons/. Se um arquivo
# instalado regredir depois disso (arte antiga que voltou, sobrescrita por
# instalador de app, cópia manual), nada aqui detectava: as seções seguintes só
# regeneram cache e reativam gsettings, e o cache regenerado a partir de arte
# errada continua errado.
#
# rsync -c compara por CHECKSUM, não por mtime: o build.sh é determinístico
# (exclude-chunk=date,tIME em redimensionar_png), então "nada transferido"
# significa mesmo conteúdo.
#
# --delete: estes quatro diretórios são 100% gerados pelo build.sh, então o
# destino tem que CONVERGIR para o dist/ -- arquivo que sobrou de um mapping
# antigo continua sendo servido pelo tema (e pode sombrear o hicolor). Duas
# guardas antes de deletar qualquer coisa:
#   1. validar_path_destrutivo (allowlist de lib/common.sh);
#   2. razão dist/destino: se o dist/ tem menos de 90% dos arquivos do destino,
#      é build parcial ou interrompido -- ressincroniza sem deletar e avisa.
# Sem backup a cada rodada de propósito: o conteúdo é integralmente regenerável
# por ./build.sh && ./install.sh --user.
if [[ -d "$REPO_ROOT/dist/icons" ]] && command -v rsync &>/dev/null; then
    _info "Conferindo temas de ícones contra dist/"
    total_ressync=0
    total_removidos=0
    for tema in Dracula-Icones dracula-icons-main dracula-icons-circle Dracula-Cursor; do
        src_tema="$REPO_ROOT/dist/icons/$tema"
        dest_tema="$HOME/.local/share/icons/$tema"
        [[ -d "$src_tema" ]] || continue
        [[ -d "$dest_tema" ]] || continue

        delete_flag=()
        if ! validar_path_destrutivo "$dest_tema" >/dev/null 2>&1; then
            _warn "$tema: destino fora da allowlist destrutiva — sincronizo sem --delete"
        else
            n_src=$(find "$src_tema" -type f ! -name icon-theme.cache | wc -l)
            n_dest=$(find "$dest_tema" -type f ! -name icon-theme.cache | wc -l)
            if [[ "$n_dest" -gt 0 && $((n_src * 100 / n_dest)) -lt 90 ]]; then
                _warn "$tema: dist/ tem $n_src arquivos contra $n_dest instalados" \
                    "— build parcial? sincronizo sem --delete"
            else
                delete_flag=(--delete)
            fi
        fi

        # -l: os upstreams trazem diretórios @2x como symlink; sem ele o rsync
        #     imprime "skipping non-regular file" em stdout a cada rodada e a
        #     contagem nunca zera.
        # --exclude icon-theme.cache: gerado localmente pela seção 8; comparar
        #     contra a cópia do dist/ daria divergência eterna de 1 arquivo.
        #     Item excluído também fica protegido do --delete.
        mapfile -t linhas < <(rsync -rlc "${delete_flag[@]}" --out-format='%n' \
            --exclude=icon-theme.cache "$src_tema/" "$dest_tema/" \
            2>/dev/null | grep -v '/$' | grep -v '^skipping ')

        n_upd=0
        n_del=0
        for linha in "${linhas[@]}"; do
            [[ -z "$linha" ]] && continue
            if [[ "$linha" == "deleting "* ]]; then
                n_del=$((n_del + 1))
            else
                n_upd=$((n_upd + 1))
            fi
        done

        if [[ "$n_upd" -gt 0 ]]; then
            _warn "$tema: $n_upd arquivo(s) divergiam do dist/ — ressincronizados"
            total_ressync=$((total_ressync + n_upd))
        fi
        if [[ "$n_del" -gt 0 ]]; then
            _warn "$tema: $n_del órfão(s) removidos (não existem mais no dist/)"
            total_removidos=$((total_removidos + n_del))
        fi
    done
    if [[ "$total_ressync" -eq 0 && "$total_removidos" -eq 0 ]]; then
        _ok "Temas de ícones em sincronia com dist/"
    fi
else
    _warn "dist/icons ausente ou rsync indisponível — pulei a conferência de ícones"
fi

# ─── 2. Pop!_Shell e Pop!_Cosmic dark.css (se regrediram) ───
# Detecção robusta: compara byte-a-byte o dark.css instalado com o source
# canônico do repo (src/shell/<ext>-dark.css). Qualquer divergência indica
# regressão — independente de paleta de cor ou marca textual.
pop_shell_ok=1
declare -A SHELL_SOURCES=(
    [pop-shell]="$REPO_ROOT/src/shell/pop-shell-dark.css"
    [pop-cosmic]="$REPO_ROOT/src/shell/pop-cosmic-dark.css"
)
for ext in pop-shell pop-cosmic; do
    base="/usr/share/gnome-shell/extensions/${ext}@system76.com"
    src="${SHELL_SOURCES[$ext]}"
    instalado="$base/dark.css"
    [[ -f "$instalado" && -f "$src" ]] || continue
    if ! cmp -s "$src" "$instalado"; then
        _info "$ext dark.css regrediu (diff vs $src) — reaplicando"
        sudo "$REPO_ROOT/scripts/instalar_pop_shell_css.sh" install || _warn "Falha ao reaplicar $ext"
        pop_shell_ok=0
    fi
done
[[ $pop_shell_ok -eq 1 ]] && _ok "Pop!_Shell/Pop!_Cosmic dark.css preservados (byte-a-byte vs source)"

# ─── 2.5 Localização pt-BR Pop!_Cosmic + higiene do launcher ───
_info "Reaplicando localização pt-BR do launcher Pop!_Cosmic"
"$REPO_ROOT/scripts/instalar_pop_cosmic_ptbr.sh" || _warn "instalar_pop_cosmic_ptbr.sh falhou (não-fatal)"

_info "Reaplicando higiene do launcher (NoDisplay + folder-children)"
"$REPO_ROOT/scripts/instalar_higiene_launcher.sh" || _warn "instalar_higiene_launcher.sh falhou (não-fatal)"

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

# ─── 6. Tema de som Dracula (gsettings costuma regredir com upgrade do GNOME) ───
# Default Dracula (SPRINT 25); cai para Pop se só ele estiver instalado.
sound_atual="$(gsettings get org.gnome.desktop.sound theme-name 2>/dev/null || echo '')"
tema_som=""
if [[ -d "$HOME/.local/share/sounds/Dracula" || -d /usr/share/sounds/Dracula ]]; then
    tema_som="Dracula"
elif [[ -d "$HOME/.local/share/sounds/Pop" || -d /usr/share/sounds/Pop ]]; then
    tema_som="Pop"
fi
if [[ -n "$tema_som" ]]; then
    if [[ "$sound_atual" != "'$tema_som'" ]]; then
        _info "Tema som regrediu ($sound_atual) — reativando $tema_som via gsettings"
        gsettings set org.gnome.desktop.sound theme-name "$tema_som" && _ok "theme-name='$tema_som' restaurado"
    fi
else
    _warn "Nenhum tema de som instalado. Rode: ./scripts/instalar_sons.sh"
fi

# ─── 7. App themes (idempotentes: kitty include, qbittorrent, etc.) ───
_info "Reaplicando app themes"
"$REPO_ROOT/scripts/instalar_app_themes.sh" || _warn "instalar_app_themes.sh falhou"

# ─── 7.5 Ícones de jogos Steam (re-gera se sources foram baixados após últimos ícones) ───
_info "Atualizando ícones de jogos Steam"
"$REPO_ROOT/scripts/atualizar_icones_steam.sh" || _warn "atualizar_icones_steam.sh falhou"

# ─── 7.6 Spicetify / Spotify Flatpak (SPRINT_17) ───
# Detecta dessincronia pós flatpak update. Default: avisa.
# Para auto-fix: rode 'bash scripts/atualizar_spicetify.sh --auto-fix' manualmente.
_info "Verificando Spicetify"
"$REPO_ROOT/scripts/atualizar_spicetify.sh" || _warn "atualizar_spicetify.sh falhou (não-fatal)"

# ─── 7.7 Keybindings (dconf) ───
# Subscript reaplica snapshots de media-keys/wm-keybindings/terminal/sound.
# Idempotente em resultado; cria backup pequeno em ~/.cache/dracula_os_backup/.
_info "Reaplicando keybindings (dconf)"
"$REPO_ROOT/scripts/instalar_keybindings.sh" || _warn "instalar_keybindings.sh falhou (não-fatal)"

# ─── 7.8 dconf das extensões GNOME (sem re-download) ───
# Usa --only-dconf: pula install/enable, aplica apenas configurações dconf
# das extensões já presentes. Subscript detecta COSMIC e pula sozinho.
_info "Reaplicando dconf das extensões GNOME (--only-dconf)"
"$REPO_ROOT/scripts/instalar_gnome_extensions.sh" --only-dconf || _warn "instalar_gnome_extensions.sh --only-dconf falhou (não-fatal)"

# ─── 8. Rebuild caches ───
_info "Regenerando caches"
if ! gtk-update-icon-cache -f "$HOME/.local/share/icons/Dracula-Icones" 2>/dev/null; then
    _warn "gtk-update-icon-cache falhou para Dracula-Icones"
fi
if ! update-desktop-database "$HOME/.local/share/applications" 2>/dev/null; then
    _warn "update-desktop-database falhou para ~/.local/share/applications"
fi
_ok "Caches regenerados"

# ─── 8.5 gsettings: icon-theme / gtk-theme / cursor-theme ───
# Reativa o tema caso GNOME tenha resetado para Adwaita após upgrade.
# Cada `gsettings set` é silencioso quando o valor já é o atual (no-op).
_info "Reativando tema via gsettings (icon/gtk/cursor)"
gsettings set org.gnome.desktop.interface icon-theme 'Dracula-Icones' \
    && _ok "icon-theme=Dracula-Icones" || _warn "Falha ao setar icon-theme"
gsettings set org.gnome.desktop.interface gtk-theme 'Dracula-standard-buttons' \
    && _ok "gtk-theme=Dracula-standard-buttons" || _warn "Falha ao setar gtk-theme"
gsettings set org.gnome.desktop.interface cursor-theme 'Dracula-Cursor' \
    && _ok "cursor-theme=Dracula-Cursor" || _warn "Falha ao setar cursor-theme"
if gsettings list-schemas 2>/dev/null | grep -q "^org.gnome.shell.extensions.user-theme$"; then
    gsettings set org.gnome.shell.extensions.user-theme name 'Dracula-standard-buttons' 2>/dev/null \
        && _ok "user-theme=Dracula-standard-buttons" || true
fi

# ─── 8b. Pipeline Relatório MEC (auto-cura pós-upgrade; não-fatal) ───
if [[ -x "$REPO_ROOT/scripts/instalar_relatorio_mec.sh" ]]; then
    "$REPO_ROOT/scripts/instalar_relatorio_mec.sh" >/dev/null 2>&1 \
        && _ok "pipeline Relatório MEC verificado" || _warn "instalar_relatorio_mec.sh falhou (não-fatal)"
fi

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
