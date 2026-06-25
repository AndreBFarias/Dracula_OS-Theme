# Sprint 23 — Topbar em múltiplos monitores

Fazer a barra superior do GNOME aparecer em **todos os monitores** (notebook + monitor externo), não só no primário. O GNOME 42 nativo (X11/Mutter) só desenha a topbar no monitor primário por design; o COSMIC/novo Pop!_OS faz isso nativamente. A solução para GNOME 42 é a extensão **Multi Monitors Add-On**, que clona o painel nos monitores adicionais.

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 23.
> - **Extensão**: `multi-monitors-add-on@spin83`. O repo original `spin83` só vai até GNOME 3.38; o fork mantido **`lazanet/multi-monitors-add-on`** branch `gnome-42_44` declara `shell-version: ["40","41","42","43","44"]` — cobre o host (GNOME 42.9).
> - **Sem sudo**: extensão é user-level (`~/.local/share/gnome-shell/extensions/`). Integra ao pipeline existente (`extensions.json` + `instalar_gnome_extensions.sh`), nada de script novo.
> - **`show-indicator=false`**: no Pop!_OS 22.04 (GNOME 42~44) o indicador de tray dos monitores extras é buggy (mostra erro e desativa o toggle). Desligá-lo evita isso; o **painel superior continua funcionando em todos os monitores**.

## Contexto

### Causa (verificada)

- Host: notebook (eDP, interno) + monitor externo 1920x1080. Topbar só no primário.
- Manifesto tinha apenas `multi-monitor=true` do **dock** (`dconf/dash-to-dock-pop.dconf:25`) — isso estende o dock, não a barra superior. Nenhuma extensão de topbar multi-monitor declarada.

### Solução

1. `extensions.json`: nova entrada `multi-monitors-add-on@spin83` (repo lazanet, branch `gnome-42_44`, subdir `multi-monitors-add-on@spin83`, faixa 40-44).
2. `dconf/multi-monitors-add-on.dconf`: `show-panel=true` (barra nos monitores adicionais) + `show-indicator=false` (evita o bug do 22.04). Demais chaves (`show-activities`, `show-app-menu`, `show-date-time`) ficam no default `true` → painel secundário funcional.

O nome do arquivo dconf (`multi-monitors-add-on`) casa com o namespace do schema (`org.gnome.shell.extensions.multi-monitors-add-on`), exigência de `instalar_gnome_extensions.sh:125` (`namespace_key="${dconf_file%.dconf}"`).

## Escopo (touches autorizados)

- `app-themes/gnome-extensions/extensions.json` — 1 entrada nova.
- `app-themes/gnome-extensions/dconf/multi-monitors-add-on.dconf` — arquivo novo.
- `CHANGELOG.md`, `docs/sprints/INDEX.md` — 1 entrada cada.
- `docs/sprints/SPRINT_23_TOPBAR_MULTI_MONITOR.md` — este spec.

NÃO tocar: `instalar_gnome_extensions.sh` (já suporta `repo_branch`/`repo_subdir`/`dconf`), demais extensões, demais scripts.

## Integração ao install

Automática: `install.sh --gnome-extensions` (e `--all`, e portanto `--bootstrap`) chama `instalar_gnome_extensions.sh`, que clona o fork, copia o subdir para `~/.local/share/gnome-shell/extensions/multi-monitors-add-on@spin83/`, ativa via `gnome-extensions enable` e aplica o dconf. Reversível: `instalar_gnome_extensions.sh --revert` desativa todas do manifesto (incluindo esta).

## Proof-of-work runtime-real

```bash
jq -e '.extensions | all(has("uuid") and has("name") and has("repo"))' \
   app-themes/gnome-extensions/extensions.json          # hook validar-extensions-json: OK

# Clone real do fork (branch+subdir corretos):
git clone --depth 1 -b gnome-42_44 https://github.com/lazanet/multi-monitors-add-on /tmp/mm
jq -c '{uuid,"shell-version"}' /tmp/mm/multi-monitors-add-on@spin83/metadata.json
# => {"uuid":"multi-monitors-add-on@spin83","shell-version":["40","41","42","43","44"]}  (Verificado.)
ls /tmp/mm/multi-monitors-add-on@spin83/schemas/org.gnome.shell.extensions.multi-monitors-add-on.gschema.xml  # presente
```

Resultado verificado: JSON válido, schema mínimo do hook OK, clone resolve subdir/metadata/schema. O caminho de instalação está provado offline.

## Validação de runtime (executada pelo usuário ou sob autorização)

Requer aplicar na sessão + reload do Shell + o monitor externo conectado:

```bash
./install.sh --user --gnome-extensions
# Recarregar: X11 → Alt+F2, r, Enter   (Wayland → logout/login)
```

Esperado: barra superior aparece também no monitor externo (sem o indicador MM, por `show-indicator=false`). Captura visual no monitor secundário confirma.

## Riscos conhecidos

- **Indicador buggy no 22.04**: mitigado por `show-indicator=false`. Mesmo se a extensão logar um erro no indicador, o painel funciona (documentado pelo upstream/UbuntuHandbook).
- **Conflito com Pop!_Shell/Pop!_Cosmic**: Pop!_Shell faz tiling; a Multi Monitors Add-On só adiciona painel/overview nos monitores extras. Não há sobreposição de responsabilidade observada; validar no reload.
- **GNOME 45+**: o fork declara até 44; em upgrade do SO, a faixa `shell-version-max: 44` faz `instalar_gnome_extensions.sh` pular a extensão (não quebra). Trocar para a "Multi Monitor Bar" (GNOME 45+) numa sprint futura, se necessário.
- **EGO**: `gnome-extensions install` (linha 93) não baixa por UUID; cai no fallback git (lazanet) — caminho validado acima.

## Referências

- Fork GNOME 42-44: `https://github.com/lazanet/multi-monitors-add-on` (branch `gnome-42_44`).
- UbuntuHandbook (Ubuntu 22.04): instalação + limitação do indicador.
- Schema: `org.gnome.shell.extensions.multi-monitors-add-on` (keys `show-panel`, `show-indicator`, `show-activities`, `show-app-menu`, `show-date-time`, `thumbnails-slider-position`).
- `scripts/instalar_gnome_extensions.sh:73-128` — suporte a `repo_branch`/`repo_subdir`/`dconf`.

---

*"A mesma borda do mundo em cada tela." — a barra que orienta, em todos os monitores.*
