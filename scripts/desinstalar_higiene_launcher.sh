#!/usr/bin/env bash
# desinstalar_higiene_launcher.sh — reverte instalar_higiene_launcher.sh.
# Para Parte A: se override foi criado por nós (marca # dracula-os: created),
# remove o arquivo inteiro; senão, remove só a linha NoDisplay=true.
# Para Parte B: re-adiciona 'Utilities' a folder-children (reset do dconf
# relocatable não é restaurado — limitação documentada).
# Suporta DRACULA_DRY_RUN=1 para imprimir comandos sem executar.

set -euo pipefail

DESKTOP_USER="${HOME}/.local/share/applications/gnome-session-properties.desktop"
MARCA_CRIADO="# dracula-os: created"
DRY_RUN="${DRACULA_DRY_RUN:-0}"

# ─── Parte A reverter ───
reverter_a() {
    if [[ ! -f "$DESKTOP_USER" ]]; then
        echo "OK: Parte A nada a reverter ($DESKTOP_USER ausente)."
        return 0
    fi

    if grep -qF "$MARCA_CRIADO" "$DESKTOP_USER"; then
        if [[ "$DRY_RUN" == "1" ]]; then
            echo "DRY_RUN: rm -f $DESKTOP_USER"
        else
            rm -f "$DESKTOP_USER"
        fi
        echo "OK: Parte A — $DESKTOP_USER removido (era criado por nós)."
        return 0
    fi

    if grep -q "^NoDisplay=true" "$DESKTOP_USER"; then
        if [[ "$DRY_RUN" == "1" ]]; then
            echo "DRY_RUN: sed -i /^NoDisplay=true\$/d $DESKTOP_USER"
        else
            sed -i "/^NoDisplay=true$/d" "$DESKTOP_USER"
        fi
        echo "OK: Parte A — linha NoDisplay=true removida de $DESKTOP_USER"
    else
        echo "OK: Parte A já revertida (NoDisplay=true ausente)."
    fi
}

# ─── Parte B reverter ───
reverter_b() {
    if ! command -v gsettings >/dev/null 2>&1; then
        echo "AVISO: gsettings ausente — Parte B pulada."
        return 0
    fi

    local atual
    atual="$(gsettings get org.gnome.desktop.app-folders folder-children 2>/dev/null || echo "[]")"

    if echo "$atual" | grep -q "'Utilities'"; then
        echo "OK: Parte B já revertida (Utilities presente em folder-children)."
        return 0
    fi

    # Re-adiciona 'Utilities' como primeiro item.
    # Casos: lista vazia "@as []" / "[]"  → ['Utilities']
    #        lista não-vazia ['YaST']     → ['Utilities', 'YaST']
    local novo
    if [[ "$atual" == "@as []" ]] || [[ "$atual" == "[]" ]]; then
        novo="['Utilities']"
    else
        novo="$(echo "$atual" | sed -E "s/^\[/['Utilities', /")"
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        echo "DRY_RUN: gsettings set org.gnome.desktop.app-folders folder-children \"$novo\""
    else
        gsettings set org.gnome.desktop.app-folders folder-children "$novo"
    fi
    echo "OK: Parte B — folder-children agora $novo"
    echo "    (reset do schema relocatable /folders/Utilities/ não é restaurado;"
    echo "     o vendor default repovoa em logout/login.)"
}

reverter_a || echo "AVISO: reverter Parte A falhou (não-fatal)"
reverter_b || echo "AVISO: reverter Parte B falhou (não-fatal)"
