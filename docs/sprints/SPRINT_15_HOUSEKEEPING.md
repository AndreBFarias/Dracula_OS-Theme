# Sprint 15 — Endurecimento final: retenção de backups, consistência diagnóstico×reaplicar e housekeeping

Auditoria pós-ciclo SPRINTs 10–14 detectou quatro acionáveis pequenos que não mereciam sprints individuais. Esta sprint fecha tudo de uma vez, em mudanças cirúrgicas, sem refactor de larga escala e sem features especulativas.

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 15.
> - **Mudanças cirúrgicas** (CLAUDE.md §3) — adicionar/trocar somente o necessário; não reformatar adjacente.
> - **Helper de retenção é higiene**, não capacidade nova: sem CLI, sem subscript dedicado, sem timer.
> - **Política de retenção é por contagem (N últimos)**, não por idade. Default `N=10`.
> - **Acentuação pt-BR íntegra** em log strings, comentários e docs.
> - **Idempotência** preservada em todos os subscripts tocados.
> - **Sem testes novos** para `_purgar_backups_antigos` (custo/benefício baixo). Verificação é manual via simulação descrita em "Testes".

## Contexto

Quatro achados verificados via leitura direta dos arquivos do repo:

### Achado 1 — Poluição de `~/.cache/dracula_os_backup/` (IMPORTANTE)

`scripts/instalar_keybindings.sh:20-21` cria `BACKUP_DIR="$HOME/.cache/dracula_os_backup/keybindings_$TS"` a cada execução. `scripts/limpar_duplicatas.sh:23-24` cria `BACKUP_DIR="$HOME/.cache/dracula_os_backup/$TS"` (sem prefixo `keybindings_`).

A SPRINT 14 promoveu `instalar_keybindings.sh` a ser chamado por `reaplicar_tema.sh` (seção 7.7), e o APT hook da SPRINT 06 invoca `reaplicar_tema.sh` em cada `apt upgrade`. Resultado: cada upgrade gera um `keybindings_<TS>/` novo. Em desenvolvimento ativo, já apareceram 3 backups em poucas horas:

```
$ ls ~/.cache/dracula_os_backup/
keybindings_20260507_135411
keybindings_20260507_135417
keybindings_20260507_144014
```

Sem rotação, o diretório cresce indefinidamente.

**Solução**: adicionar helper `_purgar_backups_antigos` em `scripts/lib/common.sh`, chamado por cada subscript logo após criar o backup novo. API:

```bash
# _purgar_backups_antigos <pattern_glob> <quantidade_a_manter>
# Mantém os N mais recentes (por mtime), remove o resto. Pattern deve estar
# dentro de ~/.cache/dracula_os_backup/. Sem matches → no-op silencioso.
```

O helper **deve** validar via `validar_path_destrutivo` antes de qualquer `rm -rf` (allowlist `~/.cache/dracula_os_backup/` já existe em `lib/common.sh:73`).

### Achado 2 — `diagnostico.sh` usa `grep` heurístico, inconsistente com `reaplicar_tema.sh`

`scripts/diagnostico.sh:55-58`:

```bash
check "Pop!_Shell dark.css Dracula aplicado" \
    "grep -q 'pop-shell-search.modal-dialog\\|bd93f9' /usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css 2>/dev/null"
check "Pop!_Cosmic dark.css Dracula aplicado" \
    "grep -q 'rgba(40,\\s*42,\\s*54' /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css 2>/dev/null"
```

A SPRINT 14 (entrada `### Alterado` no CHANGELOG `[Unreleased]`) trocou a detecção do reaplicador para `cmp -s` byte-a-byte contra os sources canônicos `src/shell/pop-{shell,cosmic}-dark.css`. O diagnóstico ficou incoerente: detecta paleta, não fidelidade ao source. Trocar para o mesmo `cmp -s`.

`$REPO_ROOT` está disponível em `diagnostico.sh:17` (deriva de `_repo_root "${BASH_SOURCE[0]}"`).

