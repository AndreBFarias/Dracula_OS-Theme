#!/usr/bin/env bash
# instalar_apt_hook.sh — instala/remove hook APT que dispara reaplicar_tema.sh
# automaticamente após apt install/upgrade/full-upgrade.
#
# Uso:
#   sudo ./scripts/instalar_apt_hook.sh install   # instala o hook
#   sudo ./scripts/instalar_apt_hook.sh --revert  # remove o hook
#
# O hook é portátil: usa ${SUDO_USER:-$USER} para detectar o user real
# (nunca hardcoded). O caminho do repo também é resolvido dinamicamente.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

REPO_ROOT="$(_repo_root "${BASH_SOURCE[0]}")"
HOOK_FILE="/etc/apt/apt.conf.d/99-dracula-os-theme"
LOG_SYSTEM="/var/log/dracula-theme-reaplicar.log"

if [[ $EUID -ne 0 ]]; then
    _err "Requer sudo: sudo $0 $*"
    exit 1
fi

# Detecta user real (quem rodou sudo)
USER_REAL="${SUDO_USER:-${USER:-}}"
if [[ -z "$USER_REAL" || "$USER_REAL" == "root" ]]; then
    _err "Não foi possível detectar o user original (SUDO_USER vazio). Abortando."
    _err "Rode com: sudo -E $0 $*"
    exit 1
fi

USER_HOME="$(getent passwd "$USER_REAL" | cut -d: -f6)"
if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
    _err "Home do user '$USER_REAL' não encontrado."
    exit 1
fi

MODO="${1:-install}"
case "$MODO" in
    --revert|revert|uninstall)
        if [[ -f "$HOOK_FILE" ]]; then
            rm -f "$HOOK_FILE"
            _ok "Hook APT removido: $HOOK_FILE"
        else
            _warn "Hook APT não estava instalado."
        fi
        exit 0
        ;;
    install|--install) ;;
    *)
        echo "Uso: sudo $0 install | --revert"
        exit 1
        ;;
esac

# ─── Lista de pacotes que disparam a reaplicação ───
# Qualquer pacote cujo nome comece com esses prefixos gatilhará o hook.
# Demais operações APT (ex.: instalar htop) não rodam o reaplicar — economia de tempo.
PACOTES_GATILHO=(
    "pop-shell"
    "pop-cosmic"
    "gnome-shell"
    "gnome-shell-extension"
    "mutter"
    "libgtk-3"
    "libgtk-4"
    "kitty"
    "qbittorrent"
    "gnome-terminal"
)

# Regex metadado para futura evolução (Pre-Invoke filter):
# ^(pop-shell|pop-cosmic|gnome-shell|...)
# Hoje o hook é sempre-disparado (reaplicar_tema.sh é idempotente).

SCRIPT_ALVO="$REPO_ROOT/scripts/reaplicar_tema.sh"

if [[ ! -x "$SCRIPT_ALVO" ]]; then
    _err "reaplicar_tema.sh não existe ou não é executável: $SCRIPT_ALVO"
    exit 1
fi

# O hook recebe a lista de pacotes afetados em /var/cache/apt/term.log não é confiável.
# A forma canônica é ler dpkg --get-selections ou usar DPkg::Post-Invoke-Success.
# Aqui optamos por DPkg::Post-Invoke (roda sempre, mesmo em falha parcial) e filtramos
# inspecionando os nomes de pacote via variável APT_PACKAGES (fornecida por DPkg::Pre-Invoke
# em sistemas modernos) OU por fallback simples: sempre chama o reaplicar (idempotente).
#
# Decisão: chamar sempre. O reaplicar_tema.sh é idempotente e barato (~1-2s quando nada
# regrediu). Filtrar por pacote exige DPkg::Pre-Invoke para capturar lista, complexo.
# Se no futuro o custo incomodar, trocar para lógica condicional via Pre-Invoke.

cat > "$HOOK_FILE" <<EOF
// Dracula_OS-Theme — reaplicação automática pós apt upgrade
// Gerado por instalar_apt_hook.sh em $(date -Iseconds)
// User: $USER_REAL
// Script: $SCRIPT_ALVO
// Remover: sudo $SCRIPT_DIR/instalar_apt_hook.sh --revert

DPkg::Post-Invoke {
    "test -x $SCRIPT_ALVO && su - $USER_REAL -c '$SCRIPT_ALVO' >> $LOG_SYSTEM 2>&1 || true";
};
EOF

chmod 644 "$HOOK_FILE"
touch "$LOG_SYSTEM"
chmod 644 "$LOG_SYSTEM"

_ok "Hook APT instalado: $HOOK_FILE"
_info "Disparará em todo apt install/upgrade/full-upgrade."
_info "Log sistêmico: $LOG_SYSTEM"
_info "Pacotes gatilho configurados (metadados): ${PACOTES_GATILHO[*]}"
_dim "Para remover: sudo $0 --revert"

# "Quis custodiet ipsos custodes?" -- quem vigia os vigilantes? O hook APT, claro.
