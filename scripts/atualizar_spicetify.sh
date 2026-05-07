#!/usr/bin/env bash
# atualizar_spicetify.sh — detecta dessincronia Spicetify x Spotify Flatpak
# após `flatpak update` e (opcionalmente) resolve. Idempotente. Sem sudo.
#
# Modo padrão: detecta, loga sugestão, exit 0 não-fatal.
# Modo --auto-fix (ou env DRACULA_SPOTIFY_AUTOFIX=1): executa o roteiro
# completo (kill Spotify -> limpa cache -> flatpak --reinstall -> apply).
#
# DRACULA_DRY_RUN=1: imprime comandos sem executar.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

AUTO_FIX=0
[[ "${DRACULA_SPOTIFY_AUTOFIX:-0}" == "1" ]] && AUTO_FIX=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto-fix) AUTO_FIX=1; shift ;;
        --help|-h)
            cat <<'EOF'
Uso: atualizar_spicetify.sh [--auto-fix]

Detecta o estado "Spotify version and backup version are mismatched" do
Spicetify após `flatpak update`. Sem flag, apenas sugere o fix. Com
--auto-fix (ou DRACULA_SPOTIFY_AUTOFIX=1), executa kill+cache+reinstall+apply.

Variáveis:
  DRACULA_DRY_RUN=1         imprime comandos sem executar
  DRACULA_SPOTIFY_AUTOFIX=1 equivalente a --auto-fix
EOF
            exit 0 ;;
        *) _warn "Argumento ignorado: $1"; shift ;;
    esac
done

SPICETIFY_BIN="$HOME/.spicetify/spicetify"

if [[ ! -x "$SPICETIFY_BIN" ]] && ! command -v spicetify >/dev/null 2>&1; then
    _info "Spicetify não instalado, pulando"
    exit 0
fi
[[ -x "$SPICETIFY_BIN" ]] || SPICETIFY_BIN="$(command -v spicetify)"

if ! _detectar_spotify_flatpak; then
    _info "Spotify (Flatpak) não detectado, pulando"
    exit 0
fi

_info "Verificando estado do Spicetify (spicetify apply)"
saida=""
status=0
if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
    _dim "[dry-run] $SPICETIFY_BIN apply"
    # Em dry-run + --auto-fix, simulamos o cenário de mismatch para que o
    # usuário enxergue os 4 comandos do roteiro completo.
    if [[ $AUTO_FIX -eq 1 ]]; then
        status=1
        saida="warning Spotify version and backup version are mismatched."
    fi
else
    saida="$("$SPICETIFY_BIN" apply 2>&1)" || status=$?
fi

if [[ $status -ne 0 ]] && echo "$saida" | grep -q "version and backup version are mismatched"; then
    _warn "Spicetify reporta version mismatch (Spotify foi atualizado)"
    if [[ $AUTO_FIX -eq 1 ]]; then
        _info "AUTO-FIX ativo: vou matar Spotify, limpar cache, reinstalar Flatpak e reaplicar"
        if _resolver_spicetify_mismatch "$SPICETIFY_BIN"; then
            _ok "Tema reaplicado após reinstall do Spotify"
            exit 0
        else
            _err "Auto-fix falhou; rode os passos manualmente (ver app-themes/spicetify/README.md#troubleshooting)"
            exit 0
        fi
    else
        _warn "Para resolver: rode 'bash scripts/atualizar_spicetify.sh --auto-fix'"
        _warn "ou exporte DRACULA_SPOTIFY_AUTOFIX=1 antes do reaplicar_tema.sh."
        exit 0
    fi
elif [[ $status -ne 0 ]]; then
    _warn "spicetify apply retornou $status (não é mismatch — verifique manualmente)"
    echo "$saida" | head -20 >&2
    exit 0
fi

_ok "spicetify aplicado / tema OK"
exit 0
