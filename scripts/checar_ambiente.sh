#!/usr/bin/env bash
# checar_ambiente.sh — doctor de pré-requisitos para rodar o Dracula_OS-Theme.
#
# Verifica binários, versões e compatibilidade de ambiente. Read-only (não
# instala nada). Para cada dependência faltante imprime o comando apt para
# instalar, pronto para copiar.
#
# Uso:
#   ./scripts/checar_ambiente.sh              # output colorido
#   ./scripts/checar_ambiente.sh --quiet      # só exit code
#
# Exit 0 = ambiente OK para build+install. 1 = dependências faltantes ou
# versão incompatível.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

QUIET=0
for arg in "$@"; do
    [[ "$arg" == "--quiet" ]] && QUIET=1
done

faltantes=()         # binários que faltam completamente
versoes_baixas=()    # binários presentes mas versão insuficiente
avisos=()            # não-fatal

# Mapeia binário → pacote apt
declare -A PACOTE_APT=(
    [bash]="bash"
    [python3]="python3"
    [jq]="jq"
    [gtk-update-icon-cache]="libgtk-3-bin"
    [dconf]="dconf-cli"
    [gsettings]="libglib2.0-bin"
    [gnome-extensions]="gnome-shell-extension-prefs"
    [rsvg-convert]="librsvg2-bin"
    [inkscape]="inkscape"
    [magick]="imagemagick"
    [convert]="imagemagick"
    [git]="git"
    [curl]="curl"
    [unzip]="unzip"
    [sha256sum]="coreutils"
    [readlink]="coreutils"
)

check_bin() {
    local bin="$1" critico="${2:-1}"
    if command -v "$bin" &>/dev/null; then
        [[ $QUIET -eq 0 ]] && _ok "$bin presente ($(command -v "$bin"))"
        return 0
    fi
    if [[ $critico -eq 1 ]]; then
        faltantes+=("$bin")
        [[ $QUIET -eq 0 ]] && _err "$bin ausente"
    else
        avisos+=("$bin")
        [[ $QUIET -eq 0 ]] && _warn "$bin ausente (opcional)"
    fi
    return 1
}

[[ $QUIET -eq 0 ]] && _dim "=== Dracula_OS-Theme — checar ambiente ==="

# ─── Core ───
check_bin bash
check_bin python3
check_bin jq
check_bin gtk-update-icon-cache
check_bin dconf
check_bin gsettings
check_bin git
check_bin curl
check_bin unzip
check_bin sha256sum
check_bin readlink

# ─── GNOME / Pop!_OS ───
check_bin gnome-extensions

# ─── Pelo menos um conversor SVG → PNG ───
conversor_ok=0
for bin in rsvg-convert inkscape magick convert; do
    if command -v "$bin" &>/dev/null; then
        conversor_ok=1
        [[ $QUIET -eq 0 ]] && _ok "Conversor SVG→PNG disponível: $bin"
        break
    fi
done
if [[ $conversor_ok -eq 0 ]]; then
    faltantes+=("rsvg-convert")
    [[ $QUIET -eq 0 ]] && _err "Nenhum conversor SVG→PNG encontrado (rsvg-convert, inkscape, imagemagick)"
fi

# ─── Versão Python >= 3.10 ───
if command -v python3 &>/dev/null; then
    py_ver="$(python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")' 2>/dev/null || echo "0.0")"
    py_major="${py_ver%%.*}"
    py_minor="${py_ver##*.}"
    if [[ $py_major -lt 3 ]] || [[ $py_major -eq 3 && $py_minor -lt 10 ]]; then
        versoes_baixas+=("python3 (atual: $py_ver, requer >= 3.10)")
        [[ $QUIET -eq 0 ]] && _err "python3 versão $py_ver < 3.10"
    else
        [[ $QUIET -eq 0 ]] && _ok "python3 versão $py_ver"
    fi
fi

# ─── Versão GNOME Shell ───
if command -v gnome-shell &>/dev/null; then
    shell_ver="$(gnome-shell --version 2>/dev/null | awk '{print $3}')"
    shell_major="${shell_ver%%.*}"
    if [[ -n "$shell_major" ]] && [[ "$shell_major" =~ ^[0-9]+$ ]]; then
        if [[ $shell_major -lt 42 ]]; then
            versoes_baixas+=("gnome-shell (atual: $shell_ver, requer >= 42)")
            [[ $QUIET -eq 0 ]] && _err "GNOME Shell $shell_ver < 42"
        else
            [[ $QUIET -eq 0 ]] && _ok "GNOME Shell $shell_ver"
        fi
    fi
else
    avisos+=("gnome-shell")
    [[ $QUIET -eq 0 ]] && _warn "gnome-shell não encontrado — você pode estar em COSMIC"
fi

# ─── Distribuição Pop!_OS ───
if command -v lsb_release &>/dev/null; then
    distro="$(lsb_release -si 2>/dev/null || echo '?')"
    release="$(lsb_release -sr 2>/dev/null || echo '?')"
    if [[ "$distro" != "Pop" ]]; then
        avisos+=("distro-nao-pop")
        [[ $QUIET -eq 0 ]] && _warn "Distribuição: $distro $release (testado em Pop!_OS 22.04+)"
    else
        case "$release" in
            22.04|24.04) [[ $QUIET -eq 0 ]] && _ok "Pop!_OS $release suportado" ;;
            *) [[ $QUIET -eq 0 ]] && _warn "Pop!_OS $release não testado (esperado 22.04 ou 24.04)" ;;
        esac
    fi
fi

# ─── Detecção de sessão/desktop ───
desktop="${XDG_CURRENT_DESKTOP:-}"
[[ $QUIET -eq 0 ]] && _dim "Desktop atual: ${desktop:-desconhecido}"

# ─── Relatório ───
echo ""
problemas=0

if [[ ${#faltantes[@]} -gt 0 ]]; then
    problemas=$((problemas + ${#faltantes[@]}))
    [[ $QUIET -eq 0 ]] && _err "Binários ausentes (críticos):"
    pacotes_apt=()
    for bin in "${faltantes[@]}"; do
        pkg="${PACOTE_APT[$bin]:-$bin}"
        # Evita duplicata
        ja_listado=0
        for existente in "${pacotes_apt[@]}"; do
            [[ "$existente" == "$pkg" ]] && ja_listado=1
        done
        [[ $ja_listado -eq 0 ]] && pacotes_apt+=("$pkg")
    done
    [[ $QUIET -eq 0 ]] && echo -e "  ${C_CYAN}sudo apt install ${pacotes_apt[*]}${C_RESET}"
fi

if [[ ${#versoes_baixas[@]} -gt 0 ]]; then
    problemas=$((problemas + ${#versoes_baixas[@]}))
    [[ $QUIET -eq 0 ]] && _err "Versões insuficientes:"
    [[ $QUIET -eq 0 ]] && for v in "${versoes_baixas[@]}"; do echo "    - $v"; done
fi

if [[ ${#avisos[@]} -gt 0 && $QUIET -eq 0 ]]; then
    _warn "Avisos não-fatais:"
    for a in "${avisos[@]}"; do echo "    - $a"; done
fi

if [[ $problemas -eq 0 ]]; then
    [[ $QUIET -eq 0 ]] && _ok "Ambiente OK para build + install."
    exit 0
else
    [[ $QUIET -eq 0 ]] && _err "$problemas problemas críticos — corrija antes de rodar ./build.sh"
    exit 1
fi

# "Non est ad astra mollis e terris via." -- não há caminho fácil da terra às estrelas.
