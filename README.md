# Dracula_OS-Theme

Experiência Dracula unificada para Pop!_OS / GNOME — ícones, cursor, tema GTK, shell e temas de aplicativos (kitty, qBittorrent, Spotify via Spicetify, GNOME Terminal, Obsidian, Telegram, Discord, OnlyOffice) num único monorepo portátil.

## Componentes

| Camada | Nome instalado | Fonte |
|---|---|---|
| Ícones | `Dracula-Icones` | `src/icons/` + upstreams (`dracula-icons-main`, `dracula-icons-circle`) |
| Cursor | `Dracula-Cursor` | `src/cursors/` |
| Tema GTK | `Dracula-standard-buttons` | `src/gtk/` |
| Shell | `Dracula-standard-buttons/gnome-shell/` | `src/shell/` |
| App themes | diversos | `app-themes/` |

## Requisitos

- GNOME / Pop!_OS (testado em Pop!_OS 22.04, GNOME 42.9)
- `librsvg2-bin` (para `rsvg-convert`)
- `gtk-update-icon-cache`
- `sassc` (opcional, para recompilar SCSS do tema GTK)
- Extensão `user-theme` (para tema shell)

## Instalação

### User-local (recomendado)

```bash
./build.sh
./install.sh --user
```

### System-wide

```bash
./build.sh
sudo ./install.sh --system
```

### Ativar temas

```bash
gsettings set org.gnome.desktop.interface icon-theme 'Dracula-Icones'
gsettings set org.gnome.desktop.interface gtk-theme 'Dracula-standard-buttons'
gsettings set org.gnome.desktop.interface cursor-theme 'Dracula-Cursor'
gsettings set org.gnome.shell.extensions.user-theme name 'Dracula-standard-buttons'
```

Ou use `./install.sh --user --activate`.

## Temas internos de apps

Aplicados separadamente via:

```bash
./scripts/instalar_app_themes.sh
```

Cobre: kitty, qBittorrent, GNOME Terminal (perfil dconf), Spotify (via Spicetify), Obsidian, Telegram, Discord (BetterDiscord), OnlyOffice.

## Desinstalação

```bash
./uninstall.sh --user
```

## Estrutura

```
src/                  # fontes (SVGs, CSS, SCSS)
dist/                 # saída do build (git-ignored)
app-themes/           # temas internos de apps
overrides/            # overrides de .desktop (ex.: ZapZap → WhatsApp)
scripts/              # utilitários (catalog, scan, limpeza, release)
```

## Licença

GPL-3.0 — veja [LICENSE](LICENSE).
