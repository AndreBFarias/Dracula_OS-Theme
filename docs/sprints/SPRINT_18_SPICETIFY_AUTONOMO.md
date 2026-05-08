# Sprint 18 — Spicetify autônomo (sem dependência do Spellbook-OS)

Sprint dedicada ao **gap 4** da auditoria viva pós-ciclo SPRINT 10–17:
`scripts/instalar_app_themes.sh` (linhas 96–133) delega Spicetify ao
`spicetify-setup.sh` mantido em `Spellbook-OS`, e em máquina sem o repo
externo o passo é silenciosamente pulado (`_skip`). A SPRINT 17 fechou
**recuperação pós-update** (`atualizar_spicetify.sh`) e **documentação**
do boundary, mas **não fechou autonomia de instalação inicial**. Esta
sprint replica localmente o setup de instalação em `scripts/instalar_spicetify.sh`,
torna-o fonte primária de `aplicar_spicetify`, e mantém o Spellbook-OS
disponível apenas como fallback explícito via `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1`.

> **Substitui** a delegação compulsória ao Spellbook-OS para Spicetify
> instalação inicial (não para `atualizar_spicetify.sh` — esse é
> autocontido desde a SPRINT 17). Spellbook-OS deixa de ser dependência
> obrigatória do Dracula_OS-Theme para Spicetify; vira fallback opcional.

---

## Contexto

`scripts/instalar_app_themes.sh:96-133` define `_buscar_spicetify_setup()`
e `aplicar_spicetify()`. A primeira procura `spicetify-setup.sh` em quatro
paths (`$REPO/../Spellbook-OS/scripts/`, `$HOME/Desenvolvimento/Spellbook-OS/scripts/`,
`${XDG_DATA_HOME:-$HOME/.local/share}/Spellbook-OS/scripts/`,
`/opt/Spellbook-OS/scripts/`). Em qualquer outro contexto (clone limpo
do repo em outra máquina), `_skip` é chamado com mensagem informativa,
mas o usuário não recebe Spicetify configurado e a falha é não-fatal.

A SPRINT 17 documentou explicitamente esta dependência (`README.md`
linhas 164–185, `docs/index.html` linha 61, `app-themes/spicetify/README.md`
linhas 1–4) — é uma decisão consciente de boundary. Mas o feedback do
usuário (próprio do projeto) é: **portabilidade compulsória**, sem
dependência externa não-empacotada. A SPRINT 17 ela mesma já registrou
em "Achados colaterais A5":

> A5 — SPRINT 18 (Spicetify autônomo) precisa de detecção de Spellbook-OS
> ausente. Caminho proposto: instalar Spicetify via `curl ... | sh`
> oficial e clonar `spicetify/spicetify-themes`.

Esta sprint executa esse caminho.

`scripts/atualizar_spicetify.sh` (SPRINT 17, 91 linhas) **não** é
substituído nem refatorado: ele cobre recuperação pós `flatpak update`,
ortogonal a esta sprint. Continua chamado da seção 7.6 de
`reaplicar_tema.sh`. **Boundary preservado**.

`/home/andrefarias/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh`
(277 linhas) tem oito funções organizadas linearmente. Replicar localmente
mantendo paridade exata de configuração (TEMA, ESQUEMA, EXTENSIONS,
CUSTOM_APPS, 13 chaves de `spicetify config`, sanitização de
`custom_apps` espúrio na lista de extensions) garante que máquinas com
ou sem Spellbook produzam o **mesmo estado final** do Spotify.

---

## Decisões fixas (não reabrir)

- **Numeração**: SPRINT 18. `INDEX.md` linha 26 (após SPRINT 17).
- **Replicação local**: novo `scripts/instalar_spicetify.sh` no Dracula_OS-Theme,
  inspirado no `spicetify-setup.sh` do Spellbook-OS mas autocontido.
- **Script local é fonte primária**; Spellbook-OS vira fallback opcional
  via `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1`.
- **Sem refactor do Spellbook-OS** (fora deste repo, boundary preservado).
- **13 chaves de `spicetify config`** preservadas idênticas: `current_theme=Sleek`,
  `color_scheme=Dracula`, `inject_css=1`, `replace_colors=1`,
  `overwrite_assets=1`, `inject_theme_js=1`, `sidebar_config=1`,
  `experimental_features=1`, `home_config=1`, `expose_apis=1`,
  `disable_sentry=1`, `disable_ui_logging=1`, `remove_rtl_rule=1`.
- **Lista exata de extensions/custom_apps preservada**:
  - `EXTENSIONS=autoSkipExplicit.js|autoSkipVideo.js|bookmark.js|fullAppDisplay.js|keyboardShortcut.js|loopyLoop.js|popupLyrics.js|shuffle+.js|trashbin.js|webnowplaying.js`
  - `CUSTOM_APPS=marketplace|lyrics-plus|reddit|new-releases`
- **Sanitização de `custom_apps` espúrio na lista de extensions** preservada
  (Spellbook linhas 178–186) — workaround conhecido do Spicetify CLI.
- **Mudanças cirúrgicas** em `scripts/instalar_app_themes.sh`: reescrever
  apenas `aplicar_spicetify()` (linhas 115–133); `_buscar_spicetify_setup()`
  (linhas 96–113) preservada (vira utilitária do fallback).
- **Sem sudo. MODO=user.** Toda a árvore mexida vive em `~/.spicetify/`,
  `~/.config/spicetify/`, `~/.var/app/com.spotify.Client/`.
- **Acentuação pt-BR íntegra** em logs, comentários e docs (`não`,
  `instalação`, `aplicação`, `função`, `configuração`, `atualização`,
  `acentuação`, `detecção`).
- **Não testar `curl | sh` no host real**: máquina já tem Spicetify
  instalado; um install retornaria "já instalado" sem provar nada novo.
  Validação de fluxo zero-state via mocks.
- **`DRACULA_DRY_RUN=1`** suportado em ambos scripts novos (não executa
  `curl | sh`, `git clone`, nem `spicetify backup apply`).
- **`--apenas-detectar`** retorna echo simples do tipo (`flatpak`/`snap`/
  `nativo`/`nenhum`) e exit 0 — formato texto, não JSON. Justificativa:
  consumidor único é log/diagnóstico humano, JSON seria over-engineering
  (CLAUDE.md §2).
- **`--skip-marketplace`** suportado para fluxos de CI ou ambientes
  offline; pula `instalar_marketplace()` mas mantém o resto.
- **Validação ao final** idêntica à do Spellbook (3 checks: `bookmark.js`
  na lista de extensions, `marketplace` em custom_apps, `current_theme=Sleek`).
- **Fallback automático para Spellbook-OS**: **NÃO**. Só explícito via
  `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1`. Justificativa: autonomia. Se
  o script local funciona, não vale dois caminhos co-ativos.

---

## Estratégia: replicação ponto-a-ponto

### Mapping linha-por-linha do `spicetify-setup.sh` (Spellbook) → `instalar_spicetify.sh` (local)

| Bloco Spellbook (linhas)     | Função/Bloco local                              | Diferença                                                      |
|------------------------------|-------------------------------------------------|----------------------------------------------------------------|
| 1–5 (shebang + comentário)   | shebang + comentário pt-BR autorreferente       | Atualizar comentário para "Dracula_OS-Theme — Spicetify autônomo" |
| 6 (`set -euo pipefail`)      | Idem                                            | Igual                                                          |
| 7–10 (paths)                 | Idem                                            | Igual                                                          |
| 12–24 (cores + `_info/_ok/_warn/_err`) | **Source `lib/common.sh`**                | Helpers já existem em `lib/common.sh:23-26`. Não duplicar.     |
| 26–30 (TEMA, ESQUEMA, EXTENSIONS, CUSTOM_APPS) | Idem (constantes globais)        | Mesmos valores                                                 |
| 32–45 (`detectar_spotify`)   | `detectar_spotify()`                            | Mesmo algoritmo                                                |
| 47–63 (`instalar_spicetify`) | `instalar_spicetify()`                          | Adicionar guard `DRACULA_DRY_RUN=1` (skip `curl | sh`)         |
| 65–85 (`instalar_temas`)     | `instalar_temas()`                              | Adicionar guard `DRACULA_DRY_RUN=1` (skip `git clone`)         |
| 87–101 (`instalar_marketplace`) | `instalar_marketplace()`                     | Adicionar guard `DRACULA_DRY_RUN=1` + guard `SKIP_MARKETPLACE=1` |
| 103–144 (`configurar_paths`) | `configurar_paths()`                            | Adicionar guard `DRACULA_DRY_RUN=1` (skip `flatpak run` e `kill`); reduzir `seq 1 15` para 10 (mais conservador, ~20s) |
| 146–168 (`aplicar_config`)   | `aplicar_config()`                              | Mesmas 13 chaves; guard `DRACULA_DRY_RUN=1` em cada `spicetify config` |
| 170–189 (`aplicar_extensions`) | `aplicar_extensions()`                        | Lista idêntica; sanitização idêntica (linhas 178–186)          |
| 191–214 (`restaurar_e_aplicar`) | `restaurar_e_aplicar()`                      | Limpeza de cache do Flatpak respeita `validar_path_destrutivo`; guard `DRACULA_DRY_RUN=1` em `restore`/`clear`/`backup apply` |
| 216–245 (`validar`)          | `validar()`                                     | Mesmos 3 checks                                                |
| 247–273 (`main`)             | `main()`                                        | Adicionar parsing de `--apenas-detectar` e `--skip-marketplace` ANTES do banner |

### Diferenças intencionais (não fidelidade cega)

