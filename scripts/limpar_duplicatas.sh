#!/usr/bin/env bash
# limpar_duplicatas.sh — remove instalações antigas e duplicatas do Dracula
# com backup prévio. DESTRUTIVO: só roda com --yes ou resposta interativa.
#
# Uso:
#   ./scripts/limpar_duplicatas.sh            # modo interativo
#   ./scripts/limpar_duplicatas.sh --yes      # sem confirmação (cuidado!)
#   ./scripts/limpar_duplicatas.sh --dry-run  # só mostra o que faria

set -euo pipefail

DRY_RUN=0
AUTO_YES=0
for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=1
    [[ "$arg" == "--yes"     ]] && AUTO_YES=1
done

TS=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.cache/dracula_os_backup_$TS"

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'
C_DIM='\033[2m'
C_RESET='\033[0m'

_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }
_warn() { echo -e "  ${C_YELLOW}!!${C_RESET} $*" >&2; }
_err()  { echo -e "  ${C_RED}ERRO${C_RESET} $*" >&2; }

# Lista de alvos (path → descrição)
ALVOS=(
    "$HOME/.icons/Dracula-Icons|merge antigo do instalador.py (substituído por herança declarativa)"
    "$HOME/.icons/Dracula-Icones|tema custom antigo (substituído pela nova instalação em ~/.local/share/icons/)"
    "$HOME/.icons/Dracula-Cursor|duplicata do /usr/share/icons/Dracula-Cursor"
    "$HOME/.icons/instalador.py|script legado — nova lógica no repo"
    "$HOME/.local/share/icons/Dracula-cursors|duplicata de cursor"
    "$HOME/.themes/Dracula|tema GTK antigo (upstream)"
)

confirmar() {
    local alvo="$1" desc="$2"
    if [[ $AUTO_YES -eq 1 ]]; then
        return 0
    fi
    read -r -p "Remover '$alvo' ($desc)? [s/N] " resposta
    [[ "$resposta" =~ ^[sSyY]$ ]]
}

processar() {
    local linha="$1"
    local alvo="${linha%%|*}"
    local desc="${linha#*|}"

    if [[ ! -e "$alvo" ]]; then
        echo -e "  ${C_DIM}--${C_RESET} $alvo (já não existe)"
        return 0
    fi

    if ! confirmar "$alvo" "$desc"; then
        echo -e "  ${C_DIM}--${C_RESET} $alvo (pulado)"
        return 0
    fi

    # Backup
    mkdir -p "$BACKUP_DIR"
    _info "backup: $alvo → $BACKUP_DIR/"
    if [[ $DRY_RUN -eq 0 ]]; then
        if [[ -d "$alvo" ]]; then
            cp -r "$alvo" "$BACKUP_DIR/" || _warn "backup falhou, mas prosseguindo"
        else
            cp "$alvo" "$BACKUP_DIR/" || _warn "backup falhou"
        fi
        rm -rf "$alvo"
    else
        echo "  [dry-run] rm -rf $alvo"
    fi
    _ok "removido: $alvo"
}

main() {
    echo -e "${C_DIM}Dracula_OS-Theme — limpar duplicatas${C_RESET}"
    echo -e "${C_DIM}Backup em: $BACKUP_DIR${C_RESET}"
    [[ $DRY_RUN -eq 1 ]] && echo -e "${C_YELLOW}[DRY RUN] nada será modificado${C_RESET}"
    echo ""

    # Guarda: só roda se o novo tema ja estiver instalado
    if [[ ! -d "$HOME/.local/share/icons/Dracula-Icones" && ! -d "/usr/share/icons/Dracula-Icones.new" ]]; then
        _err "Novo tema NAO instalado em ~/.local/share/icons/Dracula-Icones/"
        _err "Rode ./install.sh --user ANTES de limpar duplicatas, senao o sistema fica sem icones."
        exit 1
    fi

    # Guarda: .desktop com paths absolutos ainda nao foram normalizados
    # (|| true porque grep sem match retorna 1 e set -e + pipefail matariam)
    local abs_path_count
    abs_path_count=$(grep -l "^Icon=/home/andrefarias/.icons/Dracula-Icones" "$HOME/.local/share/applications/"*.desktop 2>/dev/null | wc -l || true)
    if [[ $abs_path_count -gt 0 && $DRY_RUN -eq 0 ]]; then
        _warn "Existem $abs_path_count .desktop com Icon= absoluto apontando para ~/.icons/Dracula-Icones/"
        _warn "Rode ./scripts/normalizar_desktops.sh ANTES de limpar, senao esses apps ficam sem icone."
        if [[ $AUTO_YES -eq 0 ]]; then
            read -r -p "Prosseguir assim mesmo? [s/N] " r
            [[ ! "$r" =~ ^[sSyY]$ ]] && exit 1
        fi
    fi


    for linha in "${ALVOS[@]}"; do
        processar "$linha"
    done

    echo ""
    _ok "Limpeza concluída. Backups em $BACKUP_DIR"
    _warn "Preserva: ~/.local/share/icons/dracula-icons-{main,circle} (upstreams)"
}

main "$@"

# "A única coisa que mantém um homem vivo é sua ignorância." -- Ecclesiastes (aplicado ao código legado)
