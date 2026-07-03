#!/usr/bin/env bash
# instalar_relatorio_mec.sh — pipeline do Relatório de Serviço MEC sempre funcional
#
# Garante (idempotente; re-execução só age no que divergiu):
#   1. Fontes Liberation Sans Narrow em ~/.local/share/fonts/LiberationNarrow/
#      (métrica-compatível com Arial Narrow — corpo do docx universal)
#   2. Aliases fontconfig em ~/.config/fontconfig/conf.d/60-relatorio-mec.conf
#      (Arial Nova/Open Sans Condensed/etc. -> equivalentes universais)
#   3. Scripts relatorio_fontfix + relatorio_pdf em ~/.local/bin/
#   4. Checagem das dependências apt (avisa; só instala se --apt e sudo disponível)
#
# Uso: instalar_relatorio_mec.sh [--apt]

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/src/relatorio-mec"

C_CYAN='\033[0;36m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'; C_RESET='\033[0m'
_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }
_warn() { echo -e "  ${C_YELLOW}!!${C_RESET} $*" >&2; }

APT=0
[[ "${1:-}" == "--apt" ]] && APT=1

MUDOU_FONTE=0

# ─── 1. Fontes Liberation Sans Narrow ───
DEST_FONTES="$HOME/.local/share/fonts/LiberationNarrow"
mkdir -p "$DEST_FONTES"
for f in "$SRC"/fontes/*.ttf; do
    alvo="$DEST_FONTES/$(basename "$f")"
    if cmp -s "$f" "$alvo"; then
        continue
    fi
    cp "$f" "$alvo"
    MUDOU_FONTE=1
    _info "fonte atualizada: $(basename "$f")"
done
[[ $MUDOU_FONTE -eq 0 ]] && _ok "fontes Liberation Sans Narrow já em dia (skip)"

# ─── 2. Aliases fontconfig (conf.d — não toca no fonts.conf do usuário) ───
DEST_CONF="$HOME/.config/fontconfig/conf.d/60-relatorio-mec.conf"
mkdir -p "$(dirname "$DEST_CONF")"
if cmp -s "$SRC/60-relatorio-mec.conf" "$DEST_CONF"; then
    _ok "aliases fontconfig já em dia (skip)"
else
    cp "$SRC/60-relatorio-mec.conf" "$DEST_CONF"
    MUDOU_FONTE=1
    _info "aliases fontconfig aplicados"
fi

# fc-cache só quando algo mudou (operação cara)
if [[ $MUDOU_FONTE -eq 1 ]]; then
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
    _ok "cache de fontes atualizado"
fi

# ─── 3. Scripts em ~/.local/bin ───
mkdir -p "$HOME/.local/bin"
for s in relatorio_fontfix relatorio_pdf docx_doctor; do
    alvo="$HOME/.local/bin/$s"
    if cmp -s "$SRC/$s" "$alvo"; then
        _ok "$s já em dia (skip)"
    else
        cp "$SRC/$s" "$alvo" && chmod +x "$alvo"
        _info "$s instalado/atualizado"
    fi
done

# ─── 4. Dependências apt ───
# dpkg-query com Status explícito: "dpkg -s" retorna 0 até para pacote removido
# com config residual (deinstall ok config-files)
_pacote_instalado() {
    [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" == "install ok installed" ]]
}
# NOTA: libreoffice-writer foi REMOVIDO das dependências de propósito (2026-07-02):
# o motor de layout oficial é o OnlyOffice (o LO renderizava bordas/margens diferente).
# O fluxo é: OnlyOffice exporta o PDF -> relatorio_pdf lava com pdftocairo.
FALTAM=()
_pacote_instalado poppler-utils || FALTAM+=(poppler-utils)
# [[ -n $(...) ]] em vez de pipe com grep -q: com pipefail, grep -q fecha o pipe
# cedo e o SIGPIPE no fc-list vira falso-negativo
[[ -n "$(fc-list :family=Arial 2>/dev/null)" ]] || FALTAM+=(ttf-mscorefonts-installer)
if [[ ${#FALTAM[@]} -eq 0 ]]; then
    _ok "dependências apt presentes (poppler, mscorefonts)"
elif [[ $APT -eq 1 ]]; then
    _info "instalando via apt: ${FALTAM[*]} (pede sudo)"
    sudo apt-get install -y "${FALTAM[@]}" || _warn "apt falhou — instale manualmente: sudo apt install ${FALTAM[*]}"
else
    _warn "faltam pacotes apt: ${FALTAM[*]} — rode: sudo apt install ${FALTAM[*]}"
fi

# ─── Verificação final (prova de resolução) ───
for fam in "Arial Nova" "Arial Narrow" "Open Sans Condensed"; do
    res=$(fc-match "$fam" 2>/dev/null | sed 's/.*: //')
    _ok "fc-match '$fam' -> $res"
done
_ok "pipeline do Relatório MEC verificado"
