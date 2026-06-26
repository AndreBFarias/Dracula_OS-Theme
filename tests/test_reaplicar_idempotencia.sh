#!/usr/bin/env bash
# test_reaplicar_idempotencia.sh — roda reaplicar_tema.sh duas vezes e verifica
# que a segunda execução não produz mudanças adicionais (idempotência).
#
# Capta hashes de arquivos críticos antes/depois e compara.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARQUIVOS_CRITICOS=(
    "$HOME/.config/kitty/kitty.conf"
    "$HOME/.local/share/applications/com.rtosta.zapzap.desktop"
)

snapshot() {
    local sum
    sum=""
    for f in "${ARQUIVOS_CRITICOS[@]}"; do
        [[ -f "$f" ]] && sum="$sum$(sha256sum "$f" 2>/dev/null)"$'\n'
    done
    echo "$sum"
}

# Evita aprovação vácua: se nenhum arquivo-alvo existe, o snapshot fica vazio e
# "" == "" passaria sem testar nada. Nesse caso, SKIP honesto (não falso-OK).
existe_algum=0
for f in "${ARQUIVOS_CRITICOS[@]}"; do
    [[ -f "$f" ]] && existe_algum=1
done
if [[ $existe_algum -eq 0 ]]; then
    echo "SKIP: nenhum arquivo-alvo presente (tema não instalado neste ambiente)."
    exit 0
fi

echo "=== Rodada 1 de reaplicar_tema.sh ==="
"$REPO_ROOT/scripts/reaplicar_tema.sh" >/dev/null 2>&1 || true

antes="$(snapshot)"

echo "=== Rodada 2 (deve ser no-op) ==="
"$REPO_ROOT/scripts/reaplicar_tema.sh" >/dev/null 2>&1 || true

depois="$(snapshot)"

if [[ "$antes" == "$depois" ]]; then
    echo "OK: idempotência verificada (arquivos críticos inalterados entre execuções)."
    exit 0
else
    echo "FAIL: diferenças entre execuções 1 e 2:" >&2
    diff <(echo "$antes") <(echo "$depois") >&2 || true
    exit 1
fi
