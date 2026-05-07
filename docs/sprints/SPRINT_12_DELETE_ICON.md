# Sprint 12 — Propagação completa dos symbolic icons no `Dracula-Icones`

Tornar o tema `Dracula-Icones` (gerado pelo `build.sh`) **autocontido para todo symbolic icon disponível nos heritages** (`dracula-icons-circle`, `dracula-icons-main`). Após esta sprint, qualquer chamada `St.Icon({icon_name: 'X-symbolic'})` no GNOME Shell ou em extensões (incluindo `pop-cosmic@system76.com`) que tenha equivalente em algum heritage será resolvida **diretamente** no `Dracula-Icones`, sem cair em `Adwaita` / `hicolor` por buraco no índice nem depender da ordem de lookup do `Inherits=`.

A causa-raiz original (botão "excluir pasta" do launcher Pop!_Cosmic renderizando um segundo lápis em vez de lixeira) é resolvida como **caso particular** desta propagação geral.

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 12 (10 e 11 já commitadas). Nome de arquivo permanece `SPRINT_12_DELETE_ICON.md` por já estar referenciado em `INDEX.md` e em commits anteriores; o título lógico passa a ser "Propagação completa dos symbolic icons".
> - **Heritages imutáveis**: NÃO tocar `src/icons/upstream/dracula-icons-circle/**` nem `src/icons/upstream/dracula-icons-main/**`. Os SVGs são **lidos** (`cp`), nunca modificados.
> - **Prioridade de merge**: `dracula-icons-circle` vence `dracula-icons-main` em colisões de nome (o `circle` é a curadoria visual preferida — confirmado pelos hashes corretos de `edit-symbolic` e `edit-delete-symbolic` no `circle`).
> - **Subdirs cobertos**: `symbolic/{actions,apps,categories,devices,emblems,emotes,mimetypes,places,status}` — exatamente os que existem em pelo menos um dos heritages.
> - **Sem variantes raster**: symbolic icons são vetoriais e color-stylable via CSS; **não** gerar PNGs em `16x16/symbolic/...` etc.
> - **Sem novo script**: a mudança vive dentro do `build.sh` existente (uma função nova + uma chamada + extensão de `gerar_index_theme()`).
> - **Sem tocar outros temas**: `Dracula-standard-buttons`, `Dracula-Cursor`, `dracula-icons-main` (cópia do upstream em `dist/`), `dracula-icons-circle` (idem) ficam intactos.
> - **Sem features especulativas** (CLAUDE.md §2): não criar conversor de SVG, não inventar Context novo, não criar array configurável de "symbolic icons preferidos".

## Contexto

### Causa-raiz observada (caso particular)

No launcher `pop-cosmic@system76.com`, ao abrir uma pasta personalizada (ex.: `suse-yast.directory`), o header exibe dois ícones de ação no canto superior direito invocados pelas linhas (versão `0.1.0~1765823448~22.04~07b06d4`):

- `applications.js:325` — `'edit-symbolic'` (rename, deveria ser **lápis**).
- `applications.js:329` — `'edit-delete-symbolic'` (delete, deveria ser **lixeira**).

O usuário relatou (com screenshot) que aparecem **dois lápis** em vez de lápis + lixeira.

### Causa-raiz observada (estrutural)

- Tema ativo: `Dracula-Icones` (`gsettings get org.gnome.desktop.interface icon-theme` retorna `'Dracula-Icones'`).
- `~/.local/share/icons/Dracula-Icones/index.theme` declara:
  ```
  Inherits=dracula-icons-circle,dracula-icons-main,Adwaita,hicolor
  Directories=scalable/apps,scalable/mimetypes,16x16/apps,16x16/mimetypes,...,256x256/apps,256x256/mimetypes
  ```
  **NÃO contém `symbolic/*`** em `Directories=` — confirmado por `grep -c "symbolic/" ~/.local/share/icons/Dracula-Icones/index.theme` retornando `0`.
- Como o `Dracula-Icones` não tem nenhum `symbolic/*` em `Directories=`, **todo lookup de symbolic icon cai em `Inherits=`**, ordem `dracula-icons-circle, dracula-icons-main, Adwaita, hicolor`. O `circle` traz o SVG correto para `edit-delete-symbolic`, mas em algumas máquinas o GTK/St acaba memoizando uma resolução para o `main` (que tem variante divergente) ou para `Adwaita`. Resultado: ícones errados de forma intermitente.
- O `build.sh` atual não tem nenhuma menção a `symbolic` (`grep -c "symbolic" build.sh` retorna `0`). Todo o pipeline de geração do `Dracula-Icones` cobre apenas `apps` e `mimetypes`.

### Solução estrutural

Materializar **todos os SVGs symbolic dos heritages** em `dist/icons/Dracula-Icones/symbolic/<sub>/` com merge por nome (prioridade `circle`), e declarar todos os `symbolic/<sub>` populados no `index.theme` gerado. O lookup do GTK encontra os SVGs locais antes de descer para `Inherits=`, eliminando a fragilidade.

### Escala medida (heritages no repo)

`src/icons/upstream/dracula-icons-circle/symbolic/`:

| Subdir | SVGs |
|---|---|
| actions | 402 |
| apps | 99 |
| categories | 16 |
| devices | 78 |
| emblems | 11 |
| emotes | 27 |
| mimetypes | 25 |
| places | 30 |
| status | 333 |
| **Total** | **1.021** |

