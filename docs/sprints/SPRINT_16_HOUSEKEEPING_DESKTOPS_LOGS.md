# Sprint 16 — Housekeeping II: rotação de backups de `.desktop` e de logs

Auditoria pós-ciclo SPRINTs 10–15 deixou dois achados colaterais (registrados em `SPRINT_15_HOUSEKEEPING.md` linhas 369–375 como A1 e A2) sem cobertura. Esta sprint fecha os dois com mudanças cirúrgicas, sem refactor de larga escala, sem features especulativas e sem testes novos. Continua a doutrina da SPRINT 15: rotação por contagem (N últimos), default `N=10`, defesa via `validar_path_destrutivo`.

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 16.
> - **Mudanças cirúrgicas** (CLAUDE.md §3) — adicionar/trocar somente o necessário.
> - **A1 → Opção A**: alinhar `normalizar_desktops.sh` ao layout único `~/.cache/dracula_os_backup/desktops_<TS>/desktops/` (tudo dentro do diretório-mãe que a SPRINT 15 já cobre).
> - **A2 → Opção 2 com wrapper**: refatorar `_purgar_backups_antigos` em uma função genérica `_purgar_antigos` (lida com arquivos OU diretórios), mantendo `_purgar_backups_antigos` como wrapper de compatibilidade para os call-sites da SPRINT 15. Custo: ~5 linhas extras. Justificativa: o corpo de `_purgar_backups_antigos` é genérico — `ls -dt` ordena por mtime independente de tipo, `rm -rf -- <alvo>` funciona em arquivo ou diretório, `validar_path_destrutivo` aceita ambos. Especializar por tipo seria duplicação inútil.
> - **Política de retenção é por contagem (N últimos)**, não por idade. Default `N=10`.
> - **Acentuação pt-BR íntegra** em log strings, comentários e docs.
> - **Idempotência** preservada em todos os subscripts tocados.
> - **Sem testes novos** para o helper genérico (mesmo critério da SPRINT 15). Verificação é manual via simulação descrita em "Testes".
> - **Não tocar** `reaplicar_tema.sh` — já está coberto transitivamente pela cadeia (chama `normalizar_desktops.sh`, que agora purga; usa `_log_file()`, que agora purga).

## Contexto

### Achado A1 — `normalizar_desktops.sh` cria backup com pattern fora do helper

`scripts/normalizar_desktops.sh:13`:

```bash
BACKUP_DIR="$HOME/.cache/dracula_os_backup_$(date +%Y%m%d_%H%M%S)/desktops"
```

Pattern: `~/.cache/dracula_os_backup_<TS>/desktops/` — note o **underscore** entre `backup` e `<TS>`, criando uma pasta NOVA toplevel para cada execução. **Diferente** do pattern `~/.cache/dracula_os_backup/<subdir>/` que `instalar_keybindings.sh` e `limpar_duplicatas.sh` usam (pasta única `dracula_os_backup/` com subdirs por timestamp), e que foi coberto pelo helper `_purgar_backups_antigos` da SPRINT 15.

`reaplicar_tema.sh` chama `normalizar_desktops.sh` em cada APT hook (seção 5 do reaplicador, herdada da SPRINT 06), portanto `~/.cache/dracula_os_backup_<TS>/` cresce silenciosamente a cada `apt upgrade`. Listagem real em desenvolvimento já mostrou múltiplos diretórios toplevel acumulados.

**Solução (Opção A)**: trocar destino para `$HOME/.cache/dracula_os_backup/desktops_<TS>/desktops/` (subdir dentro da pasta-mãe única). Em seguida chamar o helper de purga existente para o pattern `desktops_*`.

Vantagens:
- Tudo num lugar só (mesmo diretório-mãe coberto pela SPRINT 15).
- Helper já existente reutilizado (sem novo glob fora da árvore).
- `validar_path_destrutivo` cobre nativamente (`~/.cache/dracula_os_backup` está na allowlist em `lib/common.sh:73`).

Caveat sobre o duplo `desktops/desktops/`:
- Estrutura final: `$HOME/.cache/dracula_os_backup/desktops_<TS>/desktops/<arquivo>.desktop`.
- O subdir interno `desktops/` é parte do contrato original do script (ver comentário `lib/common.sh` ausente; comentário em `normalizar_desktops.sh:8`). Mantido por **mudança cirúrgica** — não vamos reescrever a lógica do mkdir/cp do script.