1. **Source de `lib/common.sh`**: usa logger do projeto, não duplica cores nem `_info/_ok/_warn/_err`. Helper `_dim` disponível para `[dry-run]`.
2. **`DRACULA_DRY_RUN=1`** em todos os pontos destrutivos/dispendiosos: `curl | sh`, `git clone`, `flatpak run`, `kill`, `spicetify config`, `spicetify restore/clear/backup apply`, `rm -rf cache`.
3. **`validar_path_destrutivo`** antes de `rm -rf cache_dir` no `restaurar_e_aplicar()` (Spellbook não faz essa validação, mas o caminho está na allowlist desde a SPRINT 17 — usar gratuitamente é defesa em profundidade).
4. **Loop de geração de prefs reduzido**: Spellbook tem `seq 1 15` com `sleep 2` (até 30s); local usa `seq 1 10` com `sleep 2` (até 20s). Justificativa: 30s é exagero; se em 20s o Spotify Flatpak não gerou prefs, há problema fundamental — `_warn` resolve melhor que esperar mais.
5. **Argparse simples** com `--apenas-detectar`, `--skip-marketplace`, `--help`. Spellbook não tem flags.
6. **`validar()` com retorno explícito**: Spellbook retorna 1 em erro, mas `set -euo pipefail` aborta antes; local mantém retorno 1 com `_warn` ao final do `main()` apenas no nível de log.
7. **Sem epígrafe de Platão no rodapé**: substituir por epígrafe próprio do projeto (estilo dos outros sprints).

---

## Entregáveis

### Arquivos a criar

- `scripts/instalar_spicetify.sh` — **NOVO**, ~290 linhas. Source `lib/common.sh`,
  oito funções equivalentes, `DRACULA_DRY_RUN=1`, `--apenas-detectar`,
  `--skip-marketplace`, `--help`. Idempotente.
- `scripts/desinstalar_spicetify.sh` — **NOVO**, ~40 linhas. `spicetify restore`
  por padrão; `--full` remove `~/.spicetify/` e `~/.config/spicetify/` com
  `validar_path_destrutivo`. Não-fatal se nada existe.
- `docs/sprints/SPRINT_18_SPICETIFY_AUTONOMO.md` — este documento.

### Arquivos a modificar

- `scripts/instalar_app_themes.sh` — reescrever **apenas** `aplicar_spicetify()`
  (linhas 115–133). `_buscar_spicetify_setup()` (linhas 96–113) **preservada**
  (vira utilitária acionada apenas pelo branch fallback). Novo fluxo:
  1. Se `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1` E `_buscar_spicetify_setup`
     retorna 0 → executa o setup do Spellbook (comportamento legado).
  2. Caso contrário (default) → executa `$REPO_ROOT/scripts/instalar_spicetify.sh`.
  3. Mantém comportamento não-fatal (`_warn` em falha; fluxo geral segue).
  4. Mantém suporte a `DRY_RUN` da própria função (variável `DRY_RUN`,
     diferente de `DRACULA_DRY_RUN`; ambas têm o mesmo efeito).
- `scripts/lib/common.sh` — **NÃO modificar.** Allowlist destrutiva já tem
  `~/.var/app/com.spotify.Client/cache` (SPRINT 17). Adicionar
  `~/.config/spicetify` E `~/.spicetify` à allowlist para o `--full` do
  `desinstalar_spicetify.sh`. (Esta é a única alteração permitida em
  `lib/common.sh`: 2 linhas novas na allowlist.)
- `README.md` — atualizar:
  - Linha 52 (Integração Spellbook-OS na tabela): manter texto, mas
    reescrever a célula para refletir que Spicetify deixou de ser
    dependência (continua reaproveitando `rebuild_dracula_theme`).
  - Linha 158 (`# Spicetify aplicado via Spellbook-OS`): substituir por
    `# Spicetify aplicado via scripts/instalar_spicetify.sh`.
  - Seção `### Dependências externas` (linhas 164–185, criada na SPRINT 17):
    reescrever o bullet de Spicetify para indicar que **autonomia foi
    alcançada na SPRINT 18**; Spellbook-OS vira fallback opcional via
    `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1`. Manter o bullet de
    `atualizar_spicetify.sh` (recuperação pós-update).
  - Linha 327–328 (Troubleshooting): manter referência ao Spellbook como
    fallback, mas indicar que o caminho primário agora é local.
  - Linha 351–353 (Integração com Spellbook-OS): atualizar texto removendo
    "Spicetify exige" e substituindo por "Spicetify pode reusar" (opt-in).
- `docs/index.html` — atualizar card "App themes integrados" (linha 61):
  remover `<strong>Spicetify</strong> usa o setup do <a ...>Spellbook-OS</a>;`,
  substituir por nota que Spicetify é instalado via
  `<code>scripts/instalar_spicetify.sh</code>` autocontido. Manter o final
  da frase sobre `atualizar_spicetify.sh --auto-fix` (recuperação pós-update).
- `app-themes/spicetify/README.md` — atualizar:
  - Linhas 1–4 (header): remover "via o script `spicetify-setup.sh` mantido
    em Spellbook-OS"; substituir por "via `scripts/instalar_spicetify.sh`".
  - Linhas 7–18 (seção `## Reaplicar`): substituir o comando
    `~/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh` por
    `bash scripts/instalar_spicetify.sh`. Atualizar parágrafo seguinte
    para refletir que a detecção/instalação/clone agora são locais.
    Manter referência ao Spellbook como fallback opcional.
  - Linhas 30–34 (`## Por que não duplicar...`): **substituir** o título
    para `## Boundary com Spellbook-OS` e reescrever: explicar que a
    SPRINT 18 internalizou o setup; Spellbook-OS continua reusável via
    `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1` por questão de boundary, não
    por necessidade.
  - Manter intacta a seção `## Troubleshooting` (linhas 36 em diante,
    SPRINT 17).
- `docs/sprints/INDEX.md` — adicionar linha 26 nova após SPRINT 17:
  ```
  | 18 | [Spicetify autônomo (sem Spellbook-OS)](SPRINT_18_SPICETIFY_AUTONOMO.md) | Em implementação | <data> |
  ```
- `CHANGELOG.md` — entrada `[Unreleased]` `### Adicionado`, após o item
  da SPRINT 17, parágrafo único descrevendo a entrega.

### Arquivos NÃO tocar

- `scripts/atualizar_spicetify.sh` (SPRINT 17, 91 linhas) — ortogonal,
  cobre recuperação pós-update. Não interagir.
- `~/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh` — fora do
  repo. Boundary preservado.
- `_buscar_spicetify_setup()` em `instalar_app_themes.sh:96-113` —
  **preservada** porque vira o detector usado pelo branch
  `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1`.
- Logger pattern (`_info`, `_ok`, `_warn`, `_err`, `_dim`) — usar como
  existe em `lib/common.sh:23-27`.
- Resto da allowlist destrutiva — apenas estender com 2 entradas exatas.
- `_resolver_spicetify_mismatch` e `_detectar_spotify_flatpak` em
  `lib/common.sh:202-245` — não tocar.
- `install.sh` e `uninstall.sh` — `aplicar_spicetify` segue sendo chamado
  por `instalar_app_themes.sh`; o roteamento interno mudou, a interface
  não. **Sem alteração.**
- `scripts/reaplicar_tema.sh` — seção 7.6 (SPRINT 17) chama
  `atualizar_spicetify.sh`, ortogonal a esta sprint. **Sem alteração.**
- `scripts/diagnostico.sh` — não tem checks de Spicetify hoje (registrado
  como achado A1 da SPRINT 17). Manter assim.
- `assets/`, `app-themes/spicetify/` (exceto README) — sem mudança.
- `build.sh`, `tests/`, `.github/workflows/` — fora do escopo.

---

## Decisões de design abertas — resolvidas pelo planejador

1. **Fallback automático para Spellbook-OS quando o local falha?**
   **Não.** Apenas explícito via `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1`.
   Justificativa: dois caminhos co-ativos esconderiam falha do script
   local (mascaramento). Se o local quebra, queremos saber.

2. **`--apenas-detectar` retorna texto ou JSON?**
   Texto (echo + exit 0). Consumidor único é log/diagnóstico humano.
   JSON seria over-engineering (CLAUDE.md §2).

3. **`detectar_spotify` retorna `nenhum` quando não encontra?**
   Sim, **igual ao Spellbook**. `main` aborta com `_err` se for `nenhum`.
   `--apenas-detectar` retorna `nenhum` e exit 0 (não aborta — é
   diagnóstico).

4. **Diferenças na lista de extensions/custom_apps vs Spellbook?**
   **Nenhuma.** Mesma lista. Justificativa: paridade de estado final;
   usuário com ou sem Spellbook tem o mesmo Spotify.

5. **Substituir `set -euo pipefail` do Spellbook por `set -uo pipefail`?**
   **Manter `-e`.** Spellbook usa `set -euo pipefail` (linha 5); local
   também. O `_err` já garante exit 1 nos pontos críticos; não há fluxo
   onde queremos seguir após erro estrutural (diferente de
   `reaplicar_tema.sh`, que usa `-uo pipefail` para sobreviver a falhas
   de seção).

6. **`--full` no `desinstalar_spicetify.sh` remove `~/.config/spicetify/`?**
   **Sim** com `validar_path_destrutivo`. Justificativa: usuário pediu
   `--full` explicitamente. Sem `--full`, só `spicetify restore` (preserva
   configs e themes clonados, útil para reaplicar depois).

7. **`--full` faz `flatpak install --reinstall` para limpar Spotify?**
   **Não.** Isso é responsabilidade de `atualizar_spicetify.sh --auto-fix`
   (SPRINT 17). Aqui é só desinstalar Spicetify.

8. **`DRACULA_PREFER_SPELLBOOK_SPICETIFY=1` em ambiente sem Spellbook → erro?**
   **Não.** `_buscar_spicetify_setup` retorna 1, log `_warn`
   "Spellbook-OS solicitado mas não encontrado, caindo para script local",
   segue com o local. Comportamento não-surpresivo.

9. **Validação após executar o script local: usar a `validar()` interna ou checks externos?**
   Interna. Mesmos 3 checks do Spellbook. Reproduz contrato; reduz
   superfície de teste.

10. **`spicetify backup apply` vs `apply` no fluxo zero-state?**
    `backup apply` (igual ao Spellbook). É o fluxo correto para primeira
    instalação. `apply` (sem `backup`) só é usado em recuperação pós-update
    (`atualizar_spicetify.sh`, SPRINT 17), onde o backup já existe e foi
    invalidado pelo update.

11. **Nome do script: `instalar_spicetify.sh` vs `setup_spicetify.sh`?**
    `instalar_spicetify.sh`. Padrão do projeto: todos os scripts de
    instalação são `instalar_*` (ver `instalar_app_themes.sh`,
    `instalar_keybindings.sh`, `instalar_pop_cosmic_ptbr.sh`,
    `instalar_wallpapers.sh` da SPRINT 17 etc.).

