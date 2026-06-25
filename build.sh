#!/usr/bin/env bash
# build.sh — pipeline de build do Dracula_OS-Theme
# Lê mapping.json e gera o tema completo em dist/

set -euo pipefail

# ─── Paths ───
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_ROOT/src"
DIST="$REPO_ROOT/dist"
MAPPING="$REPO_ROOT/mapping.json"

# ─── Constantes ───
TEMA_ICONES="Dracula-Icones"
TEMA_CURSOR="Dracula-Cursor"
TEMA_GTK="Dracula-standard-buttons"
TAMANHOS=(16 22 24 32 48 64 128 256)

# ─── Cores para saída ───
C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'
C_DIM='\033[2m'
C_RESET='\033[0m'

_info()  { echo -e "  ${C_CYAN}>>${C_RESET} $*"; }
_ok()    { echo -e "  ${C_GREEN}OK${C_RESET}  $*"; }
_warn()  { echo -e "  ${C_YELLOW}!!${C_RESET} $*" >&2; }
_err()   { echo -e "  ${C_RED}ERRO${C_RESET} $*" >&2; exit 1; }

# ─── Detectar conversor SVG→PNG ───
CONVERSOR=""
MAGICK_CMD=""
if command -v rsvg-convert &>/dev/null; then
    CONVERSOR="rsvg-convert"
elif command -v inkscape &>/dev/null; then
    CONVERSOR="inkscape"
elif command -v magick &>/dev/null; then
    # ImageMagick 7
    CONVERSOR="magick"
    MAGICK_CMD="magick"
elif command -v convert &>/dev/null; then
    # ImageMagick 6
    CONVERSOR="magick"
    MAGICK_CMD="convert"
else
    _err "Nenhum conversor SVG→PNG encontrado. Instale librsvg2-bin, inkscape ou imagemagick."
fi

# Gera PNG em tamanho N a partir do SVG
converter_svg() {
    local svg="$1" out="$2" size="$3"
    case "$CONVERSOR" in
        rsvg-convert)
            rsvg-convert -w "$size" -h "$size" -o "$out" "$svg" 2>/dev/null
            ;;
        inkscape)
            inkscape "$svg" --export-type=png --export-filename="$out" \
                --export-width="$size" --export-height="$size" 2>/dev/null >/dev/null
            ;;
        magick)
            "$MAGICK_CMD" -background none -resize "${size}x${size}" "$svg" "$out" 2>/dev/null
            ;;
    esac
    # Valida resultado
    if [[ ! -s "$out" ]] || [[ $(stat -c%s "$out") -lt 100 ]]; then
        return 1
    fi
    return 0
}

# Redimensiona PNG existente para outro tamanho (usa mesmo binário magick)
redimensionar_png() {
    local src="$1" out="$2" size="$3"
    local cmd="${MAGICK_CMD:-convert}"
    "$cmd" "$src" -resize "${size}x${size}" "$out" 2>/dev/null
    [[ -s "$out" ]]
}

# ─── Fase A: Limpar dist/ ───
limpar_dist() {
    _info "Limpando $DIST/"
    rm -rf "$DIST"
    mkdir -p "$DIST"/{icons,themes,apps}
    _ok "dist/ limpo"
}

# ─── Fase B: Copiar upstreams ───
copiar_upstreams() {
    _info "Copiando upstreams (dracula-icons-main + dracula-icons-circle)"
    cp -r "$SRC/icons/upstream/dracula-icons-main" "$DIST/icons/"
    cp -r "$SRC/icons/upstream/dracula-icons-circle" "$DIST/icons/"
    _ok "upstreams copiados"
}

