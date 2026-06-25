# Sprint 24 — Cobertura de ícones nativos via aliases técnicos

Fechar o gap em que apps nativos do GNOME 42 (Pop!_OS) apareciam **sem tema** porque seu `Icon=` real (reverse-DNS, ex.: `org.gnome.Settings`) não era materializado pelo `build.sh`. A causa-raiz era o pipeline gerar nomes-alvo apenas a partir de `app_id` + `aliases_humanos`, ignorando o campo `aliases` (onde vivem os nomes técnicos).

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 24.
> - **Sem sudo**; mudança no pipeline (`build.sh` + `mapping.json`), consumida pelo `install.sh` via `dist/`.
> - **Fix geral, não pontual**: incluir o campo `aliases` na geração resolve `org.gnome.Settings` e todos os demais de uma vez, em vez de remendar entrada por entrada.

## Contexto

### Causa-raiz (verificada)

- `.desktop` nativo do Settings: `Icon=org.gnome.Settings` (`/usr/share/applications/gnome-control-center.desktop`).
- `mapping.json` tem a entrada `gnome-control-center` com `org.gnome.Settings` em **`aliases`** (não em `aliases_humanos`).
- `gerar_tema_icones()` montava `alvos=(app_id + aliases_humanos)` e iterava com `jq` emitindo só esses dois campos. Logo gerava `gnome-control-center.png` mas **não** `org.gnome.Settings.png` → o ícone de "Configurações" caía no Adwaita.

### Solução

`build.sh`:
1. `jq` passa a emitir um 4º campo: `aliases` (join por vírgula).
2. O `while read` captura `aliases_tecnicos`.
3. A lista `alvos` é montada de `app_id` + `aliases_humanos` + `aliases`, **deduplicada** (membership check), pois `aliases` quase sempre contém o próprio `app_id`.

`mapping.json`:
4. Nova entrada `firefox` (aliases `firefox`, `firefox-esr`) apontando para a logo do depósito `current/48x48/apps-global/firefox.png` — o Firefox não tinha mapeamento e caía no fallback.

## Escopo (touches autorizados)

- `build.sh` — `gerar_tema_icones()`: linha do `jq`, `while read`, bloco de montagem de `alvos`.
- `mapping.json` — 1 entrada nova (`firefox`).
- `CHANGELOG.md`, `docs/sprints/INDEX.md` — 1 entrada cada.
- `docs/sprints/SPRINT_24_ICONES_NATIVOS_ALIASES.md` — este spec.

NÃO tocar: `dist/`, demais funções de `build.sh`, demais scripts.

## Aritmética da mudança

- Nomes-alvo adicionais cobertos por `aliases` (com fonte válida, fora `app_id`/`aliases_humanos`): **63**.
- Inclui os app-IDs reverse-DNS modernos: `org.gnome.Settings`, `org.gnome.Nautilus`, `org.gnome.Calculator`, `org.gnome.Terminal`, `org.gnome.Calendar`, `org.gnome.Weather`, `org.gnome.FileRoller`, `org.gnome.DiskUtility`, `org.gnome.Evince`, `org.gnome.Extensions`, `org.gnome.SimpleScan`, `org.gnome.baobab`, etc.
- `mapping.json`: `168 → 169` apps processados (entrada `firefox`).

## Proof-of-work runtime-real

```bash
bash -n build.sh
jq empty mapping.json
./build.sh                       # "169 apps processados, 36 ignorados, 0 falhas"

# Settings agora tematizado, mesma arte do gnome-control-center:
P=$(convert dist/icons/Dracula-Icones/256x256/apps/org.gnome.Settings.png   -strip png:- | sha256sum)
Q=$(convert dist/icons/Dracula-Icones/256x256/apps/gnome-control-center.png -strip png:- | sha256sum)
# P == Q  → c73b976a…  (Verificado.)

ls dist/icons/Dracula-Icones/256x256/apps/org.gnome.*.png   # dezenas de app-IDs nativos
ls dist/icons/Dracula-Icones/256x256/apps/firefox*.png      # firefox.png + firefox-esr.png

bash scripts/diagnostico.sh --quiet ; echo "exit=$?"        # 0
```

Validação visual: montagem `[Settings | Nautilus | Calculator | Firefox]` confirma os quatro com arte Dracula (toggle, pasta gótica, calculadora, raposa gótica) — antes Adwaita genérico.

## Gaps remanescentes (registrados — viram SPRINT 29)

Entradas `origem: nao-encontrado` ainda sem ícone próprio (caem no fallback): Citrix `Ubuntu-*` (~10), painéis `gnome-*-panel` (sub-páginas do Settings, baixa visibilidade), `org.gnome.Software` (Pop!_OS usa Pop!_Shop), e apps sem logo da paleta. A curadoria de **SVG logos livres compatíveis com a paleta Dracula** para esses casos exige uma lista de apps-alvo e seleção de arte — escopo da SPRINT 29 (Curadoria de logos SVG).

## Invariantes preservados

- Acentuação pt-BR; mudança cirúrgica; sem sudo; sem `/usr/share/`.
- Dedup evita geração duplicada quando `aliases` repete o `app_id`.
- `set +e` no loop preservado (uma falha de conversão não aborta o build).

## Riscos conhecidos

- **Colisão de nome-alvo**: se duas entradas reivindicam o mesmo nome via alias, a última na ordem do `jq` vence. Não observado em apps comuns (spot-check: nautilus, Settings, Calculator, Clapper, Firefox intactos).
- **Cache do GTK/Shell**: refletir no desktop exige `gtk-update-icon-cache` (já no install) + eventual reload do Shell.

---

*"O nome certo encontra o ícone certo." — reverse-DNS também merece tema.*