12. **Mensagem de skip quando Spotify não está instalado: erro ou aviso?**
    **Aviso não-fatal**, exit 1 só em modo `main` direto; quando chamado
    via `aplicar_spicetify` em `instalar_app_themes.sh`, a função-mãe
    captura e converte em `_warn`. Justificativa: usuário que clonou o
    repo pode não usar Spotify; `install.sh --user --all` não pode abortar
    por isso.

    Implementação: `main()` aborta com `_err` (exit 1) se
    `detectar_spotify` retorna `nenhum`. `aplicar_spicetify` captura o
    exit 1 e loga `_warn` ("Spotify não detectado; pulando Spicetify").

---

## Acceptance criteria

### Sintaxe e source

1. `bash -n scripts/instalar_spicetify.sh` — exit 0.
2. `bash -n scripts/desinstalar_spicetify.sh` — exit 0.
3. `bash -n scripts/lib/common.sh` — exit 0 (após adição da allowlist).
4. `bash -n scripts/instalar_app_themes.sh` — exit 0 (após reescrita de
   `aplicar_spicetify`).
5. `( source scripts/lib/common.sh && declare -F validar_path_destrutivo )`
   — função declarada (sem regressão).
6. `shellcheck --severity=warning scripts/instalar_spicetify.sh
   scripts/desinstalar_spicetify.sh scripts/instalar_app_themes.sh
   scripts/lib/common.sh` — sem warnings novos vs. baseline.

### Detecção e dry-run

7. `bash scripts/instalar_spicetify.sh --apenas-detectar` no ambiente
   atual (Spotify Flatpak) imprime exatamente `flatpak` (1 linha em
   stdout) e exit 0.
8. `DRACULA_DRY_RUN=1 bash scripts/instalar_spicetify.sh` imprime os
   passos com prefixo `[dry-run]`, **não** executa `curl | sh`,
   `git clone`, nem `spicetify backup apply`. Exit 0.
9. `DRACULA_DRY_RUN=1 bash scripts/instalar_spicetify.sh --skip-marketplace`
   pula a linha de instalação do marketplace mesmo em dry-run. Exit 0.

### Idempotência (estado já configurado, ambiente real)

10. `bash scripts/instalar_spicetify.sh` no host (Spicetify já instalado +
    Sleek + Dracula) loga `OK Spicetify já instalado (v...)`,
    `OK Tema Sleek já presente`, `OK Marketplace já instalado`. Aplica
    config (idempotente). `validar()` ao final imprime `OK Validação
    completa: tudo OK`. Exit 0.
11. Mesmo comando rodado 2× consecutivas — segunda execução tem o mesmo
    output (sem deltas). Sem novos backups duplicados em
    `~/.config/spicetify/`.

### Roteamento em `instalar_app_themes.sh`

12. `bash scripts/instalar_app_themes.sh` (default) chama o script LOCAL.
    Validação: log contém `Spicetify aplicado via instalar_spicetify.sh`
    (ou string equivalente do contrato).
13. `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1 bash scripts/instalar_app_themes.sh`
    (com Spellbook-OS presente em `$HOME/Desenvolvimento/Spellbook-OS/`)
    chama o do Spellbook. Validação: log contém `Spicetify aplicado via
    Spellbook-OS`.
14. `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1` E Spellbook-OS ausente
    (simulado via `mv ~/Desenvolvimento/Spellbook-OS
    ~/Desenvolvimento/Spellbook-OS.bak`): log `_warn` "Spellbook-OS
    solicitado mas não encontrado, caindo para script local"; segue com
    o local. Exit 0.
15. Sem Spotify (simulado via mock retornando `nenhum`):
    `aplicar_spicetify` loga `_warn` "Spotify não detectado; pulando
    Spicetify"; exit 0 (não-fatal). `instalar_app_themes.sh` continua
    com Obsidian, Telegram, etc.

### Fluxo zero-state via mock

16. Mock de `~/.spicetify/spicetify` retornando exit 1 sempre + mock de
    `flatpak list` retornando `com.spotify.Client`: roteiro completo
    em dry-run não falha, imprime os 8 passos com prefixo `[dry-run]`,
    exit 0.

### Desinstalação

17. `bash scripts/desinstalar_spicetify.sh` em estado configurado:
    executa `spicetify restore` (ou nota se binário não existe), exit 0.
    Não remove `~/.spicetify/` nem `~/.config/spicetify/`.
18. `bash scripts/desinstalar_spicetify.sh --full` remove
    `~/.spicetify/` e `~/.config/spicetify/` com
    `validar_path_destrutivo`. Exit 0.
19. `DRACULA_DRY_RUN=1 bash scripts/desinstalar_spicetify.sh --full`
    imprime os comandos `[dry-run]`, não remove nada.
20. `bash scripts/desinstalar_spicetify.sh` em ambiente sem Spicetify:
    no-op silencioso, exit 0.

### Documentação

21. `README.md` linha 52 (tabela "Integração Spellbook-OS"): texto
    atualizado para refletir que Spicetify deixou de ser dependência.
22. `README.md` linha 158: comentário atualizado para
    `# Spicetify aplicado via scripts/instalar_spicetify.sh`.
23. `README.md` seção "Dependências externas": bullet de Spicetify
    indica autonomia local + Spellbook como fallback opcional.
24. `docs/index.html` card "App themes integrados": Spellbook-OS removido
    como dependência primária; substituído por
    `scripts/instalar_spicetify.sh`. Recuperação pós-update mantida.
25. `app-themes/spicetify/README.md` linha 1: header atualizado para
    `via scripts/instalar_spicetify.sh`. Seção `## Reaplicar` aponta
    primeiro para o script local.
26. `app-themes/spicetify/README.md`: seção renomeada de
    `## Por que não duplicar...` para `## Boundary com Spellbook-OS`,
    com texto atualizado.
27. `app-themes/spicetify/README.md` seção `## Troubleshooting` (SPRINT 17)
    intacta.

### Sprint, Index e Changelog

28. `docs/sprints/SPRINT_18_SPICETIFY_AUTONOMO.md` criado (este documento).
29. `docs/sprints/INDEX.md` linha 26 nova com SPRINT 18.
30. `CHANGELOG.md` `[Unreleased]` `### Adicionado` com entrada SPRINT 18.

### Integração e regressão

31. `bash scripts/diagnostico.sh --quiet` exit 0 (sem regressão; recall:
    diagnostico hoje não cobre Spicetify, conforme A1 da SPRINT 17).
32. `bash scripts/atualizar_spicetify.sh` exit 0 (sem regressão; ortogonal
    a esta sprint).
33. `bash scripts/reaplicar_tema.sh` exit 0; seção 7.6 continua chamando
    `atualizar_spicetify.sh`.
34. **Acentuação**: varredura nos arquivos novos/modificados com
    `grep -nE 'instalacao|aplicacao|deteccao|nao |execucao|funcao|configuracao|atualizacao|reaplicacao|reinstalacao|acentuacao'`
    retorna 0 hits relevantes (filtrar manualmente "nao" dentro de
    palavras como "Platao" — embora o epígrafe seja substituído por um
    pt-BR).

---

## Invariantes a preservar

- `set -euo pipefail` em `scripts/instalar_spicetify.sh` (paridade com
  Spellbook + padrão dos scripts SPRINT 17).
- `set -euo pipefail` em `scripts/desinstalar_spicetify.sh`.
- Source de `lib/common.sh` no padrão SPRINT 06+:
  `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` +
  `# shellcheck source=lib/common.sh`.
- `_DRACULA_COMMON_SOURCED` guard em `lib/common.sh:11-12` — não duplicar.
- `validar_path_destrutivo` invocado antes de **todo** `rm -rf` desta
  sprint:
  - cache do Flatpak no `restaurar_e_aplicar()` (já está na allowlist
    desde SPRINT 17).
  - `~/.spicetify` e `~/.config/spicetify` no `desinstalar_spicetify.sh
    --full` (entradas novas na allowlist).
- Allowlist destrutiva: estender com **duas** entradas exatas
  (`~/.spicetify` e `~/.config/spicetify`), não generalizar.
- Logger pattern: usar `_info`/`_ok`/`_warn`/`_err`/`_dim` exclusivamente
  (não importar/redefinir as cores `_C_*` do Spellbook).
- Idempotência:
  - `instalar_spicetify`: `[[ -x "$SPICETIFY_BIN" ]]` antes de instalar;
    `[[ -d "$THEMES_DIR/$TEMA" ]]` antes de clonar; `[[ -d
    "$CUSTOM_APPS_DIR/marketplace" ]]` antes de instalar marketplace;
    `aplicar_config` é naturalmente idempotente (overwrite).
  - `desinstalar_spicetify`: no-op silencioso quando nada existe.
- Suporte a `DRACULA_DRY_RUN=1` em ambos scripts novos.
- Sem sudo. Sem `requires-root`. MODO=user.
- CLAUDE.md §2 (simplicidade): scripts lineares; replicação fiel + 5
  diferenças intencionais documentadas no mapping. Sem refactor além
  do necessário.
- CLAUDE.md §3 (cirúrgico): `aplicar_spicetify` reescrita; o resto de
  `instalar_app_themes.sh` intocado. `_buscar_spicetify_setup` preservada.
- Boundary externo:
  `~/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh` não tocado;
  permanece reusável via flag opt-in.
- Acentuação pt-BR íntegra em **strings de log**, comentários e docs:
  `instalação`, `aplicação`, `função`, `configuração`, `detecção`,
  `acentuação`, `está`, `também`, `não`, `através`, `padrão`.

---

## Plano de implementação

> Ordem proposta: Passo 1 (allowlist em lib/common.sh) → Passo 2
> (instalar_spicetify) → Passo 3 (desinstalar_spicetify) → Passo 4
> (aplicar_spicetify reescrita) → Passo 5 (docs README/HTML/spicetify) →
> Passo 6 (sprint/index/changelog). Cada passo é commitável isoladamente;
> recomenda-se commit único final por simplicidade.

### Passo 1 — `scripts/lib/common.sh` — allowlist (2 entradas)

**Edit cirúrgico**: adicionar duas linhas à `_allowlist_destrutiva` (linha
69–86 atual), após `~/.local/share/backgrounds/dracula` (linha 80, SPRINT 17)
e antes de `/usr/share/icons` (linha 81):