### Achado A2 — Logs em `~/.cache/dracula_os_theme/` sem rotação

`scripts/lib/common.sh:46-58` — funções `_log_dir()` e `_log_file()`:

```bash
_log_dir() {
    local dir="$HOME/.cache/dracula_os_theme"
    mkdir -p "$dir"
    echo "$dir"
}

_log_file() {
    local nome="${1:-operacao}"
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    echo "$(_log_dir)/${nome}_${ts}.log"
}
```

Cada execução de `reaplicar_tema.sh` (e qualquer outro script que chame `_log_file`) gera um arquivo novo `<nome>_<TS>.log`. Sem rotação. APT hook + reaplicação manual + diagnóstico podem encher o diretório indefinidamente.

Listagem real em desenvolvimento mostrou ≥ 5 logs `reaplicar_tema_*.log` acumulados.

**Solução**: chamar a nova função genérica `_purgar_antigos` ao final de `_log_file()` — purga os logs antigos da **mesma família** (mesmo `nome`, glob `${nome}_*.log`) **antes** de retornar o caminho do log novo. O log novo ainda nem existe nesse momento (vai ser criado pelo `tee -a` do chamador), portanto a purga não pode apagá-lo. Manter os 10 mais recentes que já existiam é suficiente — o novo (11º) é criado pelo `tee` logo depois.

**Race condition**: improvável em execução serial via APT hook (apt segura lock dpkg, scripts rodam um por vez). Múltiplos `reaplicar_tema.sh` paralelos não acontecem na prática. Não tratar.

## Decisão de design para A2 — função genérica `_purgar_antigos`

A função genérica é praticamente idêntica ao corpo atual de `_purgar_backups_antigos`:

| Item | `_purgar_backups_antigos` atual | `_purgar_antigos` (novo, genérico) |
|------|----------------------------------|-------------------------------------|
| Ordena por mtime | `ls -1dt $pattern` | `ls -1dt $pattern` (idêntico) |
| Mantém N | `[[ $i -le $manter ]] && continue` | idêntico |
| Restrição de path | hard-coded `$HOME/.cache/dracula_os_backup/` | parametrizável (terceiro argumento opcional) ou removida em favor de `validar_path_destrutivo` (que já cobre `~/.cache/dracula_os_theme` via allowlist `lib/common.sh:72`) |
| Remoção | `rm -rf "$alvo"` | idêntico — funciona para arquivo e diretório |

API proposta:

```bash
# _purgar_antigos <pattern_glob> <quantidade_a_manter>
# Mantém os N mais recentes (por mtime, desc) que casam com o glob, removendo
# o restante. Cada candidato passa por validar_path_destrutivo antes do rm
# (defesa contra patterns corrompidos). Funciona em arquivos OU diretórios.
# Sem matches → no-op silencioso.
```

`_purgar_backups_antigos` vira **wrapper** de compatibilidade:

```bash
_purgar_backups_antigos() {
    _purgar_antigos "$@"
}
```

Custo da refatoração: ~5 linhas extras (wrapper + 2 linhas de comentário). Mantém os call-sites da SPRINT 15 (`instalar_keybindings.sh:86` e `limpar_duplicatas.sh:112`) funcionando sem qualquer alteração. Compatibilidade preservada.

**Defesa**: a função genérica usa `validar_path_destrutivo` em vez de hard-code do prefixo `dracula_os_backup`. Isso amplia o uso (logs também passam — `dracula_os_theme` está na allowlist) mas mantém a barreira de segurança. Antes da refatoração, o hard-code era cinta-e-suspensório redundante; remover é cirúrgico e consistente com o resto da `lib/common.sh` que confia em `validar_path_destrutivo`.

## Falsos positivos / fora-de-escopo (verificados antes do redigir)

