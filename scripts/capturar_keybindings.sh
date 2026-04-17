#!/usr/bin/env bash
# capturar_keybindings.sh — snapshot dos atalhos do usuário em app-themes/keybindings/
#
# Os arquivos .dconf gerados por este script são o que `instalar_keybindings.sh`
# aplica em um PC novo. Rode sempre que alterar seus atalhos e quiser que a
# próxima reinstalação restaure o novo conjunto.
#
# Uso:
#   ./scripts/capturar_keybindings.sh          # sobrescreve snapshots

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$REPO_ROOT/app-themes/keybindings"

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RESET='\033[0m'

_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }
_skip() { echo -e "  ${C_YELLOW}--${C_RESET} $*"; }

mkdir -p "$DIR"

# Namespaces dconf e seus arquivos de destino
declare -A NAMESPACES=(
    ["/org/gnome/settings-daemon/plugins/media-keys/"]="media-keys.dconf"
    ["/org/gnome/desktop/wm/keybindings/"]="wm-keybindings.dconf"
    ["/org/gnome/terminal/legacy/keybindings/"]="terminal.dconf"
)

_info "Capturando snapshots em $DIR/"
for path in "${!NAMESPACES[@]}"; do
    arquivo="${NAMESPACES[$path]}"
    destino="$DIR/$arquivo"
    raw=$(dconf dump "$path" 2>/dev/null)
    if [[ -z "$raw" || "$raw" == $'[/]\n' ]]; then
        rm -f "$destino"
        _skip "$arquivo (sem customização — removido)"
        continue
    fi
    echo "$raw" > "$destino"
    _ok "$arquivo ($(wc -l < "$destino") linhas)"
done

# Desativação do som do PrintScreen fica em arquivo separado
# para permitir desativar sem mexer nos atalhos
cat > "$DIR/sound.dconf" <<'EOF'
[/]
event-sounds=false
EOF
_ok "sound.dconf (desativa som do shutter + notificações)"

# "O que pode ser feito a qualquer momento nunca é feito." -- Voltaire