```bash
    "$HOME/.spicetify"
    "$HOME/.config/spicetify"
```

(Posição: agrupa as entradas relacionadas ao Spicetify; cresce a allowlist
em 2 linhas. Total esperado: 17 → 19 entradas, dentro do limite de
restrição da CLAUDE.md §2.)

### Passo 2 — `scripts/instalar_spicetify.sh` (NOVO)

Esqueleto linear, ~290 linhas. Abaixo a estrutura por blocos com
referência ao Spellbook-OS (linhas indicadas como `Spellbook:NN`):

```bash
#!/usr/bin/env bash
# instalar_spicetify.sh — instalador autônomo do Spicetify para o
# Dracula_OS-Theme. Detecta Spotify (Flatpak/snap/nativo), instala o
# binário Spicetify (oficial), clona spicetify/spicetify-themes, instala
# o Marketplace, configura prefs_path, aplica 13 chaves de config,
# extensions e custom_apps, executa restore + clear + backup apply, e
# valida. Idempotente. Sem sudo.
#
# Replica a lógica de Spellbook-OS/scripts/spicetify-setup.sh (277L)
# localmente para que o Dracula_OS-Theme não dependa de outro repo.
#
# Variáveis:
#   DRACULA_DRY_RUN=1   imprime comandos com prefixo [dry-run] e não
#                       executa curl|sh, git clone, spicetify backup apply.
#
# Flags:
#   --apenas-detectar   imprime tipo de Spotify (flatpak/snap/nativo/
#                       nenhum) e sai com 0. Útil para diagnóstico.
#   --skip-marketplace  pula instalação do Marketplace (CI/offline).
#   --help|-h           ajuda.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# --- Paths Spicetify (Spellbook:7-10) ---
SPICETIFY_BIN="$HOME/.spicetify/spicetify"
SPICETIFY_DIR="$HOME/.spicetify"
THEMES_DIR="$HOME/.config/spicetify/Themes"
CUSTOM_APPS_DIR="$SPICETIFY_DIR/CustomApps"

# --- Configuração padrão (Spellbook:26-30) ---
TEMA="Sleek"
ESQUEMA="Dracula"
EXTENSIONS="autoSkipExplicit.js|autoSkipVideo.js|bookmark.js|fullAppDisplay.js|keyboardShortcut.js|loopyLoop.js|popupLyrics.js|shuffle+.js|trashbin.js|webnowplaying.js"
CUSTOM_APPS="marketplace|lyrics-plus|reddit|new-releases"

# --- Flags ---
APENAS_DETECTAR=0
SKIP_MARKETPLACE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apenas-detectar) APENAS_DETECTAR=1; shift ;;
        --skip-marketplace) SKIP_MARKETPLACE=1; shift ;;
        --help|-h)
            cat <<'EOF'
Uso: instalar_spicetify.sh [--apenas-detectar] [--skip-marketplace]

Instalador autônomo do Spicetify (sem dependência do Spellbook-OS).

Flags:
  --apenas-detectar   imprime tipo de Spotify (flatpak/snap/nativo/nenhum)
                      e sai. Não instala nada.
  --skip-marketplace  pula a instalação do Marketplace custom app.

Variáveis:
  DRACULA_DRY_RUN=1   apenas loga, não executa curl|sh nem git clone.
EOF
            exit 0 ;;
        *) _warn "Argumento ignorado: $1"; shift ;;
    esac
done

# --- Detecção do Spotify (Spellbook:33-45) ---
detectar_spotify() {
    if flatpak list 2>/dev/null | grep -q "com.spotify.Client"; then
        echo "flatpak"
    elif snap list 2>/dev/null | grep -q "spotify"; then
        echo "snap"
    elif command -v spotify &>/dev/null; then
        echo "nativo"
    elif [[ -d "/opt/spotify" ]]; then
        echo "nativo"
    else
        echo "nenhum"
    fi
}

# --- Instalar Spicetify (Spellbook:48-63) ---
instalar_spicetify() {
    if [[ -x "$SPICETIFY_BIN" ]]; then
        local versao
        versao=$("$SPICETIFY_BIN" --version 2>/dev/null || echo "desconhecida")
        _ok "Spicetify já instalado (v${versao})"
        return 0
    fi
    _info "Instalando Spicetify (curl oficial)..."
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh"
        return 0
    fi
    curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh
    if [[ -x "$SPICETIFY_BIN" ]]; then
        _ok "Spicetify instalado ($("$SPICETIFY_BIN" --version))"
    else
        _err "Falha ao instalar Spicetify"
        exit 1
    fi
}

# --- Instalar temas (Spellbook:66-85) ---
instalar_temas() {
    if [[ -d "$THEMES_DIR/$TEMA" ]]; then
        _ok "Tema $TEMA já presente"
        return 0
    fi
    _info "Clonando repositório de temas..."
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] git clone --depth=1 https://github.com/spicetify/spicetify-themes.git \$tmp"
        _dim "[dry-run] cp -r \$tmp/* $THEMES_DIR/"
        return 0
    fi
    local tmp_dir
    tmp_dir=$(mktemp -d)
    git clone --depth=1 https://github.com/spicetify/spicetify-themes.git "$tmp_dir"
    mkdir -p "$THEMES_DIR"
    cp -r "$tmp_dir"/* "$THEMES_DIR/"
    rm -rf "$tmp_dir"
    if [[ -d "$THEMES_DIR/$TEMA" ]]; then
        _ok "Temas instalados (tema ativo: $TEMA)"
    else
        _warn "Clone concluído mas tema $TEMA não encontrado"
    fi
}

# --- Instalar Marketplace (Spellbook:88-101) ---
instalar_marketplace() {
    if [[ $SKIP_MARKETPLACE -eq 1 ]]; then
        _info "Marketplace pulado (--skip-marketplace)"
        return 0
    fi
    if [[ -d "$CUSTOM_APPS_DIR/marketplace" ]]; then
        _ok "Marketplace já instalado"
        return 0
    fi
    _info "Instalando Marketplace custom app..."
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh"
        return 0
    fi
    curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh
    if [[ -d "$CUSTOM_APPS_DIR/marketplace" ]]; then
        _ok "Marketplace instalado"
    else
        _warn "Marketplace não encontrado após instalação"
    fi
}

# --- Configurar paths (Spellbook:104-144) ---
# Diferenças vs Spellbook: dry-run guard; loop de geração de prefs reduzido
# para 10 iterações de 2s (max 20s) em vez de 15 (max 30s).
configurar_paths() {
    local tipo="$1"
    _info "Configurando paths para instalação $tipo..."
    case "$tipo" in
        flatpak)
            local flatpak_prefs="$HOME/.var/app/com.spotify.Client/config/spotify/prefs"
            if [[ -f "$flatpak_prefs" ]]; then
                if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
                    _dim "[dry-run] $SPICETIFY_BIN config prefs_path $flatpak_prefs"
                else
                    "$SPICETIFY_BIN" config prefs_path "$flatpak_prefs"
                    _ok "prefs_path configurado para Flatpak"
                fi
            else
                _warn "prefs do Flatpak não encontrado — abrindo Spotify para gerar"
                if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
                    _dim "[dry-run] flatpak run com.spotify.Client & ; sleep até 20s ; kill"
                    _dim "[dry-run] $SPICETIFY_BIN config prefs_path $flatpak_prefs"
                    return 0
                fi
                flatpak run com.spotify.Client &>/dev/null &
                local pid=$!
                local i
                for i in $(seq 1 10); do
                    [[ -f "$flatpak_prefs" ]] && break
                    sleep 2
                done
                kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null || true
                if [[ -f "$flatpak_prefs" ]]; then
                    "$SPICETIFY_BIN" config prefs_path "$flatpak_prefs"
                    _ok "prefs_path configurado para Flatpak"
                else
                    _warn "Falha ao gerar prefs — configure prefs_path manualmente"
                fi
            fi
            ;;
        snap)
            local snap_prefs="$HOME/snap/spotify/current/.config/spotify/prefs"
            if [[ -f "$snap_prefs" ]]; then
                if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
                    _dim "[dry-run] $SPICETIFY_BIN config prefs_path $snap_prefs"
                else
                    "$SPICETIFY_BIN" config prefs_path "$snap_prefs"
                    _ok "prefs_path configurado para Snap"
                fi
            fi
            ;;
        nativo)
            _ok "prefs_path padrão para instalação nativa"
            ;;
    esac
}

# --- Aplicar configuração (Spellbook:147-168, 13 chaves) ---
aplicar_config() {
    _info "Aplicando configuração..."
    local k v
    # Pares chave=valor; mesmas 13 do Spellbook
    local pares=(
        "current_theme=$TEMA"
        "color_scheme=$ESQUEMA"
        "inject_css=1"
        "replace_colors=1"
        "overwrite_assets=1"
        "inject_theme_js=1"
        "sidebar_config=1"
        "experimental_features=1"
        "home_config=1"
        "expose_apis=1"
        "disable_sentry=1"
        "disable_ui_logging=1"
        "remove_rtl_rule=1"
    )
    for par in "${pares[@]}"; do
        k="${par%%=*}"; v="${par#*=}"
        if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
            _dim "[dry-run] $SPICETIFY_BIN config $k $v"
        else
            "$SPICETIFY_BIN" config "$k" "$v"
        fi
    done
    _ok "Configuração aplicada via CLI"
}

# --- Extensions e custom apps (Spellbook:171-189) ---
aplicar_extensions() {
    _info "Configurando extensions e custom apps..."
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] $SPICETIFY_BIN config extensions $EXTENSIONS"
        _dim "[dry-run] $SPICETIFY_BIN config custom_apps $CUSTOM_APPS"
        return 0
    fi
    "$SPICETIFY_BIN" config extensions "$EXTENSIONS"
    "$SPICETIFY_BIN" config custom_apps "$CUSTOM_APPS"

    # Sanitização de 'custom_apps' espúrio na lista de extensions
    # (workaround conhecido do Spicetify CLI; Spellbook:178-186)
    local ext_atual
    ext_atual=$("$SPICETIFY_BIN" config extensions | tr '\n' '|' | sed 's/|$//')
    if echo "$ext_atual" | grep -q '|custom_apps|'; then
        ext_atual=$(echo "$ext_atual" | sed 's/|custom_apps|/|/g; s/^custom_apps|//; s/|custom_apps$//')
        local ini_file="$HOME/.config/spicetify/config-xpui.ini"
        if [[ -f "$ini_file" ]]; then
            sed -i "s|^extensions.*=.*|extensions            = ${ext_atual}|" "$ini_file"
        fi
    fi
    _ok "Extensions e custom apps configurados"
}

# --- Restaurar e aplicar (Spellbook:194-214) ---
# Diferença vs Spellbook: validar_path_destrutivo antes de rm -rf cache.
restaurar_e_aplicar() {
    local tipo="$1"
    if [[ "$tipo" == "flatpak" ]]; then
        local cache_dir="$HOME/.var/app/com.spotify.Client/cache/spotify/Default/Cache"
        if [[ -d "$cache_dir" ]]; then
            if validar_path_destrutivo "$cache_dir" >/dev/null 2>&1; then
                if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
                    _dim "[dry-run] rm -rf -- $cache_dir/*"
                else
                    rm -rf "${cache_dir:?}/"*
                    _ok "Cache web do Flatpak limpo"
                fi
            else
                _warn "Cache fora da allowlist; pulando limpeza"
            fi
        fi
    fi
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] $SPICETIFY_BIN restore"
        _dim "[dry-run] $SPICETIFY_BIN clear"
        _dim "[dry-run] $SPICETIFY_BIN backup apply"
        _ok "[dry-run] Spicetify aplicado (simulação)"
        return 0
    fi
    _info "Restaurando Spotify ao estado original..."
    "$SPICETIFY_BIN" restore 2>/dev/null || true
    _info "Limpando backup anterior..."
    "$SPICETIFY_BIN" clear
    _info "Criando backup e aplicando customizações..."
    "$SPICETIFY_BIN" backup apply
    _ok "Spicetify aplicado com sucesso"
}

# --- Validação (Spellbook:217-245) ---
validar() {
    local erros=0
    _info "Validando instalação..."
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _ok "[dry-run] Validação pulada"
        return 0
    fi
    if ! "$SPICETIFY_BIN" config extensions | grep -q "bookmark.js"; then
        _warn "Extensions não configuradas corretamente"
        erros=$((erros+1))
    fi
    if ! "$SPICETIFY_BIN" config custom_apps | grep -q "marketplace"; then
        _warn "Custom apps não configurados corretamente"
        erros=$((erros+1))
    fi
    local tema_atual
    tema_atual=$("$SPICETIFY_BIN" config current_theme 2>/dev/null || echo "")
    if [[ "$tema_atual" != "$TEMA" ]]; then
        _warn "Tema atual ($tema_atual) difere do esperado ($TEMA)"
        erros=$((erros+1))
    fi
    if [[ $erros -eq 0 ]]; then
        _ok "Validação completa: tudo OK"
    else
        _warn "$erros problema(s) detectado(s)"
        return 1
    fi
}

# --- Main ---
main() {
    local tipo_spotify
    tipo_spotify=$(detectar_spotify)

    if [[ $APENAS_DETECTAR -eq 1 ]]; then
        echo "$tipo_spotify"
        exit 0
    fi

    _info "Spotify detectado: $tipo_spotify"
    if [[ "$tipo_spotify" == "nenhum" ]]; then
        _err "Spotify não encontrado. Instale o Spotify primeiro."
        exit 1
    fi

    instalar_spicetify
    configurar_paths "$tipo_spotify"
    instalar_temas
    instalar_marketplace
    aplicar_config
    aplicar_extensions
    restaurar_e_aplicar "$tipo_spotify"
    validar

    _ok "Spicetify configurado com sucesso. Abra o Spotify para verificar."
}

main "$@"

# "A música acalma a fera." — adágio popular pt-BR
```