- **`scripts/instalar_app_themes.sh:195`** usa `~/.cache/dracula-telegram/dracula.tdesktop-theme` — cache próprio do tema do Telegram, não cresce, não é poluição. **Não tocar**.
- **`scripts/normalizar_desktops.sh:13`** legado fora-do-helper já está coberto por A1.
- **`reaplicar_tema.sh:102`** comentário cita `~/.cache/dracula_os_backup/` mas não cria backup novo lá; é referência textual.
- **Outros scripts** (`instalar_apt_hook.sh`, `checar_ambiente.sh`, `atualizar_icones_steam.sh`, `instalar_pop_cosmic_ptbr.sh`, `instalar_higiene_launcher.sh`, etc.) — `grep -rn '\$HOME/.cache\|~/.cache' scripts/` confirma que nenhum cria backup com timestamp em `~/.cache/dracula_os_backup/` ou logs fora de `_log_file`. Nada a fazer.

## Escopo (touches autorizados)

Arquivos **a modificar**:

- `scripts/lib/common.sh` — refatorar `_purgar_backups_antigos` em `_purgar_antigos` genérico + wrapper de compat; chamar `_purgar_antigos` no final de `_log_file()`.
- `scripts/normalizar_desktops.sh` — trocar `BACKUP_DIR` para `$HOME/.cache/dracula_os_backup/desktops_<TS>/desktops` e adicionar source de `lib/common.sh` + chamada ao helper.
- `docs/sprints/INDEX.md` — adicionar linha SPRINT 16.
- `CHANGELOG.md` — entrada nova em `[Unreleased]` `### Adicionado`.

Arquivos **a criar**:

- `docs/sprints/SPRINT_16_HOUSEKEEPING_DESKTOPS_LOGS.md` (este documento).

Arquivos **NÃO tocar** (invariantes):

- `scripts/reaplicar_tema.sh` — coberto transitivamente. Não modificar.
- `scripts/instalar_keybindings.sh`, `scripts/limpar_duplicatas.sh` — call-sites da SPRINT 15 funcionam sem alteração via wrapper. Não modificar.
- `scripts/diagnostico.sh`, `scripts/release.sh` — cobertos pela SPRINT 15.
- `install.sh`, `uninstall.sh`, `build.sh` — fora.
- Allowlist `_allowlist_destrutiva` em `lib/common.sh:64-79` — **não modificar** (já contém `~/.cache/dracula_os_theme` linha 72 e `~/.cache/dracula_os_backup` linha 73).
- Logger pattern (`_info`, `_ok`, `_warn`, `_err`, `_dim`) — usar como existente.
- Sources canônicos `src/shell/pop-{shell,cosmic}-dark.css` — fora.
- `app-themes/`, `dist/`, `releases/` — fora.

## Acceptance criteria

1. `bash -n` em todos os scripts modificados retorna exit 0:
   - `bash -n scripts/lib/common.sh`
   - `bash -n scripts/normalizar_desktops.sh`
2. `source scripts/lib/common.sh && declare -F _purgar_antigos _purgar_backups_antigos` imprime ambas as funções (genérica + wrapper).
3. `( source scripts/lib/common.sh && _purgar_backups_antigos --help 2>&1 || true )` continua funcionando (wrapper preserva semântica para os call-sites SPRINT 15).
4. **Simulação A1 — backup de `.desktop`**: criar 12 dirs `~/.cache/dracula_os_backup/desktops_dummy_<NN>/` com mtimes crescentes, chamar `_purgar_antigos "$HOME/.cache/dracula_os_backup/desktops_dummy_*" 10`, listar resultado: sobram exatamente 10. (Nome `desktops_dummy_*` evita colisão com `desktops_<TS>` reais que possam existir.)
5. **Simulação A2 — logs**: criar 12 arquivos `~/.cache/dracula_os_theme/teste_dummy_<NN>.log` com mtimes crescentes, chamar `_purgar_antigos "$HOME/.cache/dracula_os_theme/teste_dummy_*.log" 10`, listar: sobram exatamente 10.
6. **Pattern sem matches**: `_purgar_antigos "$HOME/.cache/dracula_os_backup/_inexistente_*" 10` retorna exit 0 sem ruído.
7. **Pattern fora da allowlist**: `_purgar_antigos "/etc/passwd*" 10` não remove nada (cada candidato rejeitado por `validar_path_destrutivo`).
8. `bash scripts/normalizar_desktops.sh --dry-run` exit 0; mensagem `Backup em: $HOME/.cache/dracula_os_backup/desktops_<TS>/desktops` aparece (note: dry-run não cria backup, apenas anuncia o destino).
9. `bash scripts/reaplicar_tema.sh` exit 0 em ambiente sadio; após execução, `ls -1 ~/.cache/dracula_os_theme/reaplicar_tema_*.log | wc -l` ≤ 10.
10. `bash scripts/diagnostico.sh --quiet` exit 0 (sem regressão).
11. `grep -c 'dracula_os_backup_\$(date' scripts/normalizar_desktops.sh` retorna 0 (pattern legado removido).
12. `grep -nE 'BACKUP_DIR=.*dracula_os_backup/desktops_' scripts/normalizar_desktops.sh` retorna 1 hit (novo destino).
13. `grep -n 'source.*lib/common.sh' scripts/normalizar_desktops.sh` retorna ≥ 1 hit (helper acessível).
14. Acentuação pt-BR íntegra: `grep -nE 'implementacao|concluida|nao |execucao|funcao|backup antigo|rotacao|rotacionar' scripts/lib/common.sh scripts/normalizar_desktops.sh docs/sprints/SPRINT_16_HOUSEKEEPING_DESKTOPS_LOGS.md docs/sprints/INDEX.md CHANGELOG.md` retorna 0 hits relevantes.
15. `wc -l scripts/lib/common.sh` na faixa **190–205** (ver "Aritmética").

