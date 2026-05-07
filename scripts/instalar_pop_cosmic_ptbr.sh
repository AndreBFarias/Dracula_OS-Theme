#!/usr/bin/env bash
# instalar_pop_cosmic_ptbr.sh — localiza launcher Pop!_Cosmic em pt-BR via cópia user-dir.
# Sem sudo. GNOME Shell carrega ~/.local/share/gnome-shell/extensions/ com precedência.

set -euo pipefail

SYS_EXT="${POP_COSMIC_SYSTEM_DIR:-/usr/share/gnome-shell/extensions/pop-cosmic@system76.com}"
USER_EXT="${POP_COSMIC_USER_DIR:-$HOME/.local/share/gnome-shell/extensions/pop-cosmic@system76.com}"
APP_JS="$USER_EXT/applications.js"
DRACULA_DRY_RUN="${DRACULA_DRY_RUN:-0}"

if [[ ! -d "$SYS_EXT" ]]; then
    echo "AVISO: pop-cosmic não está instalado em $SYS_EXT — nada a fazer."
    exit 0
fi

if [[ -f "$APP_JS" ]] && grep -q "'Início'" "$APP_JS"; then
    echo "OK: pop-cosmic pt-BR já instalado em $USER_EXT (idempotente)."
    exit 0
fi

mkdir -p "$(dirname "$USER_EXT")"
if [[ "$DRACULA_DRY_RUN" = "1" ]]; then
    echo "DRY-RUN: cp -r --preserve=timestamps,mode $SYS_EXT $USER_EXT"
else
    cp -r --preserve=timestamps,mode "$SYS_EXT" "$USER_EXT"
fi

apply_sed() {
    local pattern="$1" replacement="$2"
    if [[ "$DRACULA_DRY_RUN" = "1" ]]; then
        echo "DRY-RUN: sed -i \"s|$pattern|$replacement|\" $APP_JS"
    else
        sed -i "s|$pattern|$replacement|" "$APP_JS"
    fi
}

apply_sed "'Library Home'" "'Início'"
apply_sed 'create_button.label.text = "Create Folder";' 'create_button.label.text = "Criar pasta";'
apply_sed 'new CosmicFolderEditDialog("New Folder", "Folder Name", "Create", true,' \
          'new CosmicFolderEditDialog("Nova pasta", "Nome da pasta", "Criar", true,'
apply_sed '"Deleting this folder will move the application icons to Library Home."' \
          '"Excluir esta pasta moverá os ícones para Início."'
apply_sed 'new CosmicFolderEditDialog("Delete Folder?", desc, "Delete", false,' \
          'new CosmicFolderEditDialog("Excluir pasta?", desc, "Excluir", false,'
apply_sed 'new CosmicFolderEditDialog("Rename Folder", null, "Rename", true,' \
          'new CosmicFolderEditDialog("Renomear pasta", null, "Renomear", true,'

if [[ "$DRACULA_DRY_RUN" != "1" ]]; then
    err=0
    for marca in "'Início'" "Criar pasta" "Nova pasta" "Nome da pasta" "Excluir pasta?" "Renomear pasta" "moverá os ícones"; do
        if ! grep -qF "$marca" "$APP_JS"; then
            echo "ERRO: marca pt-BR ausente após patch: $marca"
            err=1
        fi
    done
    if grep -qF "'Library Home'" "$APP_JS"; then
        echo "ERRO: 'Library Home' ainda presente em $APP_JS"
        err=1
    fi
    [[ $err -ne 0 ]] && exit 1
    echo "OK: pop-cosmic pt-BR instalado em $USER_EXT"
    echo "    Reinicie o GNOME Shell: Alt+F2, digite 'r', Enter (X11) ou logout/login (Wayland)."
fi
