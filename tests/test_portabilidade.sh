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

# Busca apenas em arquivos de código (scripts + JSON + GitHub Actions).
# Exclui docs/sprints/ porque são registros históricos onde o path pode aparecer
# em exemplos de comando, e a assinatura na raiz.
matches="$(grep -rn "$PADRAO" \
    --include="*.sh" \
    --include="*.json" \
    --include="*.yml" \
    --include="*.yaml" \
    --exclude-dir="docs" \
    --exclude-dir=".git" \
    --exclude-dir="dist" \
    --exclude-dir="releases" \
    . 2>/dev/null || true)"

if [[ -n "$matches" ]]; then
    echo "FAIL: hardcoded '$PADRAO' encontrado em arquivos de código:" >&2
    echo "$matches" >&2
    exit 1
fi

echo "OK: nenhum hardcoded '$PADRAO' em código versionado."
exit 0
