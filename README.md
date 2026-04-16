# Dracula_OS-Theme

Experiência Dracula unificada para **Pop!_OS / GNOME** — ícones, cursor, tema GTK, tema shell e temas internos de aplicativos (kitty, qBittorrent, Spicetify/Spotify, GNOME Terminal, Obsidian, Telegram, Discord, OnlyOffice) num único monorepo portátil.

Desenvolvido e testado em **Pop!_OS 22.04 LTS / GNOME 42.9 / X11**.

## Sumário

- [O que este pacote instala](#o-que-este-pacote-instala)
- [Requisitos](#requisitos)
- [Instalação rápida](#instalação-rápida)
- [Componentes](#componentes)
- [Arquitetura do repo](#arquitetura-do-repo)
- [Build pipeline](#build-pipeline)
- [Temas internos de apps](#temas-internos-de-apps)
- [Overrides de .desktop](#overrides-de-desktop)
- [Limpar instalações antigas](#limpar-instalações-antigas)
- [Desinstalação](#desinstalação)
- [Troubleshooting](#troubleshooting)
- [Licença](#licença)

## O que este pacote instala

| Componente | Nome ativo | Destino (user) |
|---|---|---|
| Ícones | `Dracula-Icones` | `~/.local/share/icons/Dracula-Icones/` |
| Cursor | `Dracula-Cursor` | `~/.local/share/icons/Dracula-Cursor/` |
| Tema GTK (2/3/4) | `Dracula-standard-buttons` | `~/.local/share/themes/Dracula-standard-buttons/` |
| Tema shell | `Dracula-standard-buttons/gnome-shell/` | (embutido no tema GTK) |
| Upstreams (heranças) | `dracula-icons-main`, `dracula-icons-circle` | `~/.local/share/icons/` |
| Overrides `.desktop` | ZapZap → WhatsApp, Snap oculto | `~/.local/share/applications/` |
| Temas de apps | kitty, qBittorrent, Terminal, Spicetify, Obsidian, Telegram, Discord, OnlyOffice | paths de cada app |

O tema de ícones **Dracula-Icones** é completo (apps + mimetypes), com **2235 arquivos** instalados cobrindo 203 apps + 4 mimetypes customizados (`.md`, `.sh`, `.desktop`, `.mp4`).

## Requisitos

- Pop!_OS 22.04+ (ou GNOME 42+ em qualquer distro)
- `librsvg2-bin` (`rsvg-convert`) **OU** `imagemagick` como fallback
- `gtk-update-icon-cache` (pacote `libgtk-3-bin`)
- `jq`, `python3` (>=3.10)
- Extensão `user-theme` habilitada
- Extensão `pop-shell@system76.com` (para recursos específicos do launcher)
- Opcional: `sassc` (recompilar SCSS do tema GTK)

## Instalação rápida

```bash
# 1. Clonar o repo
git clone https://github.com/andrebfarias/Dracula_OS-Theme.git ~/Desenvolvimento/Dracula_OS-Theme
cd ~/Desenvolvimento/Dracula_OS-Theme

# 2. Baixar upstreams (dracula-icons-main/circle) — git-ignored no repo
./scripts/baixar_upstreams.sh

# 3. Gerar mapping.json a partir dos .desktop atuais
python3 scripts/extrair_mapeamento.py

# 4. Build (gera dist/)
./build.sh

# 5. Instalar (user-local) + ativar + app themes + CSS pop-shell
./install.sh --user --all

# Alternativa passo-a-passo:
# ./install.sh --user                       # só instala
# ./install.sh --user --activate            # instala + ativa via gsettings
# ./install.sh --user --app-themes          # instala + aplica kitty/qbittorrent/etc
# ./install.sh --user --pop-shell-css       # instala + substitui pop-shell/pop-cosmic dark.css (sudo)
# ./install.sh --user --all                 # tudo acima
```

### Normalizar `.desktop` com Icon absoluto (opcional)

Se você tem `.desktop` apontando para paths absolutos antigos (`~/.icons/Dracula-Icones/scalable/...`), rode:

```bash
./scripts/normalizar_desktops.sh         # interativo
./scripts/normalizar_desktops.sh --dry-run   # preview
```

Backup automático em `~/.cache/dracula_os_backup_<timestamp>/desktops/`.

## Componentes

### 1. Tema de ícones (`Dracula-Icones`)

Herda de `dracula-icons-circle` + `dracula-icons-main` + `Adwaita` + `hicolor` via `Inherits=`. Só os overrides custom ficam no tema — o resto cai nos upstreams. Isso mantém cobertura total sem duplicar arquivos.

**Fontes de ícones**:
- `src/icons/current/` — 3437 SVGs customizados (tema antigo preservado)
- `src/icons/new-sessao-atual/` — 295 SVGs estilizados gótico/fantasia
- `src/icons/projects/` — 19 ícones de projetos pessoais (`~/Desenvolvimento/`)
- `src/icons/upstream/` — vendored de `m4thewz/dracula-icons` + `dracula-icons-circle` (git-ignored)

**Mapeamento declarativo** (`mapping.json`): 203 apps com `fonte` + `aliases_humanos`. O `build.sh` gera para cada app:
- `{app_id}.svg` e `{app_id}.png` em 8 tamanhos (reverse-DNS)
- `{alias_humano}.svg` e `{alias_humano}.png` em 8 tamanhos (ex: `whatsapp`, `discord`, `obsidian`)

Isso permite `.desktop` usarem `Icon=whatsapp` diretamente sem conhecer o reverse-DNS do app.

### 2. Tema GTK (`Dracula-standard-buttons`)

Vendored de `~/.local/share/themes/Dracula-standard-buttons/` com 2180 linhas de `gnome-shell.css`. O `build.sh` anexa `src/shell/pop-shell-dracula.css` ao final (marcador `==== Dracula_OS-Theme overrides ====` permite idempotência).

### 3. Cursor (`Dracula-Cursor`)

Copiado de `/usr/share/icons/Dracula-Cursor/`.

### 4. Pop!_Shell + Pop!_Cosmic dark.css (requer sudo)

Duas extensões do Pop!_OS têm seu **próprio CSS** que sobrepõe o tema GTK:

- `/usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css` — controla tiling overlay e search
- `/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css` — controla o **launcher Applications** (`.cosmic-applications-dialog` com `#36322f` marrom por padrão)

O `scripts/instalar_pop_shell_css.sh` (chamado por `./install.sh --pop-shell-css`) faz backup dos `.orig` e substitui pelos nossos em `src/shell/pop-shell-dark.css` e `src/shell/pop-cosmic-dark.css`.

## Arquitetura do repo

```
Dracula_OS-Theme/
├── README.md
├── LICENSE                        # GPL-3.0
├── CHANGELOG.md
├── .gitignore                     # dist/, src/icons/upstream/, *_backup_*
├── catalog.json                   # descrição dos 295 SVGs novos
├── mapping.json                   # app → ícone (gerado por extrair_mapeamento.py)
├── install.sh                     # --user | --system | --all | --pop-shell-css | --app-themes | --activate
├── uninstall.sh
├── build.sh                       # SVG → PNGs + index.theme + caches
│
├── src/
│   ├── icons/
│   │   ├── upstream/              # (git-ignored) baixado via scripts/baixar_upstreams.sh
│   │   ├── current/               # tema custom atual (3437 SVGs + 35 PNGs 48x48)
│   │   ├── new-sessao-atual/      # 295 SVGs estilizados gótico
│   │   ├── projects/              # ícones de ~/Desenvolvimento/
│   │   └── {apps,mimetypes,places,status,devices,actions}/   # overrides futuros
│   ├── cursors/                   # XCursor (futuro)
│   ├── gtk/                       # tema GTK source (SCSS/CSS — futuro)
│   └── shell/
│       ├── pop-shell-dracula.css  # regras Dracula anexadas ao gnome-shell.css
│       ├── pop-shell-dark.css     # substitui dark.css do Pop!_Shell
│       └── pop-cosmic-dark.css    # substitui dark.css do Pop!_Cosmic (launcher Applications)
│
├── dist/                          # (git-ignored) saída do build
│
├── app-themes/
│   ├── kitty/                     # current-theme.conf Dracula oficial
│   ├── qbittorrent/               # dracula.qbtheme
│   ├── gnome-terminal/            # dracula-profile.dconf (paleta custom do user)
│   ├── spicetify/                 # README → Spellbook-OS/scripts/spicetify-setup.sh
│   ├── obsidian/                  # Dracula.theme.css + manifest.json (oficial)
│   ├── telegram/                  # dracula.tdesktop-theme (oficial)
│   ├── discord-betterdiscord/     # Dracula.theme.css (de dracula/vesktop-discord)
│   └── onlyoffice/                # README (só dark built-in)
│
├── overrides/
│   ├── com.rtosta.zapzap.desktop              # ZapZap → WhatsApp
│   └── whatsapp-linux-app_whatsapp-linux-app.desktop   # Snap oculto (NoDisplay=true)
│
└── scripts/
    ├── baixar_upstreams.sh        # clone dos upstreams (1ª vez)
    ├── extrair_mapeamento.py      # gera mapping.json dos .desktop do sistema
    ├── gerar_catalog.py           # descreve os 295 SVGs em catalog.json
    ├── renomear_fontes.py         # corrige typos nos SVGs-fonte (idempotente)
    ├── limpar_duplicatas.sh       # remove Dracula-* antigos (com guard + backup)
    ├── aplicar_overrides.sh       # copia .desktop overrides
    ├── normalizar_desktops.sh     # remove Icon= com path absoluto
    ├── instalar_app_themes.sh     # kitty/qbittorrent/terminal/spicetify/obsidian/telegram/discord
    └── instalar_pop_shell_css.sh  # substitui pop-shell e pop-cosmic dark.css
```

## Build pipeline

`build.sh` executa em ordem:

1. Limpa `dist/`
2. Copia upstreams (`dracula-icons-{main,circle}`) para `dist/icons/` como temas independentes
3. Gera `dist/icons/Dracula-Icones/` a partir de `mapping.json`:
   - Para cada app, copia SVG/PNG-fonte como `{app_id}` e cada `{alias_humano}`
   - Gera PNG em 16, 22, 24, 32, 48, 64, 128, 256 via `rsvg-convert` (ou `magick`/`convert` como fallback)
4. Gera mimetypes custom (`.md`, `.sh`, `.desktop`, `.mp4`) com múltiplos nomes XDG cada
5. Escreve `index.theme` com `Inherits=dracula-icons-circle,dracula-icons-main,Adwaita,hicolor`
6. Copia cursor e tema GTK
7. Concatena `src/shell/pop-shell-dracula.css` ao `gnome-shell.css` do tema (inline, pois GNOME Shell não suporta `@import`)
8. `gtk-update-icon-cache -f -t` nos 3 temas

**Idempotência**: rodar múltiplas vezes regenera `dist/` do zero, sem duplicação.

## Temas internos de apps

`scripts/instalar_app_themes.sh` aplica:

| App | Ação |
|---|---|
| **kitty** | Copia `current-theme.conf` → `~/.config/kitty/` + garante `include current-theme.conf` no `kitty.conf` (backup `.bak` se divergir) |
| **qBittorrent** | Copia `dracula.qbtheme` → `~/.themes/` |
| **GNOME Terminal** | `dconf load` do perfil customizado (paleta verde-limão/magenta do user preservada) |
| **Spicetify** | Delega para `~/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh` (detecta Flatpak/snap/nativo, aplica tema Sleek + Dracula) |
| **Obsidian** | Lê `~/.var/app/.../obsidian.json`, itera cada vault e instala tema em `<vault>/.obsidian/themes/Dracula/` |
| **Telegram** | Copia `.tdesktop-theme` para `~/.cache/dracula-telegram/` (user importa manualmente no app) |
| **Discord** | Copia `Dracula.theme.css` para `~/.config/BetterDiscord/themes/`, `~/.config/vesktop/themes/`, `~/.config/Vencord/themes/` (o que existir) |
| **OnlyOffice** | Documenta ativação do dark mode built-in |

Use `--dry-run` para preview.

## Overrides de .desktop

Os `.desktop` em `overrides/` são copiados para `~/.local/share/applications/` (prioridade XDG sobre `/var/lib/flatpak/exports/`):

- **ZapZap (Flatpak)**: `Name=WhatsApp`, `Icon=whatsapp-linux-app`, Exec preservado
- **WhatsApp (Snap)**: `NoDisplay=true` — oculto no launcher para evitar duplicata com o ZapZap renomeado

Restauração: `./uninstall.sh --user` remove os overrides (volta ao .desktop original gerado pelo Flatpak/Snap).

## Limpar instalações antigas

`scripts/limpar_duplicatas.sh` remove instalações Dracula espalhadas:

- `~/.icons/Dracula-Icones/` (versão custom antiga)
- `~/.icons/Dracula-Icons/` (merge antigo do `instalador.py`)
- `~/.icons/Dracula-Cursor/`
- `~/.icons/instalador.py`
- `~/.local/share/icons/Dracula-cursors/`
- `~/.themes/Dracula/`

**Guards**:
- Bloqueia se `~/.local/share/icons/Dracula-Icones/` não existe (instale primeiro)
- Avisa se houver `.desktop` com `Icon=/caminho/absoluto` ainda (rode `normalizar_desktops.sh` antes)
- Backup automático em `~/.cache/dracula_os_backup_<timestamp>/`

**Preserva**: `~/.local/share/icons/dracula-icons-main/` e `dracula-icons-circle/` (upstreams que o novo tema herda).

```bash
./scripts/limpar_duplicatas.sh --dry-run    # preview
./scripts/limpar_duplicatas.sh              # interativo
./scripts/limpar_duplicatas.sh --yes        # sem confirmação (cuidado)
```

## Desinstalação

```bash
./uninstall.sh --user      # remove tudo que install.sh --user pôs
./uninstall.sh --system    # remove tudo que install.sh --system pôs
```

Inclui:
- Remove temas instalados em `~/.local/share/{icons,themes}/`
- Remove overrides `.desktop` em `~/.local/share/applications/`
- Restaura `dark.css` originais de Pop!_Shell e Pop!_Cosmic (se `.orig` existir)

Depois, desative temas manualmente via `gsettings`:
```bash
gsettings reset org.gnome.desktop.interface icon-theme
gsettings reset org.gnome.desktop.interface gtk-theme
gsettings reset org.gnome.desktop.interface cursor-theme
```

## Troubleshooting

### Ícones não aparecem após instalar

```bash
gtk-update-icon-cache -f ~/.local/share/icons/Dracula-Icones
update-desktop-database ~/.local/share/applications
```

Se ainda não aparecer: `Alt+F2` → `r` → Enter (X11) ou logout/login (Wayland).

### Apps com Icon= path absoluto quebraram

Rode `./scripts/normalizar_desktops.sh` para reescrever `Icon=<path>` para `Icon=<app_id>`. Backup automático.

### Launcher do Pop!_OS continua opaco

Ver `SPRINT-TRANSPARENCIA.md` na raiz do repo — documentação da investigação em andamento.

### Spicetify reclama de versão mismatched

Normal após update do Spotify Flatpak. Reaplicar:
```bash
~/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh
```

### GitHub push rejeita por tamanho

`.gitignore` ignora `src/icons/upstream/` (~120MB) — são baixados via `baixar_upstreams.sh`. Se seu clone tem commits antigos com upstream dentro, use `git filter-repo` para purgar o histórico.

## Integração com Spellbook-OS

Se você usa [Spellbook-OS](https://github.com/AndreBFarias/Spellbook-OS), as funções `_reconstruir_caches_icones` (em `functions/sistema.zsh`) já cobrem `~/.local/share/icons/` automaticamente. Adicionada também a função `rebuild_dracula_theme` que roda `build.sh` + `install.sh --user` em um passo.

## Licença

GPL-3.0 — veja [LICENSE](LICENSE).
