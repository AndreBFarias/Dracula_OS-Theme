#!/usr/bin/env bash
# lib/common.sh — biblioteca sourceable com logging e utilitários do Dracula_OS-Theme.
#
# Uso:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
#
# Criado na SPRINT_06 (stub) e expandido na SPRINT_08 (validação destrutiva,
# trap de cleanup, backup com manifest).

# Guarda contra dupla importação
if [[ -n "${_DRACULA_COMMON_SOURCED:-}" ]]; then return 0; fi
_DRACULA_COMMON_SOURCED=1

# ─── Cores ───
C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'
C_DIM='\033[2m'
C_RESET='\033[0m'

# ─── Logging ───
_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }
_warn() { echo -e "  ${C_YELLOW}!!${C_RESET} $*" >&2; }
_err()  { echo -e "  ${C_RED}ERRO${C_RESET} $*" >&2; }
_dim()  { echo -e "${C_DIM}$*${C_RESET}"; }

# ─── Detecção de REPO_ROOT ───
# Scripts em scripts/ ou na raiz podem chamar: _repo_root "${BASH_SOURCE[0]}"
_repo_root() {
    local script_path="${1:-${BASH_SOURCE[1]}}"
    local dir
    dir="$(cd "$(dirname "$script_path")" && pwd)"
    # Se estamos em scripts/, sobe um nível
    if [[ "$(basename "$dir")" == "scripts" ]]; then
        dirname "$dir"
    elif [[ "$(basename "$dir")" == "lib" ]]; then
        dirname "$(dirname "$dir")"
    else
        echo "$dir"
    fi
}

# ─── Log rotacionado em ~/.cache/dracula_os_theme/ ───
_log_dir() {
    local dir="$HOME/.cache/dracula_os_theme"
    mkdir -p "$dir"
    echo "$dir"
}

# Retorna caminho de arquivo de log com timestamp; chamador redireciona via | tee -a
_log_file() {
    local nome="${1:-operacao}"
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    echo "$(_log_dir)/${nome}_${ts}.log"
}

# ─── Validação de path destrutivo (SPRINT_08) ───
# Antes de qualquer `rm -rf`, chamar `validar_path_destrutivo "$path"`.
# Aborta o script se o path NÃO é prefixado por um dos diretórios permitidos.
# Defesa contra variáveis corrompidas que poderiam levar a `rm -rf /` ou `/home`.
_allowlist_destrutiva=(
    "$HOME/.local/share/icons"
    "$HOME/.local/share/themes"
    "$HOME/.local/share/applications"
    "$HOME/.local/share/sounds"
    "$HOME/.local/share/gnome-shell/extensions"
    "$HOME/.icons"
    "$HOME/.themes"
    "$HOME/.cache/dracula_os_theme"
    "$HOME/.cache/dracula_os_backup"
    "/usr/share/icons"
    "/usr/share/themes"
    "/usr/share/sounds"
    "/usr/share/gnome-shell/extensions"
    "/tmp/dracula_os_theme"
)

validar_path_destrutivo() {
    local alvo="${1:-}"
    if [[ -z "$alvo" ]]; then
        _err "validar_path_destrutivo: argumento vazio"
        return 2
    fi
    # Resolve path absoluto sem seguir symlinks (readlink -m é mais robusto que realpath)
    local absoluto
    absoluto="$(readlink -m "$alvo" 2>/dev/null || echo "$alvo")"
    # Rejeita paths raiz e home puro
    case "$absoluto" in
        /|/home|/home/*"/"|"$HOME"|"$HOME/")
            _err "validar_path_destrutivo: path proibido: '$absoluto'"
            return 1
            ;;
    esac
    local permitido
    for permitido in "${_allowlist_destrutiva[@]}"; do
        # Match se absoluto começa com permitido/ ou é exatamente permitido
        if [[ "$absoluto" == "$permitido" || "$absoluto" == "$permitido/"* ]]; then
            return 0
        fi
    done
    _err "validar_path_destrutivo: '$absoluto' fora da allowlist."
    _err "Allowlist: ${_allowlist_destrutiva[*]}"
    return 1
}

# ─── Trap de cleanup (SPRINT_08) ───
# Uso:
#   _cleanup_meu_script() { echo "limpando..."; }
#   trap_cleanup_init _cleanup_meu_script
_CLEANUP_FN=""
_trap_cleanup_runner() {
    local exit_code=$?
    if [[ -n "$_CLEANUP_FN" ]] && declare -F "$_CLEANUP_FN" >/dev/null; then
        "$_CLEANUP_FN" "$exit_code" || true
    fi
    return $exit_code
}
trap_cleanup_init() {
    _CLEANUP_FN="${1:-}"
    trap '_trap_cleanup_runner' EXIT INT TERM
}

# ─── Backup com manifest sha256 (SPRINT_08) ───
# Copia origem para destino e gera manifest sha256 para validação.
# Retorna 0 se e somente se todos os hashes batem após a cópia.
# Uso:
#   backup_com_manifest "$alvo" "$backup_dir" || { _err "backup falhou"; exit 1; }
backup_com_manifest() {
    local origem="${1:-}" destino_dir="${2:-}"
    [[ -z "$origem" || -z "$destino_dir" ]] && { _err "backup_com_manifest: args <origem> <destino_dir>"; return 2; }
    [[ ! -e "$origem" ]] && { _err "backup_com_manifest: origem não existe: $origem"; return 2; }

    mkdir -p "$destino_dir"
    local nome
    nome="$(basename "$origem")"
    local manifest="$destino_dir/${nome}.sha256"

    # Gera manifest da origem
    if [[ -d "$origem" ]]; then
        (cd "$(dirname "$origem")" && find "$nome" -type f -exec sha256sum {} +) > "$manifest" 2>/dev/null
        cp -r "$origem" "$destino_dir/" || { _err "backup_com_manifest: cp falhou"; return 1; }
    else
        (cd "$(dirname "$origem")" && sha256sum "$nome") > "$manifest" 2>/dev/null
        cp "$origem" "$destino_dir/" || { _err "backup_com_manifest: cp falhou"; return 1; }
    fi

    # Valida manifest contra a cópia
    if ! (cd "$destino_dir" && sha256sum -c "${nome}.sha256") >/dev/null 2>&1; then
        _err "backup_com_manifest: checksum FALHOU em $destino_dir — cópia inconsistente"
        return 1
    fi
    return 0
}

# "Nosce te ipsum." -- conhece-te a ti mesmo.
