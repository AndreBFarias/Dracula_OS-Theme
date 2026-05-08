#!/usr/bin/env bash
# test_portabilidade.sh — falha se algum arquivo versionado tem hardcoded
# username do autor original.
#
# Executado em CI para impedir regressões de portabilidade.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

# Monta padrão dinamicamente para evitar auto-match deste próprio arquivo
PADRAO="/home/$(echo -n 'andre' 'farias' | tr -d ' ')"

# Busca apenas em arquivos VERSIONADOS pelo git (scripts + JSON + GitHub Actions).
# git ls-files filtra automaticamente .gitignore + untracked (ex.:
# .claude/settings.local.json), eliminando falso-positivo da SPRINT 19.
# Exclui docs/sprints/ porque são registros históricos onde o path pode aparecer
# em exemplos de comando, e a assinatura na raiz.
mapfile -t arquivos < <(git ls-files \
    '*.sh' '*.json' '*.yml' '*.yaml' \
    | grep -Ev '^(docs/|dist/|releases/)' || true)

matches=""
if [[ ${#arquivos[@]} -gt 0 ]]; then
    matches="$(grep -nH "$PADRAO" -- "${arquivos[@]}" 2>/dev/null || true)"
fi

if [[ -n "$matches" ]]; then
    echo "FAIL: hardcoded '$PADRAO' encontrado em arquivos de código:" >&2
    echo "$matches" >&2
    exit 1
fi

echo "OK: nenhum hardcoded '$PADRAO' em código versionado."
exit 0