(Tamanho esperado: 285–310 linhas com todas as funções, comentários
e blocos `[dry-run]`. Faixa de validação `wc -l`: **285–315**.)

### Passo 3 — `scripts/desinstalar_spicetify.sh` (NOVO)

Esqueleto curto, ~40 linhas:

```bash
#!/usr/bin/env bash
# desinstalar_spicetify.sh — reverte Spicetify. Sem flag, executa
# `spicetify restore` (preserva configs/themes). Com `--full`, remove
# também ~/.spicetify/ e ~/.config/spicetify/ (com validar_path_destrutivo).
# Não-fatal se nada existe.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

SPICETIFY_BIN="$HOME/.spicetify/spicetify"
FULL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --full) FULL=1; shift ;;
        --help|-h)
            cat <<'EOF'
Uso: desinstalar_spicetify.sh [--full]

Sem --full: executa `spicetify restore` (preserva configs).
Com --full: remove ~/.spicetify/ e ~/.config/spicetify/.

Variáveis:
  DRACULA_DRY_RUN=1   apenas loga, não executa.
EOF
            exit 0 ;;
        *) _warn "Argumento ignorado: $1"; shift ;;
    esac
done

if [[ -x "$SPICETIFY_BIN" ]]; then
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] $SPICETIFY_BIN restore"
    else
        "$SPICETIFY_BIN" restore 2>/dev/null || _warn "spicetify restore falhou"
        _ok "Spicetify restaurado (Spotify limpo)"
    fi
else
    _info "Spicetify não instalado em $SPICETIFY_BIN; nada a restaurar"
fi

if [[ $FULL -eq 1 ]]; then
    for dir in "$HOME/.spicetify" "$HOME/.config/spicetify"; do
        if [[ -d "$dir" ]]; then
            if ! validar_path_destrutivo "$dir"; then
                _err "Pulando $dir por segurança"
                continue
            fi
            if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
                _dim "[dry-run] rm -rf -- $dir"
            else
                rm -rf -- "$dir" && _ok "removido: $dir"
            fi
        fi
    done
fi

exit 0
```

(Faixa esperada `wc -l`: **45–55**.)

### Passo 4 — `scripts/instalar_app_themes.sh` — reescrita de `aplicar_spicetify`

**Edit cirúrgico**: substituir o corpo da função `aplicar_spicetify`
(linhas 115–133) pelo seguinte. `_buscar_spicetify_setup` (linhas 96–113)
**permanece** sem mudança porque vira utilitária do branch fallback.

```bash
aplicar_spicetify() {
    # SPRINT 18: script local é fonte primária. Spellbook-OS vira fallback
    # opcional via DRACULA_PREFER_SPELLBOOK_SPICETIFY=1.
    local repo_root
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local local_setup="$repo_root/scripts/instalar_spicetify.sh"

    # Branch 1: Spellbook explicitamente preferido
    if [[ "${DRACULA_PREFER_SPELLBOOK_SPICETIFY:-0}" == "1" ]]; then
        local setup
        if setup="$(_buscar_spicetify_setup)"; then
            _info "Spicetify: delegando para Spellbook-OS (DRACULA_PREFER_SPELLBOOK_SPICETIFY=1)"
            if [[ $DRY_RUN -eq 0 ]]; then
                if "$setup"; then
                    _ok "Spicetify aplicado via Spellbook-OS"
                else
                    _warn "Spicetify retornou erro via Spellbook-OS (não fatal)"
                fi
            else
                echo "  [dry-run] $setup"
            fi
            return 0
        else
            _warn "Spellbook-OS solicitado mas não encontrado, caindo para script local"
        fi
    fi

    # Branch 2: script local (default)
    if [[ ! -x "$local_setup" ]]; then
        _skip "Spicetify: $local_setup não encontrado/executável"
        return 0
    fi
    _info "Spicetify: aplicando via instalar_spicetify.sh (autônomo)"
    if [[ $DRY_RUN -eq 0 ]]; then
        if "$local_setup"; then
            _ok "Spicetify aplicado via instalar_spicetify.sh"
        else
            _warn "instalar_spicetify.sh retornou erro (Spotify ausente ou falha — não fatal)"
        fi
    else
        echo "  [dry-run] $local_setup"
    fi
}
```

(Tamanho: 35 linhas vs. 19 atuais; +16 líquido. `_buscar_spicetify_setup`
fica intocada nas linhas 96–113.)

### Passo 5 — `README.md` — três edits

**Edit A** (linha 52, tabela "Integração Spellbook-OS"): substituir a
célula da direita:

De:
```
| **Integração Spellbook-OS** | `rebuild_dracula_theme` + cobertura de `~/.local/share/icons/` em `_reconstruir_caches_icones` |
```

Para:
```
| **Integração Spellbook-OS** | `rebuild_dracula_theme` + cobertura de `~/.local/share/icons/` em `_reconstruir_caches_icones`. Spicetify deixou de ser dependência (SPRINT 18 internalizou o setup); Spellbook permanece reutilizável via `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1`. |
```

**Edit B** (linha 158, comentário): substituir
`# Spicetify aplicado via Spellbook-OS (tema Sleek + color scheme Dracula)`
por
`# Spicetify aplicado via scripts/instalar_spicetify.sh (tema Sleek + color scheme Dracula)`.

**Edit C** (seção `### Dependências externas`, linhas 164–185):
reescrever o bullet de Spicetify:

De (~6 linhas, linhas 168–175):
```
- **Spicetify** (Spotify Flatpak): a função `aplicar_spicetify` em
  `scripts/instalar_app_themes.sh` busca `spicetify-setup.sh` do
  [Spellbook-OS](https://github.com/AndreBFarias/coding/Spellbook-OS) em quatro
  caminhos conhecidos (`$REPO/../Spellbook-OS/scripts/`,
  `$HOME/Desenvolvimento/Spellbook-OS/scripts/`,
  `$XDG_DATA_HOME/Spellbook-OS/scripts/`, `/opt/Spellbook-OS/scripts/`). Sem o
  Spellbook, o passo é pulado com warning. Alternativa: rodar manualmente o
  setup oficial do [Spicetify CLI](https://spicetify.app).
```

Para (~9 linhas):
```
- **Spicetify** (Spotify Flatpak): a partir da SPRINT 18, a função
  `aplicar_spicetify` em `scripts/instalar_app_themes.sh` chama
  `scripts/instalar_spicetify.sh` (autocontido neste repo) por padrão.
  O setup detecta o tipo de Spotify (Flatpak/snap/nativo), instala
  Spicetify via `curl | sh` oficial, clona `spicetify/spicetify-themes`,
  configura `prefs_path`, aplica 13 chaves de config + extensions +
  custom apps (marketplace, lyrics-plus, reddit, new-releases) e roda
  `spicetify backup apply`. Para reusar o setup mantido em
  [Spellbook-OS](https://github.com/AndreBFarias/Spellbook-OS) como
  fallback, exporte `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1` antes de
  rodar o instalador.
```

