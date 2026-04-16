#!/usr/bin/env bash
# release.sh — gera tarball versionado do Dracula_OS-Theme para distribuição
#
# Uso:
#   ./scripts/release.sh [versão]    # default: 1.0.0

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSAO="${1:-1.0.0}"
NOME="Dracula_OS-Theme-v${VERSAO}"
TMP=$(mktemp -d)
DIST_DIR="$REPO_ROOT/releases"

C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_RESET='\033[0m'

_info() { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()   { echo -e "  ${C_GREEN}OK${C_RESET} $*"; }

mkdir -p "$DIST_DIR"

_info "Montando $NOME em $TMP/"

# Copiar tudo exceto dist/, .git/, backups, upstreams (usuário baixa separado)
rsync -a \
    --exclude='.git/' \
    --exclude='dist/' \
    --exclude='releases/' \
    --exclude='*_backup_*/' \
    --exclude='*.pyc' \
    --exclude='__pycache__/' \
    --exclude='src/icons/upstream/' \
    "$REPO_ROOT/" "$TMP/$NOME/"

# Garantir que a nota de upstreams está no tarball
cat > "$TMP/$NOME/UPSTREAMS.md" <<EOF
# Upstreams

Os upstreams \`dracula-icons-main\` e \`dracula-icons-circle\` não estão
incluídos neste tarball para manter o tamanho reduzido. Após extrair,
rode:

    cd $NOME
    ./scripts/baixar_upstreams.sh

Isso clona os dois repositórios upstream em \`src/icons/upstream/\`.

Em seguida, \`./build.sh\` e \`./install.sh --user\` funcionam normalmente.
EOF

_info "Gerando ${NOME}.tar.gz"
cd "$TMP"
tar czf "$DIST_DIR/${NOME}.tar.gz" "$NOME/"
cd - >/dev/null

# Checksum
cd "$DIST_DIR"
sha256sum "${NOME}.tar.gz" > "${NOME}.tar.gz.sha256"
cd - >/dev/null

# Cleanup
rm -rf "$TMP"

_ok "Release criado: $DIST_DIR/${NOME}.tar.gz"
_ok "Checksum:       $DIST_DIR/${NOME}.tar.gz.sha256"
ls -la "$DIST_DIR"/${NOME}*

# "Finis coronat opus." -- o fim coroa a obra.
