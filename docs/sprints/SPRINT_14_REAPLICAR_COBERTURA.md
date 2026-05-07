# Sprint 14 — Cobertura completa do `reaplicar_tema.sh` (5 gaps + endurecimento)

Auditoria comparativa entre `install.sh` e `scripts/reaplicar_tema.sh` revelou cinco funcionalidades que o instalador persiste mas que o reaplicador **não** restaura após um `apt upgrade` / `do-release-upgrade`. Sem reaplicação, o tema regride parcialmente, mesmo com o APT hook (SPRINT 06) acionando `reaplicar_tema.sh`. Esta sprint fecha os cinco gaps reusando os subscripts existentes (sem criar novos) e endurece três detecções fracas.

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 14 (10/11/12/13 já em changelog `[Unreleased]`).
> - **Mudanças cirúrgicas** em `scripts/reaplicar_tema.sh` — adicionar seções novas, sem refatorar adjacente.
> - **Não criar scripts novos**. Reusar `instalar_*.sh` existentes.
> - **Sem features especulativas** (CLAUDE.md §2): sem timer, sem UI, sem refactor de extração de funções, sem renumeração cosmética. Manter o padrão decimal atual (2.5, 7.5, 7.7, ...) — o orquestrador continua linear.
> - **Acentuação pt-BR íntegra** em log strings e docs.
> - **Subscripts existentes assumidos idempotentes** (já prometido em sprints anteriores). Achados de não-idempotência são registrados na seção "Achados colaterais" com sugestão mínima.
> - **`gnome-extensions` deve usar `--only-dconf`** quando chamado pelo reaplicador (não re-baixar pacotes em cada `apt upgrade`). Flag já existe no script — não inventar `--reaplicar`.
> - **Não re-habilitar à força extensões que o usuário desabilitou propositalmente** — apenas garantir que dconf das extensões ATUALMENTE ATIVAS preserve a configuração do tema.
> - **Tempo target**: `bash scripts/reaplicar_tema.sh` em ambiente já configurado < 10s.

## Contexto

O usuário pediu literalmente: *"ver se tem coisas do projeto que não estão asseguradas em `reaplicar_tema.sh`"* e *"deixar mais robusto e inteligente"*. Auditoria via diff conceitual `install.sh` × `reaplicar_tema.sh` produziu cinco gaps numerados abaixo.

`scripts/reaplicar_tema.sh` hoje (verificado: 103 linhas, 10 seções):

```
1.   Pré-requisitos (Dracula-Icones presente)
2.   Pop!_Shell + Pop!_Cosmic dark.css
3.   Overrides .desktop (aplicar_overrides.sh)
4.   Permissões .desktop (chmod 644)
5.   Normalização Icon= absoluto
6.   Tema som Pop (gsettings)
7.   App themes (instalar_app_themes.sh)
7.5  Ícones jogos Steam (atualizar_icones_steam.sh) — SPRINT 13
8.   Rebuild caches (gtk-update-icon-cache, update-desktop-database)
9.   Diagnóstico final
```

Falta: localização pt-BR (SPRINT 10), higiene launcher (SPRINT 11), keybindings, dconf de extensões GNOME e gsettings de `icon-theme/gtk-theme/cursor-theme`. Falta também: capturar exit code do `gtk-update-icon-cache` (silencia hoje com `2>/dev/null || true`).

## Os cinco gaps

| # | Gap | Por que regride | Subscript que reaplica |
|---|---|---|---|
| 1 | `gsettings set` icon-theme/gtk-theme/cursor-theme | `apt upgrade gnome-shell`/`gnome-control-center` pode resetar para Adwaita | (inline `gsettings set`, sem subscript) |
| 2 | Pop!_Cosmic pt-BR (SPRINT 10) | Se cópia user-dir for removida ou GNOME a limpar, `Início`/`Criar pasta` voltam para inglês | `scripts/instalar_pop_cosmic_ptbr.sh` |
| 3 | Higiene Launcher (SPRINT 11) | `gnome-session-properties.desktop` user-side pode ser sobrescrito; `folder-children` pode reapresentar `'Utilities'` em logout devido ao vendor schema do pop-cosmic | `scripts/instalar_higiene_launcher.sh` |
| 4 | Keybindings (dconf) | `apt upgrade gnome-shell` pode resetar shortcuts em `/org/gnome/settings-daemon/plugins/media-keys/`, `/org/gnome/desktop/wm/keybindings/`, `/org/gnome/terminal/legacy/keybindings/`, `/org/gnome/desktop/sound/` | `scripts/instalar_keybindings.sh` |
| 5 | dconf das extensões GNOME (SPRINT 05) | `apt upgrade gnome-shell` pode resetar configs em `/org/gnome/shell/extensions/<uuid>/` | `scripts/instalar_gnome_extensions.sh --only-dconf` |