### Achado 3 — `cd -` desprotegido em `release.sh`

`scripts/release.sh:63, 68` têm `cd - >/dev/null` sem `||`. Se o `cd` anterior (linha 61 `cd "$TMP"` ou linha 66 `cd "$DIST_DIR"`) falhar, o `cd -` volta para um diretório arbitrário. `set -euo pipefail` (linha 7) já aborta no `cd` que falhou, então o impacto prático é nulo na maioria dos casos — mas a forma idiomática é `cd ... || exit 1` em ambos.

### Achado 4 — `INDEX.md` desatualizado

`docs/sprints/INDEX.md:18-22` mostra SPRINTs 10–14 com status "Em implementação", apesar de já estarem commitadas:

| Sprint | Commit |
|--------|--------|
| 10 | `83057b18` |
| 11 | `e9b21530` |
| 12 | `a4b17a2a` |
| 13 | `80d19852` |
| 14 | `6cc25a45` |

Trocar status para "Concluída" nas 5 linhas.

## Falsos positivos (NÃO incluir)

- **DEBT-002 — `uninstall.sh` não reverte overrides**: falso. Verificado em `uninstall.sh:49-50`: já remove `com.rtosta.zapzap.desktop` e `whatsapp-linux-app_whatsapp-linux-app.desktop`.
- **OPT-001 — `sed` ineficiente**: ganho ~10ms; custo/benefício ruim. Pular.
- **BUG-001 — `set -uo` vs `-euo` inconsistente**: deliberado nos scripts de diagnóstico/reaplicação (continuar após falhas parciais — decisão da SPRINT 06). Não tocar.

## Escopo (touches autorizados)

Arquivos **a modificar**:

- `scripts/lib/common.sh` — adicionar função `_purgar_backups_antigos()`.
- `scripts/instalar_keybindings.sh` — uma chamada nova ao helper, logo após o backup do estado atual (após a linha 83 `_ok "backup feito"`).
- `scripts/limpar_duplicatas.sh` — uma chamada nova ao helper dentro do `processar()` ou ao final de `main()`. Decisão: chamar em `main()` no final (após o loop de `processar`), porque o backup só é populado dentro do loop e a poluição importa de execução-em-execução. Detalhe no plano abaixo.
- `scripts/diagnostico.sh` — substituir as duas linhas dos `check` de `dark.css`.
- `scripts/release.sh` — duas trocas `cd - >/dev/null` → `cd - >/dev/null || exit 1`.
- `docs/sprints/INDEX.md` — linhas 18-22, status `Em implementação` → `Concluída`.
- `CHANGELOG.md` — entrada nova em `[Unreleased]`.

Arquivos **a criar**:

- `docs/sprints/SPRINT_15_HOUSEKEEPING.md` (este documento).

Arquivos **NÃO tocar** (invariantes):

- `scripts/reaplicar_tema.sh` — completamente fora. SPRINT 14 fechou.
- `install.sh`, `uninstall.sh`, `build.sh` — fora.
- `scripts/normalizar_desktops.sh` — registrar achado colateral A1 (usa `~/.cache/dracula_os_backup_<TS>/desktops/`, fora do `dracula_os_backup/`), mas **não tocar nesta sprint**.
- `scripts/instalar_apt_hook.sh`, `scripts/checar_ambiente.sh`, `scripts/atualizar_icones_steam.sh`, etc. — não criam backup por timestamp dentro de `~/.cache/dracula_os_backup/`. Verificado.
- Sources canônicos `src/shell/pop-shell-dark.css` e `src/shell/pop-cosmic-dark.css` — usados no diagnóstico, sem modificação.
- `app-themes/`, `dist/`, `releases/` — completamente fora.
- `scripts/lib/common.sh` blocos não relacionados (logging, `validar_path_destrutivo`, `backup_com_manifest`, trap) — não reformatar.

## Acceptance criteria

