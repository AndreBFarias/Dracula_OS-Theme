#!/usr/bin/env bash
# desinstalar_fontes_design.sh — remove tudo que instalar_fontes_design.sh criou
set -uo pipefail
rm -rf "$HOME/.local/share/fonts/JetBrainsMono"
rm -rf "$HOME/.local/share/fonts/FiraCode"
fc-cache -f >/dev/null 2>&1
echo "fontes de design (JetBrains Mono, Fira Code) removidas"
