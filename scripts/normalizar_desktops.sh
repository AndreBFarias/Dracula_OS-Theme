#!/usr/bin/env bash
# normalizar_desktops.sh — reescreve .desktop que usam path absoluto em Icon=
# para referências simples por nome (que o tema resolve).
#
# Uso: ./scripts/normalizar_desktops.sh [--dry-run]
#
# Segurança: cada .desktop alterado é copiado antes para
# ~/.cache/dracula_os_backup_<timestamp>/desktops/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAPPING="$REPO_ROOT/mapping.json"
DRY_RUN=0
BACKUP_DIR="$HOME/.cache/dracula_os_backup_$(date +%Y%m%d_%H%M%S)/desktops"

for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=1
done

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_DIM='\033[2m'
C_RESET='\033[0m'

_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }
_warn() { echo -e "  ${C_YELLOW}!!${C_RESET} $*" >&2; }

# Diretórios onde podemos editar .desktop (user-local)
DIRS=(
    "$HOME/.local/share/applications"
    "$HOME/.local/share/flatpak/exports/share/applications"
)

processar_desktop() {
    local f="$1"
    # Lê Icon= atual
    local icon_atual
    icon_atual=$(grep -m1 "^Icon=" "$f" | cut -d= -f2- || true)
    if [[ -z "$icon_atual" ]]; then
        return 0
    fi
    # Só age se for path absoluto
    if [[ "$icon_atual" != /* ]]; then
        return 0
    fi

    # REGRA: sempre usar o app_id como novo Icon — o build.sh garante que
    # existe um arquivo com esse nome no tema instalado (ou cai no upstream).
    # Isso é mais robusto que derivar do basename do arquivo-fonte, porque
    # muitos projetos usam nome genérico (icon.png, logo.png) ou sem relação
    # com o app.
    local app_id
    app_id=$(basename "$f" .desktop)
    local nome_novo="$app_id"

    _info "$app_id: Icon='$icon_atual' → Icon='$nome_novo'"

    if [[ $DRY_RUN -eq 1 ]]; then
        return 0
    fi

    # Backup
    mkdir -p "$BACKUP_DIR"
    cp "$f" "$BACKUP_DIR/$(basename "$f")"

    # Escapa caracteres regex no LADO ESQUERDO (match)
    local icon_esc
    icon_esc=$(printf '%s' "$icon_atual" | sed 's/[.[\*^$()+?{|\\/]/\\&/g')
    # Escapa & e \ no LADO DIREITO (replacement) — sed substitui & pelo match inteiro
    local nome_esc
    nome_esc=$(printf '%s' "$nome_novo" | sed 's/[&\\/]/\\&/g')

    sed -i "s|^Icon=${icon_esc}|Icon=${nome_esc}|" "$f" || _warn "sed falhou em $f"
}

main() {
    echo -e "${C_DIM}Dracula_OS-Theme — normalizar .desktop${C_RESET}"
    [[ $DRY_RUN -eq 1 ]] && echo -e "${C_YELLOW}[DRY RUN] nada será modificado${C_RESET}"
    echo -e "${C_DIM}Backup em: $BACKUP_DIR${C_RESET}"
    echo ""

    local total=0
    for d in "${DIRS[@]}"; do
        [[ ! -d "$d" ]] && continue
        for f in "$d"/*.desktop; do
            [[ ! -f "$f" ]] && continue
            # Flatpak exports são symlinks read-only
            if [[ -L "$f" ]]; then
                continue
            fi
            processar_desktop "$f" && total=$((total + 1)) || true
        done
    done

    _ok "Processados $total .desktop files"
}

main "$@"

# "In simplicitate veritas." -- a verdade está na simplicidade.