`src/icons/upstream/dracula-icons-main/symbolic/`:

| Subdir | SVGs |
|---|---|
| actions | 619 |
| apps | 284 |
| categories | 41 |
| devices | 84 |
| emblems | 11 |
| emotes | 27 |
| mimetypes | 27 |
| places | 34 |
| status | 431 |
| **Total** | **1.558** |

União por nome (prioridade `circle`, calculada via `sort -u` no planejamento):

| Subdir | União | Observação |
|---|---|---|
| actions | 619 | `main` ⊇ `circle` em nome; conteúdo do `circle` vence quando há colisão |
| apps | 284 | idem |
| categories | 41 | idem |
| devices | 84 | idem |
| emblems | 11 | conjuntos coincidem |
| emotes | 27 | conjuntos coincidem |
| mimetypes | 27 | idem |
| places | 34 | idem |
| status | 431 | idem |
| **Total** | **1.558** | |

(O executor deve **recalcular e validar** esses números antes de implementar — ver "Aritmética" abaixo.)

## Hipóteses / Objetivos

1. **`Directories=` declarando `symbolic/<sub>` faz o GTK/St procurar localmente antes da herança.** Comportamento padrão do `gtk-update-icon-cache` (validar com cache regenerado sem warnings).
2. **`Type=Scalable` com `MinSize=8/MaxSize=512` e `Size=16` é o esquema canônico** usado pelos próprios upstreams `dracula-icons-circle` e `dracula-icons-main` para `symbolic/<sub>` (executor deve confirmar inspecionando `src/icons/upstream/dracula-icons-circle/index.theme` e `dracula-icons-main/index.theme`).
3. **Cópia direta de SVG (`cp -p`) preserva integridade**: nenhuma conversão/raster é necessária. `sha256sum` final no `dist/` casa com o `circle` (quando existe lá) ou com o `main` (quando o nome só existe no `main`).
4. **Idempotência do build não muda**: `limpar_dist()` apaga e recria `dist/`; rodar `build.sh` duas vezes seguidas continua produzindo o mesmo output (mesmos hashes).
5. **`install.sh` não precisa de mudanças**: ele já faz `cp -r "$DIST/icons/Dracula-Icones" "$DEST_ICONS/"` integralmente (linha 107) e roda `gtk-update-icon-cache -f -t "$DEST_ICONS/Dracula-Icones"` (linha 108). Qualquer subdir nova em `dist/` vai junto.
6. **Não-regressão dos heritages no `dist/`**: `dist/icons/dracula-icons-main/` e `dist/icons/dracula-icons-circle/` continuam intocados (a sprint só adiciona em `dist/icons/Dracula-Icones/`).

## Escopo (touches autorizados)

Arquivos a modificar (mudança cirúrgica):
- `build.sh` — adicionar uma função nova `gerar_symbolic_icons()` e uma chamada em `main()` entre `gerar_mimetypes` e `gerar_index_theme`; estender `gerar_index_theme()` para incluir todas as subdirs `symbolic/*` populadas e seus blocos.
- `CHANGELOG.md` — uma entrada nova sob `## [Unreleased]`.
- `docs/sprints/INDEX.md` — atualizar título da SPRINT 12 (escopo expandido).

Arquivos a criar:
- (nenhum) — este spec já existe e é apenas reescrito.

Arquivos NÃO tocar:
- `src/icons/upstream/dracula-icons-circle/**` — heritage imutável.
- `src/icons/upstream/dracula-icons-main/**` — heritage imutável.
- `install.sh` — sem mudança necessária (já copia qualquer subdir do `Dracula-Icones`).
- `applications.js` da extensão pop-cosmic (sistema ou cópia user-dir) — esta sprint não muda o consumidor, só o fornecedor de ícones.
- `scripts/lib/common.sh` — sem nova função compartilhada.
- Outros temas em `dist/icons/`: `dracula-icons-main`, `dracula-icons-circle`, `Dracula-Cursor`.
- Qualquer arquivo em `/usr/share/`.

## Plano de implementação

### Passo 1 — Confirmar premissas no `build.sh`

Antes de codar, executor deve abrir `build.sh` e confirmar (`grep -n` recomendado):

- Função `limpar_dist()` está em torno da linha 82 (zera `dist/` por inteiro). **Mantém idempotência por construção**.
- Função `gerar_mimetypes()` termina em torno da linha 219.
- Função `gerar_index_theme()` começa em torno da linha 222 e tem `local dirs=("scalable/apps" "scalable/mimetypes")` em torno da linha 225, com heredoc `local blocos="..."` nas linhas 226-239 e loop `for size in "${TAMANHOS[@]}"; do dirs+=...` nas linhas 240-253.
- `main()` em torno da linha 365, com sequência atual:
  ```
  limpar_dist
  copiar_upstreams
  gerar_tema_icones
  gerar_mimetypes
  gerar_index_theme
  copiar_cursor_gtk_shell
  preparar_extras
  atualizar_caches
  ```
- A chamada nova `gerar_symbolic_icons` deve ficar **entre `gerar_mimetypes` e `gerar_index_theme`** — porque `gerar_index_theme` precisa saber quais subdirs symbolic foram populadas.

### Passo 2 — Nova função `gerar_symbolic_icons()` em `build.sh`

