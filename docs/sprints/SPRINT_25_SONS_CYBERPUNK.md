# Sprint 25 — Tema de som cyberpunk/sci-fi (Kenney CC0) + idempotência

Substituir o tema de som padrão (Pop, do upstream System76) por um tema
**sci-fi/cyberpunk sutil** curado de um pacote livre, e corrigir a idempotência
do instalador.

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 25.
> - **Fonte**: Kenney "Sci-fi Sounds" (CC0 1.0, sem atribuição obrigatória). Escolha do usuário.
> - **Default Dracula**: `install.sh --sounds`/`--all` passa a aplicar o tema `Dracula`; `Pop` continua via `--theme Pop`.
> - **Curadoria sutil**: só sons curtos (0,24 s–0,95 s); explosões/lasers grandes/loops de 5 s ficam de fora.
> - **Aprovação de ouvido**: o mapeamento é um ponto de partida; trocar um som é só substituir o `.oga`.

## Solução

- `src/sounds/Dracula/` (novo): `index.theme` (`Name=Dracula`, `Inherits=freedesktop`) + 25 `.oga` em `stereo/{action,alert,notification}/`, copiados sem reencode do pacote Kenney (já são Ogg Vorbis). `UPSTREAM-README.md` + `License.txt` documentam a origem CC0.
- `scripts/instalar_sons.sh` refatorado: flag `--theme <nome>` (default `Dracula`); **idempotência** via `diff -rq` antes do `rm -rf`/`cp`; gsettings só muda se necessário.
- `scripts/reaplicar_tema.sh`, `scripts/diagnostico.sh`, `uninstall.sh`: generalizados para `Dracula` (default) com `Pop` como fallback aceitável.

## Mapeamento evento → som (curado)

| Evento | Categoria | Fonte Kenney |
|---|---|---|
| audio-volume-change | action | laserRetro_000 |
| bell | action | laserSmall_000 |
| camera-focus / camera-shutter | action | laserRetro_002 / impactMetal_004 |
| count-down / screen-capture | action | laserRetro_003 / impactMetal_002 |
| alarm-clock-elapsed / software-update-urgent | alert | forceField_000 / forceField_001 |
| battery-low / power-unplug-battery-low | alert | laserSmall_002 / laserSmall_003 |
| complete | notification | impactMetal_000 |
| device-added / device-removed | notification | doorOpen_000 / doorClose_001 |
| power-plug / power-unplug | notification | doorOpen_001 / doorClose_002 |
| system-ready / system-shutdown | notification | forceField_004 / forceField_002 |
| message / message-new-email / message-new-instant | notification | laserSmall_000 / laserRetro_004 / laserSmall_004 |
| desktop-screen-lock / battery-caution / battery-full / theme-demo / window-attention-inactive | notification | doorClose_000 / laserSmall_001 / laserRetro_001 / impactMetal_000 / laserSmall_001 |

## Proof-of-work runtime-real (executado ao vivo)

```bash
bash -n scripts/instalar_sons.sh                     # OK
bash scripts/instalar_sons.sh --user                 # 25 sons, theme-name='Dracula'
bash scripts/instalar_sons.sh --user                 # 2ª vez: "= já idêntico" (idempotente)
gsettings get org.gnome.desktop.sound theme-name     # 'Dracula'
paplay ~/.local/share/sounds/Dracula/stereo/notification/complete.oga   # tocou (usuário aprova de ouvido)
./build.sh                                           # dist/sounds/Dracula com 25 .oga
bash scripts/diagnostico.sh --quiet                  # exit 0
```

## Escopo (touches autorizados)

- `src/sounds/Dracula/` — novo (index.theme + 25 .oga + UPSTREAM-README + License.txt).
- `scripts/instalar_sons.sh` — refatorado (--theme + idempotência).
- `scripts/reaplicar_tema.sh`, `scripts/diagnostico.sh`, `uninstall.sh` — generalizados Dracula/Pop.
- `CHANGELOG.md`, `docs/sprints/INDEX.md`, `docs/sprints/SPRINT_25_SONS_CYBERPUNK.md`.

## Riscos conhecidos

- **Volume**: os sons Kenney são de jogo; podem soar altos. Não houve reencode/normalização (cópia lossless). Se incomodar, ajustar o volume do sistema ou trocar por `.oga` mais suaves.
- **Aprovação subjetiva**: o mapeamento é um ponto de partida; o usuário valida de ouvido e troca o que quiser.
- **Integração**: `install.sh --sounds`/`--all` aplica via `instalar_sons.sh` (já wired); `dist/sounds/Dracula` é gerado pelo `build.sh`.

---

*"Um bipe de nave para cada gesto." — o sistema responde em sci-fi.*