## Invariantes a preservar

- `set -euo pipefail` em `normalizar_desktops.sh:10`. Não trocar.
- `_DRACULA_COMMON_SOURCED` guard em `lib/common.sh:11-12` — não duplicar.
- Allowlist de `validar_path_destrutivo` (`lib/common.sh:64-79`) — **não modificar** (já contém `~/.cache/dracula_os_theme` linha 72 e `~/.cache/dracula_os_backup` linha 73).
- Logger pattern (`_info`, `_ok`, `_warn`, `_err`, `_dim`).
- Acentuação pt-BR em strings de log e comentários novos.
- Idempotência em `normalizar_desktops.sh` (script pode rodar N vezes; cada execução cria seu próprio backup `desktops_<TS>` e purga os antigos).
- Compatibilidade dos call-sites SPRINT 15 (`instalar_keybindings.sh:86`, `limpar_duplicatas.sh:112`) — wrapper `_purgar_backups_antigos` deve aceitar a mesma assinatura `<pattern> <manter>`.
- CLAUDE.md §3 (cirúrgico): não tocar nada além do necessário; não reformatar comentários ou estilo adjacente.

## Plano de implementação

### Passo 1 — `scripts/lib/common.sh` — refatorar helper

**Substituir** o bloco atual `_purgar_backups_antigos` (linhas 158–185) pelo bloco abaixo. Mantém o cabeçalho de comentário SPRINT 15 e adiciona nota SPRINT 16.

```bash
# ─── Retencao de artefatos antigos (SPRINT 15 + 16) ───
# Mantem apenas os N artefatos mais recentes (por mtime, desc) que casam
# com o glob, removendo os mais antigos. Funciona para arquivos OU
# diretorios. Cada candidato a remocao passa por validar_path_destrutivo
# (defesa contra patterns corrompidos). Sem matches -> no-op silencioso.
#
# Uso tipico:
#   _purgar_antigos "$HOME/.cache/dracula_os_backup/keybindings_*" 10
#   _purgar_antigos "$HOME/.cache/dracula_os_theme/reaplicar_tema_*.log" 10
_purgar_antigos() {
    local pattern="${1:-}"
    local manter="${2:-10}"
    [[ -z "$pattern" ]] && { _err "_purgar_antigos: pattern vazio"; return 2; }
    local lista
    # Ordena por mtime decrescente; ignora erro se nao casa nada
    lista="$(ls -1dt $pattern 2>/dev/null)" || true
    [[ -z "$lista" ]] && return 0
    local i=0 alvo
    while IFS= read -r alvo; do
        i=$((i+1))
        [[ $i -le $manter ]] && continue
        # Defesa: cada alvo tem que estar na allowlist destrutiva
        if ! validar_path_destrutivo "$alvo" >/dev/null 2>&1; then
            _warn "_purgar_antigos: pulando '$alvo' (fora da allowlist)"
            continue
        fi
        rm -rf -- "$alvo" 2>/dev/null || _warn "_purgar_antigos: rm falhou em '$alvo'"
    done <<< "$lista"
    return 0
}

# Wrapper de compatibilidade SPRINT 15. Mantem assinatura para os call-sites
# instalar_keybindings.sh e limpar_duplicatas.sh.
_purgar_backups_antigos() {
    _purgar_antigos "$@"
}
```