Inserir entre `gerar_mimetypes()` (termina em torno da linha 219) e `gerar_index_theme()` (começa em torno da linha 222). Estilo idêntico ao das funções vizinhas (logs `_info` / `_ok` / `_warn`, mesma convenção de variáveis):

```bash
# ─── Fase C3: Propagar symbolic/* dos heritages ao Dracula-Icones ───
# Merge com prioridade dracula-icons-circle: para cada nome único em
# symbolic/<sub>, copia do circle se existir; senão do main.
# Resultado: lookup local de qualquer X-symbolic disponível nos heritages,
# sem depender de Inherits=.
# Subdirs efetivamente populadas são exportadas no array global
# SYMBOLIC_SUBDIRS_POPULADAS para gerar_index_theme() consumir.
SYMBOLIC_SUBDIRS_POPULADAS=()

gerar_symbolic_icons() {
    _info "Propagando symbolic icons dos heritages (prioridade: circle)"
    local destino_base="$DIST/icons/$TEMA_ICONES/symbolic"
    local fonte_circle="$SRC/icons/upstream/dracula-icons-circle/symbolic"
    local fonte_main="$SRC/icons/upstream/dracula-icons-main/symbolic"
    local subdirs=(actions apps categories devices emblems emotes mimetypes places status)
    local total_geral=0

    for sub in "${subdirs[@]}"; do
        local destino="$destino_base/$sub"
        local count_circle=0 count_main_only=0

        # Coletar nomes únicos (basename) das duas fontes
        local -A nomes=()
        if [[ -d "$fonte_circle/$sub" ]]; then
            for svg in "$fonte_circle/$sub"/*.svg; do
                [[ -f "$svg" ]] || continue
                nomes["$(basename "$svg")"]="circle"
            done
        fi
        if [[ -d "$fonte_main/$sub" ]]; then
            for svg in "$fonte_main/$sub"/*.svg; do
                [[ -f "$svg" ]] || continue
                local n
                n="$(basename "$svg")"
                # circle vence; só seta main se ainda não tiver origem
                if [[ -z "${nomes[$n]:-}" ]]; then
                    nomes["$n"]="main"
                fi
            done
        fi

        local total=${#nomes[@]}
        if [[ $total -eq 0 ]]; then
            # Subdir vazia em ambos heritages — não criar e não declarar
            continue
        fi

        mkdir -p "$destino"
        for nome in "${!nomes[@]}"; do
            local origem="${nomes[$nome]}"
            local src_svg
            if [[ "$origem" == "circle" ]]; then
                src_svg="$fonte_circle/$sub/$nome"
                count_circle=$((count_circle + 1))
            else
                src_svg="$fonte_main/$sub/$nome"
                count_main_only=$((count_main_only + 1))
            fi
            cp -p "$src_svg" "$destino/$nome"
        done

        SYMBOLIC_SUBDIRS_POPULADAS+=("symbolic/$sub")
        total_geral=$((total_geral + total))
        _ok "symbolic/$sub: $total ícones (circle=$count_circle, main-only=$count_main_only)"
    done

    _ok "symbolic propagado: ${#SYMBOLIC_SUBDIRS_POPULADAS[@]} subdirs, $total_geral SVGs"
}
```

> **Detalhes importantes**:
> - `local -A nomes=()` (associative array) exige bash >= 4. O projeto já usa bash extensions; `set -euo pipefail` no topo confirma. Executor pode validar com `bash --version`.
> - `cp -p` preserva timestamps, ajudando a estabilidade de hash entre runs.
> - `SYMBOLIC_SUBDIRS_POPULADAS` é declarada **fora da função** (escopo global do script) para sobreviver ao retorno e ser lida por `gerar_index_theme()`.
> - O `set +e` que `gerar_tema_icones()` usa **não vaza para cá** porque ele tem `set -e` no fim (linha 176). Esta função roda sob `set -e` normal — qualquer falha aborta com mensagem clara.

### Passo 3 — Estender `gerar_index_theme()` em `build.sh`

Modificações cirúrgicas (sem reformatar adjacente):

- Inicializar `dirs` e `blocos` como hoje.
- **Após** o loop `for size in "${TAMANHOS[@]}"` que adiciona os blocos raster, adicionar um loop **novo** que itera `SYMBOLIC_SUBDIRS_POPULADAS` e adiciona cada subdir ao `dirs` e seu bloco ao `blocos`.
- Mapping fixo `subdir → Context` (declarado dentro da função, como tabela local):

| Subdir | Context |
|---|---|
| symbolic/actions | Actions |
| symbolic/apps | Applications |
| symbolic/categories | Categories |
| symbolic/devices | Devices |
| symbolic/emblems | Emblems |
| symbolic/emotes | Emotes |
| symbolic/mimetypes | MimeTypes |
| symbolic/places | Places |
| symbolic/status | Status |

Forma esperada do trecho a inserir (executor adapta exatamente ao estilo local; o que importa é o comportamento):

