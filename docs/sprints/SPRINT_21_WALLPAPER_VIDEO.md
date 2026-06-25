# Sprint 21 — Wallpaper de vídeo (Hidamari)

Colocar um vídeo como **wallpaper animado** no Pop!_OS (GNOME 42, X11/Mutter), em todos os monitores, integrado ao instalador. Usa o **Hidamari** (Flatpak), seguindo o padrão de app Flatpak da SPRINT 20 (GIMP).

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 21.
> - **Ferramenta**: Hidamari (`io.github.jeffshee.Hidamari`, Flatpak/flathub). Escolha do usuário. Suporta X11 (pausa automática quando há janela maximizada).
> - **Versionar o `.mp4`** no repo (escolha do usuário): `assets/wallpapers/Only_god_is_real_art.mp4` (4,1 MB). O hook `check-added-large-files` passa a excluir `assets/wallpapers/` (mídia de wallpaper é exceção intencional ao teto de 4 MB).
> - **Sem sudo**: Flatpak user + config user. Idempotente, reversível.

## Contexto

### Estado anterior

- `scripts/instalar_wallpapers.sh` só trata `*.png` (`gsettings picture-uri`). Não há wallpaper de vídeo. O `.mp4` em `assets/wallpapers/` era ignorado.

### Como o Hidamari guarda config (descoberto empiricamente)

- **Não usa gsettings** (o gschema `io.github.jeffshee.Hidamari` é vazio).
- Config em `~/.var/app/io.github.jeffshee.Hidamari/config/hidamari/config.json` (v4):
  - `mode`: `MODE_NULL` | `MODE_VIDEO` | ...
  - `data_source`: dict **por conector de monitor** (`Default`, `HDMI-1-0`, `eDP`, ...) → caminho do vídeo.
  - `is_static_wallpaper`, `is_pause_when_maximized`, `audio_volume`, `is_first_time`, ...
- Biblioteca de vídeos: `<Vídeos>/Hidamari/`. O Flatpak precisa de acesso `xdg-videos`.

## Solução

Novo `scripts/instalar_wallpaper_video.sh`:
1. Garante flathub (user) e instala/atualiza o Hidamari.
2. `flatpak override --user --filesystem=xdg-videos`.
3. Copia o vídeo-fonte para `<Vídeos>/Hidamari/` (idempotente via `cmp -s`).
4. Garante o `config.json` (gera no primeiro run via `flatpak run … -b` se ausente).
5. `jq`: `mode=MODE_VIDEO` + **todos** os `data_source` (por monitor) + `Default` → caminho do vídeo. Idempotente (pula se já aponta para o vídeo).
6. (Re)inicia o wallpaper (`flatpak run … -b`) e cria autostart `~/.config/autostart/dracula-hidamari.desktop`.

Variáveis: `DRACULA_DRY_RUN=1`, `DRACULA_WALLPAPER_VIDEO=<caminho>`. Flags: `--revert` (remove autostart + `MODE_NULL`), `--full` (com `--revert`, desinstala o Flatpak + remove o vídeo copiado), `--apenas-detectar`.

## Escopo (touches autorizados)

- `scripts/instalar_wallpaper_video.sh` — novo (~170 linhas).
- `install.sh` — flag `--video-wallpaper` + bloco de chamada (fase user, não-fatal) + inclusão em `--all`.
- `uninstall.sh` — bloco de reversão (`--revert`; `DRACULA_HIDAMARI_FULL=1` → `--full`).
- `.pre-commit-config.yaml` — `assets/wallpapers/` adicionado à exclusão de `check-added-large-files`.
- `assets/wallpapers/Only_god_is_real_art.mp4` — vídeo versionado.
- `CHANGELOG.md`, `docs/sprints/INDEX.md`, `docs/sprints/SPRINT_21_WALLPAPER_VIDEO.md`.

## Proof-of-work runtime-real (executado neste host)

```bash
bash -n scripts/instalar_wallpaper_video.sh install.sh uninstall.sh   # sintaxe OK
flatpak install -y --user flathub io.github.jeffshee.Hidamari          # exit 0
bash scripts/instalar_wallpaper_video.sh                              # configura
bash scripts/instalar_wallpaper_video.sh --apenas-detectar
# => Hidamari 3.6 | modo: MODE_VIDEO | vídeo (Default): …/Hidamari/Only_god_is_real_art.mp4 | autostart presente

# Idempotência (2ª execução):
#   = vídeo já idêntico ; = config já aponta para o vídeo ; = autostart já idêntico
```

**Validação visual (ao vivo, X11)**: dois monitores detectados (`xrandr`: HDMI-1-0 externo + eDP interno). Após aplicar `MODE_VIDEO`, captura de tela (`scrot`, 3840x1080) mostra o vídeo glitch/datamosh renderizando como wallpaper animado no monitor externo. Log do Hidamari: `[Mode] MODE_VIDEO` + `[Server] Started`.

## Riscos conhecidos

- **Decodificação por software**: o host não tem VDPAU (`libvdpau_radeonsi.so` ausente; AMD Rembrandt). O Hidamari/GStreamer cai em decodificação por software → custo de CPU/bateria contínuo. Mitigado por `is_pause_when_maximized=true` (pausa quando há janela maximizada/fullscreen). Aceitável para desktop; em modo bateria, o usuário pode reverter (`--revert`).
- **Tamanho do repo**: o `.mp4` (4,1 MB) versionado infla o repositório (decisão consciente do usuário). Hook ajustado para não bloquear.
- **Conectores de monitor variam**: o script aplica o vídeo a **todos** os `data_source` detectados + `Default`, então é portátil entre setups de monitor.
- **Wayland**: o Hidamari também suporta Wayland; este host é X11. Não testado em Wayland nesta sprint.

## Integração ao install

`./install.sh --user --video-wallpaper` (ou `--all`, e portanto `--bootstrap`). Reversão por `./uninstall.sh --user` (autostart + `MODE_NULL`; `DRACULA_HIDAMARI_FULL=1` para remover o Flatpak/vídeo).

---

*"O movimento por trás dos ícones." — o desktop deixa de ser estático.*