Os subscripts foram inspecionados (`scripts/instalar_pop_cosmic_ptbr.sh` 64L, `instalar_higiene_launcher.sh` 88L, `instalar_keybindings.sh` 102L, `instalar_gnome_extensions.sh` 136L) e:

- `instalar_pop_cosmic_ptbr.sh` — idempotente puro (linha 17: short-circuit por `grep -q "'Início'"`).
- `instalar_higiene_launcher.sh` — idempotente puro (Parte A short-circuit por `grep -q "^NoDisplay=true"`; Parte B short-circuit por comparação de string `folder-children`).
- `instalar_gnome_extensions.sh` — flag `--only-dconf` (linha 31, 87) JÁ existe e pula download/enable, aplicando apenas `dconf load /org/gnome/shell/extensions/<key>/` para cada UUID do manifesto. Detecção de COSMIC (linhas 38-43) também já protege.
- `instalar_keybindings.sh` — idempotente em RESULTADO mas **não em side-effect**: a cada execução cria `~/.cache/dracula_os_backup/keybindings_<TS>/` (linha 21, 77). Em uma máquina com APT hook ativo isso polui o cache a cada `apt upgrade`. Achado registrado abaixo.

## Endurecimentos (3 detecções fracas)

### E1. Seção 2 (CSS dark.css) — manter como está

A regex `bd93f9|rgba\(40,\s*42,\s*54|pop-shell-search.modal-dialog` é razoável e a sugestão original (hash sha256) tem custo de manutenção alto sem ganho proporcional. **Decisão: não mudar nesta sprint.** Anotar em "Não-objetivos".

### E2. Seção 6 (tema som Pop) — já parcialmente endurecida

Linha 70 do `reaplicar_tema.sh` JÁ valida `[[ -d "$HOME/.local/share/sounds/Pop" || -d /usr/share/sounds/Pop ]]` antes de `gsettings set`. **Decisão: não mudar nesta sprint** — a sugestão da auditoria estava desatualizada em relação ao código atual. Anotar em "Não-objetivos".

### E3. Seção 8 (rebuild caches) — endurecer

`gtk-update-icon-cache -f "$HOME/.local/share/icons/Dracula-Icones" 2>/dev/null || true` silencia exit code. Trocar por captura explícita com `_warn` quando falhar. Idem `update-desktop-database`.

## Escopo (touches autorizados)

Arquivos **a modificar**:

- `scripts/reaplicar_tema.sh` — adicionar seções novas + endurecer seção 8 (E3).
- `CHANGELOG.md` — entrada `[Unreleased]` com a SPRINT 14.
- `docs/sprints/INDEX.md` — linha SPRINT 14.

Arquivos **a criar**:

- `docs/sprints/SPRINT_14_REAPLICAR_COBERTURA.md` (este).

Arquivos **NÃO tocar** (invariantes):

- `install.sh` — fora de escopo. Já chama todos os subscripts; não há gap simétrico.
- `scripts/instalar_pop_cosmic_ptbr.sh`, `instalar_higiene_launcher.sh`, `instalar_gnome_extensions.sh` — usar como estão.
- `scripts/instalar_keybindings.sh` — **não tocar nesta sprint**. O achado de poluição de cache é registrado para sprint posterior (ver "Achados colaterais"). Como o reaplicador roda só após `apt upgrade` (não a cada boot) e cada backup é pequeno (4 arquivos `.dconf` de poucos KB), a poluição é tolerável transitoriamente.
- `scripts/diagnostico.sh` — fora de escopo. Continua sendo o oráculo final.
- `scripts/lib/common.sh` — usar `_info`, `_ok`, `_warn`, `_err`, `_dim` como já presentes.
- `dist/`, `app-themes/`, `build.sh` — completamente fora.

