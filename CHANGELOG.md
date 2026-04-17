# Changelog

Todas as mudanças notáveis deste projeto são documentadas neste arquivo.
Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) + SemVer.

## [1.1.0] — 2026-04-16

### Adicionado

- **Logo oficial** em `assets/logo.png`, gerado a partir de `src/icons/new-sessao-atual/bat.svg`, referenciado no README.
- **Pasta de documentação** `docs/` com `CONTRIBUTING.md` (checklist de PR, padrão de commits) e `sprints/INDEX.md` (índice das sprints).
- Seção "Documentação" no README apontando para os novos índices.
- **Sprint 03 — Tema de som Pop!_OS**: `src/sounds/Pop/` com os 26 `.oga` do upstream `pop-os/gtk-theme` (CC-BY-SA-4.0). Script `scripts/instalar_sons.sh` e flag `--sounds` no `install.sh` (também em `--all`). Ativa `gsettings set org.gnome.desktop.sound theme-name 'Pop'`.
- **Sprint 04 — Atalhos + som do PrintScreen**: snapshots dconf em `app-themes/keybindings/` (media-keys, terminal, sound). Scripts `scripts/capturar_keybindings.sh` e `scripts/instalar_keybindings.sh` com `--revert`. Nova flag `--keybindings` no `install.sh`.
- **Sprint 05 — Extensões GNOME**: manifesto `app-themes/gnome-extensions/extensions.json` com as 13 extensões do usuário + 12 dconf dumps. Scripts `scripts/capturar_gnome_extensions.sh` e `scripts/instalar_gnome_extensions.sh` (EGO primeiro, git clone como fallback, `--only-dconf` e `--revert`). Nova flag `--gnome-extensions` no `install.sh`.
- `--all` do `install.sh` agora inclui as três novas flags.
- `uninstall.sh` remove tema de som Pop automaticamente.

### Modificado

- Sprints migradas para `docs/sprints/` com padrão de nomenclatura numerada:
  - `SPRINT-POS-UPGRADE.md` → `docs/sprints/SPRINT_01_POS_UPGRADE.md`.
  - `SPRINT-TRANSPARENCIA.md` → `docs/sprints/SPRINT_02_TRANSPARENCIA.md`.
- Árvore de arquitetura no README atualizada com `docs/` e `assets/`.
- Referência em "Troubleshooting" apontando para o novo caminho da sprint de transparência.

### Corrigido

- Acentuação PT-BR em mensagens de log/assinatura:
  - `build.sh`: "conversao" → "conversão"; "gotica" → "gótica"; "maxima sofisticacao" → "máxima sofisticação".
  - `scripts/instalar_pop_shell_css.sh`: "sessao/shell" → "sessão/shell"; "proprio" → "próprio"; "substituido" → "substituído".
  - `scripts/release.sh`: "esta no tarball" → "está no tarball".
- **Sprint 02 — Transparência do launcher Pop!_Cosmic concluída**: valor de alpha no `.cosmic-applications-dialog` ajustado de `rgba(40,42,54,0.70)` (opaco demais) para `rgba(40,42,54,0.45)` (translúcido visível). Hipóteses H4 e H5 confirmaram seletor correto e compositor aceitando alpha. `src/shell/pop-cosmic-dark.css` atualizado.

### Removido

- Pastas vazias sem uso em `src/icons/`: `status/`, `actions/`, `places/`, `apps/`, `devices/`, `mimetypes/`.

### Produção

- `.gitkeep` documentados em `src/gtk/`, `src/cursors/`, `src/shell/assets/` (preenchidos condicionalmente pelo `build.sh`).
- Projeto pronto para clone limpo: zero pastas vazias não intencionais, zero arquivos soltos na raiz, acentuação correta em toda comunicação PT-BR.

## [1.0.0] — 2026-04-16

Versão inicial consolidada do monorepo Dracula_OS-Theme.

### Adicionado

- **Estrutura do monorepo**: `src/`, `dist/`, `app-themes/`, `overrides/`, `scripts/` + `build.sh`, `install.sh`, `uninstall.sh` na raiz.
- **GPL-3.0** como licença.
- **Assets** importados:
  - 3437 SVGs do tema custom atual (`~/.icons/Dracula-Icones/scalable/apps/`) em `src/icons/current/`.
  - 35 PNGs globais em `src/icons/current/48x48/apps-global/`.
  - 295 SVGs estilizados (tema gótico/fantasia Dracula) em `src/icons/new-sessao-atual/`.
  - 19 ícones de projetos pessoais de `~/Desenvolvimento/` em `src/icons/projects/` (Neurosonancy, Beholder, ProtocoloOuroboros, etc.).
  - Upstreams `dracula-icons-main` (69MB) e `dracula-icons-circle` (52MB) em `src/icons/upstream/` — git-ignored, baixados via `scripts/baixar_upstreams.sh`.

