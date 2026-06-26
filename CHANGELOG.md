# Changelog

Todas as mudanças notáveis deste projeto são documentadas neste arquivo.
Formato: [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) + SemVer.

## [Unreleased]

### Adicionado

- **Sprint 32 — Fechamento do débito do estudo**: `extrair_mapeamento.py` passa a fazer **merge não-destrutivo** ao regenerar `mapping.json` — preserva entradas curadas (origem `logo-usuario` ou campo `"curado": true`), encerrando o risco de apagar a curadoria (firefox/citrix/dbeaver/photogimp/Clapper). `diagnostico.sh` ganha guard `[[ -f ]]` nos checks de `pop-shell`/`pop-cosmic` dark.css (não acusa mais regressão falsa em máquina sem a extensão, espelhando o `reaplicar_tema.sh`). Testes reforçados: `test_reaplicar_idempotencia.sh` faz SKIP honesto se nenhum arquivo-alvo existe (antes passava vácuo); `test_diagnostico_exit_codes.sh` ganha cenário 3 (após restaurar, exige voltar ao estado original e confirma exit 0 no caso saudável). README auditado contra o código (13 drifts corrigidos: 208 apps, ~4324 arquivos, 53 aliases humanos, 14 extensões, ~1.574 symbolic, flag `--video-wallpaper`, `--all` incluindo `--apt-hook`, som default Dracula, árvore `src/` com `gtk/`/`cursors/`/`wallpaper/`, bloco de componentes do wallpaper de vídeo). Tag anotada `v1.2.0` criada retroativamente (`76de89dc`). Os 34 apps `nao-encontrado` (gnome-*-panel, portais XDG, Citrix/Antigravity/openjdk) ficam no fallback por design — sem arte Dracula disponível.
- **Sprint 31 — Hardening de infraestrutura**: vendoriza o tema GTK (`Dracula-standard-buttons`, em `src/gtk/`) e o cursor (`Dracula-Cursor`, em `src/cursors/`) — antes só existiam no host e o `--bootstrap` saía com tema quebrado em máquina limpa. `install.sh`: `--all` passa a incluir `--apt-hook`; guards idempotentes (`_pop_css_ja_aplicado` via `cmp`; check de existência do hook APT) pulam o sudo quando já aplicado; `instalar_app_themes.sh` vira não-fatal (`|| _warn`); resumo final via `diagnostico.sh`; comentários e `_info` de runtime "Hidamari" corrigidos para xwinwrap+mpv. Corrige `_purgar_antigos: command not found` em `scripts/instalar_app_themes.sh` (faltava `source lib/common.sh`), bug que abortava o `--all` inteiro no `aplicar_obsidian`. Novo `app-themes/kitty/current-theme.conf` (tema Dracula oficial; antes o `include` apontava para arquivo inexistente). README do OnlyOffice corrigido (ativação é manual, não automatizada via `gsettings`). Limpeza: removidos `assets/screenshots/` (duplicata byte-a-byte de `docs/assets/screenshots/`) e `src/wallpaper/xwinwrap-UPSTREAM-README.md` (órfão). Fora deste repo (ambiente do usuário): exceção `Dracula_OS-Theme` em `~/.config/zsh/functions/projeto.zsh` (o santuário delega `install.sh --user --all`, eliminando o `[!] Falha ao executar install.sh`); e `~/.config/zsh/scripts/emoji_guardian.py` ganha `EXCLUDED_PATH_SUBSTRINGS` para nunca varrer plugins de terceiros do Obsidian (cujos emojis são dados funcionais que o sanitizer vinha corrompendo).
- **Sprint 10 — Localização pt-BR do launcher Pop!_Cosmic**: `scripts/instalar_pop_cosmic_ptbr.sh` instala uma cópia da extensão `pop-cosmic@system76.com` em `~/.local/share/gnome-shell/extensions/` (sem sudo, com precedência user-over-system do GNOME) com strings traduzidas: `Library Home` → `Início`, `Create Folder` → `Criar pasta`, `New Folder`/`Folder Name`/`Create` → `Nova pasta`/`Nome da pasta`/`Criar`, `Delete Folder?`/`Delete` → `Excluir pasta?`/`Excluir`, `Rename Folder`/`Rename` → `Renomear pasta`/`Renomear`, e descrição do diálogo de exclusão localizada. Sobrevive a `apt upgrade pop-cosmic`. Removível via `scripts/desinstalar_pop_cosmic_ptbr.sh`.
- **Sprint 11 — Higiene do app-grid Pop!_Cosmic**: `scripts/instalar_higiene_launcher.sh` esconde o app `gnome-session-properties.desktop` (rótulo "Aplicativos iniciais de sessão") do launcher via `NoDisplay=true` no override de `~/.local/share/applications/`, sem tocar o pacote do sistema. Também remove as pastas vendor `Utilitários` (`X-GNOME-Utilities`) e `suse-yast.directory` (`X-SuSE-YaST`) do rodapé do launcher via `gsettings set org.gnome.desktop.app-folders folder-children` + `dconf reset` do relocatable schema de cada — controlado por array `PASTAS_VENDOR=("Utilities" "YaST")`. Idempotente, sem sudo, não-fatal. Reversível via `scripts/desinstalar_higiene_launcher.sh`. Limitação conhecida: o vendor schema do GNOME/Pop!_Cosmic pode reinjetar as pastas em logout/login — basta re-rodar (ou esperar o APT hook).
- **Sprint 12 — Propagação completa dos symbolic icons no `Dracula-Icones`**: o tema gerado pelo `build.sh` passa a embutir todos os symbolic icons disponíveis nos heritages (`dracula-icons-circle` e `dracula-icons-main`) em `symbolic/{actions,apps,categories,devices,emblems,emotes,mimetypes,places,status}` com merge por nome (prioridade `circle`), e declara todas essas subdirs em `index.theme` com `Type=Scalable` e `Context` apropriado. Lookup local elimina a fragilidade da resolução por `Inherits=`, corrigindo entre outros o ícone "excluir pasta" do launcher Pop!_Cosmic (lápis → lixeira). Total: 1.558 SVGs propagados (1.021 do `circle`, 537 só do `main`). Mudança restrita ao `build.sh` (uma função nova + uma chamada + extensão de `gerar_index_theme`); os SVGs vêm dos heritages sem modificação, incluindo tratamento de symlinks com conteúdo embutido típicos do upstream.
- **Sprint 13 — Patcher universal de ícones Steam**: `scripts/atualizar_icones_steam.sh` varre `~/.local/share/applications/*.desktop` por entradas `Icon=steam_icon_<APPID>`, gera PNG 256x256 em `~/.local/share/icons/hicolor/256x256/apps/steam_icon_<APPID>.png` a partir da capsule 300x450 do `librarycache` da Steam (com fallback para header 460x215 e, em último caso, upscale do 32x32 já presente em `hicolor`), e regenera `icon-theme.cache`. Idempotente por mtime, sem sudo, com flag `--force` e suporte a `DRACULA_DRY_RUN=1`. Integrado ao `install.sh` (fase user, não-fatal) e à seção 7.5 nova de `scripts/reaplicar_tema.sh`, herdando assim a robustez pós-`apt full-upgrade` do APT hook (Sprint 06). Dependência runtime: `imagemagick` (`convert`). Substitui o ícone genérico exibido no launcher Pop!_Cosmic por arte real do jogo.
- **Sprint 14 — Cobertura completa de `scripts/reaplicar_tema.sh`**: cinco gaps de reaplicação pós-`apt upgrade` fechados via reuso dos subscripts existentes, sem criar scripts novos. Novas seções idempotentes: 2.5 (`instalar_pop_cosmic_ptbr.sh` + `instalar_higiene_launcher.sh`), 7.7 (`instalar_keybindings.sh`), 7.8 (`instalar_gnome_extensions.sh --only-dconf`, sem re-download), 8.5 (`gsettings set` icon-theme/gtk-theme/cursor-theme/user-theme). Endurecimento da seção 8: `gtk-update-icon-cache` e `update-desktop-database` agora capturam exit code e logam `_warn` em falha em vez de silenciar. Tempo total em ambiente já configurado < 10s.
- **Sprint 15 — Housekeeping: rotação de backups e correções secundárias**: nova função `_purgar_backups_antigos` em `scripts/lib/common.sh` mantém apenas os 10 backups mais recentes em `~/.cache/dracula_os_backup/`, com proteção por prefixo. Integrada em `scripts/instalar_keybindings.sh` (pattern `keybindings_*`) e `scripts/limpar_duplicatas.sh` (pattern `[0-9]*_[0-9]*` para casar `YYYYMMDD_HHMMSS` sem colidir com keybindings). `scripts/diagnostico.sh` migra para `cmp -s` byte-a-byte na verificação de `pop-shell-dark.css`/`pop-cosmic-dark.css` (alinhamento com `reaplicar_tema.sh`). `scripts/release.sh` endurece dois `cd - >/dev/null` com `|| exit 1` para falha explícita em diretórios inválidos.
- **Sprint 16 — Housekeeping II: rotação de backups de `.desktop` e de logs**: refatoração de `_purgar_backups_antigos` em função genérica `_purgar_antigos` (lida com arquivos OU diretórios) em `scripts/lib/common.sh`; wrapper de compatibilidade preserva os call-sites da SPRINT 15. `scripts/normalizar_desktops.sh` migra `BACKUP_DIR` para `$HOME/.cache/dracula_os_backup/desktops_<TS>/desktops/` (dentro do diretório-mãe único) e ganha chamada `_purgar_antigos "$HOME/.cache/dracula_os_backup/desktops_*" 10` ao final de `main()`. `_log_file()` em `lib/common.sh` purga logs antigos da mesma família (`<nome>_*.log`) antes de retornar o caminho do log novo, capando `~/.cache/dracula_os_theme/` em ~10 entradas por família. Fim da poluição transitiva via APT hook nos dois pontos remanescentes pós-SPRINT 15.
- **Sprint 17 — Cobertura de gaps (wallpapers, Spicetify pós-update, dependências externas)**: três entregas independentes sob a mesma sprint. (1) `scripts/instalar_wallpapers.sh` + `scripts/desinstalar_wallpapers.sh` instalam `assets/wallpapers/{dracula-base,dracula-os-default}.png` em `~/.local/share/backgrounds/dracula/` (idempotentes via `cmp -s`); por padrão **não trocam** o wallpaper atual, opção `--apply <nome>` aplica via `gsettings`. Integrados em `install.sh` (fase user, não-fatal) e `uninstall.sh`. Suporte a `DRACULA_DRY_RUN=1`. (2) `scripts/atualizar_spicetify.sh` detecta o estado `Spotify version and backup version are mismatched` que aparece quando `flatpak update` mexe em `com.spotify.Client` e dessincroniza o Spicetify. Default: avisa e sugere o fix. Com `--auto-fix` (ou `DRACULA_SPOTIFY_AUTOFIX=1`), executa o roteiro completo: encerra processos do Spotify, limpa cache em `~/.var/app/com.spotify.Client/cache/`, roda `flatpak install --reinstall --noninteractive flathub com.spotify.Client` e `spicetify apply`. Integrado em `scripts/reaplicar_tema.sh` (seção 7.6 nova, modo seguro sem auto-fix). Dois helpers novos em `scripts/lib/common.sh`: `_detectar_spotify_flatpak` e `_resolver_spicetify_mismatch`. Allowlist destrutiva estendida com `~/.var/app/com.spotify.Client/cache` e `~/.local/share/backgrounds/dracula`. (3) Documentação da dependência Spellbook-OS para Spicetify em três frentes: nova seção `### Dependências externas` no `README.md`, nota explícita no card "App themes integrados" de `docs/index.html`, e seção `## Troubleshooting` em `app-themes/spicetify/README.md` com one-liner e equivalente manual. Decisão consciente: `assets/logo.png` permanece doc-only (não vira pixmap; gap de polish sem demanda real). Boundary respeitado: o `spicetify-setup.sh` do Spellbook-OS continua sendo o orquestrador canônico de instalação; esta sprint cobre apenas recuperação pós-update.
- **Sprint 18 — Spicetify autônomo (sem Spellbook-OS)**: `scripts/instalar_spicetify.sh` (~360 linhas) replica localmente o `spicetify-setup.sh` do Spellbook-OS com paridade exata de estado final (13 chaves de `spicetify config`, mesma lista de extensions/custom_apps, sanitização do `custom_apps` espúrio na lista de extensions). Detecta Flatpak/snap/nativo, instala o CLI via `curl | sh` oficial, clona `spicetify/spicetify-themes`, configura `prefs_path`, instala Marketplace, executa `restore` + `clear` + `backup apply`. Idempotente, sem sudo. Diferenças intencionais vs Spellbook: source de `lib/common.sh` (sem duplicar logger), guards `DRACULA_DRY_RUN=1` em todos os pontos destrutivos/dispendiosos, `validar_path_destrutivo` antes de `rm -rf` no cache do Flatpak, flags `--apenas-detectar` (formato texto, exit 0) e `--skip-marketplace` (CI/offline). `scripts/desinstalar_spicetify.sh` faz `spicetify restore` por padrão; com `--full` remove `~/.spicetify/` e `~/.config/spicetify/` (allowlist destrutiva estendida em `lib/common.sh`). `aplicar_spicetify()` em `scripts/instalar_app_themes.sh` reescrita: script local é fonte primária; o Spellbook-OS vira fallback **opt-in explícito** via `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1` (sem fallback automático para evitar mascaramento). Escopo expandido nesta sprint: nova flag `--spicetify` em `install.sh` (não incluída em `--all` para evitar duplicação com `--app-themes`), e `uninstall.sh` ganha 5 wires de reversão (Spicetify via `desinstalar_spicetify.sh` com `DRACULA_SPICETIFY_FULL=1` opcional; APT hook via `instalar_apt_hook.sh --revert`; extensões GNOME via `instalar_gnome_extensions.sh --revert`; atalhos via `instalar_keybindings.sh --revert`; ícones de jogos Steam patcheados em `hicolor/{256x256,32x32}/apps/steam_icon_*.png`). Boundary com Spellbook-OS preservado mas não-obrigatório.
- **Sprint 19 — `test_portabilidade.sh`: filtrar arquivos não-versionados**: substitui `grep -rn ... .` por `git ls-files ... | xargs grep` em `tests/test_portabilidade.sh`, alinhando a implementação ao comentário do próprio script ("falha se algum arquivo versionado tem hardcoded username"). Elimina falso-positivo causado por `.claude/settings.local.json` (gerado em runtime pelo Claude Code, fora do controle do projeto). Mensagens de saída e exit codes preservados; CI mantém contrato externo. Achado colateral identificado durante a validação da SPRINT 18.
- **Sprint 20 — GIMP (Flatpak) + PhotoGIMP autônomo**: `scripts/instalar_gimp.sh` garante o remote `flathub`, instala/atualiza `org.gimp.GIMP` e aplica o [PhotoGIMP](https://github.com/Diolinux/PhotoGIMP) (layout/atalhos estilo Photoshop + splash + launcher próprio "PhotoGIMP"). Release fixada para reprodutibilidade: tag `3.0`, asset `PhotoGIMP-linux.zip`, **sha256 pinado** (`1af6e2a6…e54e`) com cache em `~/.cache/dracula_os_theme/`. A versão-dir de config é **detectada dinamicamente** — prioriza o host `~/.config/GIMP/<versão>` (caso o Flatpak tenha o override `xdg-config/GIMP:create`, como neste sistema, onde a config ativa é `3.2` apesar de o pacote trazer `3.0`) e cai para o sandbox `~/.var/app/org.gimp.GIMP/config/GIMP/<versão>` em Flatpak stock; em máquina nova sem config, faz um start headless (`flatpak run … -i --quit`) para gerá-la. A config atual é respaldada com `backup_com_manifest` em `~/.cache/dracula_os_backup/gimp_<ts>/` (retém 10 via `_purgar_antigos`) antes de sobrescrever; o launcher do PhotoGIMP (mesmo nome `org.gimp.GIMP.desktop`) sombreia o exportado pelo Flatpak via precedência de `XDG_DATA_HOME`, com `Exec` já correto para Flatpak (sem patch). Lixo `.DS_Store` do upstream é removido antes da cópia; aviso não-fatal se o GIMP estiver aberto (`flatpak ps`) para não perder o estado ao sair. O passo `flatpak update` preempta o relink de runtime pendente que fazia o **primeiro** start do GIMP parecer travado ("não abre"). Idempotente, sem sudo, suporte a `DRACULA_DRY_RUN=1`, flags `--apenas-detectar`/`--skip-photogimp`. Wired em `install.sh`: nova flag `--gimp` (fase user, não-fatal) **incluída em `--all`** (e portanto em `--bootstrap`). Validação visual: splash "PhotoGIMP by Diolinux" e janela single-window estilo Photoshop capturados via CLI X11.
- **Sprint 22 — Logo do Clapper no app e nos arquivos de vídeo**: a logo nova do Clapper (`src/icons/current/48x48/apps-global/Clapper.png`, claquete de tema gótico) passa a ser a fonte do ícone do **aplicativo** (`mapping.json`) e dos **mimetypes de vídeo**. `gerar_mimetypes()` em `build.sh` ganha suporte a fonte PNG (via `redimensionar_png`; antes só SVG) e resolução de fonte por caminho — com `/` é relativa a `src/icons/`, sem `/` assume `new-sessao-atual/`. Os mimetypes de vídeo trocam a fonte `mobile-game.svg` (fliperama colorido) pela logo do Clapper e são estendidos de `video-mp4,video-x-mp4,application-mp4` para 10 nomes XDG (`video-x-generic`, `video-mp4`, `video-x-mp4`, `video-x-matroska`, `video-webm`, `video-quicktime`, `video-x-msvideo`, `video-x-flv`, `video-x-ms-wmv`, `application-mp4`), cobrindo mkv/webm/avi/mov/wmv/flv além de mp4. Arquivos de vídeo no Nautilus passam a exibir o mesmo ícone do player. Sem sudo; integra ao `install.sh` via `dist/` (rebuild por `build.sh`/`--bootstrap`). Total: 23 nomes de mimetype gerados; identidade de pixels (sha strip) confirmada entre app, `video-x-generic` e `video-mp4`.
- **Sprint 24 — Cobertura de ícones nativos via aliases técnicos**: `gerar_tema_icones()` em `build.sh` passa a gerar nomes-alvo também a partir do campo `aliases` de cada entrada do `mapping.json` (antes só `app_id` + `aliases_humanos`), deduplicados. Materializa **63 nomes-alvo adicionais** — sobretudo os app-IDs reverse-DNS modernos (`org.gnome.Settings`, `org.gnome.Nautilus`, `org.gnome.Calculator`, `org.gnome.Terminal`, `org.gnome.Calendar`, `org.gnome.Weather`, `org.gnome.FileRoller`, `org.gnome.DiskUtility`, ...) que são o `Icon=` real dos `.desktop` do GNOME 42 e antes caíam no fallback Adwaita. Corrige em particular o ícone de "Configurações" (`org.gnome.Settings`), apontado pelo usuário. Acrescenta a entrada `firefox`/`firefox-esr` (fonte `current/48x48/apps-global/firefox.png`). Sem sudo; integra via `dist/` (rebuild por `build.sh`/`--bootstrap`). Verificado: `org.gnome.Settings.png` idêntico (sha strip) ao `gnome-control-center.png`; `diagnostico.sh --quiet` exit 0.
- **Sprint 23 — Topbar em múltiplos monitores**: adiciona a extensão `multi-monitors-add-on@spin83` (fork `lazanet/multi-monitors-add-on`, branch `gnome-42_44`, `shell-version` 40-44) ao manifesto `app-themes/gnome-extensions/extensions.json`, com `repo_subdir` `multi-monitors-add-on@spin83` e `dconf/multi-monitors-add-on.dconf` (`show-panel=true` para estender a barra superior aos monitores adicionais; `show-indicator=false`; **`thumbnails-slider-position='none'`** para evitar o crash da feature de overview-thumbnails no GNOME 42.9 — `mmoverview.js:370 stateAdjustment is undefined` — preservando a barra). O GNOME 42 nativo só mostra a topbar no monitor primário; a extensão clona o painel nos demais. Instalada/ativada por `install.sh --gnome-extensions` (e `--all`/`--bootstrap`); revertível via `instalar_gnome_extensions.sh --revert`. **Validado ao vivo** (X11, 2 monitores): com `'none'` a extensão vai a `State: ENABLED` e a barra superior aparece também no monitor externo (captura `scrot`); com o default 'auto' ia a `State: ERROR`.
- **Sprint 21 — Wallpaper de vídeo (Hidamari)**: novo `scripts/instalar_wallpaper_video.sh` instala o Hidamari (Flatpak `io.github.jeffshee.Hidamari`, padrão da SPRINT 20), copia o vídeo para `<Vídeos>/Hidamari/` (idempotente via `cmp -s`), aplica `mode=MODE_VIDEO` + todos os `data_source` por monitor no `config.json` do Hidamari, inicia o wallpaper e cria autostart em `~/.config/autostart/dracula-hidamari.desktop`. Idempotente, sem sudo, com `DRACULA_DRY_RUN=1`, `DRACULA_WALLPAPER_VIDEO`, flags `--revert`/`--full`/`--apenas-detectar`. Nova flag `--video-wallpaper` em `install.sh`, **incluída em `--all`** (e `--bootstrap`); reversão em `uninstall.sh` (`DRACULA_HIDAMARI_FULL=1` desinstala o Flatpak + remove o vídeo). O vídeo `assets/wallpapers/Only_god_is_real_art.mp4` (4,1 MB) passa a ser versionado — `check-added-large-files` exclui `assets/wallpapers/`. Validado ao vivo (X11, 2 monitores): `MODE_VIDEO` renderizando o wallpaper animado (captura `scrot`). Nota: sem VDPAU no host, a decodificação é por software (custo de CPU/bateria; pausa quando há janela maximizada).
- **Sprint 26 — Captura da config completa do Obsidian (settings + plugins)**: novo `scripts/capturar_obsidian.sh` espelha `<vault>/.obsidian/` → `app-themes/obsidian/config/` (rsync `--delete`, excluindo os voláteis `workspace.json`/`workspace-mobile.json`). Versionados **119 arquivos / 35 plugins de terceiros** + settings, hotkeys, snippets (`dracula_background.css`), themes e listas de plugins. `aplicar_obsidian()` em `scripts/instalar_app_themes.sh` passa a fazer backup do `.obsidian` existente (`~/.cache/dracula_os_backup/obsidian_<ts>/`, retém 10) e deployar a config completa por vault, preservando o `workspace.json`; pular com `DRACULA_OBSIDIAN_SKIP_CONFIG=1`. Integra via `install.sh --app-themes`/`--all`. Decisão informada do usuário (repo público): inclui código de plugins e dados do vault; sem segredos (apiKeys vazios, verificado); nenhum arquivo da blacklist anti-IA nos plugins.

### Removido

- **`check-added-large-files`** desativado no `.pre-commit-config.yaml` (SPRINT 26): o projeto versiona mídia grande de propósito (vídeo do wallpaper em `assets/wallpapers/` e a config do Obsidian com `quickadd/main.js` > 4 MB).

- **Sprint 30 — Wallpaper de vídeo via xwinwrap + mpv (substitui o Hidamari)**: o backend Hidamari (SPRINT 21) não renderizava o vídeo de forma confiável neste host (Mutter X11, GPU AMD+NVIDIA sem VDPAU — o GStreamer caía no fallback estático). Novo backend: `xwinwrap` (vendorizado em `src/wallpaper/xwinwrap.c`, GPL, compilado no install → `~/.local/bin/dracula-xwinwrap`) + `mpv -wid` por monitor, via launcher `scripts/dracula_video_wallpaper.sh` (instalado em `~/.local/bin/dracula-video-wallpaper`) que detecta os monitores por `xrandr`. `--hwdec=no` (o VAAPI corrompia com barras verdes); centralizado por padrão (`DRACULA_WALLPAPER_SCALE=panscan` preenche). `scripts/instalar_wallpaper_video.sh` reescrito (compila/copia/launcher/autostart, idempotente, `--revert`/`--apenas-detectar`); `uninstall.sh` e a allowlist de `lib/common.sh` atualizados. O instalador **instala os pré-requisitos apt automaticamente** (`sudo apt-get install -y mpv libx11-dev libxext-dev libxrender-dev gcc x11-xserver-utils` quando faltam) e **remove o Hidamari Flatpak** antigo. A flag `install.sh --video-wallpaper` (e `--all`) é a mesma. Validado ao vivo: vídeo centralizado e animando nos 2 monitores, sem artefato; shellcheck 0; Hidamari desinstalado.
- **Sprint 29 — Wire das logos curadas do depósito apps-global**: três entradas novas em `mapping.json` apontando para logos góticas que já existiam em `src/icons/current/48x48/apps-global/` mas não entravam no build: `photogimp` ← `gimp.png` (launcher do PhotoGIMP, SPRINT 20), `dbeaver` ← `dbeaver.png` (+ `io.dbeaver.DBeaverCommunity`), e `citrix` ← `citrix.png` cobrindo os 10 ícones do Citrix Workspace (`Ubuntu-configmgr`, `Ubuntu-conncenter`, `Ubuntu-fido2_llt`, `Ubuntu-logmgr`, `Ubuntu-nfcui`, `Ubuntu-receiver`, `Ubuntu-receiver_fido2`, `Ubuntu-selfservice`, `Ubuntu-sendfeedback`, `Ubuntu-wfica`), todos antes em fallback. Apps já tematizados preservados. Build: 169 → 172 apps, 0 falhas. Validado ao vivo (aplicado em `~/.local/share/icons` + cache).
- **Sprint 25 — Tema de som cyberpunk/sci-fi (Kenney CC0)**: novo `src/sounds/Dracula/` — `index.theme` (`Name=Dracula`, `Inherits=freedesktop`) + 25 efeitos `.oga` curados do pacote **Kenney "Sci-fi Sounds"** (CC0 1.0, `License.txt`/`UPSTREAM-README.md` incluídos), escolhendo só os sons curtos e sutis (0,24–0,95 s) para `stereo/{action,alert,notification}/`. `scripts/instalar_sons.sh` refatorado: flag `--theme <nome>` (default `Dracula`, `Pop` ainda disponível) + **idempotência** (`diff -rq` antes de `rm -rf`/`cp`; gsettings só muda se necessário). `scripts/reaplicar_tema.sh`, `scripts/diagnostico.sh` e `uninstall.sh` generalizados para Dracula (default) com Pop como fallback. Aplicado via `install.sh --sounds`/`--all`. Validado ao vivo (`theme-name='Dracula'`, idempotente, `paplay` toca os sons); aprovação final de ouvido pelo usuário.

### Alterado

- **Sprint 27 — Pasta "Utilitários"/YaST escondida de forma durável**: `scripts/instalar_higiene_launcher.sh` (Parte B) passa a **esvaziar** as pastas vendor (`dconf write apps/categories/excluded-apps = []`) em vez de `dconf reset` — o reset revertia ao default POPULADO do Pop!_OS (`50_pop-session.gschema.override` + `/usr/bin/pop-app-folders`), por isso reapareciam. Pasta vazia é escondida pelo GNOME e o valor de usuário sobrevive ao login (`pop-app-folders` é cache-gated e só toca pastas `Pop-*`). `scripts/desinstalar_higiene_launcher.sh` restaura o conteúdo via `dconf reset` na reversão. Validado ao vivo: do estado `['Utilities','YaST']` → `folder-children []` + pastas vazias; `diagnostico --quiet` exit 0.
- **Detecção de regressão Pop!_Shell/Pop!_Cosmic dark.css**: comparação byte-a-byte (`cmp -s`) entre o arquivo instalado e o source canônico do repo (`src/shell/pop-shell-dark.css`, `src/shell/pop-cosmic-dark.css`) em vez de grep heurístico de paleta (`bd93f9|rgba(40,42,54|...`). Captura QUALQUER divergência (paleta nova, regressão parcial, edição manual) sem precisar atualizar a regex quando o build mudar. Aplicado também em `scripts/diagnostico.sh` (Sprint 15).

### Corrigido

- **Wallpaper de vídeo "parava"/não preenchia (SPRINT 21)**: `instalar_wallpaper_video.sh` agora seta `is_pause_when_maximized=false` no Hidamari (o default `true` pausava o vídeo sempre que havia janela maximizada — parecia estático no uso diário) e `picture-options='centered'` (preferência do usuário — vídeo retrato centralizado, sem zoom que corta a imagem). Nota: o vídeo `Only_god_is_real_art.mp4` é 720x900 (retrato), então fica centralizado com fundo ao redor em monitor landscape.
- **CI verde de novo**: tanto `anonymity-check` quanto `ci.yml` falhavam em todo push há meses. (1) `.github/workflows/anonymity-check.yml` tinha um erro de sintaxe bash (faltava o `if` do check de trailer, deixando um `fi` órfão) — reconstruído usando `NOREPLY_RE`. (2) `scripts/baixar_upstreams.sh`: o repo `m4thewz/dracula-icons-circle` foi removido do GitHub e a variante virou a **branch `circle`** do repo principal — atualizado o source (com suporte a branch), consertando o `--bootstrap` para máquinas novas (o smoke-build do CI estava falhando com `could not read Username for github.com`). (3) Zerados os warnings de `shellcheck --severity=warning` em todos os scripts (`SC2155`, `SC2294` ×2, `SC2034`), deixando o job de lint verde.

## [1.2.0] — 2026-04-17

### Adicionado

- **Sprint 06 — Resiliência pós full-upgrade**: tema agora se auto-restaura após `apt upgrade`/`full-upgrade` via APT hook, sem intervenção manual.
- `scripts/lib/common.sh` — biblioteca sourceable com logging unificado, detecção de `REPO_ROOT`, diretório de log rotacionado em `~/.cache/dracula_os_theme/`, `validar_path_destrutivo`, `trap_cleanup_init`, `backup_com_manifest`.
- `scripts/diagnostico.sh` — health check read-only (28 pontos: gsettings, arquivos, dark.css com marca Dracula, overrides, extensões do manifesto). Exit 0 = OK, 1 = regressões. Flag `--quiet`.
- `scripts/reaplicar_tema.sh` — reaplicação idempotente sem rebuild: só toca componentes regredidos. Detecta Pop!_Shell/Pop!_Cosmic `dark.css` perdidos, tema de som Pop desativado, `.desktop` com `Icon=` absoluto ou permissão 600. Output tee-ado para log.
- `scripts/instalar_apt_hook.sh` — gera `/etc/apt/apt.conf.d/99-dracula-os-theme` portátil (usa `${SUDO_USER:-$USER}`, não hardcoded). Flag `--revert` remove o hook.
- **Sprint 07 — Portabilidade universal**: `scripts/checar_ambiente.sh` (doctor de pré-requisitos: binários, versões, distro, desktop), flag `install.sh --bootstrap` (rota completa para máquina Pop!_OS limpa).
- **Sprint 08 — Segurança e robustez**: `validar_path_destrutivo` com allowlist restrita antes de `rm -rf`, `trap_cleanup_init` para restaurar backup em interrupção, `backup_com_manifest` com verificação sha256 antes de remover originais. Aplicado em `uninstall.sh`, `scripts/limpar_duplicatas.sh`, `scripts/instalar_keybindings.sh`. Idempotência do include `current-theme.conf` no `kitty.conf` blindada com `grep -Fxq` (linha exata).
- **Sprint 09 — Testes, CI e suporte 24.04/COSMIC**: `.github/workflows/ci.yml` (shellcheck, lint-manifesto, portabilidade, smoke-build), `tests/test_portabilidade.sh`, `tests/test_reaplicar_idempotencia.sh`, `tests/test_diagnostico_exit_codes.sh`, campos `shell-version-min/max` em `extensions.json`, detecção de COSMIC via `$XDG_CURRENT_DESKTOP` em `instalar_gnome_extensions.sh`.
- Flags novas no `install.sh`: `--apt-hook`, `--bootstrap`.
- Novos ícones remapeados (seguindo estilo gótico/fantasia do projeto):
  - `VOID | QRcode` → `projects/qrcode-void-generator.png` (ícone autoral original).
  - `Configuração avançada de rede` → `new-sessao-atual/spider-web.svg`.
  - `Discos` → `new-sessao-atual/treasure-chest.svg`.
  - `Fontes` → `new-sessao-atual/scroll.svg`.
  - `Gerenciador de arquivos compactados` → `new-sessao-atual/chest.svg`.
  - `R` (linguagem) → `new-sessao-atual/spell-book.svg` (nova entrada `rlogo_icon` com alias `R`).

### Modificado

- `docs/sprints/INDEX.md` — status de SPRINT_01 corrigido (era "Concluída", na verdade só tinha pseudo-código; agora "Em investigação (absorvida pela SPRINT_06)"). Adicionadas SPRINTs 06, 07, 08, 09.
- `scripts/limpar_duplicatas.sh` — hardcoded `/home/andrefarias/.icons` substituído por `$HOME/.icons` (último hardcoded versionado do repo).
- `scripts/instalar_app_themes.sh` — busca `spicetify-setup.sh` em quatro locais em ordem (irmão do repo, `$HOME/Desenvolvimento`, `$XDG_DATA_HOME`, `/opt`) antes de desistir, com warning explícito; idempotência do kitty include via `grep -Fxq`.
- `app-themes/gnome-extensions/extensions.json` — todas as 13 entradas recebem `shell-version-min: 42` e `shell-version-max: 46` (default genérico; ajustar por extensão se necessário).

### Corrigido

- Regressão real confirmada em ambiente real: `gsettings org.gnome.desktop.sound theme-name` foi resetado para `'freedesktop'` após `apt full-upgrade`. `reaplicar_tema.sh` reativa automaticamente para `'Pop'`.

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

- Acentuação PT-BR em mensagens de log/assinatura: corrigidas formas sem acento em strings literais de `build.sh` (palavras "conversão", "gótica", "máxima sofisticação"), `scripts/instalar_pop_shell_css.sh` (palavras "sessão/shell", "próprio", "substituído") e `scripts/release.sh` ("está no tarball").
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