## Acceptance criteria

1. **Sintaxe**: `bash -n scripts/reaplicar_tema.sh` exit 0.
2. **Lint**: `shellcheck --severity=warning scripts/reaplicar_tema.sh` sem warnings novos em relação ao baseline atual.
3. **Execução em ambiente sadio**: `bash scripts/reaplicar_tema.sh` exit 0.
4. **Idempotência**: 2ª execução consecutiva não muda mtime de `applications.js` em `~/.local/share/gnome-shell/extensions/pop-cosmic@system76.com/`, nem de `gnome-session-properties.desktop` user-side, nem do `dconf dump /org/gnome/desktop/wm/keybindings/`. Logs mostram "OK: já aplicado" para cada subscript chamado.
5. **Cobertura dos 5 gaps verificada após execução em ambiente regredido**:
   - Gap 1: após `gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'` + reaplicar, `gsettings get ... icon-theme` retorna `'Dracula-Icones'`.
   - Gap 2: após `rm ~/.local/share/gnome-shell/extensions/pop-cosmic@system76.com/applications.js` + reaplicar, o arquivo volta a existir e contém a string `'Início'`.
   - Gap 3: após `sed -i '/^NoDisplay=true/d' ~/.local/share/applications/gnome-session-properties.desktop` + reaplicar, a linha `NoDisplay=true` volta.
   - Gap 4: após `dconf reset -f /org/gnome/desktop/wm/keybindings/` + reaplicar, ao menos uma chave customizada do tema reaparece no `dconf dump`.
   - Gap 5: após `dconf reset -f /org/gnome/shell/extensions/dash-to-dock/` (ou outra do manifesto que tenha `.dconf` declarado) + reaplicar, a chave volta. **Caveat**: se nenhuma extensão do manifesto declarar `.dconf` no `app-themes/gnome-extensions/extensions.json`, este teste não se aplica e o critério é "subscript executou exit 0". Verificar `jq '.extensions[] | select(.dconf != null)' app-themes/gnome-extensions/extensions.json` antes de planejar este teste.
6. **Endurecimento E3**: introduzir falha simulada em `gtk-update-icon-cache` (ex.: passar diretório inválido, `mv ~/.local/share/icons/Dracula-Icones /tmp/x` antes de rodar) → log mostra `_warn "gtk-update-icon-cache falhou"` em vez de silêncio.
7. **`bash scripts/diagnostico.sh --quiet`** continua exit 0 após reaplicar.
8. **Tempo**: `time bash scripts/reaplicar_tema.sh` em máquina já configurada (idempotente puro) < 10s wall-clock.
9. **CHANGELOG e INDEX** atualizados; sprint listada com status "Em implementação".

## Invariantes a preservar

- `set -uo pipefail` em `reaplicar_tema.sh` — não mudar para `set -euo pipefail` (decisão da SPRINT 06: queremos seguir mesmo se uma seção falhar).
- Cada chamada de subscript deve permanecer **não-fatal** (`|| _warn`).
- Saída continua tee-ada para `LOG_FILE` (linha 21).
- O diagnóstico final (`scripts/diagnostico.sh --quiet`) é o oráculo de exit code.
- Detecção de COSMIC já presente em `instalar_gnome_extensions.sh` (linhas 38-43): a chamada da nova seção 7.8 não precisa repetir essa detecção — o subscript pula sozinho.
- CLAUDE.md §3 (Mudanças Cirúrgicas): não tocar formatação ou comentários adjacentes às seções existentes.

## Plano de implementação

Numeração nova proposta (mantendo decimais do estilo atual):

```
1.    Pré-requisitos
2.    Pop!_Shell/Pop!_Cosmic dark.css
2.5   [NOVO] Localização pt-BR Pop!_Cosmic + higiene launcher
3.    Overrides .desktop
4.    Permissões .desktop
5.    Normalização Icon= absoluto
6.    Tema som Pop (mantida; já endurecida)
7.    App themes
7.5   Ícones jogos Steam (SPRINT 13)
7.7   [NOVO] Keybindings (dconf)
7.8   [NOVO] dconf das extensões GNOME
8.    Rebuild caches (endurecer captura de exit — E3)
8.5   [NOVO] gsettings icon-theme / gtk-theme / cursor-theme
9.    Diagnóstico final
```