# ─── Fase C: Gerar tema Dracula-Icones a partir do mapping.json ───
gerar_tema_icones() {
    _info "Construindo $TEMA_ICONES a partir de mapping.json"

    local destino="$DIST/icons/$TEMA_ICONES"
    mkdir -p "$destino/scalable/apps"
    for size in "${TAMANHOS[@]}"; do
        mkdir -p "$destino/${size}x${size}/apps"
    done

    # Lê mapping.json e para cada entrada com fonte válida copia+gera
    local processados=0
    local ignorados=0
    local falhas=0

    # Desativa set -e dentro do loop para não abortar em uma falha isolada
    set +e
    # Processa cada app: lemos app_id, fonte, aliases_humanos e aliases (técnicos)
    while IFS=$'\t' read -r app_id fonte aliases_humanos aliases_tecnicos; do
        # Pular linhas vazias ou "null"
        if [[ -z "$app_id" || "$fonte" == "null" || "$fonte" == "None" ]]; then
            ignorados=$((ignorados + 1))
            continue
        fi

        local src_path="$SRC/icons/$fonte"
        if [[ "$fonte" == src/icons/* ]]; then
            src_path="$REPO_ROOT/$fonte"
        fi
        if [[ "$fonte" == /* ]]; then
            src_path="$fonte"
        fi

        if [[ ! -f "$src_path" ]]; then
            ignorados=$((ignorados + 1))
            continue
        fi

        local ext="${src_path##*.}"
        # Lista de nomes-alvo: app_id + aliases_humanos + aliases (técnicos),
        # deduplicados. Inclui os aliases técnicos para cobrir nomes como
        # org.gnome.Settings (o Icon= real do .desktop nativo) que não estão
        # em aliases_humanos — sem eles o ícone do app cai no fallback Adwaita.
        local -a alvos=("$app_id")
        local grupo extra a ja
        for grupo in "$aliases_humanos" "$aliases_tecnicos"; do
            [[ -z "$grupo" || "$grupo" == "null" ]] && continue
            IFS=',' read -ra extras <<< "$grupo"
            for extra in "${extras[@]}"; do
                [[ -z "$extra" ]] && continue
                ja=0
                for a in "${alvos[@]}"; do [[ "$a" == "$extra" ]] && { ja=1; break; }; done
                [[ $ja -eq 0 ]] && alvos+=("$extra")
            done
        done

        for nome_alvo in "${alvos[@]}"; do
            case "$ext" in
                svg|SVG)
                    cp "$src_path" "$destino/scalable/apps/$nome_alvo.svg"
                    for size in "${TAMANHOS[@]}"; do
                        if ! converter_svg "$src_path" "$destino/${size}x${size}/apps/$nome_alvo.png" "$size"; then
                            falhas=$((falhas + 1))
                        fi
                    done
                    ;;
                png|PNG)
                    for size in "${TAMANHOS[@]}"; do
                        if ! redimensionar_png "$src_path" "$destino/${size}x${size}/apps/$nome_alvo.png" "$size"; then
                            falhas=$((falhas + 1))
                        fi
                    done
                    cp "$src_path" "$destino/scalable/apps/$nome_alvo.png"
                    ;;
                jpg|jpeg|JPG|JPEG)
                    for size in "${TAMANHOS[@]}"; do
                        redimensionar_png "$src_path" "$destino/${size}x${size}/apps/$nome_alvo.png" "$size" || falhas=$((falhas + 1))
                    done
                    ;;
                *)
                    ignorados=$((ignorados + 1))
                    continue 2
                    ;;
            esac
        done
        processados=$((processados + 1))
    done < <(jq -r 'to_entries[] | "\(.key)\t\(.value.fonte)\t\(if .value.aliases_humanos then (.value.aliases_humanos | join(",")) else "" end)\t\(if .value.aliases then (.value.aliases | join(",")) else "" end)"' "$MAPPING")
    set -e

    _ok "Tema gerado: $processados apps processados, $ignorados ignorados, $falhas falhas de conversão"
}

# ─── Fase C2: Gerar mimetypes custom ───
# Mapeamento: mimetype → SVG-fonte em src/icons/new-sessao-atual/
# Cada mimetype pode ter multiplos nomes (aliases XDG).
gerar_mimetypes() {
    _info "Gerando mimetypes custom"
    local destino="$DIST/icons/$TEMA_ICONES"
    mkdir -p "$destino/scalable/mimetypes"
    for size in "${TAMANHOS[@]}"; do
        mkdir -p "$destino/${size}x${size}/mimetypes"
    done

    # formato: "fonte|nome1,nome2,nome3,..."
    # A fonte com "/" é relativa a src/icons/; sem "/" assume new-sessao-atual/.
    # Aceita SVG (converter_svg) ou PNG (redimensionar_png).
    # Os mimetypes de vídeo usam a logo do Clapper, para que arquivos de vídeo
    # exibam o mesmo ícone do player (decisão do usuário).
    local -a MIMETYPES=(
        "spellbook.svg|text-markdown,text-x-markdown,text-md,application-x-markdown,text-plain+markdown"
        "spell.svg|application-x-shellscript,shellscript,text-x-script,gnome-mime-application-x-shellscript,application-x-sh,text-x-sh"
        "gate.svg|application-x-desktop,gnome-mime-application-x-desktop"
        "current/48x48/apps-global/Clapper.png|video-x-generic,video-mp4,video-x-mp4,video-x-matroska,video-webm,video-quicktime,video-x-msvideo,video-x-flv,video-x-ms-wmv,application-mp4"
    )

    local total=0
    for entry in "${MIMETYPES[@]}"; do
        local fonte="${entry%%|*}"
        local nomes_csv="${entry#*|}"
        local src
        if [[ "$fonte" == */* ]]; then
            src="$SRC/icons/$fonte"
        else
            src="$SRC/icons/new-sessao-atual/$fonte"
        fi
        if [[ ! -f "$src" ]]; then
            _warn "mimetype: fonte não existe: $fonte"
            continue
        fi
        local ext="${src##*.}"
        IFS=',' read -ra nomes <<< "$nomes_csv"
        for nome in "${nomes[@]}"; do
            case "$ext" in
                svg|SVG)
                    cp "$src" "$destino/scalable/mimetypes/${nome}.svg"
                    for size in "${TAMANHOS[@]}"; do
                        converter_svg "$src" "$destino/${size}x${size}/mimetypes/${nome}.png" "$size" 2>/dev/null || true
                    done
                    ;;
                png|PNG)
                    cp "$src" "$destino/scalable/mimetypes/${nome}.png"
                    for size in "${TAMANHOS[@]}"; do
                        redimensionar_png "$src" "$destino/${size}x${size}/mimetypes/${nome}.png" "$size" 2>/dev/null || true
                    done
                    ;;
                *)
                    _warn "mimetype: extensão não suportada: $fonte"
                    continue
                    ;;
            esac
            total=$((total + 1))
        done
    done
    _ok "mimetypes gerados: $total nomes"
}

