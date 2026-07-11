#!/usr/bin/env bash
# instalar_fontes_design.sh — fontes de design no padrão do tema (SPRINT 33)
#
# Instala JetBrains Mono + Fira Code em ~/.local/share/fonts/ para que o texto
# vivo de SVGs (e do desktop) renderize e EXPORTE correto. Corrige na raiz o
# bug em que a exportação PNG de um .svg no Boxy SVG perdia o texto por ausência
# das fontes no sistema.
#
# Idempotente (re-execução só age no que divergiu); sem sudo; user-mode.
#
# Uso: instalar_fontes_design.sh

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/src/fontes-design"
DEST_FONTES="$HOME/.local/share/fonts"
BOXY_APP="com.boxy_svg.BoxySVG"

C_CYAN='\033[0;36m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'; C_RESET='\033[0m'
_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }
_warn() { echo -e "  ${C_YELLOW}!!${C_RESET} $*" >&2; }

if [[ ! -d "$SRC" ]]; then
    _warn "src/fontes-design ausente — nada a instalar"
    exit 0
fi

MUDOU=0

# ─── 1. Copiar cada família para ~/.local/share/fonts/<Família>/ ───
# Itera sobre os subdiretórios de src/fontes-design (uma família por pasta).
for familia_dir in "$SRC"/*/; do
    [[ -d "$familia_dir" ]] || continue
    familia="$(basename "$familia_dir")"
    alvo_dir="$DEST_FONTES/$familia"
    mkdir -p "$alvo_dir"
    # Copia .ttf e a licença OFL (redistribuição correta)
    for f in "$familia_dir"*.ttf "$familia_dir"OFL.txt; do
        [[ -e "$f" ]] || continue
        alvo="$alvo_dir/$(basename "$f")"
        if cmp -s "$f" "$alvo"; then
            continue
        fi
        cp "$f" "$alvo"
        MUDOU=1
        _info "$familia/$(basename "$f") atualizado"
    done
done
[[ $MUDOU -eq 0 ]] && _ok "fontes de design já em dia (skip)"

# ─── 2. fc-cache só quando algo mudou (operação cara) ───
if [[ $MUDOU -eq 1 ]]; then
    fc-cache -f "$DEST_FONTES" >/dev/null 2>&1 || true
    _ok "cache de fontes atualizado"
fi

# ─── 3. Higiene do Flatpak Boxy SVG (não-fatal; só se instalado) ───
# O sandbox já lê ~/.local/share/fonts, mas tem cache de fontconfig próprio que
# pode ficar velho. Se as fontes mudaram, limpa esse cache (é cache, seguro) e
# avisa para reiniciar o Boxy.
if flatpak info "$BOXY_APP" >/dev/null 2>&1; then
    if [[ $MUDOU -eq 1 ]]; then
        SANDBOX_FC_CACHE="$HOME/.var/app/$BOXY_APP/cache/fontconfig"
        if [[ -d "$SANDBOX_FC_CACHE" ]]; then
            rm -rf "$SANDBOX_FC_CACHE"
            _info "cache de fontconfig do Boxy limpo (regenera no próximo start)"
        fi
        _warn "reinicie o Boxy SVG para as novas fontes aparecerem"
    fi
    # Prova opcional: o Boxy VAI enxergar a fonte (export corrigido na raiz).
    for fam in "JetBrains Mono" "Fira Code"; do
        res="$(timeout 20 flatpak run --command=fc-match "$BOXY_APP" "$fam" 2>/dev/null || true)"
        if [[ -n "$res" ]]; then
            _ok "Boxy fc-match '$fam' -> $res"
        else
            _warn "não consegui provar fc-match in-sandbox de '$fam' (não-fatal — prova no host abaixo vale)"
        fi
    done
else
    _ok "Boxy SVG (Flatpak) não instalado — higiene do sandbox pulada"
fi

# ─── 4. Verificação final (prova de resolução no host) ───
# Casa a saída bruta do fc-match (inclui o nome do arquivo) — se resolveu para
# a fonte instalada, o arquivo é JetBrainsMono-*.ttf / FiraCode-*.ttf; se caísse
# no fallback, seria DejaVuSans.ttf ou similar.
for fam in "JetBrains Mono" "Fira Code"; do
    res="$(fc-match "$fam" 2>/dev/null)"
    if echo "$res" | grep -qiE 'jetbrainsmono|firacode'; then
        _ok "fc-match '$fam' -> $res"
    else
        _warn "fc-match '$fam' -> $res (não resolveu para a fonte esperada!)"
    fi
done
_ok "fontes de design verificadas"
