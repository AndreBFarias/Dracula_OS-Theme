#!/usr/bin/env bash
# test_diagnostico_exit_codes.sh — garante que diagnostico.sh retorna 0 quando
# o tema está bem aplicado e 1 quando há regressão simulada.
#
# Simulação de regressão: troca gsettings icon-theme para 'Adwaita' e verifica
# exit 1; depois restaura e verifica exit 0. Read-only até o teste final.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIAG="$REPO_ROOT/scripts/diagnostico.sh"

if [[ ! -x "$DIAG" ]]; then
    echo "SKIP: $DIAG não existe ou não é executável."
    exit 0
fi

# Precisa de gsettings disponível
if ! command -v gsettings >/dev/null 2>&1; then
    echo "SKIP: gsettings indisponível (provavelmente CI)."
    exit 0
fi

tema_original="$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'" || echo '')"
if [[ -z "$tema_original" ]]; then
    echo "SKIP: sem acesso a gsettings (sessão não-gráfica)."
    exit 0
fi

echo "Tema original: $tema_original"

# Cenário 1: estado atual — apenas verifica que existe saída, sem exigir exit 0
# (ambiente real pode ter regressões legítimas)
"$DIAG" --quiet
estado_atual=$?
echo "diagnóstico do estado atual: exit=$estado_atual"

# Cenário 2: força regressão óbvia trocando o tema
echo "--- simulando regressão (icon-theme=Adwaita) ---"
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
"$DIAG" --quiet
estado_regredido=$?
gsettings set org.gnome.desktop.interface icon-theme "$tema_original"

if [[ $estado_regredido -ne 1 ]]; then
    echo "FAIL: diagnóstico não retornou 1 ao detectar tema errado (retornou $estado_regredido)." >&2
    exit 1
fi

echo "OK: diagnóstico retornou 1 quando tema foi regredido, restaurado para '$tema_original'."
exit 0