**Acentuação**: o bloco ASCII acima é proposital nos comentários internos da função (comentários de código fonte em ASCII puro no padrão atual da `lib/common.sh`); strings de log via `_err`/`_warn` permanecem ASCII também porque o restante de `lib/common.sh` já segue esse estilo (verificar consistência ao implementar — se houver acentos em outros comentários da `lib/common.sh`, padronizar com pt-BR completo). **Decisão executor**: replicar exatamente o estilo já presente no arquivo (verifica antes via `grep -nE 'execucao|funcao|nao' scripts/lib/common.sh` — atualmente 0 hits acentuados em comentários, então ASCII está OK).

**Nota**: substitua o cabeçalho antigo `─── Purga de backups antigos (SPRINT_15) ───` pela versão consolidada acima.

### Passo 2 — `scripts/lib/common.sh` — chamar helper em `_log_file()`

**Substituir** a função `_log_file` (linhas 53–58) por:

```bash
# Retorna caminho de arquivo de log com timestamp; chamador redireciona via | tee -a.
# Antes de retornar, purga os logs antigos da mesma familia (mesmo <nome>),
# mantendo apenas os 10 mais recentes ja existentes.
_log_file() {
    local nome="${1:-operacao}"
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    local dir
    dir="$(_log_dir)"
    _purgar_antigos "${dir}/${nome}_*.log" 10
    echo "${dir}/${nome}_${ts}.log"
}
```

**Ordem do `_purgar_antigos` é crítica**: chamada **antes** do `echo` final. O log novo ainda não existe nesse instante (vai ser criado pelo `tee -a` do chamador, depois). A purga só toca os ≥ 10 antigos da mesma família.

**Limite**: `_log_file` pode ser chamada antes de `_purgar_antigos` ser definido se houver mudança na ordem do arquivo. Confirmação: `_log_file` está na linha 53, `_purgar_antigos` ficará a partir da linha ~165. Em bash, funções são resolvidas em chamada (late binding), não em definição — portanto a ordem no arquivo não importa para a chamada `_purgar_antigos` dentro de `_log_file`. Sem risco.

### Passo 3 — `scripts/normalizar_desktops.sh` — alinhar layout + chamar helper

**Trocar** linha 13:

```bash
BACKUP_DIR="$HOME/.cache/dracula_os_backup_$(date +%Y%m%d_%H%M%S)/desktops"
```

por:

```bash
BACKUP_DIR="$HOME/.cache/dracula_os_backup/desktops_$(date +%Y%m%d_%H%M%S)/desktops"
```

**Adicionar source da lib** logo após `set -euo pipefail` (linha 10). Inserir como nova linha 11:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
```

(Comentário em linha 8 cita o destino antigo. Trocar também para refletir o novo path: linha 8 atual `# ~/.cache/dracula_os_backup_<timestamp>/desktops/` → `# ~/.cache/dracula_os_backup/desktops_<timestamp>/desktops/`.)

**Adicionar chamada ao helper** ao final de `main()`. Inserir após `_ok "Processados $total .desktop files"` (linha 100):

```bash
    _purgar_antigos "$HOME/.cache/dracula_os_backup/desktops_*" 10
```

(Indentação: 4 espaços, alinhada com o resto de `main()`.)

**Verificação de coerência com `instalar_keybindings.sh` (SPRINT 15)**:
- Pattern `keybindings_*` casa apenas `keybindings_<TS>`. Não colide com `desktops_<TS>`. OK.
- Pattern `desktops_*` casa apenas `desktops_<TS>`. Não colide com `keybindings_<TS>`. OK.
- Pattern `[0-9]*_[0-9]*` (de `limpar_duplicatas.sh`) casa apenas `<TS>` puro. Não colide com `desktops_<TS>` (começa com letra) nem `keybindings_<TS>` (idem). OK.

