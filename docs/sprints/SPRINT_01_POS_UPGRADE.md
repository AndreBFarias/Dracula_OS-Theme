# Sprint — Contramedidas pós `apt full-upgrade` e reinstalações

Após `sudo apt full-upgrade` ou reinstalação de pacotes, várias coisas que o Dracula_OS-Theme aplicou podem ser sobrescritas. Esta sprint documenta o que quebra e como restaurar automaticamente.

---

## O que pode ser sobrescrito

| Componente | Por quem | Efeito |
|---|---|---|
| `/usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css` | upgrade do pacote `pop-shell` | volta para laranja original |
| `/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css` | upgrade do pacote `pop-cosmic` | fundo do launcher volta pro marrom |
| `.desktop` de Flatpaks em `~/.local/share/flatpak/exports/share/applications/` | `flatpak update` regenera symlinks | `Icon=` volta pro original |
| `.desktop` de Flatpaks com **permissão 600** | alguns updates do Flatpak criam 600 | **apps deixam de abrir pelo launcher Pop!_OS** |
| `kitty.conf` | upgrade do `kitty` | `include current-theme.conf` some |
| `gnome-shell.css` do tema GTK | se o tema for upstream e atualizar | overrides Dracula perdidos |
| Spicetify em Spotify Flatpak | `flatpak update com.spotify.Client` | Spotify volta ao tema default |
| Caches de ícones | apt hooks de `libgtk-3-bin` | já regenera OK, mas pode deixar janela sem ícones temporariamente |
| Permissões em `~/.local/share/applications/` | `update-desktop-database` em certas condições | algumas regressões de `600` foram vistas |

---

## Incidente referência

**16/04/2026** — GIMP Flatpak não abria pelo launcher após `normalizar_desktops.sh`. Causa: `.desktop` em `~/.local/share/applications/` com permissão `600`. Correção: `chmod 644`. Este bug foi incorporado ao `normalizar_desktops.sh` e `aplicar_overrides.sh` para evitar recorrência.

---

## Objetivos da sprint

1. **Script único de reaplicação** (`scripts/reaplicar_tema.sh`) que roda após qualquer upgrade e recoloca tudo no lugar.
2. **APT hook** em `/etc/apt/apt.conf.d/99-dracula-os-theme` que dispara o script automaticamente após `apt upgrade`/`apt full-upgrade`.
3. **Flatpak hook** (se viável) para disparar após `flatpak update`.
4. **Health check** (`scripts/diagnostico.sh`) que reporta o estado de cada componente (aplicado / regredido / ausente).
5. **Integração com Spellbook-OS** — função `dracula_status` que usa o diagnóstico.

---

## Arquitetura proposta

### `scripts/reaplicar_tema.sh`

Execução idempotente — pode rodar múltiplas vezes sem efeito colateral:

```bash
#!/usr/bin/env bash
# Reaplica todas as customizações Dracula_OS-Theme que podem ter sido
# sobrescritas por updates.
set -euo pipefail

REPO="$HOME/Desenvolvimento/Dracula_OS-Theme"
cd "$REPO"

# 1. Verifica se o tema instalado existe
if [[ ! -d "$HOME/.local/share/icons/Dracula-Icones" ]]; then
    ./scripts/baixar_upstreams.sh
    ./build.sh
    ./install.sh --user
fi

# 2. Pop!_Shell e Pop!_Cosmic dark.css (se originais voltaram)
for ext in pop-shell pop-cosmic; do
    base="/usr/share/gnome-shell/extensions/${ext}@system76.com"
    if [[ -f "$base/dark.css" ]] && ! grep -q "Dracula_OS-Theme" "$base/dark.css"; then
        sudo ./scripts/instalar_pop_shell_css.sh install
        break
    fi
done

# 3. Overrides .desktop (ZapZap/WhatsApp Snap)
./scripts/aplicar_overrides.sh

# 4. Permissões dos .desktop (GIMP-bug)
find "$HOME/.local/share/applications" -maxdepth 1 -name "*.desktop" -type f \
    -not -perm 644 -exec chmod 644 {} +

# 5. Normaliza Icon= com path absoluto (caso Flatpak regenerou)
./scripts/normalizar_desktops.sh

# 6. Reaplica app-themes (idempotente)
./scripts/instalar_app_themes.sh

# 7. Rebuild caches
gtk-update-icon-cache -f "$HOME/.local/share/icons/Dracula-Icones" 2>/dev/null || true
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo "Dracula_OS-Theme reaplicado."
```

### APT hook — `/etc/apt/apt.conf.d/99-dracula-os-theme`

```conf
DPkg::Post-Invoke {
    "test -x /home/andrefarias/Desenvolvimento/Dracula_OS-Theme/scripts/reaplicar_tema.sh && \
     su - andrefarias -c '/home/andrefarias/Desenvolvimento/Dracula_OS-Theme/scripts/reaplicar_tema.sh' \
     >/var/log/dracula-theme-reaplicar.log 2>&1 || true";
};
```

Roda automaticamente após cada `apt install/upgrade/remove`. O `su - andrefarias` garante que rode como user (para paths em `~/`). O `|| true` impede que falha do hook bloqueie o apt.

**Atenção**: esse hook tem o user `andrefarias` hardcoded — para portabilidade, criar `scripts/instalar_apt_hook.sh` que gera o arquivo substituindo pelo `$USER` atual.

### `scripts/diagnostico.sh`

Health check sem efeitos colaterais:

```bash
#!/usr/bin/env bash
# Reporta estado de cada componente Dracula_OS-Theme.
# Exit code: 0 = tudo OK, 1 = regressões detectadas.

problemas=0
check() {
    local desc="$1" cmd="$2"
    if eval "$cmd" &>/dev/null; then
        echo "  [OK]   $desc"
    else
        echo "  [FALHA] $desc"
        problemas=$((problemas+1))
    fi
}

echo "=== Dracula_OS-Theme — diagnóstico ==="

check "Tema ativo: Dracula-Icones" "[[ \"\$(gsettings get org.gnome.desktop.interface icon-theme)\" == \"'Dracula-Icones'\" ]]"
check "Tema GTK ativo" "[[ \"\$(gsettings get org.gnome.desktop.interface gtk-theme)\" == \"'Dracula-standard-buttons'\" ]]"
check "Icon cache válido" "gtk-update-icon-cache --validate \$HOME/.local/share/icons/Dracula-Icones"
check "Pop!_Shell dark.css Dracula" "grep -q 'Dracula_OS-Theme\\|pop-shell-search.modal-dialog' /usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css"
check "Pop!_Cosmic dark.css Dracula" "grep -q 'Dracula_OS-Theme\\|cosmic-applications-dialog.*rgba' /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css"
check "Override ZapZap→WhatsApp" "grep -q 'Name=WhatsApp' \$HOME/.local/share/applications/com.rtosta.zapzap.desktop"
check ".desktop sem permissão 600" "! find \$HOME/.local/share/applications -maxdepth 1 -name '*.desktop' -type f -perm 600 -print -quit | grep -q ."
check "kitty include current-theme" "grep -q '^include current-theme.conf' \$HOME/.config/kitty/kitty.conf"
check "qBittorrent theme" "[[ -f \$HOME/.themes/dracula.qbtheme ]]"
check "Spicetify current_theme = Sleek" "grep -q 'current_theme.*Sleek' \$HOME/.config/spicetify/config-xpui.ini"

echo ""
if [[ $problemas -eq 0 ]]; then
    echo "Tudo OK — $problemas regressões"
    exit 0
else
    echo "Problemas detectados — $problemas regressões. Rode: ./scripts/reaplicar_tema.sh"
    exit 1
fi
```

### Integração com Spellbook-OS

Em `~/Desenvolvimento/Spellbook-OS/functions/sistema.zsh`:

```bash
# Status do Dracula_OS-Theme
dracula_status() {
    "$HOME/Desenvolvimento/Dracula_OS-Theme/scripts/diagnostico.sh"
}

# Reaplica após problemas
dracula_fix() {
    "$HOME/Desenvolvimento/Dracula_OS-Theme/scripts/reaplicar_tema.sh"
}
```

E no `atualizar_tudo` do Spellbook, adicionar no final:

```bash
atualizar_tudo() {
    # ... comandos atuais de upgrade ...
    _reconstruir_caches_icones

    # Reaplica tema Dracula se regressões detectadas
    if [ -x "$HOME/Desenvolvimento/Dracula_OS-Theme/scripts/diagnostico.sh" ]; then
        if ! "$HOME/Desenvolvimento/Dracula_OS-Theme/scripts/diagnostico.sh" >/dev/null 2>&1; then
            echo -e "${D_YELLOW}[!]${D_RESET} Dracula_OS-Theme com regressões — reaplicando..."
            "$HOME/Desenvolvimento/Dracula_OS-Theme/scripts/reaplicar_tema.sh"
        fi
    fi
}
```

---

## Checklist de execução (quando retomar)

- [ ] Criar `scripts/reaplicar_tema.sh` (idempotente, executável)
- [ ] Criar `scripts/diagnostico.sh` (read-only, exit code útil)
- [ ] Criar `scripts/instalar_apt_hook.sh` (gera `99-dracula-os-theme` com `$USER` correto)
- [ ] Atualizar `install.sh` com flag `--apt-hook` que chama `instalar_apt_hook.sh`
- [ ] Adicionar `dracula_status` e `dracula_fix` em `Spellbook-OS/functions/sistema.zsh`
- [ ] Integrar check no `atualizar_tudo` do Spellbook
- [ ] Documentar no README da raiz (seção Troubleshooting)
- [ ] Testar cenários: `apt reinstall pop-shell`, `flatpak update com.rtosta.zapzap`, `apt full-upgrade` completo
- [ ] Testar se `chmod 644` no hook apt não cria loop com `update-desktop-database`

---

## Riscos conhecidos

| Risco | Mitigação |
|---|---|
| APT hook rodando como `su - andrefarias` quebra em sistemas multi-user | Detectar `$SUDO_USER` e usar; fallback para não rodar |
| Spicetify reaplicar pode falhar por version mismatch do Spotify | Já mitigado no `instalar_app_themes.sh` (não-fatal) |
| Pop!_Shell update pode trazer mudanças no `dark.css` que quebram nossa substituição | Detectar via diff com `.orig`; só substituir se estrutura compatível |
| Flatpak regenera `.desktop` com permissão 600 (observado em 2026-04-16) | `reaplicar_tema.sh` inclui `chmod 644` em massa; salvaguarda em `normalizar_desktops.sh` e `aplicar_overrides.sh` |
| Overrides `.desktop` não ser aplicado se Flatpak renomeou o arquivo-fonte | Monitorar nomes em `exports/share/applications/` e adaptar overrides |

---

## Referência rápida

```bash
# Checagem manual (sem efeitos)
./scripts/diagnostico.sh

# Reaplicar tudo
./scripts/reaplicar_tema.sh

# Instalar hook apt (requer sudo)
sudo ./scripts/instalar_apt_hook.sh

# Remover hook apt
sudo rm /etc/apt/apt.conf.d/99-dracula-os-theme
```