1. `bash -n` em todos os scripts modificados retorna exit 0:
   - `bash -n scripts/lib/common.sh`
   - `bash -n scripts/instalar_keybindings.sh`
   - `bash -n scripts/limpar_duplicatas.sh`
   - `bash -n scripts/diagnostico.sh`
   - `bash -n scripts/release.sh`
2. `source scripts/lib/common.sh && declare -F _purgar_backups_antigos` imprime `_purgar_backups_antigos` (função declarada e disponível ao sourcer).
3. **Simulação de retenção**: criar 12 diretórios fictícios em `/tmp/dracula_test_purga/keybindings_<NN>` com mtimes crescentes, chamar `_purgar_backups_antigos "/tmp/dracula_test_purga/keybindings_*" 10`, listar resultado: sobram exatamente 10, e os 2 mais antigos foram removidos. **Caveat**: a allowlist atual de `validar_path_destrutivo` inclui `/tmp/dracula_os_theme` mas **não** `/tmp/dracula_test_purga`. Para o teste, usar `/tmp/dracula_os_theme/test_purga/keybindings_<NN>` (allowlist permite) — ver "Testes" para detalhe.
4. **Pattern sem matches**: `_purgar_backups_antigos "$HOME/.cache/dracula_os_backup/_inexistente_*" 10` retorna exit 0 sem nenhum erro.
5. **Pattern fora da allowlist**: `_purgar_backups_antigos "/etc/passwd*" 10` retorna não-zero e imprime erro via `_err`. Validação obrigatória.
6. `bash scripts/diagnostico.sh --quiet` exit 0 antes e depois do fix em ambiente sadio (comportamento preservado).
7. `bash scripts/diagnostico.sh` (verboso) mostra `[OK]    Pop!_Shell dark.css Dracula aplicado` e `[OK]    Pop!_Cosmic dark.css Dracula aplicado`, e o método interno passa a ser `cmp -s` (validar via `grep -n cmp scripts/diagnostico.sh` retornando ≥ 2 hits novos nos blocos correspondentes).
8. `grep -n 'cd - >/dev/null$' scripts/release.sh` retorna 0 hits; `grep -n 'cd - >/dev/null || exit 1' scripts/release.sh` retorna 2 hits.
9. `grep -c 'Em implementação' docs/sprints/INDEX.md` retorna 0; `grep -c 'Concluída' docs/sprints/INDEX.md` retorna 12 (7 já existentes + 5 novas, considerando a tabela atual).
10. Acentuação: `grep -nE 'implementacao|concluida|Inicio|nao |execucao|funcao|backup antigo' scripts/lib/common.sh scripts/instalar_keybindings.sh scripts/limpar_duplicatas.sh scripts/diagnostico.sh scripts/release.sh docs/sprints/SPRINT_15_HOUSEKEEPING.md docs/sprints/INDEX.md CHANGELOG.md` retorna 0 hits relevantes.
11. **CHANGELOG**: entrada nova em `[Unreleased]` cita as quatro mudanças.

## Invariantes a preservar

- `set -euo pipefail` em `instalar_keybindings.sh:12`, `limpar_duplicatas.sh:10`, `release.sh:7`. Não trocar para `set -uo`.
- `set -uo pipefail` em `diagnostico.sh:11`. Não trocar para `-euo` (decisão deliberada — diagnostico continua mesmo com check falho).
- `_DRACULA_COMMON_SOURCED` guard em `lib/common.sh:11-12` — não duplicar.
- Allowlist de `validar_path_destrutivo` (`lib/common.sh:64-79`) — **não modificar** (já contém `~/.cache/dracula_os_backup` e `/tmp/dracula_os_theme`, suficiente para esta sprint).
- Logger pattern (`_info`, `_ok`, `_warn`, `_err`, `_dim`) — usar como existente.
- Acentuação pt-BR em todas as strings de log e comentários novos.
- CLAUDE.md §3 (cirúrgico): não tocar nada além do necessário; não reformatar comentários ou estilo adjacente.

## Plano de implementação

