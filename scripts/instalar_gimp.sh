#!/usr/bin/env bash
# instalar_gimp.sh — instalador autônomo do GIMP (Flatpak) + PhotoGIMP para o
# Dracula_OS-Theme. Garante o remote flathub, instala/atualiza org.gimp.GIMP,
# detecta a versão-dir de config ATIVA do GIMP (host com override
# xdg-config/GIMP OU sandbox do Flatpak), faz backup com manifest sha256 e
# aplica o PhotoGIMP (layout/atalhos estilo Photoshop + splash + launcher
# próprio). Idempotente. Sem sudo. (SPRINT 20)
#
# Observação: o `flatpak update` no passo de instalação também preempta o
# relink de runtime pendente que fazia o PRIMEIRO start do GIMP parecer
# "não abrir" (o launcher esperava o relink concluir antes de aparecer).
#
# Variáveis:
#   DRACULA_DRY_RUN=1   imprime comandos com prefixo [dry-run]; não baixa,
#                       não instala flatpak nem sobrescreve config.
#
# Flags:
#   --apenas-detectar   imprime estado do GIMP flatpak + versão-dir de config
#                       ativa e sai (exit 0). Não altera nada.
#   --skip-photogimp    instala/atualiza só o GIMP; não aplica o PhotoGIMP.
#   --help|-h           mostra esta ajuda.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# --- PhotoGIMP fixado (reprodutibilidade sha256-aware) ---
PHOTOGIMP_TAG="3.0"
PHOTOGIMP_URL="https://github.com/Diolinux/PhotoGIMP/releases/download/${PHOTOGIMP_TAG}/PhotoGIMP-linux.zip"
PHOTOGIMP_SHA256="1af6e2a6308bbc0fb716a7dbbd68036adbcc091da16432869c7c6c6aef18e54e"
PHOTOGIMP_ZIP="$HOME/.cache/dracula_os_theme/PhotoGIMP-linux-${PHOTOGIMP_TAG}.zip"

GIMP_APP="org.gimp.GIMP"
BACKUP_BASE="$HOME/.cache/dracula_os_backup"

DRY="${DRACULA_DRY_RUN:-0}"

# --- Flags ---
APENAS_DETECTAR=0
SKIP_PHOTOGIMP=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apenas-detectar) APENAS_DETECTAR=1; shift ;;
        --skip-photogimp)  SKIP_PHOTOGIMP=1; shift ;;
        --help|-h)
            cat <<'EOF'
Uso: instalar_gimp.sh [--apenas-detectar] [--skip-photogimp]

Instala o GIMP (Flatpak/flathub) e aplica o PhotoGIMP (layout estilo
Photoshop + atalhos + splash + launcher próprio). Idempotente, sem sudo.

Flags:
  --apenas-detectar   imprime estado do GIMP + versão-dir de config e sai.
  --skip-photogimp    instala/atualiza só o GIMP, sem aplicar o PhotoGIMP.

Variáveis:
  DRACULA_DRY_RUN=1   apenas loga; não baixa, instala ou sobrescreve nada.
EOF
            exit 0 ;;
        *) _warn "Argumento ignorado: $1"; shift ;;
    esac
done

# --- Cleanup do diretório temporário (sob /tmp/dracula_os_theme, allowlisted) ---
_TMP_PG=""
_cleanup_gimp() {
    [[ -n "$_TMP_PG" && -d "$_TMP_PG" ]] || return 0
    if validar_path_destrutivo "$_TMP_PG" >/dev/null 2>&1; then
        rm -rf -- "$_TMP_PG" 2>/dev/null || true
    fi
}
trap_cleanup_init _cleanup_gimp

# --- Detecção ---
_detectar_gimp_flatpak() {
    command -v flatpak >/dev/null 2>&1 || return 1
    flatpak list --app --columns=application 2>/dev/null | grep -qx "$GIMP_APP"
}

# Imprime a versão do GIMP Flatpak instalada (ou '?' se indisponível).
_gimp_versao() {
    flatpak list --app --columns=application,version 2>/dev/null \
        | awk -F'\t' -v app="$GIMP_APP" '$1==app{print $2; exit}' \
        | grep . || echo '?'
}