**Edit D** (linhas 327–328, Troubleshooting): manter, apenas atualizar
texto se necessário para coerência (Spellbook continua sendo fallback;
ok como está, mas o executor deve confirmar).

**Edit E** (linhas 351–353, "Integração com Spellbook-OS"): substituir
"Spicetify exige" (se houver) por "Spicetify pode reusar". Executor lê
o bloco e ajusta cirurgicamente.

### Passo 6 — `docs/index.html` — edit no card

**Edit cirúrgico** linha 61: substituir
```html
<p>Kitty, qBittorrent, GNOME Terminal (dconf), Spicetify/Spotify, Obsidian (itera vaults), Telegram, Discord (BetterDiscord/Vesktop/Vencord), OnlyOffice. <strong>Spicetify</strong> usa o setup do <a href="https://github.com/AndreBFarias/Spellbook-OS">Spellbook-OS</a>; recuperação pós <code>flatpak update</code> via <code>scripts/atualizar_spicetify.sh --auto-fix</code>.</p>
```
por
```html
<p>Kitty, qBittorrent, GNOME Terminal (dconf), Spicetify/Spotify, Obsidian (itera vaults), Telegram, Discord (BetterDiscord/Vesktop/Vencord), OnlyOffice. <strong>Spicetify</strong> é instalado via <code>scripts/instalar_spicetify.sh</code> (autocontido); recuperação pós <code>flatpak update</code> via <code>scripts/atualizar_spicetify.sh --auto-fix</code>.</p>
```

(Mantém estilo HTML adjacente. Sem refactor de CSS. Linha única
substituída.)

### Passo 7 — `app-themes/spicetify/README.md` — três edits

**Edit A** (linhas 1–4, header):

De:
```markdown
# Spicetify — Spotify com tema Dracula

O Spotify (Flatpak) deste sistema já está configurado com Spicetify + tema
**Sleek** + paleta **Dracula** via o script `spicetify-setup.sh` mantido em
Spellbook-OS.
```

Para:
```markdown
# Spicetify — Spotify com tema Dracula

O Spotify (Flatpak) deste sistema é configurado com Spicetify + tema
**Sleek** + paleta **Dracula** via `scripts/instalar_spicetify.sh`,
autocontido neste repositório (SPRINT 18; antes da SPRINT 18, o setup
era delegado ao Spellbook-OS).
```

**Edit B** (seção `## Reaplicar`, linhas 7–18):

De:
```markdown
## Reaplicar

\`\`\`bash
~/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh
\`\`\`

O script detecta automaticamente se o Spotify é Flatpak, snap ou nativo,
instala Spicetify (se necessário), clona o repositório de temas
(`spicetify/spicetify-themes`), configura `prefs_path` para o Flatpak,
aplica extensions + custom apps (marketplace, lyrics-plus, reddit,
new-releases) e executa `spicetify backup apply`.
```

Para:
```markdown
## Reaplicar

\`\`\`bash
bash scripts/instalar_spicetify.sh
\`\`\`

O script detecta automaticamente se o Spotify é Flatpak, snap ou nativo,
instala Spicetify (se necessário, via `curl | sh` oficial), clona o
repositório de temas (`spicetify/spicetify-themes`), configura
`prefs_path` para o Flatpak (rodando o Spotify uma vez se necessário),
aplica 13 chaves de config + extensions + custom apps (marketplace,
lyrics-plus, reddit, new-releases) e executa `spicetify backup apply`.

Idempotente: rodar 2× consecutivas é seguro. Suporta `DRACULA_DRY_RUN=1`,
`--apenas-detectar` (imprime tipo de Spotify e sai), e `--skip-marketplace`.

Como fallback, o setup mantido em
`~/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh` continua
disponível: `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1 bash scripts/instalar_app_themes.sh`.
```

**Edit C** (linhas 30–34, `## Por que não duplicar...` → `## Boundary com Spellbook-OS`):

De:
```markdown
## Por que não duplicar no Dracula_OS-Theme

Evitar divergência: a lógica do Spellbook-OS já trata os edge cases
(limpeza de cache do Flatpak, geração de prefs na primeira execução,
validação pós-instalação). `scripts/instalar_app_themes.sh` apenas chama
essa rotina.
```

Para:
```markdown
## Boundary com Spellbook-OS

A SPRINT 18 internalizou o setup de Spicetify neste repositório
(`scripts/instalar_spicetify.sh`) para que o Dracula_OS-Theme não
dependa de outro repo para configurar o Spotify. O `spicetify-setup.sh`
mantido em Spellbook-OS continua reutilizável via
`DRACULA_PREFER_SPELLBOOK_SPICETIFY=1` quando o usuário já tem aquele
repo clonado e prefere a versão de lá. Os dois setups produzem o mesmo
estado final (mesmas 13 chaves de config, mesma lista de extensions
e custom apps, mesma sanitização de `custom_apps` espúrio).
```

(Manter intacta a seção `## Configuração atual ativa` — linhas 20–28.
Manter intacta `## Troubleshooting` — linhas 36 em diante.)

### Passo 8 — `docs/sprints/INDEX.md` — adicionar linha

**Adicionar** após a linha 25 (SPRINT 17):

```
| 18 | [Spicetify autônomo (sem Spellbook-OS)](SPRINT_18_SPICETIFY_AUTONOMO.md) | Em implementação | <data do commit> |
```

(Manter alinhamento da tabela; padding idêntico às linhas anteriores.)

### Passo 9 — `CHANGELOG.md` — entrada `[Unreleased]` `### Adicionado`

Acrescentar como último item da seção `### Adicionado` (após o item da
SPRINT 17):

```
- **Sprint 18 — Spicetify autônomo (sem Spellbook-OS)**: novo `scripts/instalar_spicetify.sh` (autocontido neste repo) replica a lógica de `Spellbook-OS/scripts/spicetify-setup.sh` localmente. Detecta tipo de Spotify (Flatpak/snap/nativo), instala Spicetify via `curl | sh` oficial, clona `spicetify/spicetify-themes`, configura `prefs_path` (rodando Spotify uma vez se necessário, com timeout reduzido para 20s), aplica 13 chaves de `spicetify config` (`current_theme=Sleek`, `color_scheme=Dracula`, `inject_css=1`, `replace_colors=1`, `overwrite_assets=1`, `inject_theme_js=1`, `sidebar_config=1`, `experimental_features=1`, `home_config=1`, `expose_apis=1`, `disable_sentry=1`, `disable_ui_logging=1`, `remove_rtl_rule=1`), instala extensions (autoSkipExplicit/Video, bookmark, fullAppDisplay, keyboardShortcut, loopyLoop, popupLyrics, shuffle+, trashbin, webnowplaying) e custom apps (marketplace, lyrics-plus, reddit, new-releases), aplica sanitização de `custom_apps` espúrio na lista de extensions, executa `spicetify restore` + `clear` + `backup apply`, e valida (3 checks: bookmark.js, marketplace, tema=Sleek). Idempotente. Suporta `DRACULA_DRY_RUN=1`, `--apenas-detectar` (imprime tipo de Spotify e sai), `--skip-marketplace` (CI/offline). `aplicar_spicetify` em `scripts/instalar_app_themes.sh` foi reescrita para chamar o script local por padrão; o `spicetify-setup.sh` do Spellbook-OS vira fallback opcional via `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1` (nunca automático). Novo `scripts/desinstalar_spicetify.sh`: por padrão executa `spicetify restore`; com `--full` remove `~/.spicetify/` e `~/.config/spicetify/` com `validar_path_destrutivo`. Allowlist destrutiva em `lib/common.sh` estendida com `~/.spicetify` e `~/.config/spicetify`. Spellbook-OS deixa de ser dependência obrigatória do Dracula_OS-Theme; documentação em `README.md`, `docs/index.html` e `app-themes/spicetify/README.md` atualizada para refletir autonomia. Boundary preservado: `scripts/atualizar_spicetify.sh` (SPRINT 17, recuperação pós `flatpak update`) permanece autônomo e ortogonal; `_buscar_spicetify_setup()` em `instalar_app_themes.sh` é preservada como utilitária do branch fallback.
```

---

## Aritmética

Sprint **adiciona** mais do que remove. Sem meta de redução. Faixas
esperadas:

| Arquivo                                 | Antes (L) | Depois (L) | Delta                          |
|-----------------------------------------|-----------|------------|--------------------------------|
| `scripts/instalar_spicetify.sh`         | 0         | ~290       | criação                        |
| `scripts/desinstalar_spicetify.sh`      | 0         | ~50        | criação                        |
| `scripts/lib/common.sh`                 | 247       | ~249       | +2 (allowlist com 2 entradas)  |
| `scripts/instalar_app_themes.sh`        | 248       | ~265       | +17 (`aplicar_spicetify` 19→35; `_buscar_spicetify_setup` intocada) |
| `README.md`                             | 388       | ~398       | +10 (Edit A célula tabela +1; Edit B comentário 0; Edit C bullet ~+8 a ~+9) |
| `docs/index.html`                       | 192       | 192        | 0 (edit in-place de uma `<p>`) |
| `app-themes/spicetify/README.md`        | 77        | ~92        | +15 (Edit A header reescrito 0; Edit B Reaplicar +9; Edit C boundary 0..+1) |
| `docs/sprints/INDEX.md`                 | 45        | 46         | +1                             |
| `CHANGELOG.md`                          | 201       | 202        | +1 linha em `### Adicionado`   |
| `docs/sprints/SPRINT_18_SPICETIFY_AUTONOMO.md` | 0  | novo       | criação                        |

**Validação obrigatória antes do commit**:

