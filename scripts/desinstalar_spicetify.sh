#!/usr/bin/env bash
# desinstalar_spicetify.sh — reverte Spicetify. Sem flag, executa
# `spicetify restore` (preserva configs/themes). Com `--full`, remove
# também ~/.spicetify/ e ~/.config/spicetify/ (com validar_path_destrutivo).
# Não-fatal se nada existe.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

SPICETIFY_BIN="$HOME/.spicetify/spicetify"
FULL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --full) FULL=1; shift ;;
        --help|-h)
            cat <<'EOF'
Uso: desinstalar_spicetify.sh [--full]

Sem --full: executa `spicetify restore` (preserva configs).
Com --full: remove ~/.spicetify/ e ~/.config/spicetify/.

Variáveis:
  DRACULA_DRY_RUN=1   apenas loga, não executa.
EOF
            exit 0 ;;
        *) _warn "Argumento ignorado: $1"; shift ;;
    esac
done

if [[ -x "$SPICETIFY_BIN" ]]; then
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] $SPICETIFY_BIN restore"
    else
        "$SPICETIFY_BIN" restore 2>/dev/null || _warn "spicetify restore falhou"
        _ok "Spicetify restaurado (Spotify limpo)"
    fi
else
    _info "Spicetify não instalado em $SPICETIFY_BIN; nada a restaurar"
fi

if [[ $FULL -eq 1 ]]; then
    for dir in "$HOME/.spicetify" "$HOME/.config/spicetify"; do
        if [[ -d "$dir" ]]; then
            if ! validar_path_destrutivo "$dir"; then
                _err "Pulando $dir por segurança"
                continue
            fi
            if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
                _dim "[dry-run] rm -rf -- $dir"
            else
                rm -rf -- "$dir" && _ok "removido: $dir"
            fi
        fi
    done
fi

exit 0