```bash
    # Após o loop de TAMANHOS, anexar symbolic/* populados
    declare -A CONTEXT_SYMBOLIC=(
        [symbolic/actions]=Actions
        [symbolic/apps]=Applications
        [symbolic/categories]=Categories
        [symbolic/devices]=Devices
        [symbolic/emblems]=Emblems
        [symbolic/emotes]=Emotes
        [symbolic/mimetypes]=MimeTypes
        [symbolic/places]=Places
        [symbolic/status]=Status
    )

    for sub in "${SYMBOLIC_SUBDIRS_POPULADAS[@]}"; do
        local ctx="${CONTEXT_SYMBOLIC[$sub]:-}"
        if [[ -z "$ctx" ]]; then
            _warn "index.theme: Context desconhecido para $sub — pulando"
            continue
        fi
        dirs+=("$sub")
        blocos+="
[$sub]
Size=16
Type=Scalable
MinSize=8
MaxSize=512
Context=$ctx
"
    done
```

> **Observação**: `SYMBOLIC_SUBDIRS_POPULADAS` deve estar **definida** antes de `gerar_index_theme()` rodar. Se a ordem em `main()` colocar `gerar_symbolic_icons` antes de `gerar_index_theme`, isso é garantido. Se a função não rodar (ex.: heritages ausentes), inicializar a variável global como `SYMBOLIC_SUBDIRS_POPULADAS=()` no topo do script garante que o loop simplesmente itera zero vezes.

### Passo 4 — Chamada em `main()`

Inserir a chamada nova entre `gerar_mimetypes` e `gerar_index_theme`:

```bash
    limpar_dist
    copiar_upstreams
    gerar_tema_icones
    gerar_mimetypes
    gerar_symbolic_icons     # NOVO
    gerar_index_theme
    copiar_cursor_gtk_shell
    preparar_extras
    atualizar_caches
```

### Passo 5 — `CHANGELOG.md` — entrada nova sob `## [Unreleased]`

Adicionar dentro do bloco `### Adicionado` já existente, preservando ordem cronológica:

```markdown
- **Sprint 12 — Propagação completa dos symbolic icons no `Dracula-Icones`**: o tema gerado pelo `build.sh` passa a embutir todos os symbolic icons disponíveis nos heritages (`dracula-icons-circle` e `dracula-icons-main`) em `symbolic/{actions,apps,categories,devices,emblems,emotes,mimetypes,places,status}` com merge por nome (prioridade `circle`), e declara todas essas subdirs em `index.theme`. Lookup local elimina a fragilidade da resolução por `Inherits=`, corrigindo entre outros o ícone "excluir pasta" do launcher Pop!_Cosmic (lápis → lixeira). Mudança restrita ao `build.sh`; SVGs vêm dos heritages sem modificação.
```

### Passo 6 — `docs/sprints/INDEX.md` — atualizar título da SPRINT 12

A linha atual (a adicionar) era:

```
| 12 | [Ícone correto de "excluir pasta" no launcher Pop!_Cosmic](SPRINT_12_DELETE_ICON.md) | Em implementação | 2026-05-07 |
```

Reescrever para:

```
| 12 | [Propagação completa dos symbolic icons no Dracula-Icones](SPRINT_12_DELETE_ICON.md) | Em implementação | 2026-05-07 |
```

## Aritmética da mudança

### No código (`build.sh`)

- **Linhas adicionadas (estimativa)**:
  - Função `gerar_symbolic_icons()`: ~50 linhas (incluindo comentário de cabeçalho).
  - Declaração global `SYMBOLIC_SUBDIRS_POPULADAS=()`: 1 linha.
  - Chamada em `main()`: 1 linha.
  - Bloco novo em `gerar_index_theme()` (declaração `CONTEXT_SYMBOLIC` + loop): ~25 linhas.
  - **Total**: ~77 linhas adicionadas, **0 removidas**, **0 reformatadas** fora dos pontos de inserção.
- **`grep -c "symbolic" build.sh`**: passa de `0` (atual) para `>= 15`.

### Na saída (`dist/icons/Dracula-Icones/`)

Cálculo planejado (executor deve **recalcular e bater**):

```
count_circle_total      = 402+99+16+78+11+27+25+30+333 = 1021
count_main_total        = 619+284+41+84+11+27+27+34+431 = 1558
count_main_only_total   = count_uniao_total - count_circle_total
count_uniao_total       = 619+284+41+84+11+27+27+34+431 = 1558  # (main ⊇ circle por nome)
count_main_only_total   = 1558 - 1021 = 537
```

**Esperado por subdir após merge** (count = união, conteúdo = `circle` quando existe, senão `main`):

| Subdir | count | circle | main-only |
|---|---|---|---|
| actions | 619 | 402 | 217 |
| apps | 284 | 99 | 185 |
| categories | 41 | 16 | 25 |
| devices | 84 | 78 | 6 |
| emblems | 11 | 11 | 0 |
| emotes | 27 | 27 | 0 |
| mimetypes | 27 | 25 | 2 |
| places | 34 | 30 | 4 |
| status | 431 | 333 | 98 |
| **Total** | **1558** | **1021** | **537** |

> **Aviso ao executor**: os números acima assumem `main ⊇ circle` por nome em todas as subdirs (verificado no planejamento via `sort -u` para `actions`, `apps`, ..., `status`). Antes de implementar, o executor **deve revalidar** com:
>
> ```bash
> for d in actions apps categories devices emblems emotes mimetypes places status; do
>   c=$(ls src/icons/upstream/dracula-icons-circle/symbolic/$d 2>/dev/null | sort -u)
>   m=$(ls src/icons/upstream/dracula-icons-main/symbolic/$d 2>/dev/null | sort -u)
>   union=$(echo -e "$c\n$m" | sort -u | grep -v '^$' | wc -l)
>   only_circle=$(comm -23 <(echo "$c") <(echo "$m") | grep -v '^$' | wc -l)
>   echo "$d: union=$union, only-in-circle=$only_circle"
> done
> ```
>
> Se `only-in-circle > 0` em qualquer subdir, a tabela acima precisa ser corrigida (count total continua = união; só muda a discriminação `circle` vs `main-only`). O comportamento da função permanece correto.