# ─── Fase C3: Propagar symbolic/* dos heritages ao Dracula-Icones ───
# Merge com prioridade dracula-icons-circle: para cada nome único em
# symbolic/<sub>, copia do circle se existir; senão do main.
# Resultado: lookup local de qualquer X-symbolic disponível nos heritages,
# sem depender de Inherits=.
# Subdirs efetivamente populadas são exportadas no array global
# SYMBOLIC_SUBDIRS_POPULADAS para gerar_index_theme() consumir.
SYMBOLIC_SUBDIRS_POPULADAS=()

gerar_symbolic_icons() {
    _info "Propagando symbolic icons dos heritages (prioridade: circle)"
    local destino_base="$DIST/icons/$TEMA_ICONES/symbolic"
    local fonte_circle="$SRC/icons/upstream/dracula-icons-circle/symbolic"
    local fonte_main="$SRC/icons/upstream/dracula-icons-main/symbolic"
    local subdirs=(actions apps categories devices emblems emotes mimetypes places status)
    local total_geral=0

    for sub in "${subdirs[@]}"; do
        local destino="$destino_base/$sub"
        local count_circle=0 count_main_only=0

        # Coletar nomes únicos (basename) das duas fontes.
        # Heritages contêm também "dangling symlinks" cujo target é o próprio
        # conteúdo SVG embutido (artefato do export upstream). Aceitamos arquivo
        # regular OU symlink; a cópia trata cada caso adequadamente.
        local -A nomes=()
        if [[ -d "$fonte_circle/$sub" ]]; then
            for svg in "$fonte_circle/$sub"/*.svg; do
                [[ -e "$svg" || -L "$svg" ]] || continue
                nomes["$(basename "$svg")"]="circle"
            done
        fi
        if [[ -d "$fonte_main/$sub" ]]; then
            for svg in "$fonte_main/$sub"/*.svg; do
                [[ -e "$svg" || -L "$svg" ]] || continue
                local n
                n="$(basename "$svg")"
                # circle vence; só seta main se ainda não tiver origem
                if [[ -z "${nomes[$n]:-}" ]]; then
                    nomes["$n"]="main"
                fi
            done
        fi

        local total=${#nomes[@]}
        if [[ $total -eq 0 ]]; then
            # Subdir vazia em ambos heritages — não criar e não declarar
            continue
        fi

        mkdir -p "$destino"
        for nome in "${!nomes[@]}"; do
            local origem="${nomes[$nome]}"
            local src_svg
            if [[ "$origem" == "circle" ]]; then
                src_svg="$fonte_circle/$sub/$nome"
                count_circle=$((count_circle + 1))
            else
                src_svg="$fonte_main/$sub/$nome"
                count_main_only=$((count_main_only + 1))
            fi
            # Symlink dangling com conteúdo SVG no próprio target → materializar
            # o conteúdo lendo o readlink. Arquivo regular → cp -p preserva mtime.
            if [[ -L "$src_svg" && ! -e "$src_svg" ]]; then
                readlink "$src_svg" > "$destino/$nome"
            else
                cp -p "$src_svg" "$destino/$nome"
            fi
        done

        SYMBOLIC_SUBDIRS_POPULADAS+=("symbolic/$sub")
        total_geral=$((total_geral + total))
        _ok "symbolic/$sub: $total ícones (circle=$count_circle, main-only=$count_main_only)"
    done

    _ok "symbolic propagado: ${#SYMBOLIC_SUBDIRS_POPULADAS[@]} subdirs, $total_geral SVGs"
}

# ─── Fase D: Gerar index.theme ───
gerar_index_theme() {
    _info "Gerando index.theme"
    local destino="$DIST/icons/$TEMA_ICONES"
    local dirs=("scalable/apps" "scalable/mimetypes")
    local blocos="[scalable/apps]
Size=48
Type=Scalable
MinSize=8
MaxSize=512
Context=Applications

[scalable/mimetypes]
Size=48
Type=Scalable
MinSize=8
MaxSize=512
Context=MimeTypes
"
    for size in "${TAMANHOS[@]}"; do
        dirs+=("${size}x${size}/apps" "${size}x${size}/mimetypes")
        blocos+="
[${size}x${size}/apps]
Size=${size}
Type=Fixed
Context=Applications

[${size}x${size}/mimetypes]
Size=${size}
Type=Fixed
Context=MimeTypes
"
    done

    # Após o loop de TAMANHOS, anexar symbolic/* populados (SPRINT 12)
    declare -A CONTEXT_SYMBOLIC=(
        [symbolic/actions]=Actions
        [symbolic/apps]=Applications
        [symbolic/categories]=Categories
        [symbolic/devices]=Devices
        [symbolic/emblems]=Emblems
        [symbolic/emotes]=Emotes
        [symbolic/mimetypes]=MimeTypes
        [symbolic/places]=Places
        [symbolic/status]=Status
    )

    for sub in "${SYMBOLIC_SUBDIRS_POPULADAS[@]}"; do
        local ctx="${CONTEXT_SYMBOLIC[$sub]:-}"
        if [[ -z "$ctx" ]]; then
            _warn "index.theme: Context desconhecido para $sub — pulando"
            continue
        fi
        dirs+=("$sub")
        blocos+="
[$sub]
Size=16
Type=Scalable
MinSize=8
MaxSize=512
Context=$ctx
"
    done

    # Junta directories separados por vírgula
    local dirs_str
    dirs_str=$(IFS=,; echo "${dirs[*]}")

    cat > "$destino/index.theme" <<EOF
[Icon Theme]
Name=${TEMA_ICONES}
Comment=Tema Dracula unificado — experiência gótica/fantasia
Inherits=dracula-icons-circle,dracula-icons-main,Adwaita,hicolor
Directories=${dirs_str}

${blocos}
EOF
    _ok "index.theme gerado"
}

# ─── Fase E: gtk-update-icon-cache em todos os 3 temas ───
atualizar_caches() {
    _info "Atualizando icon caches"
    for tema in "$TEMA_ICONES" "dracula-icons-main" "dracula-icons-circle"; do
        local dir="$DIST/icons/$tema"
        if [[ -f "$dir/index.theme" ]]; then
            gtk-update-icon-cache -f -t "$dir" 2>/dev/null \
                && _ok "cache: $tema" \
                || _warn "cache falhou: $tema"
        fi
    done
}

# ─── Fase F: Copiar cursor, GTK, shell ───
copiar_cursor_gtk_shell() {
    # Cursor — se src/cursors/ vazio, usa /usr/share/icons/Dracula-Cursor como base
    if [[ -d "$SRC/cursors" ]] && [[ -n "$(find "$SRC/cursors" -mindepth 1 -maxdepth 1 -not -name '.gitkeep' -print -quit 2>/dev/null)" ]]; then
        _info "Copiando cursor de src/cursors/"
        cp -r "$SRC/cursors" "$DIST/icons/$TEMA_CURSOR"
    elif [[ -d /usr/share/icons/Dracula-Cursor ]]; then
        _info "Copiando cursor do sistema (/usr/share/icons/Dracula-Cursor)"
        cp -r /usr/share/icons/Dracula-Cursor "$DIST/icons/$TEMA_CURSOR"
    else
        _warn "Cursor não encontrado (nem em src/ nem em /usr/share/)"
    fi
    [[ -d "$DIST/icons/$TEMA_CURSOR" ]] && _ok "Cursor em dist/"

    # GTK — se src/gtk/ vazio, usa ~/.local/share/themes/Dracula-standard-buttons
    if [[ -d "$SRC/gtk" ]] && [[ -n "$(find "$SRC/gtk" -mindepth 1 -maxdepth 1 -not -name '.gitkeep' -print -quit 2>/dev/null)" ]]; then
        _info "Copiando tema GTK de src/gtk/"
        cp -r "$SRC/gtk" "$DIST/themes/$TEMA_GTK"
    elif [[ -d "$HOME/.local/share/themes/Dracula-standard-buttons" ]]; then
        _info "Copiando tema GTK do user (~/.local/share/themes/)"
        cp -r "$HOME/.local/share/themes/Dracula-standard-buttons" "$DIST/themes/$TEMA_GTK"
    else
        _warn "Tema GTK não encontrado"
    fi

    # Shell — concatena CSS base (do tema existente) + overrides custom + auxiliares
    local shell_dir="$DIST/themes/$TEMA_GTK/gnome-shell"
    mkdir -p "$shell_dir"
    local base_css="$shell_dir/gnome-shell.css"

    if [[ -f "$SRC/shell/pop-shell-dracula.css" ]]; then
        cp "$SRC/shell/pop-shell-dracula.css" "$shell_dir/pop-shell-dracula.css"
        _ok "pop-shell-dracula.css copiado"
    fi

    # Concatena pop-shell-dracula.css diretamente ao gnome-shell.css do tema base
    # (St/Clutter do GNOME Shell NÃO suporta @import — tem que ser inline)
    if [[ -f "$SRC/shell/pop-shell-dracula.css" ]]; then
        if [[ -f "$base_css" ]]; then
            # Remove bloco de overrides anterior (se existir) para idempotência
            if grep -q "==== Dracula_OS-Theme overrides ====" "$base_css"; then
                sed -i '/==== Dracula_OS-Theme overrides ====/,$d' "$base_css"
            fi
            _info "Anexando pop-shell-dracula.css ao gnome-shell.css do tema"
            {
                echo ""
                echo "/* ==== Dracula_OS-Theme overrides ==== */"
                cat "$SRC/shell/pop-shell-dracula.css"
            } >> "$base_css"
        else
            _info "Instalando gnome-shell.css novo (base não existia)"
            {
                echo "/* Dracula_OS-Theme — gnome-shell.css */"
                cat "$SRC/shell/pop-shell-dracula.css"
            } > "$base_css"
        fi
    fi

    # Assets shell (imagens, logos)
    if [[ -d "$SRC/shell/assets" ]] && [[ -n "$(find "$SRC/shell/assets" -mindepth 1 -maxdepth 1 -not -name '.gitkeep' -print -quit 2>/dev/null)" ]]; then
        cp -r "$SRC/shell/assets"/* "$shell_dir/" 2>/dev/null || true
    fi
}

# ─── Fase G: Empacotar overrides e app-themes para install.sh usar ───
preparar_extras() {
    # Copia overrides (.desktop) para dist/apps/
    if [[ -d "$REPO_ROOT/overrides" && $(ls -A "$REPO_ROOT/overrides" 2>/dev/null | wc -l) -gt 0 ]]; then
        cp -r "$REPO_ROOT/overrides" "$DIST/"
        _ok "overrides/ copiado"
    fi
    # Sons (tema Pop)
    if [[ -d "$SRC/sounds" ]] && [[ -n "$(find "$SRC/sounds" -mindepth 1 -maxdepth 1 -not -name '.gitkeep' -print -quit 2>/dev/null)" ]]; then
        cp -r "$SRC/sounds" "$DIST/"
        _ok "sounds/ copiado"
    fi
    # App-themes (via install.sh separado)
    _info "app-themes/ continua em $REPO_ROOT/app-themes/ (instalar via scripts/instalar_app_themes.sh)"
}

# ─── Main ───
main() {
    echo -e "${C_DIM}Dracula_OS-Theme — build${C_RESET}"
    echo -e "${C_DIM}Conversor SVG: $CONVERSOR${C_RESET}"
    echo ""

    if [[ ! -f "$MAPPING" ]]; then
        _err "mapping.json não encontrado. Rode: python3 scripts/extrair_mapeamento.py"
    fi
    if ! command -v jq &>/dev/null; then
        _err "jq não encontrado. Instale: sudo apt install jq"
    fi

    limpar_dist
    copiar_upstreams
    gerar_tema_icones
    gerar_mimetypes
    gerar_symbolic_icons
    gerar_index_theme
    copiar_cursor_gtk_shell
    preparar_extras
    atualizar_caches

    echo ""
    _ok "Build concluído em $DIST/"
    echo -e "${C_DIM}Próximo passo: ./install.sh --user${C_RESET}"
}

main "$@"

# "A simplicidade é a máxima sofisticação." -- Leonardo da Vinci
