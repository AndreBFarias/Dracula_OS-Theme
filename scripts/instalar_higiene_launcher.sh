#!/usr/bin/env bash
# instalar_higiene_launcher.sh — esconde gnome-session-properties do grid
# e remove a pasta Utilities/X-GNOME-Utilities do rodapé do launcher.
# Sem sudo, idempotente, não-fatal.
# Suporta DRACULA_DRY_RUN=1 para imprimir comandos sem executar.

set -euo pipefail

DESKTOP_USER="${HOME}/.local/share/applications/gnome-session-properties.desktop"
DESKTOP_SYS="/usr/share/applications/gnome-session-properties.desktop"
MARCA_CRIADO="# dracula-os: created"
DRY_RUN="${DRACULA_DRY_RUN:-0}"

_run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "DRY_RUN: $*"
    else
        eval "$@"
    fi
}

# ─── Parte A: NoDisplay=true em gnome-session-properties.desktop ───
parte_a() {
    if [[ ! -f "$DESKTOP_USER" ]]; then
        if [[ -f "$DESKTOP_SYS" ]]; then
            _run "mkdir -p \"$(dirname "$DESKTOP_USER")\""
            _run "cp \"$DESKTOP_SYS\" \"$DESKTOP_USER\""
            # Insere marca logo após a primeira linha [Desktop Entry]
            _run "sed -i \"1a${MARCA_CRIADO}\" \"$DESKTOP_USER\""
        else
            echo "AVISO: nem $DESKTOP_USER nem $DESKTOP_SYS existem — Parte A pulada."
            return 0
        fi
    fi

    # Idempotência
    if [[ -f "$DESKTOP_USER" ]] && grep -q "^NoDisplay=true" "$DESKTOP_USER"; then
        echo "OK: Parte A já aplicada (NoDisplay=true presente)."
        return 0
    fi

    # Adiciona NoDisplay=true ao final da seção [Desktop Entry].
    # Como o arquivo só tem uma seção, append simples basta.
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "DRY_RUN: echo NoDisplay=true >> $DESKTOP_USER"
    else
        echo "NoDisplay=true" >> "$DESKTOP_USER"
    fi
    echo "OK: Parte A — NoDisplay=true adicionado em $DESKTOP_USER"
}

# ─── Parte B: remover Utilities de folder-children ───
parte_b() {
    if ! command -v gsettings >/dev/null 2>&1; then
        echo "AVISO: gsettings ausente — Parte B pulada."
        return 0
    fi

    local atual novo
    atual="$(gsettings get org.gnome.desktop.app-folders folder-children 2>/dev/null || echo "[]")"
    novo="$(echo "$atual" | sed -E "s/'Utilities',\s*//; s/,\s*'Utilities'//; s/'Utilities'//")"

    if [[ "$novo" == "$atual" ]]; then
        echo "OK: Parte B já aplicada (Utilities ausente de folder-children)."
        return 0
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        echo "DRY_RUN: gsettings set org.gnome.desktop.app-folders folder-children \"$novo\""
        if command -v dconf >/dev/null 2>&1; then
            echo "DRY_RUN: dconf reset -f /org/gnome/desktop/app-folders/folders/Utilities/"
        fi
    else
        gsettings set org.gnome.desktop.app-folders folder-children "$novo"
        if command -v dconf >/dev/null 2>&1; then
            dconf reset -f /org/gnome/desktop/app-folders/folders/Utilities/ || true
        fi
    fi
    echo "OK: Parte B — folder-children agora $novo"
}

parte_a || echo "AVISO: Parte A falhou (não-fatal)"
parte_b || echo "AVISO: Parte B falhou (não-fatal)"

echo ""
echo "Para aplicar visualmente: Alt+F2, digitar 'r', Enter (X11) ou logout/login."
echo "Limitação Parte B: vendor schema do pop-cosmic pode reinjetar 'Utilities' em logout/login."
echo "Se voltar, basta rodar este script novamente."