### No `index.theme` gerado

- **`Directories=`**: ganha 9 segmentos novos (`symbolic/actions` ... `symbolic/status`) — supondo todas populadas. Se alguma subdir estiver vazia em ambos heritages (não esperado pelos counts acima), aquela é omitida.
- **Blocos novos**: 9 blocos `[symbolic/<sub>]` com 5 chaves cada (`Size=16`, `Type=Scalable`, `MinSize=8`, `MaxSize=512`, `Context=<X>`).
- **`grep -c "symbolic/" dist/icons/Dracula-Icones/index.theme`**: passa de `0` (atual) para `>= 18` (cada subdir aparece 1x em `Directories=` + 1x como header `[symbolic/<sub>]`; 9 subdirs × 2 = 18).
- **`grep -cE "^\[symbolic/" dist/icons/Dracula-Icones/index.theme`**: `= 9` (um header por subdir populada).

### Hashes esperados (do caso particular original)

- `dist/icons/Dracula-Icones/symbolic/actions/edit-symbolic.svg` → `c0cb42df68bda09ce1378868b49c21d1880c5c2290d7845a2c9f0b4f4b9f9bcc` (vem do `circle`).
- `dist/icons/Dracula-Icones/symbolic/actions/edit-delete-symbolic.svg` → `53f5b0800bfdec87c58a85ef1a6e6e26330b1b52dc21e8bb601e96b38cacf024` (vem do `circle`).

## Acceptance criteria

1. `bash -n build.sh` — sintaxe OK após as mudanças.
2. `shellcheck --severity=warning build.sh` — sem novos warnings introduzidos pela função/chamada novas (linha-base do projeto deve ser conferida pelo executor; o critério é "delta zero").
3. Após `bash build.sh`:
   - `[[ -d dist/icons/Dracula-Icones/symbolic ]]` → true.
   - Para cada subdir esperada `actions, apps, categories, devices, emblems, emotes, mimetypes, places, status`:
     - `[[ -d dist/icons/Dracula-Icones/symbolic/<sub> ]]` → true.
     - `ls dist/icons/Dracula-Icones/symbolic/<sub>/ | wc -l` ≥ count esperado da tabela acima.
   - `find dist/icons/Dracula-Icones/symbolic/ -name '*.svg' | wc -l` = `1558` (ou o total exato medido pelo executor na revalidação).
   - `sha256sum dist/icons/Dracula-Icones/symbolic/actions/edit-symbolic.svg` = `c0cb42df68bda09ce1378868b49c21d1880c5c2290d7845a2c9f0b4f4b9f9bcc`.
   - `sha256sum dist/icons/Dracula-Icones/symbolic/actions/edit-delete-symbolic.svg` = `53f5b0800bfdec87c58a85ef1a6e6e26330b1b52dc21e8bb601e96b38cacf024`.
   - `grep -c "symbolic/" dist/icons/Dracula-Icones/index.theme` ≥ 18.
   - `grep -cE "^\[symbolic/" dist/icons/Dracula-Icones/index.theme` = 9.
   - `grep -E "^Directories=" dist/icons/Dracula-Icones/index.theme | tr ',' '\n' | grep -c "^symbolic/"` = 9.
4. Após `bash install.sh --user`:
   - `[[ -d ~/.local/share/icons/Dracula-Icones/symbolic/actions ]]` → true.
   - `[[ -f ~/.local/share/icons/Dracula-Icones/symbolic/actions/edit-delete-symbolic.svg ]]` → true.
   - `find ~/.local/share/icons/Dracula-Icones/symbolic/ -name '*.svg' | wc -l` = mesmo total medido em `dist/`.
   - `grep -c "symbolic/" ~/.local/share/icons/Dracula-Icones/index.theme` ≥ 18.
   - `~/.local/share/icons/Dracula-Icones/icon-theme.cache` regenerado (mtime posterior ao do build).
5. **Idempotência do build**: rodar `bash build.sh` duas vezes seguidas produz o mesmo `index.theme` (`diff -u` vazio) e os mesmos hashes nos SVGs (sample de 3 arquivos por subdir confere). `limpar_dist()` cuida disso por construção; o critério é só verificar.
6. **Não-regressão**:
   - `dist/icons/Dracula-Icones/scalable/apps/` e `dist/icons/Dracula-Icones/scalable/mimetypes/` continuam populados na mesma quantidade que antes da sprint (executor mede `ls | wc -l` antes/depois — registrar `APPS_BEFORE` / `APPS_AFTER` / `MIME_BEFORE` / `MIME_AFTER`).
   - `dist/icons/dracula-icons-main/` e `dist/icons/dracula-icons-circle/` (cópias dos heritages em `dist/`) ficam intactos (`find ... -name '*.svg' | wc -l` igual ao pré-sprint).
   - `dist/themes/Dracula-standard-buttons/` intocado.