- **`mapping.json` (203 apps)** gerado automaticamente por `scripts/extrair_mapeamento.py`:
  - Varre `.desktop` de `/usr/share/applications/`, `~/.local/share/applications/`, `~/.local/share/flatpak/exports/share/applications/`.
  - Preserva `Icon=` absolutos apontando para `~/.icons/Dracula-Icones/` (mapeados para `src/icons/current/`).
  - Preserva `Icon=` absolutos apontando para projetos em `~/Desenvolvimento/` (mapeados para `src/icons/projects/`).
  - Overrides manuais para 28 apps usarem SVGs dos 295 novos (lista curada pelo user).
  - `ALIASES_HEURISTICOS` (35 entradas) mapeia reverse-DNS para arquivos custom do tema.
  - `ALIASES_HUMANOS` (48 entradas) define slugs amigáveis (`whatsapp`, `discord`, `apostrophe`, etc.) que o `build.sh` gera além do reverse-DNS.
  - `APPS_DESCARTADOS` remove entries órfãs (`data-toolkit` — repo removido).

- **Catálogo** (`catalog.json`) dos 295 SVGs com descrições PT-BR, categorias (gótico/mitologia/fantasia/jogos/objetos/halloween/utilitários), cores dominantes e tamanhos. Gerado por `scripts/gerar_catalog.py`.

- **Build pipeline** (`build.sh`):
  - Detecta conversor SVG→PNG: `rsvg-convert` → `inkscape` → `magick` (IM7) → `convert` (IM6) como fallback.
  - Gera PNGs em 8 tamanhos (16, 22, 24, 32, 48, 64, 128, 256) para cada app e cada alias humano.
  - Gera ícones de mimetypes custom para `.md` (spellbook.svg), `.sh` (spell.svg), `.desktop` (gate.svg), `.mp4` (mobile-game.svg) — cobrindo ~16 convenções XDG.
  - Escreve `index.theme` com `Inherits=dracula-icons-circle,dracula-icons-main,Adwaita,hicolor` e `Context=Applications` / `Context=MimeTypes` nas declarações de Directories.
  - Concatena `src/shell/pop-shell-dracula.css` ao `gnome-shell.css` do tema base (GNOME Shell St não suporta `@import`).
  - Idempotência via marcador `==== Dracula_OS-Theme overrides ====`.
  - Total de 2235 arquivos gerados em `dist/icons/Dracula-Icones/`.

- **Install/Uninstall** (`install.sh`, `uninstall.sh`):
  - Flags: `--user` | `--system` | `--activate` (gsettings) | `--app-themes` | `--pop-shell-css` | `--all`.
  - `uninstall.sh` reverte automaticamente o `dark.css` original do Pop!_Shell e Pop!_Cosmic.

- **App themes** (automatizados via `scripts/instalar_app_themes.sh`):
  - kitty (tema Dracula oficial + garantia de `include current-theme.conf` no `kitty.conf`).
  - qBittorrent (`~/.themes/dracula.qbtheme`).
  - GNOME Terminal (paleta customizada do user preservada via dconf).
  - Spicetify (delegação para `Spellbook-OS/scripts/spicetify-setup.sh` — tema Sleek + Dracula; não-fatal em mismatch de versão do Spotify).
  - Obsidian (itera vaults via `obsidian.json` e instala em `<vault>/.obsidian/themes/Dracula/`).
  - Telegram (`.tdesktop-theme` em `~/.cache/dracula-telegram/` para importação manual).
  - Discord (BetterDiscord/Vesktop/Vencord — tema de `dracula/vesktop-discord`).
  - OnlyOffice (documentação do dark mode built-in).

- **Overrides de `.desktop`** (`overrides/`):
  - `com.rtosta.zapzap.desktop` — ZapZap Flatpak renomeado para "WhatsApp" com `Icon=whatsapp-linux-app`.
  - `whatsapp-linux-app_whatsapp-linux-app.desktop` — Snap com `NoDisplay=true` para evitar duplicata no launcher.

