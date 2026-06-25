# Sprint 30 — Wallpaper de vídeo via xwinwrap + mpv (substitui o Hidamari)

O backend Hidamari (SPRINT 21) **não renderizava** o vídeo na área de trabalho de forma confiável neste host (GNOME 42 / Mutter X11, GPU AMD Rembrandt + NVIDIA sem VDPAU): o daemon morria nos reloads de shell e o GStreamer caía no fallback estático. Substituído por **xwinwrap + mpv**, que renderiza de fato no Mutter, com decodificação por software estável e controle de escala (centralizado, como o usuário quer).

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 30.
> - **Backend**: `xwinwrap` (janela "stamp" no desktop X11) + `mpv -wid` (player). Um par por monitor.
> - **`--hwdec=no`**: o VAAPI (AMD) corrompia o vídeo com barras verdes; software decode de um vídeo 720x900 é trivial (Ryzen 12 threads).
> - **Centralizado por padrão** (`--keepaspect=yes --panscan=0`); `DRACULA_WALLPAPER_SCALE=panscan` preenche cortando.
> - **xwinwrap vendorizado** (`src/wallpaper/xwinwrap.c`, GPL, de ujjwal96/xwinwrap), compilado no install — não está no apt.
> - **Pré-requisitos apt instalados automaticamente**: o instalador roda `sudo apt-get install -y mpv libx11-dev libxext-dev libxrender-dev gcc x11-xserver-utils` quando algum falta (pede sudo). E **remove o Hidamari Flatpak** antigo (substituído por este backend).

## Causa-raiz (verificada ao vivo)

- Hidamari: `hidamari-server` morria após `Alt+F2 r`; o `_NET_WM` window não re-renderizava; só sobrava o PNG estático do gsettings (`picture-uri`) centralizado → "caixinha em fundo preto".
- xwinwrap `-ov` (override-redirect) deu `BadMatch` no X_CreateWindow; **`-fdt -b`** (force desktop type + below) funcionou e a janela ficou `IsViewable` no fundo da pilha, com mpv renderizando o vídeo visível no Mutter.

## Solução

- `src/wallpaper/xwinwrap.c` (novo, vendorizado) + `UPSTREAM-README.md`.
- `scripts/dracula_video_wallpaper.sh` (novo launcher): encerra instâncias nossas, detecta monitores via `xrandr --listmonitors` e sobe um `xwinwrap -g <geo> -ni -s -nf -fdt -b -- mpv -wid WID --x11-name=dracula-wallpaper --loop --no-audio --hwdec=no --keepaspect=yes ...` por monitor. Instalado em `~/.local/bin/dracula-video-wallpaper`.
- `scripts/instalar_wallpaper_video.sh` (reescrito): checa deps, compila o xwinwrap → `~/.local/bin/dracula-xwinwrap` (idempotente por mtime), copia o vídeo → `~/.local/share/backgrounds/dracula-video/`, instala launcher + autostart, inicia. `--revert`/`--apenas-detectar`. Limpa o autostart antigo do Hidamari.
- `scripts/lib/common.sh`: `~/.local/share/backgrounds/dracula-video` na allowlist destrutiva.
- `uninstall.sh`: revert atualizado para o novo backend.
- `install.sh`: a flag `--video-wallpaper` (e `--all`) já chama o instalador — sem mudança.

## Proof-of-work runtime-real (executado ao vivo)

```bash
gcc src/wallpaper/xwinwrap.c -lX11 -lXext -lXrender -o ~/.local/bin/dracula-xwinwrap   # compila
bash scripts/instalar_wallpaper_video.sh        # "iniciado em 2 monitor(es) [keepaspect]"
bash scripts/instalar_wallpaper_video.sh        # 2ª vez: tudo "já idêntico" (idempotente)
shellcheck --severity=warning scripts/dracula_video_wallpaper.sh scripts/instalar_wallpaper_video.sh  # 0 warnings
pgrep -xc mpv                                   # 2 (um por monitor)
```

Validação visual: captura limpa (`wmctrl -k on`) confirma o vídeo glitch centralizado e **animando** nos dois monitores, sem artefato verde.

## Riscos conhecidos

- **Reload de shell**: o xwinwrap pode cair num restart do GNOME Shell (como o Hidamari) — mas o autostart religa no login, e `dracula-video-wallpaper` religa na hora. A diferença é que ele **renderiza** no Mutter (o Hidamari não renderizava aqui).
- **Vídeo retrato 720x900**: centralizado com fundo ao redor em monitor landscape (preferência do usuário). `DRACULA_WALLPAPER_SCALE=panscan` preenche cortando.
- **Hidamari Flatpak**: removido automaticamente pelo instalador (era o backend antigo).
- **Pré-requisitos apt**: instalados pelo próprio instalador via `sudo apt-get` (pede sudo na primeira vez de máquina nova).

---

*"O que o GStreamer não pinta, o mpv pinta." — o vídeo, enfim, na parede.*