### Passo 1 — `scripts/lib/common.sh`

**Inserir após o bloco `backup_com_manifest`** (após linha 156, antes do comentário final `# "Nosce te ipsum."`):

```bash
# ─── Retenção de backups (SPRINT 15) ───
# Mantém apenas os N diretórios mais recentes (por mtime, desc) que casam
# com o glob, removendo os mais antigos. Pattern deve resolver dentro da
# allowlist de validar_path_destrutivo (defesa contra patterns corrompidos).
# Uso típico:
#   _purgar_backups_antigos "$HOME/.cache/dracula_os_backup/keybindings_*" 10
_purgar_backups_antigos() {
    local pattern="${1:-}" manter="${2:-10}"
    if [[ -z "$pattern" ]]; then
        _err "_purgar_backups_antigos: pattern vazio"
        return 2
    fi
    # Expande o glob (nullglob para evitar pattern literal quando sem matches)
    local backups
    # shellcheck disable=SC2206
    mapfile -t backups < <(ls -dt $pattern 2>/dev/null || true)
    local total=${#backups[@]}
    if (( total <= manter )); then
        return 0
    fi
    local i
    for (( i = manter; i < total; i++ )); do
        local alvo="${backups[$i]}"
        # Defesa: cada alvo tem que estar na allowlist destrutiva
        if ! validar_path_destrutivo "$alvo" >/dev/null 2>&1; then
            _warn "_purgar_backups_antigos: pulando '$alvo' (fora da allowlist)"
            continue
        fi
        rm -rf -- "$alvo" 2>/dev/null || _warn "_purgar_backups_antigos: rm falhou em '$alvo'"
    done
    return 0
}
```

**Não tocar** o restante do arquivo (mantém o frase final `"Nosce te ipsum."` na última linha).

### Passo 2 — `scripts/instalar_keybindings.sh`

**Inserir após `_ok "backup feito"`** (linha 83), nova linha:

```bash
_purgar_backups_antigos "$HOME/.cache/dracula_os_backup/keybindings_*" 10
```

Posição exata: imediatamente depois da linha 83, antes da linha 85 (comentário `# Aplicar cada snapshot`). Sem comentário extra (o helper já é auto-documentado pelo nome).

### Passo 3 — `scripts/limpar_duplicatas.sh`

O `BACKUP_DIR` deste script é `~/.cache/dracula_os_backup/$TS` (sem prefixo). O glob seguro precisa **excluir** os diretórios criados por outros scripts (`keybindings_*`). Usar pattern apenas-numérico:

```
$HOME/.cache/dracula_os_backup/[0-9]*_[0-9]*
```

Esse pattern casa com `20260507_144014` (formato `%Y%m%d_%H%M%S`) e **não** casa com `keybindings_20260507_144014` (começa com letra).

**Inserir no fim de `main()`**, depois da linha `_warn "Preserva: ..."` (linha 111):

```bash
    _purgar_backups_antigos "$HOME/.cache/dracula_os_backup/[0-9]*_[0-9]*" 10
```

(Indentação: 4 espaços, alinhada com as outras linhas dentro de `main()`.)

### Passo 4 — `scripts/diagnostico.sh`

**Substituir** as linhas 55-58:

```bash
# ─── Pop!_Shell / Pop!_Cosmic dark.css ───
check "Pop!_Shell dark.css Dracula aplicado" \
    "cmp -s '$REPO_ROOT/src/shell/pop-shell-dark.css' /usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css 2>/dev/null"
check "Pop!_Cosmic dark.css Dracula aplicado" \
    "cmp -s '$REPO_ROOT/src/shell/pop-cosmic-dark.css' /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css 2>/dev/null"
```

Verificar que `$REPO_ROOT` está acessível dentro do `eval "$cmd"` da função `check()` (linha 28). Como a string é interpolada no momento do `check ... "..."` (escopo do shell antes do `eval`), `$REPO_ROOT` é expandido já na chamada — o `eval` recebe o path absoluto literal. Confirmado seguro.