- **Pop!_Shell + Pop!_Cosmic dark.css** (`scripts/instalar_pop_shell_css.sh`):
  - Substitui `/usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css` (cores laranja/cinza → Dracula purple).
  - Substitui `/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css` (`.cosmic-applications-dialog` marrom #36322f → Dracula translúcido).
  - Backup `.orig` preservado.
  - `--revert` restaura originais.

- **Limpar duplicatas** (`scripts/limpar_duplicatas.sh`):
  - Remove `~/.icons/Dracula-Icones/`, `~/.icons/Dracula-Icons/`, `~/.icons/Dracula-Cursor/`, `~/.icons/instalador.py`, `~/.local/share/icons/Dracula-cursors/`, `~/.themes/Dracula/`.
  - Guards: exige tema novo instalado; avisa se `.desktop` com path absoluto ainda presente.
  - Backup automático em `~/.cache/dracula_os_backup_<ts>/`.
  - Preserva upstreams em `~/.local/share/icons/`.

- **Normalizar `.desktop`** (`scripts/normalizar_desktops.sh`):
  - Reescreve `Icon=<path_absoluto>` para `Icon=<app_id>` em `~/.local/share/applications/` e exports Flatpak (não-symlinks).
  - Backup automático antes de cada edição.

- **Integração Spellbook-OS**:
  - `_reconstruir_caches_icones` em `functions/sistema.zsh` agora itera também `~/.local/share/icons/`.
  - Nova função `rebuild_dracula_theme` roda `build.sh` + `install.sh --user`.

### Corrigido (auditoria inicial — 11 bugs)

| # | Bug | Fix |
|---|---|---|
| 1 | `convert` vs `magick` no IM6/IM7 | Detecção do binário + `MAGICK_CMD` em `build.sh` |
| 2 | `@import` em gnome-shell.css não funciona em St | Concatenação inline com marcador idempotente |
| 3 | `data-toolkit` com fonte quebrada | `APPS_DESCARTADOS` em `extrair_mapeamento.py` |
| 4 | WhatsApp Snap + ZapZap Flatpak | Override para ambos (`NoDisplay=true` no Snap para evitar duplicata) |
| 5 | `echo '\n...'` literal no kitty.conf | Trocado por `printf` |
| 6 | kitty sobrescreve `current-theme.conf` custom | Aviso + `.bak` se divergir |
| 7 | Obsidian path inexistente | Itera vaults via `obsidian.json` |
| 8 | `sed` sem escape de `&` | Escape duplo (match + replacement) |
| 9 | 120MB upstreams no git | `.gitignore` + `baixar_upstreams.sh` |
| 10 | `limpar_duplicatas` remove tema ativo | Guard exige tema novo instalado |
| 11 | `:select` inválido em CSS | `:selected` + `:select` como fallback |

### Ajustes pós-feedback visual

- Ulauncher → `magician-hat.svg`
- kitty → `cat.svg` (diferente do GNOME Terminal)
- Ajustes (gnome-tweaks) → `laurel.svg`
- Senhas e Chaves (seahorse) → `key.svg`
- Aplicativos iniciais de sessão → `sun.svg`
- Apóstrofe → revertido para `ghostwriter.svg` (custom, não `feather.svg`)
- GNOME Terminal → preservado `terminal.svg` original

### Renomeação dos SVGs-fonte (typos)

Via `scripts/renomear_fontes.py`:
- `ghostwritter.svg` → `ghostwriter.svg`
- `qbtorrent.svg` → `qbittorrent.svg`
- `cleanner.svg` → `cleaner.svg`
- `gerenciadoor de extensões.png` → `gerenciador-de-extensoes.png`
- `Obs-Studio.png` → `obs-studio.png`, `Whatsapp.png` → `whatsapp.png`, `Clapper.png` → `clapper.png`, `Flatseal.png` → `flatseal.png`, `chrome2.svg` → `google-chrome.svg`.

### Pendências conhecidas

- **Transparência do launcher Pop!_OS**: mesmo com substituição dos dark.css, o fundo continua opaco. Investigação em `SPRINT-TRANSPARENCIA.md` — próximas tentativas: Looking Glass para ver style_class real, `grep` em JS da extensão para detectar setters programáticos, logout completo.
- **Release no GitHub**: tarball `Dracula_OS-Theme-v1.0.0.tar.gz` pronto para publicação em `github.com/andrebfarias/Dracula_OS-Theme`.