- `wc -l scripts/instalar_spicetify.sh` na faixa **285–315**.
- `wc -l scripts/desinstalar_spicetify.sh` na faixa **45–60**.
- `wc -l scripts/lib/common.sh` na faixa **247–252**.
- `wc -l scripts/instalar_app_themes.sh` na faixa **260–270**.
- `wc -l README.md` na faixa **393–408**. Fora indica reformatação adjacente.
- `wc -l app-themes/spicetify/README.md` na faixa **88–98**.
- `wc -l docs/index.html` exatamente **192** (edit in-place de uma `<p>`).
- `wc -l docs/sprints/INDEX.md` exatamente **46**.

**Aritmética crítica (justificativas)**:

1. `scripts/instalar_spicetify.sh`: Spellbook tem 277L. Local source de
   `lib/common.sh` (-13L de cores e helpers replicados). Adiciona ~25L
   de argparse + flags (`--apenas-detectar`, `--skip-marketplace`,
   `--help`). Adiciona ~16L de guards `DRACULA_DRY_RUN=1` distribuídos.
   Adiciona ~4L de comentário Spellbook:NN nos blocos. Adiciona ~5L
   de `validar_path_destrutivo` no `restaurar_e_aplicar`.
   `277 - 13 + 25 + 16 + 4 + 5 ≈ 314`. Conservador: **285–315**, com a
   margem inferior para o caso de o executor compactar comentários.
2. `scripts/instalar_app_themes.sh`: bloco `aplicar_spicetify` antigo
   tem 19 linhas (115–133). Bloco novo tem 35 linhas (branch
   Spellbook + branch local + comentário SPRINT 18). Delta líquido +16,
   mas a janela permite +17–+22 para o caso de o executor adicionar
   1–2 linhas de banner ou comentário marginal.
3. `scripts/lib/common.sh`: 247 → 249. Apenas 2 linhas novas na
   allowlist; faixa **247–252** acomoda variação trivial.
4. `README.md`: edits A (+1), B (+0), C (~+8 a +9). Total: ~+9 a +10.
   Faixa **393–408** com margem.
5. `app-themes/spicetify/README.md`: edits A (header reescrito,
   comprimento similar, ~+0), B (Reaplicar +9 linhas), C (Boundary
   reescrito, comprimento similar, ~+0 a +1). Total: ~+9 a +10. Faixa
   **88–98** com margem.

---

## Testes / proof-of-work

### Sintaxe e source

```bash
for f in scripts/instalar_spicetify.sh scripts/desinstalar_spicetify.sh \
         scripts/lib/common.sh scripts/instalar_app_themes.sh; do
    bash -n "$f" && echo "OK $f"
done
( source scripts/lib/common.sh && declare -F validar_path_destrutivo _detectar_spotify_flatpak _resolver_spicetify_mismatch )
# esperado: 3 funções declaradas (sem regressão SPRINT 17)
```

### Lint

```bash
shellcheck --severity=warning \
    scripts/instalar_spicetify.sh \
    scripts/desinstalar_spicetify.sh \
    scripts/instalar_app_themes.sh \
    scripts/lib/common.sh
```

### Detecção e dry-run

```bash
# --apenas-detectar
out="$(bash scripts/instalar_spicetify.sh --apenas-detectar 2>/dev/null)"
echo "tipo=$out"
# esperado: "flatpak" (no host atual) ou outro valor literal; exit 0

# --help
bash scripts/instalar_spicetify.sh --help | head -20
# esperado: descreve flags, exit 0

# Dry-run completo
DRACULA_DRY_RUN=1 bash scripts/instalar_spicetify.sh
echo "exit=$?"
# esperado: exit 0; stdout contém "[dry-run]" em curl, git clone,
# spicetify config, restore/clear/backup apply

# Dry-run + skip-marketplace
DRACULA_DRY_RUN=1 bash scripts/instalar_spicetify.sh --skip-marketplace
# esperado: exit 0; stdout NÃO contém marketplace install
```

### Idempotência (host real, Spicetify já configurado)

```bash
# Run 1
bash scripts/instalar_spicetify.sh
echo "exit=$?"
# esperado: exit 0; logs "OK Spicetify já instalado", "OK Tema Sleek
# já presente", "OK Marketplace já instalado", "OK Validação completa"

# Run 2 (idempotente)
bash scripts/instalar_spicetify.sh
# esperado: output idêntico ao Run 1
```

### Roteamento em `instalar_app_themes.sh`

```bash
# Default (script local)
bash scripts/instalar_app_themes.sh 2>&1 | grep -i spicetify
# esperado: log "Spicetify aplicado via instalar_spicetify.sh"

# Spellbook explícito
DRACULA_PREFER_SPELLBOOK_SPICETIFY=1 bash scripts/instalar_app_themes.sh 2>&1 | grep -i spicetify
# esperado: log "Spicetify aplicado via Spellbook-OS"

# Spellbook ausente + flag (simulado)
mv ~/Desenvolvimento/Spellbook-OS ~/Desenvolvimento/Spellbook-OS.bak
DRACULA_PREFER_SPELLBOOK_SPICETIFY=1 bash scripts/instalar_app_themes.sh 2>&1 | grep -i spicetify
# esperado: warn "Spellbook-OS solicitado mas não encontrado, caindo
# para script local" + ok "Spicetify aplicado via instalar_spicetify.sh"
mv ~/Desenvolvimento/Spellbook-OS.bak ~/Desenvolvimento/Spellbook-OS
```

### Sem Spotify (mock)

```bash
# Mockar detectar_spotify retornando "nenhum"
# Estratégia: criar wrapper temp que sobrescreve flatpak/snap/spotify/opt
mkdir -p /tmp/dracula_mock_path
cat > /tmp/dracula_mock_path/flatpak <<'EOF'
#!/bin/sh
exit 0  # lista vazia → não imprime spotify
EOF
cat > /tmp/dracula_mock_path/snap <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x /tmp/dracula_mock_path/*

PATH="/tmp/dracula_mock_path:$PATH" bash scripts/instalar_spicetify.sh --apenas-detectar
# esperado: "nenhum" (assumindo que /opt/spotify não existe e
# `command -v spotify` falha sob esse PATH)

# main aborta com _err
PATH="/tmp/dracula_mock_path:$PATH" bash scripts/instalar_spicetify.sh
echo "exit=$?"
# esperado: exit 1; log "ERRO Spotify não encontrado..."

# aplicar_spicetify captura o erro e segue não-fatal
PATH="/tmp/dracula_mock_path:$PATH" bash scripts/instalar_app_themes.sh 2>&1 | grep -iE 'spicetify|spotify'
# esperado: warn "instalar_spicetify.sh retornou erro... não fatal"

rm -rf /tmp/dracula_mock_path
```

### Desinstalação

```bash
# Default (apenas restore)
bash scripts/desinstalar_spicetify.sh
echo "exit=$?"
# esperado: exit 0; log "Spicetify restaurado" (se binário existe) ou
# "Spicetify não instalado..." (se não existe). Diretórios ~/.spicetify
# e ~/.config/spicetify INTACTOS.
ls -d ~/.spicetify ~/.config/spicetify 2>&1
# esperado: ambos existem

# Dry-run + full
DRACULA_DRY_RUN=1 bash scripts/desinstalar_spicetify.sh --full
# esperado: stdout contém [dry-run] rm -rf -- ~/.spicetify e ~/.config/spicetify

# Sem nada instalado (no-op)
mv ~/.spicetify ~/.spicetify.bak
mv ~/.config/spicetify ~/.config/spicetify.bak
bash scripts/desinstalar_spicetify.sh
echo "exit=$?"
# esperado: exit 0; log "Spicetify não instalado em ..."
mv ~/.spicetify.bak ~/.spicetify
mv ~/.config/spicetify.bak ~/.config/spicetify

# --full REAL: NÃO testar (destrutivo). Apenas validar via dry-run.
```

### Reaplicação completa (sem regressão)

```bash
bash scripts/reaplicar_tema.sh
echo "exit=$?"
# esperado: exit 0; seção 7.6 imprime "Verificando Spicetify" via
# atualizar_spicetify.sh (SPRINT 17, ortogonal)
ls -1 ~/.cache/dracula_os_theme/reaplicar_tema_*.log | wc -l
# esperado: <= 10 (SPRINT 16, sem regressão)
```

### Diagnóstico (sem regressão)

```bash
bash scripts/diagnostico.sh --quiet
echo "exit=$?"
# esperado: exit 0
```

### Aritmética

```bash
wc -l scripts/instalar_spicetify.sh        # esperado 285..315
wc -l scripts/desinstalar_spicetify.sh     # esperado 45..60
wc -l scripts/lib/common.sh                # esperado 247..252
wc -l scripts/instalar_app_themes.sh       # esperado 260..270
wc -l README.md                            # esperado 393..408
wc -l app-themes/spicetify/README.md       # esperado 88..98
wc -l docs/index.html                      # esperado 192
wc -l docs/sprints/INDEX.md                # esperado 46
```

### Acentuação periférica

```bash
grep -nE 'instalacao|aplicacao|deteccao|nao |execucao|funcao|configuracao|atualizacao|reaplicacao|reinstalacao|acentuacao|portugues|musica' \
    scripts/instalar_spicetify.sh \
    scripts/desinstalar_spicetify.sh \
    scripts/instalar_app_themes.sh \
    scripts/lib/common.sh \
    README.md \
    app-themes/spicetify/README.md \
    docs/index.html \
    docs/sprints/SPRINT_18_SPICETIFY_AUTONOMO.md \
    docs/sprints/INDEX.md \
    CHANGELOG.md
# esperado: 0 hits relevantes (filtrar manualmente "nao" dentro de palavras)
```

### Hipótese verificada (lição 4 do GUIDE)

Antes de iniciar, executor confirma identificadores via `rg` (todos
confirmados pelo planejador na exploração desta sprint):

```bash
rg -n '_log_file|_repo_root|_purgar_antigos|validar_path_destrutivo|_allowlist_destrutiva|_detectar_spotify_flatpak|_resolver_spicetify_mismatch' scripts/lib/common.sh
rg -n 'aplicar_spicetify|_buscar_spicetify_setup|spicetify-setup' scripts/instalar_app_themes.sh
rg -n 'detectar_spotify|instalar_spicetify|instalar_temas|instalar_marketplace|configurar_paths|aplicar_config|aplicar_extensions|restaurar_e_aplicar|validar' /home/andrefarias/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh
rg -n 'Dependências externas|Spellbook-OS|Spicetify reclama|Integração com Spellbook-OS' README.md
rg -n 'App themes integrados|Spicetify|Spellbook' docs/index.html
ls -la ~/.spicetify/spicetify
flatpak list --app --columns=application 2>/dev/null | grep -i spotify
ls -d ~/Desenvolvimento/Spellbook-OS 2>/dev/null
```

