# Sprint 04 — Atalhos de teclado e som do PrintScreen

## Contexto

Atalhos customizados do usuário (Gradia em `Shift+Super+s`, `Ctrl+Alt+T`
abrindo gnome-terminal, paste com `Ctrl+V` no terminal) são reconfigurados
manualmente a cada instalação fresh. O usuário também prefere o sistema
silencioso — sem som no PrintScreen ou em outros eventos.

Sprint cria snapshots dconf e um instalador para reaplicar em PC novo.

## Snapshots capturados

```
app-themes/keybindings/
├── media-keys.dconf     # custom-keybindings (Gradia screenshot, terminal)
├── terminal.dconf       # paste='<Primary>v'
└── sound.dconf          # event-sounds=false (silencia shutter + notificações)
```

- `wm-keybindings.dconf` não gerado — usuário não tem customização em
  `/org/gnome/desktop/wm/keybindings/` (captura futura criará se houver).

## Scripts

- **`scripts/capturar_keybindings.sh`** — roda `dconf dump` nos quatro
  namespaces e salva em `app-themes/keybindings/`. Remove arquivo se
  namespace não tiver customização.
- **`scripts/instalar_keybindings.sh`** — backup do estado atual em
  `~/.cache/dracula_os_backup_keybindings_<ts>/`, depois `dconf load` de
  cada snapshot. Flag `--revert` restaura backup mais recente.

## Integração no install.sh

```bash
./install.sh --user --keybindings       # só atalhos + som
./install.sh --user --all               # tudo inclusive atalhos
```

Ordem: última seção antes do `--activate` (gsettings). Justificativa:
depende do gnome-terminal já estar instalado (qualquer distro Pop!_OS o
tem por padrão), e os atalhos custom apontam para apps (Gradia) que
precisam existir antes de acionar.

## Decisão sobre som do PrintScreen

`event-sounds=false` muta **todos** os sons de evento, não apenas o
shutter. Escolha justificada por:

1. Preferência declarada pelo usuário.
2. Alternativa cirúrgica (substituir apenas o `.oga` do shutter por
   silêncio) depende da Sprint 03 (tema Pop) já aplicada, e adiciona
   complexidade sem valor claro.

Se no futuro o usuário quiser manter notificações sonoras e mutar apenas
o shutter, basta:
```bash
gsettings set org.gnome.desktop.sound event-sounds true
cp /dev/null ~/.local/share/sounds/Pop/stereo/action/screen-capture.oga
cp /dev/null ~/.local/share/sounds/Pop/stereo/action/camera-shutter.oga
```

## Verificação

```bash
# Após ./install.sh --user --keybindings:
dconf read /org/gnome/desktop/sound/event-sounds             # → false
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybindings
# → lista com custom0 (Gradia) e custom1 (Terminal)

# Teste manual:
# - PrintScreen → não emite som
# - Shift+Super+S → abre Gradia
# - Ctrl+Alt+T → abre gnome-terminal
# - Ctrl+V dentro do terminal → cola
```

## Reverter

```bash
./scripts/instalar_keybindings.sh --revert
# ou parar de silenciar som mantendo atalhos:
gsettings reset org.gnome.desktop.sound event-sounds
```

## Recapturar após mudar atalhos

```bash
./scripts/capturar_keybindings.sh   # sobrescreve os .dconf
git add app-themes/keybindings/
git commit -m "chore(keybindings): novo snapshot"
```

## Status

**Concluída** em 2026-04-16.

*"A liberdade é a possibilidade do isolamento." — Fernando Pessoa*