7. `bash scripts/diagnostico.sh --quiet` continua exit 0 após reinstalação.
8. **Validação visual** (skill `validacao-visual`): após reload do GNOME Shell (`Alt+F2 r`), abrir uma pasta personalizada do launcher Pop!_Cosmic e confirmar lápis (rename) **+ lixeira** (delete) no header. PNG capturado com sha256 antes (estado atual) e depois (estado pós-sprint).

## Invariantes a preservar

- **Acentuação pt-BR completa em UTF-8** (CLAUDE.md / GUIDE.md §1) no `CHANGELOG.md`, `INDEX.md`, neste spec e em comentários novos do `build.sh`. **Proibido** `Inicio`, `movera`, `icones` (palavras isoladas, sem acento), `automatica`, `propagacao`, `simbolico`. Varredura obrigatória nos arquivos modificados.
- **Mudança cirúrgica** (CLAUDE.md §3): `build.sh` recebe **somente** as adições descritas; sem refatoração de funções existentes, sem reflow, sem renomear variáveis, sem ajuste de logs.
- **Não tocar `src/icons/upstream/...`**: os SVGs vêm de lá por **leitura** (`cp -p` na cópia), nunca por modificação.
- **Idempotência do build** (`limpar_dist` recria `dist/` zerado): preservar — não introduzir estado que persista fora de `dist/`.
- **NÃO escrever em `/usr/share/`** em modo user (já garantido por `install.sh --user`; nenhuma mudança nova nessa rota).
- **Soberania de subsistema** (precedente SPRINT 08): a sprint mexe **apenas** no pipeline do tema de ícones (`build.sh`); não toca `applications.js` (escopo da SPRINT 10), nem CSS (SPRINT 02), nem extensões (SPRINTs 05/09), nem `install.sh`.
- **Sem features especulativas** (CLAUDE.md §2): não criar conversor de SVG, não inventar Context novo, não expor opções configuráveis, não gerar variantes raster dos symbolic icons.
- **Sem geração de symbolic icons NOVOS**: a sprint apenas **propaga** o que já existe nos heritages. Se um nome não está em nenhum heritage, ele continua ausente.

## Proof-of-work runtime-real

