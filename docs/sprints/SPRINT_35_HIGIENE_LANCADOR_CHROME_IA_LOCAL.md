# Sprint 35 — Higiene do lançador + IA local e GPU no Chrome

Limpeza do menu de aplicativos e correção da policy do Chrome, que bloqueava a
IA local do navegador.

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

## Chrome: IA local estava bloqueada

`/etc/opt/chrome/policies/managed/aurora-no-ai-no-antigravity.json` desligava a
IA local junto com a de nuvem:

| Chave | Antes | Depois |
|---|---|---|
| `OptimizationGuideOnDeviceModelExecutionEnabled` | `false` | `true` |
| `GenAILocalFoundationalModelSettings` | `1` (não baixar modelo) | `0` |
| `BuiltInAIAPIsEnabled` | `false` | `true` |
| `HardwareAccelerationModeEnabled` | ausente | `true` |

As features de nuvem seguem desligadas (`HelpMeWrite`, `Compose`,
`TabOrganizer`, `TabCompare`, `HistorySearch`, `CreateThemes`,
`AutofillPrediction`, `DevToolsGenAi`) — elas mandam conteúdo ao Google; a IA
local roda on-device.

**A correção teve de ser feita na origem.** O `aurora-chrome-divert-apply.sh`
reescreve a policy inteira com `sudo tee` a cada execução, e o hook
`/etc/apt/apt.conf.d/99-aurora-postinvoke` o dispara em toda operação do apt.
Editar só o JSON seria desfeito no próximo `apt install`.

Aceleração de GPU já estava ativa antes da mudança
(`hardware_acceleration_mode_previous: true` no `Local State`); a policy agora
trava esse estado.

## Proof-of-work

```bash
./scripts/aplicar_overrides.sh --dry-run     # overrides reaplicáveis
~/.config/zsh/aurora/aurora-chrome-divert-apply.sh   # policy sobrevive ao self-heal
/usr/bin/python3 -c "import json; d=json.load(open('/etc/opt/chrome/policies/managed/aurora-no-ai-no-antigravity.json')); print(d['BuiltInAIAPIsEnabled'], d['HardwareAccelerationModeEnabled'])"
xdg-mime query default text/plain            # espera org.gnome.gedit.desktop
```