### Passo 1: editar `scripts/reaplicar_tema.sh`

**Após a atual seção 2** (linha 49, depois do `[[ $pop_shell_ok -eq 1 ]] && _ok ...`), inserir:

```bash
# ─── 2.5 Localização pt-BR Pop!_Cosmic + higiene do launcher ───
_info "Reaplicando localização pt-BR do launcher Pop!_Cosmic"
"$REPO_ROOT/scripts/instalar_pop_cosmic_ptbr.sh" || _warn "instalar_pop_cosmic_ptbr.sh falhou (não-fatal)"

_info "Reaplicando higiene do launcher (NoDisplay + folder-children)"
"$REPO_ROOT/scripts/instalar_higiene_launcher.sh" || _warn "instalar_higiene_launcher.sh falhou (não-fatal)"
```

**Após a atual seção 7.5** (linha 84, depois de `atualizar_icones_steam.sh`), inserir:

```bash
# ─── 7.7 Keybindings (dconf) ───
# Subscript reaplica snapshots de media-keys/wm-keybindings/terminal/sound.
# Idempotente em resultado; cria backup pequeno em ~/.cache/dracula_os_backup/.
_info "Reaplicando keybindings (dconf)"
"$REPO_ROOT/scripts/instalar_keybindings.sh" || _warn "instalar_keybindings.sh falhou (não-fatal)"

# ─── 7.8 dconf das extensões GNOME (sem re-download) ───
# Usa --only-dconf: pula install/enable, aplica apenas configurações dconf
# das extensões já presentes. Subscript detecta COSMIC e pula sozinho.
_info "Reaplicando dconf das extensões GNOME (--only-dconf)"
"$REPO_ROOT/scripts/instalar_gnome_extensions.sh" --only-dconf || _warn "instalar_gnome_extensions.sh --only-dconf falhou (não-fatal)"
```

**Substituir a atual seção 8** (linhas 86-90):

```bash
# ─── 8. Rebuild caches ───
_info "Regenerando caches"
if ! gtk-update-icon-cache -f "$HOME/.local/share/icons/Dracula-Icones" 2>/dev/null; then
    _warn "gtk-update-icon-cache falhou para Dracula-Icones"
fi
if ! update-desktop-database "$HOME/.local/share/applications" 2>/dev/null; then
    _warn "update-desktop-database falhou para ~/.local/share/applications"
fi
_ok "Caches regenerados"

# ─── 8.5 gsettings: icon-theme / gtk-theme / cursor-theme ───
# Reativa o tema caso GNOME tenha resetado para Adwaita após upgrade.
# Cada `gsettings set` é silencioso quando o valor já é o atual (no-op).
_info "Reativando tema via gsettings (icon/gtk/cursor)"
gsettings set org.gnome.desktop.interface icon-theme 'Dracula-Icones' \
    && _ok "icon-theme=Dracula-Icones" || _warn "Falha ao setar icon-theme"
gsettings set org.gnome.desktop.interface gtk-theme 'Dracula-standard-buttons' \
    && _ok "gtk-theme=Dracula-standard-buttons" || _warn "Falha ao setar gtk-theme"
gsettings set org.gnome.desktop.interface cursor-theme 'Dracula-Cursor' \
    && _ok "cursor-theme=Dracula-Cursor" || _warn "Falha ao setar cursor-theme"
if gsettings list-schemas 2>/dev/null | grep -q "^org.gnome.shell.extensions.user-theme$"; then
    gsettings set org.gnome.shell.extensions.user-theme name 'Dracula-standard-buttons' 2>/dev/null \
        && _ok "user-theme=Dracula-standard-buttons" || true
fi
```

A seção 9 (diagnóstico) permanece inalterada.

### Passo 2: atualizar `docs/sprints/INDEX.md`

Adicionar linha:

```
| 14 | [Cobertura completa do reaplicar_tema](SPRINT_14_REAPLICAR_COBERTURA.md) | Em implementação | 2026-05-07 |
```

### Passo 3: atualizar `CHANGELOG.md`

Em `[Unreleased]` → `### Adicionado`, acrescentar:

```
- **Sprint 14 — Cobertura completa de `scripts/reaplicar_tema.sh`**: cinco gaps de reaplicação pós-`apt upgrade` fechados via reuso dos subscripts existentes, sem criar scripts novos. Novas seções idempotentes: 2.5 (`instalar_pop_cosmic_ptbr.sh` + `instalar_higiene_launcher.sh`), 7.7 (`instalar_keybindings.sh`), 7.8 (`instalar_gnome_extensions.sh --only-dconf`, sem re-download), 8.5 (`gsettings set` icon-theme/gtk-theme/cursor-theme/user-theme). Endurecimento da seção 8: `gtk-update-icon-cache` e `update-desktop-database` agora capturam exit code e logam `_warn` em falha em vez de silenciar. Tempo total em ambiente já configurado < 10s.
```

## Aritmética

`scripts/reaplicar_tema.sh` atual: **103 linhas** (verificado com `wc -l`).

Adições previstas:

- Seção 2.5: ~5 linhas de código + 1 linha de comentário título = 6L.
- Seção 7.7: 2 linhas comentário + 2 linhas código = 4L.
- Seção 7.8: 3 linhas comentário + 2 linhas código = 5L.
- Reescrita da seção 8: substituir 4L por ~9L = +5L líquido.
- Seção 8.5: 12L.

Total previsto: **103 + 6 + 4 + 5 + 5 + 12 = 135 linhas** após a sprint.

Não há meta numérica de redução (sprint adiciona, não refatora). Critério: `wc -l scripts/reaplicar_tema.sh` deve retornar valor entre 130 e 145 após implementação. Fora dessa faixa indica refactor não solicitado ou implementação faltando.

## Testes / proof-of-work

Comandos a registrar no commit (rodar antes de fechar a sprint):

- `bash -n scripts/reaplicar_tema.sh`
- `shellcheck --severity=warning scripts/reaplicar_tema.sh`
- `bash scripts/reaplicar_tema.sh` (1ª execução; exit 0)
- `bash scripts/reaplicar_tema.sh` (2ª execução imediata; exit 0; logs com "já aplicado")
- `wc -l scripts/reaplicar_tema.sh` (verificar faixa 130-145)
- Para cada gap (1-5), o teste de regressão descrito em "Acceptance criteria 5":
  - Salvar estado antes (`gsettings get`, `dconf dump`, `ls -la`).
  - Regredir manualmente.
  - Rodar `bash scripts/reaplicar_tema.sh`.
  - Verificar restauração.
- `time bash scripts/reaplicar_tema.sh` (ambiente já reaplicado; conferir < 10s).
- `bash scripts/diagnostico.sh --quiet && echo OK || echo FAIL`.
- Acentuação: `grep -nE 'Inicio|movera|icone[s]?( |$)|nao' docs/sprints/SPRINT_14_REAPLICAR_COBERTURA.md scripts/reaplicar_tema.sh CHANGELOG.md` — esperado 0 hits relevantes (cuidar para "icones" só aparecer dentro de nome de tema `Dracula-Icones`, que é nome de pasta e está OK).

## Achados colaterais (registrados para sprints futuras, NÃO implementar nesta)

### A1 — `instalar_keybindings.sh` polui `~/.cache/dracula_os_backup/`

Cada execução cria `keybindings_<TS>/` com 4 arquivos `.dconf`. Com APT hook ativo, isso significa um diretório novo a cada `apt upgrade`. Tamanho típico: poucos KB por backup, mas pode acumular dezenas em poucos meses. **Sugestão para sprint futura**: trocar `TS=$(date +...)` por uso de slot único `keybindings_latest/` quando invocado em modo "reaplicar", ou adicionar política de retenção (manter só os últimos N). **Não fazer agora** — fora de escopo (é tocar `instalar_keybindings.sh`, que está fora do escopo desta sprint). Tolerável transitoriamente: cada backup é pequeno e o usuário pode limpar.