# Imprime a versão-dir de config ATIVA do GIMP (maior 3.* existente).
# Prioriza host (~/.config/GIMP — caso do override xdg-config/GIMP deste
# sistema); cai para o sandbox do Flatpak. Sem match → exit 1 (sem stdout).
_gimp_config_dir() {
    local d
    d="$(ls -d "$HOME"/.config/GIMP/3.* 2>/dev/null | sort -V | tail -1 || true)"
    [[ -n "$d" && -d "$d" ]] && { printf '%s\n' "$d"; return 0; }
    d="$(ls -d "$HOME"/.var/app/"$GIMP_APP"/config/GIMP/3.* 2>/dev/null | sort -V | tail -1 || true)"
    [[ -n "$d" && -d "$d" ]] && { printf '%s\n' "$d"; return 0; }
    return 1
}

# --- Passo 1: garantir flathub + instalar/atualizar GIMP ---
instalar_gimp_flatpak() {
    if ! command -v flatpak >/dev/null 2>&1; then
        _err "flatpak não encontrado. Instale o flatpak (ex.: sudo apt install flatpak) e rode novamente."
        return 1
    fi
    if [[ "$DRY" == "1" ]]; then
        _dim "[dry-run] flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo"
        if _detectar_gimp_flatpak; then
            _dim "[dry-run] GIMP já instalado → flatpak update -y --user $GIMP_APP"
        else
            _dim "[dry-run] flatpak install -y --user flathub $GIMP_APP"
        fi
        return 0
    fi
    flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    if _detectar_gimp_flatpak; then
        local ver
        ver="$(_gimp_versao)"
        _ok "GIMP já instalado (Flatpak v${ver})"
        _info "Atualizando GIMP (preempta o relink de runtime do 1º start)"
        flatpak update -y --user "$GIMP_APP" 2>/dev/null || _warn "flatpak update falhou (não-fatal)"
    else
        _info "Instalando GIMP via Flatpak (flathub)…"
        flatpak install -y --user flathub "$GIMP_APP" || { _err "flatpak install do GIMP falhou"; return 1; }
        _ok "GIMP instalado"
    fi
    return 0
}

# --- Passo 2: baixar PhotoGIMP (cache + sha256) ---
baixar_photogimp() {
    mkdir -p "$(dirname "$PHOTOGIMP_ZIP")"
    if [[ -f "$PHOTOGIMP_ZIP" ]] && echo "$PHOTOGIMP_SHA256  $PHOTOGIMP_ZIP" | sha256sum -c - >/dev/null 2>&1; then
        _ok "PhotoGIMP já em cache (sha256 confere)"
        return 0
    fi
    if [[ "$DRY" == "1" ]]; then
        _dim "[dry-run] curl -fsSL -o $PHOTOGIMP_ZIP $PHOTOGIMP_URL"
        _dim "[dry-run] sha256sum -c (esperado $PHOTOGIMP_SHA256)"
        return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        _err "curl não encontrado; impossível baixar o PhotoGIMP."
        return 1
    fi
    _info "Baixando PhotoGIMP ${PHOTOGIMP_TAG} (~2 MB)…"
    curl -fsSL -o "$PHOTOGIMP_ZIP" "$PHOTOGIMP_URL" || { _err "download do PhotoGIMP falhou"; return 1; }
    if ! echo "$PHOTOGIMP_SHA256  $PHOTOGIMP_ZIP" | sha256sum -c - >/dev/null 2>&1; then
        _err "sha256 do PhotoGIMP NÃO confere — abortando para não aplicar artefato adulterado"
        rm -f -- "$PHOTOGIMP_ZIP"
        return 1
    fi
    _ok "PhotoGIMP baixado (sha256 confere)"
    return 0
}