Os três globs são mutuamente exclusivos. Cada chamada do helper limpa apenas a sua família.

### Passo 4 — `docs/sprints/INDEX.md`

Adicionar **linha 24 nova** após a linha SPRINT 15 (linha 23 atual):

```
| 16 | [Housekeeping II: rotação de backups de .desktop e de logs](SPRINT_16_HOUSEKEEPING_DESKTOPS_LOGS.md) | Em implementação | 2026-05-07 |
```

(Manter alinhamento da tabela; padding idêntico às linhas 22–23.)

### Passo 5 — `CHANGELOG.md`

Em `[Unreleased]` → `### Adicionado`, acrescentar como último item (depois da linha SPRINT 15, linha 15 atual):

```
- **Sprint 16 — Housekeeping II: rotação de backups de `.desktop` e de logs**: refatoração de `_purgar_backups_antigos` em função genérica `_purgar_antigos` (lida com arquivos OU diretórios) em `scripts/lib/common.sh`; wrapper de compatibilidade preserva os call-sites da SPRINT 15. `scripts/normalizar_desktops.sh` migra `BACKUP_DIR` para `$HOME/.cache/dracula_os_backup/desktops_<TS>/desktops/` (dentro do diretório-mãe único) e ganha chamada `_purgar_antigos "$HOME/.cache/dracula_os_backup/desktops_*" 10` ao final de `main()`. `_log_file()` em `lib/common.sh` purga logs antigos da mesma família (`<nome>_*.log`) antes de retornar o caminho do log novo, capando `~/.cache/dracula_os_theme/` em ~10 entradas por família. Fim da poluição transitiva via APT hook nos dois pontos remanescentes pós-SPRINT 15.
```

## Aritmética

Sprint **adiciona** mais do que remove. Sem meta de redução. Faixas esperadas:

| Arquivo | Antes (L) | Depois (L) | Delta |
|---------|-----------|------------|-------|
| `scripts/lib/common.sh` | 188 | ~200 | +12 (função renomeada → genérica + wrapper de 3 linhas + chamada `_purgar_antigos` em `_log_file` + comentário) |
| `scripts/normalizar_desktops.sh` | 106 | ~109 | +3 (source da lib + chamada do helper + ajuste de comentário linha 8) |
| `docs/sprints/INDEX.md` | 44 | 45 | +1 |
| `CHANGELOG.md` | (atual) | +1 item | +1 linha em `### Adicionado` |
| `docs/sprints/SPRINT_16_HOUSEKEEPING_DESKTOPS_LOGS.md` | 0 | novo | criação |

**Validação obrigatória antes do commit**:
- `wc -l scripts/lib/common.sh` na faixa **190–205**. Fora indica refactor não solicitado.
- `wc -l scripts/normalizar_desktops.sh` na faixa **107–112**. Fora indica overscope.
- Demais sem meta rígida.

## Testes / proof-of-work

Comandos a registrar no commit:

### Sintaxe e source

```bash
bash -n scripts/lib/common.sh
bash -n scripts/normalizar_desktops.sh
( source scripts/lib/common.sh && declare -F _purgar_antigos _purgar_backups_antigos )
# esperado: ambas as funcoes declaradas
```

### Simulação do helper genérico (A1 — diretórios)

```bash
( source scripts/lib/common.sh
  mkdir -p "$HOME/.cache/dracula_os_backup"
  for i in $(seq -w 1 12); do
      d="$HOME/.cache/dracula_os_backup/desktops_dummy_$i"
      mkdir -p "$d"
      touch -d "2026-05-07 10:$i:00" "$d"
  done
  ls -1dt "$HOME/.cache/dracula_os_backup"/desktops_dummy_* | wc -l   # esperado: 12
  _purgar_antigos "$HOME/.cache/dracula_os_backup/desktops_dummy_*" 10
  ls -1dt "$HOME/.cache/dracula_os_backup"/desktops_dummy_* | wc -l   # esperado: 10
  rm -rf "$HOME/.cache/dracula_os_backup"/desktops_dummy_*
)
```