### Passo 5 — `scripts/release.sh`

**Substituir** linha 63:

```
cd - >/dev/null
```
por
```
cd - >/dev/null || exit 1
```

**Substituir** linha 68 (idêntica): mesma troca.

### Passo 6 — `docs/sprints/INDEX.md`

Trocar nas linhas 18-22 a célula `| Em implementação |` por `| Concluída     |` (manter alinhamento da tabela; a coluna tem 13 caracteres no template — replicar o padding da linha SPRINT 09).

Adicionar **linha 23 nova** para SPRINT 15:

```
| 15 | [Endurecimento final: retenção de backups + diagnóstico×reaplicar](SPRINT_15_HOUSEKEEPING.md) | Em implementação | 2026-05-07 |
```

### Passo 7 — `CHANGELOG.md`

Em `[Unreleased]` → `### Adicionado`, acrescentar como último item:

```
- **Sprint 15 — Endurecimento final: retenção de backups + diagnóstico×reaplicar + housekeeping**: novo helper `_purgar_backups_antigos()` em `scripts/lib/common.sh` que mantém os N mais recentes (default 10) por glob, com defesa via `validar_path_destrutivo`. Chamado por `scripts/instalar_keybindings.sh` (pattern `keybindings_*`) e `scripts/limpar_duplicatas.sh` (pattern `[0-9]*_[0-9]*`) — fim da poluição transitiva de `~/.cache/dracula_os_backup/` causada pelo APT hook. `scripts/diagnostico.sh` passa a usar `cmp -s` byte-a-byte contra `src/shell/pop-{shell,cosmic}-dark.css` (consistente com `reaplicar_tema.sh` da SPRINT 14, em vez de grep heurístico). `scripts/release.sh` ganha `|| exit 1` em duas ocorrências de `cd -`. `docs/sprints/INDEX.md` atualizado: SPRINTs 10–14 agora marcadas como Concluída.
```

## Aritmética

Esta sprint **adiciona** mais do que remove. Sem meta numérica de redução. Faixas esperadas após implementação:

| Arquivo | Antes (L) | Depois (L) | Delta |
|---------|-----------|------------|-------|
| `scripts/lib/common.sh` | 158 | ~185 | +27 (helper + 6 linhas comentário/cabeçalho) |
| `scripts/instalar_keybindings.sh` | 102 | 103 | +1 |
| `scripts/limpar_duplicatas.sh` | 116 | 117 | +1 |
| `scripts/diagnostico.sh` | 98 | 98 | 0 (substituição linha-a-linha) |
| `scripts/release.sh` | 77 | 77 | 0 (apenas suffix) |
| `docs/sprints/INDEX.md` | 42 | 43 | +1 |
| `CHANGELOG.md` | n/a | +1 item | +1 linha em `### Adicionado` |
| `docs/sprints/SPRINT_15_HOUSEKEEPING.md` | 0 | novo | criação |

Validar com `wc -l`:
- `scripts/lib/common.sh`: 180 ≤ valor ≤ 195. Fora dessa faixa indica refactor não solicitado.
- Demais sem meta rígida — verificar apenas que o delta confere.

## Testes / proof-of-work

Comandos a registrar no commit:

### Sintaxe e source

```bash
bash -n scripts/lib/common.sh
bash -n scripts/instalar_keybindings.sh
bash -n scripts/limpar_duplicatas.sh
bash -n scripts/diagnostico.sh
bash -n scripts/release.sh
( source scripts/lib/common.sh && declare -F _purgar_backups_antigos )
```

### Simulação do helper de retenção

Usar diretório dentro da allowlist (`/tmp/dracula_os_theme` está em `lib/common.sh:78`):

