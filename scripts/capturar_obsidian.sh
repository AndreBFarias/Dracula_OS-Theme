#!/usr/bin/env bash
# capturar_obsidian.sh — captura a config completa do Obsidian de um vault
# (settings, hotkeys, snippets, themes e os plugins de terceiros) para
# app-themes/obsidian/config/, para virar o padrão versionado do projeto.
# Ferramenta de MAINTAINER (roda na máquina de quem mantém o tema). (SPRINT 26)
#
# Exclui apenas os arquivos voláteis de sessão (workspace.json,
# workspace-mobile.json) — o resto vai inteiro. NÃO sanitiza segredos
# automaticamente: revise os data.json antes de commitar (no host de captura
# os apiKeys estavam vazios).
#
# Uso:
#   ./scripts/capturar_obsidian.sh [<caminho-do-vault>]
#   (sem argumento, detecta o primeiro vault em obsidian.json)
#
# Variáveis:
#   DRACULA_DRY_RUN=1   só mostra o que faria.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
REPO_ROOT="$(_repo_root "${BASH_SOURCE[0]}")"

DEST="$REPO_ROOT/app-themes/obsidian/config"
DRY="${DRACULA_DRY_RUN:-0}"

# Arquivos voláteis/sessão que NÃO devem ser versionados.
EXCLUIR=(workspace.json workspace-mobile.json)

# ─── Resolver o vault ───
VAULT="${1:-}"
if [[ -z "$VAULT" ]]; then
    for oj in \
        "$HOME/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json" \
        "$HOME/.config/obsidian/obsidian.json"; do
        if [[ -f "$oj" ]]; then
            VAULT="$(jq -r '.vaults[].path' "$oj" 2>/dev/null | head -n1)"
            [[ -n "$VAULT" ]] && break
        fi
    done
fi

if [[ -z "$VAULT" || ! -d "$VAULT/.obsidian" ]]; then
    _err "Vault não encontrado (passe o caminho como argumento). Procurado: '${VAULT:-<vazio>}'"
    exit 1
fi

_info "Vault: $VAULT"
_info "Destino: $DEST"

ORIGEM="$VAULT/.obsidian"

if [[ "$DRY" == "1" ]]; then
    _dim "[dry-run] rsync -a --delete (excl. ${EXCLUIR[*]}) '$ORIGEM/' '$DEST/'"
    exit 0
fi

mkdir -p "$DEST"

# rsync espelha a config (—delete mantém o repo idêntico ao vault em re-capturas).
if command -v rsync >/dev/null 2>&1; then
    rsync_args=(-a --delete)
    for e in "${EXCLUIR[@]}"; do rsync_args+=(--exclude "$e"); done
    rsync "${rsync_args[@]}" "$ORIGEM/" "$DEST/"
else
    # Fallback sem rsync: limpa o destino (dentro do repo) e copia, removendo excluídos.
    if validar_path_destrutivo "$DEST" >/dev/null 2>&1 || [[ "$DEST" == "$REPO_ROOT/"* ]]; then
        rm -rf -- "${DEST:?}"/*
    fi
    cp -a "$ORIGEM/." "$DEST/"
    for e in "${EXCLUIR[@]}"; do rm -f "$DEST/$e"; done
fi

total=$(find "$DEST" -type f | wc -l)
plugins=$(find "$DEST/plugins" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
_ok "Capturado: $total arquivos, $plugins plugins"
_warn "Revise os data.json por dados sensíveis antes de commitar (repo público)."
exit 0