```bash
# ─── Pré-condições e baseline ───
test -f src/icons/upstream/dracula-icons-circle/symbolic/actions/edit-symbolic.svg && echo SRC_EDIT_OK
test -f src/icons/upstream/dracula-icons-circle/symbolic/actions/edit-delete-symbolic.svg && echo SRC_DELETE_OK

sha256sum src/icons/upstream/dracula-icons-circle/symbolic/actions/edit-symbolic.svg
# esperado: c0cb42df68bda09ce1378868b49c21d1880c5c2290d7845a2c9f0b4f4b9f9bcc
sha256sum src/icons/upstream/dracula-icons-circle/symbolic/actions/edit-delete-symbolic.svg
# esperado: 53f5b0800bfdec87c58a85ef1a6e6e26330b1b52dc21e8bb601e96b38cacf024

# Recalcular união por subdir (validação da aritmética planejada)
for d in actions apps categories devices emblems emotes mimetypes places status; do
  c=$(ls src/icons/upstream/dracula-icons-circle/symbolic/$d 2>/dev/null | sort -u)
  m=$(ls src/icons/upstream/dracula-icons-main/symbolic/$d 2>/dev/null | sort -u)
  union=$(echo -e "$c\n$m" | sort -u | grep -v '^$' | wc -l)
  echo "$d: union=$union"
done
# esperado total: 619+284+41+84+11+27+27+34+431 = 1558

# Estado atual (antes da sprint) — referência para non-regression
grep -c "symbolic" build.sh                                                     # esperado atual: 0
grep -c "symbolic/" dist/icons/Dracula-Icones/index.theme 2>/dev/null            # esperado atual: 0
APPS_BEFORE=$(ls dist/icons/Dracula-Icones/scalable/apps/ 2>/dev/null | wc -l)
MIME_BEFORE=$(ls dist/icons/Dracula-Icones/scalable/mimetypes/ 2>/dev/null | wc -l)
MAIN_BEFORE=$(find dist/icons/dracula-icons-main -name '*.svg' 2>/dev/null | wc -l)
CIRCLE_BEFORE=$(find dist/icons/dracula-icons-circle -name '*.svg' 2>/dev/null | wc -l)
echo "APPS_BEFORE=$APPS_BEFORE MIME_BEFORE=$MIME_BEFORE MAIN_BEFORE=$MAIN_BEFORE CIRCLE_BEFORE=$CIRCLE_BEFORE"

# ─── Sintaxe / lint ───
bash -n build.sh
shellcheck --severity=warning build.sh

# ─── Build ───
bash build.sh

# ─── Verificações pós-build em dist/ ───
test -d dist/icons/Dracula-Icones/symbolic && echo SYMBOLIC_DIR_OK
for d in actions apps categories devices emblems emotes mimetypes places status; do
  n=$(ls dist/icons/Dracula-Icones/symbolic/$d 2>/dev/null | wc -l)
  echo "dist symbolic/$d: $n"
done
TOTAL_SYMBOLIC=$(find dist/icons/Dracula-Icones/symbolic -name '*.svg' | wc -l)
echo "TOTAL_SYMBOLIC=$TOTAL_SYMBOLIC"
# esperado: 1558

# Hashes do caso particular original (devem vir do circle)
sha256sum dist/icons/Dracula-Icones/symbolic/actions/edit-symbolic.svg
sha256sum dist/icons/Dracula-Icones/symbolic/actions/edit-delete-symbolic.svg
# esperado: hashes IDÊNTICOS aos do upstream circle (acima)

# index.theme atualizado
grep -c "symbolic/" dist/icons/Dracula-Icones/index.theme           # esperado: >= 18
grep -cE "^\[symbolic/" dist/icons/Dracula-Icones/index.theme        # esperado: 9
grep -E "^Directories=" dist/icons/Dracula-Icones/index.theme | tr ',' '\n' | grep -c "^symbolic/"  # esperado: 9

# Não-regressão: count de apps/mimetypes intocado e heritages intactos
APPS_AFTER=$(ls dist/icons/Dracula-Icones/scalable/apps/ | wc -l)
MIME_AFTER=$(ls dist/icons/Dracula-Icones/scalable/mimetypes/ | wc -l)
MAIN_AFTER=$(find dist/icons/dracula-icons-main -name '*.svg' | wc -l)
CIRCLE_AFTER=$(find dist/icons/dracula-icons-circle -name '*.svg' | wc -l)
test "$APPS_AFTER"   = "$APPS_BEFORE"   && echo APPS_UNCHANGED   || echo "APPS_DRIFT: $APPS_BEFORE -> $APPS_AFTER"
test "$MIME_AFTER"   = "$MIME_BEFORE"   && echo MIME_UNCHANGED   || echo "MIME_DRIFT: $MIME_BEFORE -> $MIME_AFTER"
test "$MAIN_AFTER"   = "$MAIN_BEFORE"   && echo MAIN_UNCHANGED   || echo "MAIN_DRIFT: $MAIN_BEFORE -> $MAIN_AFTER"
test "$CIRCLE_AFTER" = "$CIRCLE_BEFORE" && echo CIRCLE_UNCHANGED || echo "CIRCLE_DRIFT: $CIRCLE_BEFORE -> $CIRCLE_AFTER"

# ─── Idempotência do build ───
cp dist/icons/Dracula-Icones/index.theme /tmp/dracula-index-theme-1.txt
H1_EDIT=$(sha256sum dist/icons/Dracula-Icones/symbolic/actions/edit-symbolic.svg | awk '{print $1}')
H1_DEL=$(sha256sum dist/icons/Dracula-Icones/symbolic/actions/edit-delete-symbolic.svg | awk '{print $1}')

bash build.sh >/dev/null

diff -u /tmp/dracula-index-theme-1.txt dist/icons/Dracula-Icones/index.theme && echo INDEX_IDEMPOTENT || echo INDEX_DRIFTED
H2_EDIT=$(sha256sum dist/icons/Dracula-Icones/symbolic/actions/edit-symbolic.svg | awk '{print $1}')
H2_DEL=$(sha256sum dist/icons/Dracula-Icones/symbolic/actions/edit-delete-symbolic.svg | awk '{print $1}')
test "$H1_EDIT" = "$H2_EDIT" && test "$H1_DEL" = "$H2_DEL" && echo SVG_IDEMPOTENT || echo SVG_DRIFTED

# ─── Instalação user ───
bash install.sh --user

# Verificações pós-instalação
test -d ~/.local/share/icons/Dracula-Icones/symbolic/actions && echo INSTALLED_DIR_OK
test -f ~/.local/share/icons/Dracula-Icones/symbolic/actions/edit-delete-symbolic.svg && echo INSTALLED_DELETE_OK
test -f ~/.local/share/icons/Dracula-Icones/symbolic/actions/edit-symbolic.svg && echo INSTALLED_EDIT_OK
INSTALLED_TOTAL=$(find ~/.local/share/icons/Dracula-Icones/symbolic -name '*.svg' | wc -l)
test "$INSTALLED_TOTAL" = "$TOTAL_SYMBOLIC" && echo INSTALL_COUNT_OK || echo "INSTALL_COUNT_DRIFT: dist=$TOTAL_SYMBOLIC, installed=$INSTALLED_TOTAL"
grep -c "symbolic/" ~/.local/share/icons/Dracula-Icones/index.theme   # esperado: >= 18

# Cache regenerado
test -f ~/.local/share/icons/Dracula-Icones/icon-theme.cache && \
    stat -c "cache size: %s mtime: %Y" ~/.local/share/icons/Dracula-Icones/icon-theme.cache

# Smoke do diagnóstico
bash scripts/diagnostico.sh --quiet ; echo "exit=$?"   # esperado: 0

# ─── Acentuação periférica nos arquivos modificados/criados pela sprint ───
for f in build.sh CHANGELOG.md docs/sprints/SPRINT_12_DELETE_ICON.md docs/sprints/INDEX.md; do
  echo "== $f =="
  grep -nE "Inicio|movera|icones( |\.|$|,)|automatica|propagacao|simbolico" "$f" || true
done
# esperado: nenhuma forma sem acento
```

## Validação visual (skill `validacao-visual` auto-invocada)

Após `bash build.sh && bash install.sh --user` e reload do GNOME Shell (`Alt+F2`, digitar `r`, Enter — X11 confirmado):