```bash
mkdir -p /tmp/dracula_os_theme
( source scripts/lib/common.sh
  for i in $(seq -w 1 12); do
      d="/tmp/dracula_os_theme/test_purga_$i"
      mkdir -p "$d"
      touch -d "2026-05-07 10:$i:00" "$d"
  done
  ls -dt /tmp/dracula_os_theme/test_purga_* | wc -l   # esperado: 12
  _purgar_backups_antigos "/tmp/dracula_os_theme/test_purga_*" 10
  ls -dt /tmp/dracula_os_theme/test_purga_* | wc -l   # esperado: 10
  rm -rf /tmp/dracula_os_theme/test_purga_*
)
```

### Pattern vazio e fora-da-allowlist

```bash
( source scripts/lib/common.sh
  _purgar_backups_antigos "$HOME/.cache/dracula_os_backup/_inexistente_*" 10  # esperado exit 0, sem ruído
  _purgar_backups_antigos "/etc/passwd*" 10                                   # esperado: helper segue, mas
                                                                              # cada candidato é rejeitado
                                                                              # por validar_path_destrutivo
)
```

### Diagnóstico

```bash
bash scripts/diagnostico.sh --quiet && echo "exit=0 OK" || echo "exit!=0 — investigar"
bash scripts/diagnostico.sh | grep -E 'Pop!_Shell dark.css|Pop!_Cosmic dark.css'
grep -nE "cmp -s '\\\$REPO_ROOT/src/shell/pop-(shell|cosmic)-dark.css'" scripts/diagnostico.sh
# esperado: 2 hits (linhas dos dois check)
```

### `release.sh`

```bash
grep -nE 'cd - >/dev/null( \|\| exit 1)?$' scripts/release.sh
# esperado: 2 linhas, ambas com '|| exit 1'
bash -n scripts/release.sh
```

### `INDEX.md`

```bash
grep -c 'Em implementação' docs/sprints/INDEX.md   # esperado: 1 (apenas a linha SPRINT 15)
grep -c 'Concluída'        docs/sprints/INDEX.md   # esperado: 12 (07 antigas + 05 atualizadas)
```

### Acentuação

```bash
grep -nE 'implementacao|concluida|Inicio|nao |execucao|funcao|backup antigo' \
    scripts/lib/common.sh \
    scripts/instalar_keybindings.sh \
    scripts/limpar_duplicatas.sh \
    scripts/diagnostico.sh \
    scripts/release.sh \
    docs/sprints/SPRINT_15_HOUSEKEEPING.md \
    docs/sprints/INDEX.md \
    CHANGELOG.md
# esperado: 0 hits
```

### Hipótese verificada (lição 4)

Antes de iniciar, executor confirma identificadores via `rg`:

```bash
rg -n 'BACKUP_DIR|_purgar_backups_antigos|REPO_ROOT|validar_path_destrutivo' scripts/
rg -n 'cmp -s|grep -q .pop-shell-search' scripts/
rg -n 'Em implementação' docs/sprints/INDEX.md
```

## Achados colaterais (registrados; NÃO implementar nesta sprint)

### A1 — `scripts/normalizar_desktops.sh:13` cria `~/.cache/dracula_os_backup_<TS>/desktops/`

Pattern fora do diretório `~/.cache/dracula_os_backup/` (note o **underscore** em vez de barra). Não polui o cache rotacionado por esta sprint. Mas também cresce indefinidamente. **Sugestão para sprint futura**: ou consolidar dentro de `~/.cache/dracula_os_backup/desktops_<TS>/` e aplicar o helper, ou adicionar chamada dedicada `_purgar_backups_antigos "$HOME/.cache/dracula_os_backup_*" 10`. **Não fazer agora** porque exige mudar `BACKUP_DIR` em outro script (fora do escopo cirúrgico).

### A2 — `scripts/lib/common.sh:53-58` `_log_file()` também usa timestamp

Logs em `~/.cache/dracula_os_theme/` (fora de `dracula_os_backup`) também não rotacionam. Crescimento típico é menor (poucos KB por log), mas aceitar registro como achado para revisão futura. **Não fazer agora**.

### A3 — `set -uo` vs `set -euo`