Esperado:
- `validar_path_destrutivo:88`, `_detectar_spotify_flatpak:205`,
  `_resolver_spicetify_mismatch:219` em `lib/common.sh`.
- `_buscar_spicetify_setup:96`, `aplicar_spicetify:115` em
  `instalar_app_themes.sh`.
- 8 funções no `spicetify-setup.sh` do Spellbook conforme mapping.
- `Dependências externas:164` (SPRINT 17), `Integração com Spellbook-OS:351`
  em `README.md`.
- `App themes integrados:60`, `Spicetify` na linha 61 em `index.html`.
- `~/.spicetify/spicetify` executável.
- `com.spotify.Client` listado.
- `~/Desenvolvimento/Spellbook-OS` existe.

**Tudo confirmado na exploração do planejador.**

---

## Riscos e mitigações

1. **`curl | sh` requer rede** e baixa o instalador oficial do Spicetify.
   Sem rede, `instalar_spicetify` falha com `_err` e `exit 1`. O wrapper
   em `aplicar_spicetify` captura e converte em `_warn`. Aceitável.

2. **`git clone https://github.com/spicetify/spicetify-themes.git`** requer
   rede + ~25 MB. Mesma mitigação que o anterior.

3. **`flatpak run com.spotify.Client &`** para gerar prefs roda o Spotify
   em background; pode mostrar janela em ambiente gráfico. Mitigação:
   redirecionar stdout/stderr para `/dev/null` e `kill` em até 20s.
   Spellbook usa o mesmo padrão. Risco baixo.

4. **`kill "$pid"` antes do `wait`**: pode haver race onde o pid já
   morreu; `wait` retorna erro mas `|| true` mascara. Mitigação: já
   incluído no Spellbook; replicar.

5. **`spicetify backup apply` em estado já configurado**: o Spicetify
   detecta backup existente e re-aplica sem dano. Idempotente. Validado
   pelo Spellbook há tempo de produção.

6. **`sed -i "s|^extensions.*=.*|...`** em `~/.config/spicetify/config-xpui.ini`:
   workaround do Spellbook (linhas 178–186). Mantido idêntico. Risco:
   se o formato do INI mudar, o sed quebra silenciosamente. Aceitável
   (mesmo risco que o Spellbook tem hoje).

7. **`DRACULA_PREFER_SPELLBOOK_SPICETIFY=1`** em ambiente sem Spellbook:
   mitigado por `_buscar_spicetify_setup` retornar 1, log `_warn`,
   queda automática para o local. Comportamento documentado.

8. **Spotify nativo (.deb) ou snap**: `detectar_spotify` retorna `nativo`/
   `snap`; `configurar_paths` trata os dois casos com paths corretos.
   Replicado do Spellbook. Cobertura mantida.

9. **AppImage do Spotify**: não detectado (nem o Spellbook detecta).
   Fora de escopo.

10. **`shopt -s nullglob`** e expansão de globs: nenhum glob crítico
    nesta sprint. Sem risco.

11. **Concorrência com APT hook**: APT hook chama `reaplicar_tema.sh`
    que chama `atualizar_spicetify.sh` (SPRINT 17, ortogonal); não
    chama `instalar_spicetify.sh`. Sem cruzamento.

12. **Limpeza de cache em `restaurar_e_aplicar`**: protegida por
    `validar_path_destrutivo` (a entrada
    `~/.var/app/com.spotify.Client/cache` está na allowlist desde a
    SPRINT 17). Defesa em profundidade.

13. **Tamanho do `instalar_spicetify.sh` (~290L)**: acima dos demais
    scripts do projeto (média ~120L), mas justificado por replicar
    277L do Spellbook + dry-run guards. Não há simplificação trivial
    que mantenha paridade de configuração (CLAUDE.md §2: simplicidade
    é mínimo necessário, não menos).

---

## Não-objetivos (fora de escopo)

- **Refatorar `spicetify-setup.sh` do Spellbook-OS** — fora deste repo.
- **Suporte a Spotify AppImage** — não há demanda; nem o Spellbook
  cobre.
- **Suporte a YouTube Music, Apple Music, Tidal** — fora do escopo
  (sprint focada em Spotify).
- **GUI para gerenciar temas Spicetify** — over-engineering.
- **Sincronização de playlists ou estado de login** — não é responsabilidade
  do tema.
- **Wrapper genérico para outros app-themes** — cada app-theme é
  autocontido (Obsidian, Telegram, Discord etc. já são).
- **`spicetify upgrade` (atualizar binário)** — pode quebrar custom
  apps; fora.
- **Alteração de `scripts/atualizar_spicetify.sh`** — ortogonal, SPRINT 17.
- **Alteração de `_resolver_spicetify_mismatch` ou
  `_detectar_spotify_flatpak` em `lib/common.sh`** — ortogonal.
- **Cobertura de Spicetify em `scripts/diagnostico.sh`** — registrado
  como achado A1 da SPRINT 17; fica para sprint futura.
- **Hook automático de `flatpak update` para chamar
  `atualizar_spicetify.sh --auto-fix`** — descartado na SPRINT 17 por
  ser custoso (~150 MB) e mata Spotify em uso.
- **Migrar mensagens para catálogo i18n** — over-engineering.
- **CI específico testando Spicetify** — Spicetify exige Spotify;
  inviável em CI sem extensa mockagem.

---

## Achados colaterais (registrados; NÃO implementar nesta sprint)

### A1 — `scripts/diagnostico.sh` continua sem cobrir Spicetify

Já registrado na SPRINT 17 (achado A1 daquela sprint). Aplicável
também aqui: o diagnóstico não verifica se Spicetify está aplicado,
nem se o tema atual é `Sleek + Dracula`. Sugestão para sprint futura:
adicionar bloco em `diagnostico.sh` com 3 checks read-only equivalentes
ao `validar()` deste script. Custo/benefício baixo.

### A2 — `_buscar_spicetify_setup` mantém paths legados

Após esta sprint, o branch fallback usa `_buscar_spicetify_setup`. Os
4 paths legados (`$REPO/../Spellbook-OS/...`, etc.) continuam relevantes
para o branch fallback. **Sem ação.**

### A3 — Lista de extensions/custom_apps embutida em duas fontes

`Dracula_OS-Theme/scripts/instalar_spicetify.sh` (após esta sprint) e
`Spellbook-OS/scripts/spicetify-setup.sh` carregam a mesma lista. Em
caso de mudança futura, ambas precisam ser atualizadas. Sugestão:
extrair para `app-themes/spicetify/config.env` e source-ar nos dois.
Não fazer agora — over-engineering para um único ponto de divergência
hipotético.

### A4 — `spicetify` no PATH global vs `~/.spicetify/spicetify`

Algumas distros podem ter `spicetify` instalado via package manager em
`/usr/bin/spicetify`, divergente do `~/.spicetify/spicetify` que o
instalador oficial usa. O script local prioriza o `$HOME/.spicetify/`
(igual ao Spellbook) e ignora um eventual `/usr/bin/spicetify`.
Aceitável: o instalador oficial do Spicetify CLI cria
`~/.spicetify/spicetify` diretamente, e quem usa o packaged tipicamente
não roda este script.

### A5 — `app-themes/spicetify/` poderia ter `themes-pinned.txt` para versionar tema

O `git clone --depth=1` pega a master atual de `spicetify-themes`. Se
um tema "Sleek" mudar drasticamente, o usuário pega a nova versão. Para
estabilidade absoluta, pinar via tag/commit. Custo: manter o pin
atualizado periodicamente. **Sem ação** — Sleek é estável há anos.

### A6 — `--apenas-detectar` poderia também imprimir versão do Spotify

Hoje só imprime tipo (`flatpak`/`snap`/`nativo`/`nenhum`). Versão exigiria
parsing de `flatpak info`/`snap info`/`apt show` etc. Over-engineering;
não há consumidor.

---

## Referências

- `CLAUDE.md` global e local — §1 (pense antes), §2 (simplicidade), §3
  (cirúrgico), §4 (objetivos verificáveis).
- `docs/sprints/SPRINT_07_PORTABILIDADE.md` — estabelece padrões de
  busca multi-path (precedente para `_buscar_spicetify_setup`).
- `docs/sprints/SPRINT_08_SEGURANCA_ROBUSTEZ.md` — `validar_path_destrutivo`
  e allowlist; padrões usados em `desinstalar_spicetify.sh --full`.
- `docs/sprints/SPRINT_13_STEAM_ICONS.md` — precedente direto: padrão
  `instalar_<algo>.sh` autocontido + `DRACULA_DRY_RUN`.
- `docs/sprints/SPRINT_15_HOUSEKEEPING.md` — refatoração de
  `_purgar_antigos` (não tocada nesta sprint, mas referência de
  estilo).
- `docs/sprints/SPRINT_17_COBERTURA_GAPS.md` — sprint imediatamente
  anterior; estabelece (a) `atualizar_spicetify.sh` como autocontido
  (ortogonal a esta sprint), (b) helpers Spicetify em `lib/common.sh`
  (intocados aqui), (c) seção "Dependências externas" no README
  (reescrita aqui), (d) decisão consciente de boundary (revertida
  aqui de "obrigatório" para "opcional").
- `~/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh:1-277` —
  origem da replicação. Mapping linha-por-linha registrado neste spec.
- `scripts/instalar_app_themes.sh:96-133` — função reescrita; preserva
  `_buscar_spicetify_setup` como utilitária do branch fallback.
- `scripts/lib/common.sh:69-86` — allowlist destrutiva; estendida com
  2 entradas Spicetify nesta sprint.
- `scripts/atualizar_spicetify.sh:1-91` (SPRINT 17) — **ortogonal**;
  cobre recuperação pós-update, não instalação inicial. **Não tocado**.
- `CHANGELOG.md` `[Unreleased]` `### Adicionado` — entrada SPRINT 17
  (precedente imediato de estilo).

*"Quem corta o cordão umbilical aprende a respirar sozinho." — adágio
do `xpui.spa` revisitado, SPRINT 18.*