1. **Screenshot 1 (antes — opcional, se ainda reproduzível)**: lápis duplicado no header.
2. **Screenshot 2 (depois)** — abrir launcher (`Super+A`), entrar em uma pasta personalizada (ex.: `suse-yast.…` ou outra criada pelo usuário). Confirmar visualmente no canto superior direito do header da pasta: **lápis** (rename, sem alteração de aparência) **+ lixeira** (delete, antes era visualmente um segundo lápis).
3. PNG capturado com `sha256` do arquivo no relato final.

Se o ambiente da máquina de validação não tiver pasta personalizada criada, criar uma pelo próprio launcher (`Criar pasta` → `Nova pasta` — strings já em pt-BR pela SPRINT 10) com 1 app dentro, e em seguida abrir essa pasta.

## Riscos conhecidos

- **Cache de ícones stale do GTK/GNOME Shell**: mesmo com `gtk-update-icon-cache` rodando no `atualizar_caches()` do `build.sh` e no `install.sh`, é possível que o Shell em execução continue usando um lookup memoizado até `Alt+F2 r`. Não é regressão da sprint — comportamento padrão do Shell. Documentado.
- **`Type=Scalable` para `symbolic/<sub>` em vez de `Type=Symbolic`**: alguns temas usam `Type=Symbolic`. Inspeção dos heritages mostra `Type=Scalable` em `symbolic/<sub>` (esquema confirmado pelo planejamento; executor reconfirma). GTK aceita ambos. Mantemos `Scalable` por consistência com o resto do `index.theme` gerado.
- **Tamanho declarado `Size=16`**: convenção comum para symbolic icons. `MinSize=8/MaxSize=512` cobre toda a faixa que o Shell solicita.
- **Bash 4+ (`local -A`, `declare -A`)**: o projeto já usa extensions de bash; risco zero em Pop!_OS 22.04+ (bash 5.1).
- **Crescimento do `dist/icons/Dracula-Icones/`**: ~1.558 SVGs pequenos a mais. Tamanho total cresce em ~5–10 MB (estimativa, a confirmar com `du -sh dist/icons/Dracula-Icones/symbolic/`). Não afeta install (`cp -r`) nem cache.
- **Símbolos do `main` "vencendo" no caso de subdir vazia em `circle`**: comportamento correto pelo design — quando o `circle` não tem o nome, usa o `main`. Caso particular: `edit-delete-symbolic` vem do `circle` (count_circle=1 nessa entrada), então o caso original do bug fica resolvido.
- **Pop!_Cosmic em upgrade**: se a System76 lançar uma atualização que mude o nome canônico solicitado (ex.: para `user-trash-symbolic`), o ícone segue funcionando — pois `user-trash-symbolic` também é propagado por esta sprint (existe nos heritages). **Isto é exatamente o ganho da expansão de escopo**.
- **Cosmic nativo (Pop!_OS 24.04)**: a extensão JS `pop-cosmic` desaparece; o tema de ícones continua válido para outras partes do sistema. Sem regressão.

## Não-objetivos / Fora de escopo

- Geração de symbolic icons **NOVOS** que não existem em nenhum heritage (ex.: criar um SVG novo para um nome que nem `circle` nem `main` cobrem).
- Modificação de SVGs (recolorir, rebrand, redimensionar): cópia direta, sem transformação.
- Geração de variantes raster dos symbolic icons (`16x16/symbolic/...`): symbolic é vetorial e color-stylable via CSS; raster aqui seria desperdício e contradiz o design GTK.
- Outros temas (`Dracula-standard-buttons`, `Dracula-Cursor`).
- Modificação dos heritages (`src/icons/upstream/...`).
- Modificação do `install.sh` (já cobre o caso por `cp -r` integral).
- Localização do título da pasta no launcher (escopo da SPRINT 10).
- Correção do `applications.js` da extensão pop-cosmic (a extensão pede o nome certo — `edit-delete-symbolic`; o erro estava no fornecedor de ícones, não no consumidor).
- Suporte a temas-irmãos (light/dark) para os symbolic — symbolic já é color-stylable via CSS.

## Referências

- `build.sh` — pipeline atual (funções `gerar_tema_icones`, `gerar_mimetypes`, `gerar_index_theme`, `atualizar_caches`).
- `install.sh` — linha 107: `cp -r "$DIST/icons/$tema" "$DEST_ICONS/"` (cobre subdir nova automaticamente). Linha 108: `gtk-update-icon-cache -f -t "$DEST_ICONS/$tema"` (regenera cache).
- `src/icons/upstream/dracula-icons-circle/symbolic/` — fonte primária (1.021 SVGs).
- `src/icons/upstream/dracula-icons-main/symbolic/` — fonte secundária (1.558 SVGs; superset por nome).
- `~/.local/share/icons/dracula-icons-circle/index.theme` — referência para esquema `[symbolic/<sub>]`.
- `docs/sprints/SPRINT_10_LAUNCHER_PTBR.md` — sprint irmã (strings pt-BR do mesmo launcher).
- `docs/sprints/SPRINT_11_LAUNCHER_HIGIENE.md` — sprint irmã (limpeza do app-grid).
- `VALIDATOR_BRIEF.md` §"[CORE] Contratos de runtime" — comandos de validação universais.
- `CLAUDE.md` (raiz) §1, §2, §3 — pensar antes, simplicidade primeiro, mudanças cirúrgicas.

---

*"Cada coisa em seu lugar." — e cada symbolic icon resolvido localmente, sem depender da boa vontade da herança.*