Inconsistência **deliberada**: scripts de diagnóstico/reaplicação usam `-uo` para continuar após falhas parciais (decisão SPRINT 06). Subscripts unitários (`instalar_*.sh`, `release.sh`, `limpar_duplicatas.sh`) usam `-euo` para abortar cedo. Comentário explicativo opcional pode ser adicionado por executor se sobrar tempo, mas **não é entregável obrigatório** desta sprint.

### A4 — `OPT-001 sed` ineficiente

Achado válido mas custo/benefício baixo. Pular indefinidamente.

## Riscos

1. **Glob `[0-9]*_[0-9]*` em `limpar_duplicatas.sh`**: precisa que o shell **expanda** o glob no momento da chamada, não passar literal. Como o helper recebe o pattern como string e usa `ls -dt $pattern` (sem aspas) internamente, a expansão acontece dentro do helper. Risco baixo, mas executor deve confirmar via simulação (criar `~/.cache/dracula_os_backup/keybindings_TEST/` e `~/.cache/dracula_os_backup/20260101_120000/`, confirmar que o helper purga só o segundo pattern quando chamado de `limpar_duplicatas`).
2. **`mapfile` + glob sem aspas + `set -e`**: o subshell `< <(ls -dt $pattern 2>/dev/null || true)` protege contra `ls` sem matches retornando exit 1. Confirmado: `|| true` dentro do process substitution suprime o erro mesmo sob `-e`.
3. **`validar_path_destrutivo` consome stderr**: o helper redireciona `>/dev/null 2>&1` para evitar ruído quando o teste falha por design (testes `/etc/passwd*` esperam falha). Apenas o `_warn` do helper é mostrado ao usuário.
4. **`cmp -s` no diagnóstico precisa de `src/shell/pop-*-dark.css` presente**: em ambiente de tarball extraído, esses arquivos existem (estão dentro de `src/`). Em ambiente sem repo (improvável: diagnóstico só roda dentro do checkout), o `cmp` falha — comportamento idêntico ao grep falhando antes. Sem regressão.
5. **Status "Concluída" no INDEX antes do release**: as SPRINTs 10–14 estão commitadas mas ainda em `[Unreleased]`. A semântica de "Concluída" no INDEX é "implementação fechada", não "publicada em release". Coerente com o uso em SPRINTs 06–09, todas marcadas Concluída desde 04-17 e empacotadas em 1.2.0 só depois.

## Não-objetivos (fora de escopo)

- Política de retenção por idade (`mtime > 30d`). Decisão: manter contagem.
- UI ou subscript dedicado para gerenciar backups.
- Refactor de `backup_com_manifest`.
- Tocar `scripts/normalizar_desktops.sh` (achado A1).
- Tocar `_log_file` em `lib/common.sh` (achado A2).
- Renumeração cosmética de seções.
- Hash sha256 do `dark.css` no diagnóstico (alternativa cogitada e descartada na SPRINT 14 por custo/benefício; `cmp -s` é o caminho).
- Sprint dedicada a ownership do APT hook (era achado A3 da SPRINT 14, marcado falso positivo no escopo daquela sprint; permanece fora também aqui).

## Referências

- `CLAUDE.md` global e local — §2 (simplicidade), §3 (cirúrgico), §4 (objetivos verificáveis).
- `docs/sprints/SPRINT_06_RESILIENCIA_POS_UPGRADE.md` — APT hook origem da poluição.
- `docs/sprints/SPRINT_08_SEGURANCA_ROBUSTEZ.md` — `validar_path_destrutivo` e `backup_com_manifest`.
- `docs/sprints/SPRINT_14_REAPLICAR_COBERTURA.md` — `cmp -s` no reaplicador (motivo da inconsistência fix neste spec) e achado A1 que esta sprint resolve.
- `CHANGELOG.md` — entrada `[Unreleased]` `### Alterado` cita o `cmp -s` que esta sprint propaga ao diagnóstico.

*"O que poupa hoje, salva amanhã." — adágio do `~/.cache`.*