### Simulação do helper genérico (A2 — arquivos)

```bash
( source scripts/lib/common.sh
  mkdir -p "$HOME/.cache/dracula_os_theme"
  for i in $(seq -w 1 12); do
      f="$HOME/.cache/dracula_os_theme/teste_dummy_$i.log"
      : > "$f"
      touch -d "2026-05-07 10:$i:00" "$f"
  done
  ls -1t "$HOME/.cache/dracula_os_theme"/teste_dummy_*.log | wc -l   # esperado: 12
  _purgar_antigos "$HOME/.cache/dracula_os_theme/teste_dummy_*.log" 10
  ls -1t "$HOME/.cache/dracula_os_theme"/teste_dummy_*.log | wc -l   # esperado: 10
  rm -f "$HOME/.cache/dracula_os_theme"/teste_dummy_*.log
)
```

### Wrapper de compatibilidade

```bash
( source scripts/lib/common.sh
  # Reproduz call-site da SPRINT 15 (instalar_keybindings.sh:86)
  _purgar_backups_antigos "$HOME/.cache/dracula_os_backup/keybindings_inexistente_*" 10
  echo "exit=$?"   # esperado: 0
)
```

### Pattern vazio e fora-da-allowlist

```bash
( source scripts/lib/common.sh
  _purgar_antigos "$HOME/.cache/dracula_os_backup/_inexistente_*" 10  # exit 0, sem ruido
  _purgar_antigos "/etc/passwd*" 10                                    # rejeita cada candidato
)
```

### `normalizar_desktops.sh`

```bash
bash -n scripts/normalizar_desktops.sh
bash scripts/normalizar_desktops.sh --dry-run | grep 'dracula_os_backup/desktops_'
# esperado: 1 hit, formato 'Backup em: /home/.../dracula_os_backup/desktops_<TS>/desktops'
grep -nE 'BACKUP_DIR=.*dracula_os_backup/desktops_' scripts/normalizar_desktops.sh
# esperado: 1 hit (linha do BACKUP_DIR refatorado)
grep -nE 'dracula_os_backup_\$\(date' scripts/normalizar_desktops.sh
# esperado: 0 hits (pattern legado removido)
grep -nE 'source.*lib/common\.sh' scripts/normalizar_desktops.sh
# esperado: 1 hit
```

### `_log_file` purga logs antigos

```bash
( source scripts/lib/common.sh
  mkdir -p "$HOME/.cache/dracula_os_theme"
  for i in $(seq -w 1 12); do
      f="$HOME/.cache/dracula_os_theme/teste_logfile_$i.log"
      : > "$f"
      touch -d "2026-05-07 10:$i:00" "$f"
  done
  novo="$(_log_file teste_logfile)"
  echo "Novo log: $novo"
  ls -1 "$HOME/.cache/dracula_os_theme"/teste_logfile_*.log | wc -l
  # esperado: 10 (purga ja feita; arquivo novo ainda nao foi tocado pelo tee)
  rm -f "$HOME/.cache/dracula_os_theme"/teste_logfile_*.log
)
```

### Reaplicação real e diagnóstico

```bash
bash scripts/reaplicar_tema.sh
echo "exit=$?"
# esperado: exit 0 (idempotente em ambiente sadio)
ls -1 "$HOME/.cache/dracula_os_theme"/reaplicar_tema_*.log | wc -l
# esperado: <= 10

bash scripts/diagnostico.sh --quiet
echo "exit=$?"
# esperado: exit 0
```

### Aritmética

```bash
wc -l scripts/lib/common.sh         # esperado 190..205
wc -l scripts/normalizar_desktops.sh  # esperado 107..112
```

### Acentuação periférica

```bash
grep -nE 'implementacao|concluida|nao |execucao|funcao|backup antigo|rotacao|rotacionar' \
    scripts/lib/common.sh \
    scripts/normalizar_desktops.sh \
    docs/sprints/SPRINT_16_HOUSEKEEPING_DESKTOPS_LOGS.md \
    docs/sprints/INDEX.md \
    CHANGELOG.md
# esperado: 0 hits
```

### Hipótese verificada (lição 4)

Antes de iniciar, executor confirma identificadores via `rg`:

```bash
rg -n '_purgar_backups_antigos|_purgar_antigos|_log_file|_log_dir|BACKUP_DIR|validar_path_destrutivo' scripts/
rg -n '\$HOME/.cache' scripts/
```

Esperado: encontrar `_purgar_backups_antigos` em `lib/common.sh:164` e nos call-sites SPRINT 15; `_log_file` em `lib/common.sh:53` e em `reaplicar_tema.sh:18`; `BACKUP_DIR` em `normalizar_desktops.sh:13`, `instalar_keybindings.sh:21`, `limpar_duplicatas.sh:24`. Tudo confirmado na exploração do planejador.

## Riscos

1. **Glob com asterisco em `_purgar_antigos`**: o helper usa `ls -1dt $pattern` (sem aspas), portanto o glob é expandido pelo shell **dentro** da função. Risco: se o chamador passar pattern com aspas duplas que contém variável não-expandida (ex.: `_purgar_antigos '$HOME/...'`), a expansão falha. Mitigação: documentação do helper já usa aspas duplas com `$HOME` interpolado. Não-risco.
2. **`_log_file` chamando `_purgar_antigos` antes deste estar definido no arquivo**: late binding em bash resolve isso (função é encontrada na chamada, não na definição). Validado.
3. **Race: dois `reaplicar_tema.sh` paralelos**: improvável (APT segura lock). Não tratar.
4. **Chamada de `_purgar_antigos` em `_log_file` retorna 2 quando pattern vazio**: `_log_file` recebe `nome="${1:-operacao}"` portanto o glob `${dir}/${nome}_*.log` nunca é vazio. Sem risco.
5. **Mudança de layout em `normalizar_desktops.sh` e backups antigos órfãos**: backups pré-SPRINT 16 estão em `~/.cache/dracula_os_backup_<TS>/` (toplevel, com underscore). O novo helper não os enxerga (pattern `desktops_*` está dentro de `dracula_os_backup/`, não casa toplevel). **Decisão**: deixar órfãos como estão; usuário pode limpar manualmente. Migração automatizada está fora do escopo (CLAUDE.md §3).
6. **Wrapper `_purgar_backups_antigos` quebrar shellcheck**: o passagem via `"$@"` é idiomática. Sem risco.
7. **`validar_path_destrutivo` e arquivos `.log`**: a allowlist tem `~/.cache/dracula_os_theme` (linha 72) — qualquer `.log` dentro casa o prefixo. Validado: `validar_path_destrutivo "$HOME/.cache/dracula_os_theme/teste.log"` → exit 0.

## Não-objetivos (fora de escopo)

- Migrar backups órfãos pré-SPRINT 16 (`~/.cache/dracula_os_backup_<TS>/`) para o novo layout.
- Comprimir logs antigos.
- Política de retenção por idade (`mtime > 30d`).
- UI ou subscript dedicado para gerenciar logs/backups.
- Testes automatizados para `_purgar_antigos` (custo/benefício baixo, mesma decisão da SPRINT 15).
- Renomear `_purgar_backups_antigos` para `_purgar_antigos` em todos os call-sites SPRINT 15 (manter wrapper é cirúrgico).
- Tocar `reaplicar_tema.sh` (cobertura é transitiva via subscripts e `_log_file`).
- Adicionar log rotacionado em scripts que ainda não usam `_log_file` (separado do escopo desta sprint).

## Referências

- `CLAUDE.md` global e local — §2 (simplicidade), §3 (cirúrgico), §4 (objetivos verificáveis).
- `docs/sprints/SPRINT_06_RESILIENCIA_POS_UPGRADE.md` — APT hook origem da poluição.
- `docs/sprints/SPRINT_08_SEGURANCA_ROBUSTEZ.md` — `validar_path_destrutivo` e `backup_com_manifest`.
- `docs/sprints/SPRINT_15_HOUSEKEEPING.md` — `_purgar_backups_antigos` original; achados A1 e A2 registrados nas linhas 369–375 (escopo desta sprint).
- `CHANGELOG.md` — entrada `[Unreleased]` `### Adicionado` SPRINT 15 (precedente).

*"O cesto cheio precisa ser esvaziado para receber a colheita nova." — adágio do `~/.cache/`.*