# --- Passo 3: aplicar PhotoGIMP na versão-dir ativa ---
aplicar_photogimp() {
    if ! command -v unzip >/dev/null 2>&1; then
        _err "unzip não encontrado; impossível extrair o PhotoGIMP."
        return 1
    fi
    local cfg_dir
    cfg_dir="$(_gimp_config_dir || true)"

    if [[ "$DRY" == "1" ]]; then
        _dim "[dry-run] config alvo: ${cfg_dir:-<detectada/criada em runtime>}"
        _dim "[dry-run] backup_com_manifest \$cfg $BACKUP_BASE/gimp_<ts> + _purgar_antigos 10"
        _dim "[dry-run] unzip $PHOTOGIMP_ZIP → cp .config/GIMP/3.0/* → \$cfg"
        _dim "[dry-run] cp .local/share/* (launcher org.gimp.GIMP.desktop + ícones photogimp) → ~/.local/share"
        _dim "[dry-run] update-desktop-database + gtk-update-icon-cache"
        return 0
    fi

    # Fresh: nenhuma config existe → inicializa headless e redetecta.
    if [[ -z "$cfg_dir" ]]; then
        _info "Config do GIMP ainda não existe; inicializando headless…"
        timeout 90 flatpak run "$GIMP_APP" -i --quit >/dev/null 2>&1 || true
        cfg_dir="$(_gimp_config_dir || true)"
    fi
    if [[ -z "$cfg_dir" ]]; then
        _warn "Não localizei a config do GIMP. Abra o GIMP uma vez e rode novamente para aplicar o PhotoGIMP."
        return 0
    fi
    _info "Config ativa do GIMP: $cfg_dir"

    # Se o GIMP estiver aberto, ao fechá-lo ele reescreve a config e desfaz o
    # PhotoGIMP. Avisa (sem matar — evita perda de trabalho não salvo).
    # Usa `flatpak ps` (preciso) em vez de pgrep -f (casaria a própria string).
    if flatpak ps --columns=application 2>/dev/null | grep -qx "$GIMP_APP"; then
        _warn "GIMP parece estar aberto. Feche-o e reabra para o PhotoGIMP valer (ao sair, o GIMP sobrescreve a config)."
    fi

    # Backup com manifest sha256 antes de sobrescrever
    local ts backup_dir
    ts="$(date +%Y%m%d_%H%M%S)"
    backup_dir="$BACKUP_BASE/gimp_${ts}"
    if backup_com_manifest "$cfg_dir" "$backup_dir"; then
        _ok "Backup da config em $backup_dir"
        _purgar_antigos "$BACKUP_BASE/gimp_*" 10
    else
        _err "Backup da config do GIMP falhou — abortando aplicação do PhotoGIMP"
        return 1
    fi

    # Extrair em diretório temporário allowlisted e aplicar
    mkdir -p /tmp/dracula_os_theme
    _TMP_PG="$(mktemp -d /tmp/dracula_os_theme/photogimp.XXXXXX)"
    unzip -o -q "$PHOTOGIMP_ZIP" -d "$_TMP_PG" || { _err "unzip do PhotoGIMP falhou"; return 1; }
    local src="$_TMP_PG/PhotoGIMP-linux"
    [[ -d "$src/.config/GIMP/3.0" ]] || { _err "payload inesperado: $src/.config/GIMP/3.0 ausente"; return 1; }
    # Remove sujeira do macOS antes de copiar
    find "$src" -name '.DS_Store' -delete 2>/dev/null || true

    _info "Aplicando config PhotoGIMP em $cfg_dir"
    cp -rT "$src/.config/GIMP/3.0" "$cfg_dir"

    _info "Instalando launcher + ícones PhotoGIMP"
    mkdir -p "$HOME/.local/share"
    cp -rT "$src/.local/share" "$HOME/.local/share"

    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

    _ok "PhotoGIMP aplicado (launcher 'PhotoGIMP' + layout/atalhos/splash)"
    return 0
}

# --- Main ---
if [[ $APENAS_DETECTAR -eq 1 ]]; then
    if _detectar_gimp_flatpak; then
        echo "gimp_flatpak=sim ($(_gimp_versao))"
    else
        echo "gimp_flatpak=nao"
    fi
    if d="$(_gimp_config_dir)"; then echo "config_dir=$d"; else echo "config_dir=nenhum"; fi
    exit 0
fi

_dim "Dracula_OS-Theme — GIMP + PhotoGIMP"
instalar_gimp_flatpak || { _err "Falha ao garantir o GIMP"; exit 1; }

if [[ $SKIP_PHOTOGIMP -eq 1 ]]; then
    _ok "GIMP pronto (PhotoGIMP pulado por --skip-photogimp)"
    exit 0
fi

baixar_photogimp || { _warn "PhotoGIMP não baixado; GIMP segue instalado."; exit 0; }
aplicar_photogimp

echo ""
_ok "GIMP + PhotoGIMP concluído"

# "Pictura est laborum dulce lenimen." -- a pintura é o doce alívio das fadigas.
