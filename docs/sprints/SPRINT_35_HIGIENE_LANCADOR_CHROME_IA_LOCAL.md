# Sprint 35 — Higiene do lançador + Chrome sem IA local e com vídeo na GPU

Limpeza do menu de aplicativos e ajuste do Chrome: **IA local segue bloqueada**
de propósito, e a decodificação de vídeo passa a usar a GPU.

> **Decisões fixas**:
> - **Ocultar, não desinstalar**, quando o app é do sistema ou tem outro
>   consumidor. Vira `overrides/*.desktop` com `NoDisplay=true`, aplicado pelo
>   `aplicar_overrides.sh` no `install.sh` — assim sobrevive a reinstalação.
> - **Desinstalar** só o que o usuário não quer na máquina: `agente-desktop`,
>   `gnome-text-editor`, `onboard`.
> - **Ícone do Protocolo Ouroboros intocado** por pedido explícito.

## Ocultados (overrides)

`mnemo` (duplicata do build de dev; o Flatpak `io.github.andrebfarias.Mnemo` é o
principal), `setup-mozc`, `mpv`, `LinuxToys`, `org.gnome.gThumb` + `.Import`,
`onboard` + `onboard-settings`.

O override do `onboard` é cinto e suspensório: o pacote foi purgado duas vezes
nesta máquina e **voltou** — `apt-get install -y onboard` em 2026-08-18 18:16,
origem não identificada. Um `.desktop` local com `NoDisplay=true` vence o de
`/usr/share/applications`, então mesmo que o pacote reapareça ele não polui o
menu.

## Removidos

| Item | Como |
|---|---|
| `agente-desktop` | `apt purge` |
| `gnome-text-editor` | `apt purge` — o `Text Editor` duplicava o `gedit`, que é o tematizado |
| `onboard` + `-common` + `-data` | `apt purge` |
| NotebookLM, Google Photos | `.desktop` de webapp do Chrome, removidos de `~/.local/share/applications` |

Ao remover o `gnome-text-editor`, `text/plain` migrou sozinho de
`org.gnome.TextEditor.desktop` para `org.gnome.gedit.desktop`. Verificado com
`xdg-mime query default`.

## Ghostty

`Icon=` apontava para `/snap/ghostty/current/share/icons/.../com.mitchellh.ghostty.png`.
Caminho absoluto faz o GTK ignorar o tema de ícones — por isso o Ghostty nunca
recebia arte Dracula. O override troca por `Icon=ghostty` e o `mapping.json`
aponta para `current/scalable/apps/025-candle-1.svg`.

## Chrome: IA local travada, vídeo na GPU

O modelo on-device do Chrome gasta CPU, RAM e disco **da máquina do usuário**
para servir um recurso do Google. Fica desligado. O que se quer acelerado é o
vídeo — o YouTube estava sendo decodificado em software.

`/etc/opt/chrome/policies/managed/aurora-no-ai-no-antigravity.json`:

| Chave | Valor | Efeito |
|---|---|---|
| `OptimizationGuideOnDeviceModelExecutionEnabled` | `false` | modelo on-device não executa |
| `GenAILocalFoundationalModelSettings` | `1` | não baixa o modelo |
| `BuiltInAIAPIsEnabled` | `false` | sem `window.ai` / Prompt API |
| `HardwareAccelerationModeEnabled` | `true` | aceleração travada como ligada |

As de nuvem seguem desligadas (`HelpMeWrite`, `Compose`, `TabOrganizer`,
`TabCompare`, `HistorySearch`, `CreateThemes`, `AutofillPrediction`,
`DevToolsGenAi`).

### Decodificação de vídeo por hardware

`vainfo` na iGPU AMD Radeon 660M (`radeonsi`) reporta `VAProfileVP9Profile0` e
`VAProfileAV1Profile0` em `VAEntrypointVLD` — exatamente os codecs que o YouTube
entrega. O wrapper passou a injetar:

```
--ignore-gpu-blocklist --enable-gpu-rasterization --enable-zero-copy
--enable-features=VaapiVideoDecoder,VaapiVideoDecodeLinuxGL,VaapiIgnoreDriverChecks
LIBVA_DRIVER_NAME=radeonsi
```

`LIBVA_DRIVER_NAME` fixa a iGPU: nesta máquina híbrida a NVIDIA dedicada não tem
driver VA-API instalado, e sem a dica a escolha fica ao acaso.

**As duas correções tiveram de ser feitas na origem.** O
`aurora-chrome-divert-apply.sh` reescreve a policy com `sudo tee` e reinstala o
wrapper a cada execução, e o hook `/etc/apt/apt.conf.d/99-aurora-postinvoke` o
dispara em toda operação do apt. Editar só os arquivos finais seria desfeito no
próximo `apt install`.

## Proof-of-work

```bash
./scripts/aplicar_overrides.sh --dry-run     # overrides reaplicáveis
~/.config/zsh/aurora/aurora-chrome-divert-apply.sh   # policy sobrevive ao self-heal
/usr/bin/python3 -c "import json; d=json.load(open('/etc/opt/chrome/policies/managed/aurora-no-ai-no-antigravity.json')); print(d['BuiltInAIAPIsEnabled'], d['HardwareAccelerationModeEnabled'])"
xdg-mime query default text/plain            # espera org.gnome.gedit.desktop
LIBVA_DRIVER_NAME=radeonsi vainfo | grep -E "VP9|AV1"   # codecs em hardware
timeout 30 /usr/bin/google-chrome-stable --headless=new --dump-dom about:blank
```