### A2 — `gnome-extensions enable` em re-execução

Quando `instalar_gnome_extensions.sh` é chamado **sem** `--only-dconf` (não é o caso desta sprint, mas se algum dia for) e o usuário tiver desabilitado uma extensão propositalmente, o script re-habilitaria. Como a SPRINT 14 usa `--only-dconf`, este risco não se materializa aqui. Apenas registrar.

### A3 — Endurecimento da regex Dracula em `dark.css` (E1) e validação de existência de `Pop` sounds (E2)

Já listados em "Endurecimentos". Decisão: não fazer nesta sprint (E1: custo/benefício ruim; E2: já está implementado).

## Riscos

1. **Pop-up "tema mudou" do GNOME** ao chamar `gsettings set` — verificado em ambiente local: quando o valor já é o atual, o `gsettings set` é no-op silencioso. Risco baixo.
2. **`gnome-extensions` indisponível** (caso o user-mode não tenha o CLI): subscript já protege com `command -v gnome-extensions >/dev/null || ...` (linha 46). Subscript retorna exit 1, `|| _warn` do reaplicador captura, segue a vida.
3. **dconf load em namespace inválido** (ex.: extensão removida do manifesto mas ainda com `.dconf` no diretório): `dconf load` apenas escreve nas chaves listadas; se a extensão não está instalada, as chaves ficam órfãs em dconf — efeito colateral nulo.
4. **Tempo de execução**: cada subscript é I/O leve. Mesmo em pior caso (5 subscripts + 4 `gsettings set` + 2 cache rebuilds), espera-se < 5s reais. Buffer para meta de 10s.
5. **APT hook chama `reaplicar_tema.sh` como root** (via `Dpkg::Post-Invoke`). Mas o reaplicador respeita `$HOME` do usuário invocador (a SPRINT 06 já endereçou: `instalar_apt_hook.sh` usa `${SUDO_USER:-$USER}`). Subscripts user-mode (`instalar_pop_cosmic_ptbr.sh` etc.) escrevem em `~/.local/share/...` — **risco de gravar como root** se o hook não estiver passando o usuário corretamente. **Verificar antes de fechar a sprint**: ler `/etc/apt/apt.conf.d/99-dracula-os-theme` no host de teste e confirmar que invoca `reaplicar_tema.sh` via `sudo -u $USER` ou equivalente. Caso contrário, abrir achado A4.

## Não-objetivos (fora de escopo)

- Refatorar `reaplicar_tema.sh` extraindo cada seção em função separada.
- Criar dispatcher de seções (ex.: `--only=keybindings`).
- Renumerar 1-15 inteiro (cosmético).
- Sprint dedicada a `do-release-upgrade` para Pop!_OS 24.04 (mudança fundamental — fora deste escopo).
- Re-download de extensões em apt upgrade — apenas re-aplicar dconf via `--only-dconf`.
- Hash sha256 do `dark.css` (E1) — custo/benefício ruim.
- Endurecer seção 6 mais (E2) — já está parcialmente endurecida em produção.
- Tocar `instalar_keybindings.sh` para resolver poluição de cache (achado A1).
- Tocar `install.sh` para qualquer simetria (já está coberto).

## Referências

- `VALIDATOR_BRIEF.md` — checks ativos 1 (acentuação), 2 (mudança cirúrgica), 3 (idempotência).
- `docs/sprints/SPRINT_06_RESILIENCIA_POS_UPGRADE.md` — APT hook que invoca o reaplicador.
- `docs/sprints/SPRINT_10_LAUNCHER_PTBR.md` — origem de `instalar_pop_cosmic_ptbr.sh`.
- `docs/sprints/SPRINT_11_LAUNCHER_HIGIENE.md` — origem de `instalar_higiene_launcher.sh`.
- `docs/sprints/SPRINT_13_STEAM_ICONS.md` — precedente direto: padrão "adicionar seção decimal nova ao reaplicador".
- `CLAUDE.md` §2 (simplicidade primeiro), §3 (mudanças cirúrgicas), §4 (objetivos verificáveis).

*"O que se repete fortalece; o que se ignora regride." — adágio do APT hook.*
