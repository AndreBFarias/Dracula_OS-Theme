# Sprint 17 — Cobertura de gaps: wallpapers, Spicetify pós-update, dependências externas

Sprint de cobertura ampla derivada de auditoria pós-ciclo SPRINT 10–16 + auditoria
de cobertura completa do `install.sh`/`reaplicar_tema.sh` em `2026-05-07`. Quatro
gaps foram validados (3 implementáveis + 1 decisão consciente de não-implementar).
Todos os 4 abordados nesta sprint sob o mesmo guarda-chuva, sem cruzamento de
áreas problemático: cada gap toca subscripts independentes e/ou docs.

> **Substitui** o spec anterior (`SPRINT_17_SPICETIFY_RESILIENCIA.md`), que
> cobria apenas o gap Spicetify. Aquele arquivo passa a ser histórico — esta
> sprint o engloba e estende com 3 gaps adicionais.

---

## Gaps validados (1 spec, 4 gaps)

| # | Gap                                              | Status decisão       | Solução                                                     |
|---|--------------------------------------------------|----------------------|-------------------------------------------------------------|
| 1 | Wallpapers órfãos em `assets/wallpapers/`        | Implementar          | Novo `instalar_wallpapers.sh` + `desinstalar_wallpapers.sh` |
| 5 | Spicetify dessincroniza após `flatpak update`    | Implementar          | Novo `atualizar_spicetify.sh` (default avisa, `--auto-fix` resolve) |
| 6 | Dependência Spellbook-OS para Spicetify não documentada | Implementar     | Atualizar `README.md`, `docs/index.html`, `app-themes/spicetify/README.md` |
| 3 | Logo `assets/logo.png` poderia virar pixmap      | **Não implementar**  | Decisão consciente: doc-only basta. Registrar como decisão. |

> **Não confundir numeração**: os IDs 1/3/5/6 vêm da auditoria viva. A SPRINT 17 é
> uma só. SPRINT 18 dedicada cobrirá Spicetify autônomo (sem Spellbook-OS) — gap
> 4 da auditoria, fora desta sprint.

---

## Decisões fixas (não reabrir)

- **Numeração**: SPRINT 17. `INDEX.md` linha 25 (após SPRINT 16).
- **Mudanças cirúrgicas** (CLAUDE.md §3): não tocar código adjacente nem reformatar.
- **Acentuação pt-BR íntegra** em logs, comentários e docs (`não`, `instalação`,
  `aplicação`, `função`, `configuração`, `atualização`, `reaplicação`, `reinstalação`).
- **Sem sudo. MODO=user.** Toda a árvore mexida vive em `~/.local/share/`,
  `~/.var/app/`, `~/.spicetify/`.
- **Wallpapers**: instala em `~/.local/share/backgrounds/dracula/` mas **não troca**
  o wallpaper atual. Trocar é opt-in via `--apply <nome>`.
- **Spicetify auto-fix**: opt-in via `--auto-fix` ou `DRACULA_SPOTIFY_AUTOFIX=1`.
  Default: detecta, loga sugestão, exit 0 não-fatal. Justificativa: `flatpak install
  --reinstall` baixa ~150 MB e mata Spotify em uso — destrutivo do ponto de vista
  do usuário.
- **Logo**: decisão consciente de **não** instalar em pixmaps. Hoje é doc-only e
  está OK; adicionar pixmap seria polish sem demanda real (CLAUDE.md §2).
- **Boundary Spellbook-OS preservado**: `aplicar_spicetify` em
  `instalar_app_themes.sh:115-129` continua delegando ao `spicetify-setup.sh` do
  Spellbook. Esta sprint complementa, não substitui.
- **`install.sh` flag**: wallpapers integram a `--user` (sem flag nova). Justificativa:
  são parte do branding visual leve (~2.5 MB) e não fazem mudança de configuração
  do usuário (não trocam wallpaper atual).
- **`reaplicar_tema.sh`**: ganha apenas seção 7.6 (Spicetify). Wallpapers **não**
  vão para o reaplicador — são user files, não regridem em `apt upgrade`.
- **`uninstall.sh`**: chama `desinstalar_wallpapers.sh` (não-fatal).

---

## Contexto e validação

### Gap 1 — Wallpapers órfãos (CONFIRMADO)

`assets/wallpapers/` contém:

| Arquivo                | Tamanho | Origem                                    |
|------------------------|---------|-------------------------------------------|
| `dracula-base.png`     | 340 KB  | Oficial `dracula/wallpaper`               |
| `dracula-os-default.png` | 2.2 MB | Gerado em desenvolvimento (lua + morcegos) |

Nenhum script copia/instala. O usuário aplicou manualmente via `gsettings set
org.gnome.desktop.background picture-uri ...`. Em outra máquina, ficaria sem o
wallpaper sem saber que existe. **Gap de empacotamento**.

### Gap 5 — Spicetify resiliência pós `flatpak update` (CONFIRMADO em primeira mão)

Vivenciado em `2026-05-07`: `flatpak update` atualizou `com.spotify.Client` para
1.2.84.475. `~/.spicetify/spicetify apply` retornou:

```
warning Spotify version and backup version are mismatched.
info Spotify cannot be backed up at this state.
Please re-install Spotify then run "spicetify backup apply"
```

E o Theme Dev Tools dentro do Spotify mostrou `Class name list not found` e
`No marketplace theme installed`.

**Resolução manual** exigiu 4 passos sequenciais (não-óbvios):

1. `pgrep -f spotify | xargs -r kill -9` (libera o `xpui.spa` em uso).
2. `rm -rf ~/.var/app/com.spotify.Client/cache/*` (495 MB no caso real).
3. `flatpak install --reinstall --noninteractive flathub com.spotify.Client`
   (re-extração limpa do bundle; ~150 MB download).
4. `spicetify apply` (não `backup apply` — após reinstall, o `apply` re-cria o
   backup automaticamente).

O passo 2 já está parcialmente coberto pelo `spicetify-setup.sh` do Spellbook
(linhas 195–199); o passo 3 é a lacuna que esta sprint fecha.

### Gap 6 — Dependência externa não documentada (CONFIRMADO)

`scripts/instalar_app_themes.sh:115-133` (função `aplicar_spicetify()`) delega
para `spicetify-setup.sh` do Spellbook-OS, busca em 4 paths conhecidos. Se não
encontra → `_warn` silencioso. **Não está documentado** no `README.md` nem em
`docs/index.html`. Usuário em outra máquina sem Spellbook-OS ficaria sem
Spicetify e sem mensagem clara.

### Gap 3 — Logo (decisão consciente)

`assets/logo.png` (60 KB) é a marca do projeto. Hoje só usado em `README.md` e
`docs/assets/logo.png`. Caminhos avaliados:

- (a) Deixar como está (doc-only). **Escolhido.** Sem demanda real, é polish.
- (b) Instalar em `~/.local/share/pixmaps/dracula-os-theme.png`. **Descartado.**
  Nenhum app referencia esse pixmap; criaria entrada órfã no XDG.

Esta sprint registra a decisão (a) explicitamente para que futuras auditorias não
re-questionem. Não há mudança de código.

---

## Escopo (touches autorizados)

### Arquivos a criar

- `scripts/instalar_wallpapers.sh` — copia `assets/wallpapers/*.png` para
  `~/.local/share/backgrounds/dracula/`. Idempotente. Suporta `--apply <nome>` e
  `DRACULA_DRY_RUN=1`.
- `scripts/desinstalar_wallpapers.sh` — remove `~/.local/share/backgrounds/dracula/`
  com `validar_path_destrutivo`.
- `scripts/atualizar_spicetify.sh` — detector + auto-fixer opt-in (idêntico ao
  spec anterior; reproduzido aqui).
- `docs/sprints/SPRINT_17_COBERTURA_GAPS.md` — este documento.

### Arquivos a modificar

- `scripts/lib/common.sh` — adicionar 2 helpers Spicetify (`_detectar_spotify_flatpak`,
  `_resolver_spicetify_mismatch`) **e** estender allowlist destrutiva com 2 entradas
  (`~/.var/app/com.spotify.Client/cache` e `~/.local/share/backgrounds/dracula`).
- `scripts/reaplicar_tema.sh` — adicionar seção 7.6 (entre 7.5 Steam e 7.7
  keybindings) chamando `atualizar_spicetify.sh` sem `--auto-fix` (default seguro).
- `install.sh` — adicionar 1 chamada não-fatal a `instalar_wallpapers.sh` na fase
  `--user` (entre seção "Ícones de jogos Steam" e "Temas GTK/Shell"). Sem flag nova.
- `uninstall.sh` — adicionar 1 chamada não-fatal a `desinstalar_wallpapers.sh`
  (depois das remoções de pop-shell/sons).
- `README.md` — atualizar:
  - Seção `### Componentes instalados` (linha 136): adicionar bloco wallpapers.
  - Seção `### Troubleshooting` (linha 261): substituir o bloco "Spicetify
    reclama de versão mismatched" (linhas 293-297) pelo one-liner novo +
    documentação da dependência Spellbook-OS.
  - Adicionar nova seção `### Dependências externas` (após Componentes
    instalados, antes de Arquitetura) explicitando Spellbook-OS para Spicetify.
- `docs/index.html` — atualizar:
  - Card "App themes integrados" (linhas 59-62): adicionar nota sobre
    dependência Spellbook-OS.
- `app-themes/spicetify/README.md` — adicionar seção `## Troubleshooting` ao
  final do arquivo com one-liner exato e equivalente manual.
- `docs/sprints/INDEX.md` — adicionar linha SPRINT 17.
- `CHANGELOG.md` — entrada `[Unreleased]` `### Adicionado`.

### Arquivos NÃO tocar

- `scripts/instalar_app_themes.sh` — `aplicar_spicetify` (linhas 115–129) já
  delega ao Spellbook e captura erro com `_warn`. **Não modificar**.
- `~/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh` — fora do repo.
  Boundary preservado.
- `assets/wallpapers/*.png` — assets imutáveis.
- `assets/logo.png` — decisão consciente de não instalar (Gap 3).
- `build.sh`, `scripts/diagnostico.sh` — fora do escopo.
- Logger pattern (`_info`, `_ok`, `_warn`, `_err`, `_dim`) — usar como existente.
- Resto da allowlist destrutiva — apenas estender com as 2 entradas novas, sem
  generalizar (`~/.var/app` ou `~/.local/share/backgrounds` inteiros seriam
  amplos demais e abririam vetor lateral).

---

## Decisões de design abertas — resolvidas pelo planejador

1. **Nome do spec**: `SPRINT_17_COBERTURA_GAPS.md`. Reflete o escopo amplo
   (4 gaps cobertos sob a mesma sprint). O arquivo anterior
   `SPRINT_17_SPICETIFY_RESILIENCIA.md` é **substituído** (renomeado durante
   a execução, manter histórico via git mv).

2. **Flag de install para wallpapers**: integrar a `--user` (sem flag nova).
   Justificativa: (a) wallpapers são leves (~2.5 MB total); (b) são parte do
   branding visual; (c) **não trocam** o wallpaper atual — apenas disponibilizam
   no XDG; (d) coerente com como `atualizar_icones_steam.sh` é chamado no fim
   da fase `--user` sem flag dedicada (precedente SPRINT 13).

3. **`reaplicar_tema.sh` chama `instalar_wallpapers.sh`?**: **Não**. Wallpapers
   são user files em `~/.local/share/backgrounds/dracula/`; não regridem em
   `apt upgrade` nem em `flatpak update`. Adicionar ao reaplicador seria custo
   sem benefício.

4. **Posição do `instalar_wallpapers.sh` no `install.sh`**: depois da seção
   "Ícones de jogos Steam" (linha 117) e antes de "Temas GTK/Shell" (linha 119).
   Mantém a fase user contígua.

5. **`--apply <nome>` no `instalar_wallpapers.sh`**: opção, **não default**. Se
   passada, executa `gsettings set org.gnome.desktop.background picture-uri
   "file://..."` para o nome dado. Sem `--apply`, o script apenas copia.

6. **`reaplicar_tema.sh` passa `--auto-fix` para Spicetify?**: **Não**. Default
   seguro (mesmo motivo do spec original): `flatpak install --reinstall` baixa
   ~150 MB; mata Spotify em uso; usuário pode estar com música tocando.

7. **Detecção de "version mismatch"**: AND lógico entre exit code != 0 **E**
   grep no stdout/stderr pelo padrão fixo `version and backup version are
   mismatched`. Outros erros caem no warn genérico.

8. **Documentação de dependência**: adicionar em **três** lugares — `README.md`
   (nova seção `### Dependências externas`), `docs/index.html` (nota dentro do
   card "App themes integrados"), `app-themes/spicetify/README.md` (seção
   Troubleshooting com one-liner). Não duplicar texto: cada lugar tem ângulo
   diferente (instalação geral, vitrine, troubleshooting específico).

9. **Allowlist destrutiva**: adicionar **duas** entradas:
   - `~/.var/app/com.spotify.Client/cache` (para o `rm -rf cache/*` do auto-fix).
   - `~/.local/share/backgrounds/dracula` (para o `desinstalar_wallpapers.sh`).
   Não generalizar para `~/.var/app` ou `~/.local/share/backgrounds` inteiros.

10. **Estado "bom" do Spicetify**: `spicetify apply` exit 0 + stdout sem
    `mismatch`. Script é no-op silencioso com `_ok`.

11. **`DRACULA_DRY_RUN`**: imprime cada comando com prefixo `[dry-run]` sem
    executar. Suportado por todos os 3 scripts novos.

---

## Acceptance criteria

### Sintaxe e source

1. `bash -n scripts/instalar_wallpapers.sh` — exit 0.
2. `bash -n scripts/desinstalar_wallpapers.sh` — exit 0.
3. `bash -n scripts/atualizar_spicetify.sh` — exit 0.
4. `bash -n scripts/lib/common.sh` — exit 0.
5. `bash -n scripts/reaplicar_tema.sh` — exit 0.
6. `bash -n install.sh && bash -n uninstall.sh` — exit 0.
7. `( source scripts/lib/common.sh && declare -F _detectar_spotify_flatpak
   _resolver_spicetify_mismatch )` — imprime ambas as funções.
8. `shellcheck --severity=warning` em todos os arquivos modificados/criados —
   sem warnings novos vs. baseline.

### Wallpapers (Gap 1)

9. `bash scripts/instalar_wallpapers.sh` cria
   `~/.local/share/backgrounds/dracula/dracula-base.png` e
   `~/.local/share/backgrounds/dracula/dracula-os-default.png` (cópias byte-a-byte
   das fontes em `assets/wallpapers/`).
10. **Idempotência**: 2ª execução não muda mtime dos PNGs no destino (uso de
    `cmp -s` antes de copiar).
11. `bash scripts/instalar_wallpapers.sh` **não** muda a chave
    `org.gnome.desktop.background picture-uri` (sem `--apply`).
12. `bash scripts/instalar_wallpapers.sh --apply dracula-os-default` muda
    `picture-uri` para `file://$HOME/.local/share/backgrounds/dracula/dracula-os-default.png`.
13. `DRACULA_DRY_RUN=1 bash scripts/instalar_wallpapers.sh` imprime as cópias
    com prefixo `[dry-run]` e não escreve no destino.
14. `bash scripts/desinstalar_wallpapers.sh` remove
    `~/.local/share/backgrounds/dracula/` (com `validar_path_destrutivo` no caminho).
15. `bash scripts/desinstalar_wallpapers.sh` em ambiente sem o diretório:
    no-op silencioso, exit 0.

### Spicetify (Gap 5)

16. **Estado bom**: `bash scripts/atualizar_spicetify.sh` exit 0 com log
    `OK: spicetify aplicado / tema OK`. Sem `flatpak install`.
17. **Estado mismatch (default, sem `--auto-fix`)**: simulação via mock —
    exit 0 não-fatal, stdout/stderr contém `version mismatch detectado` e
    sugere `--auto-fix`.
18. **Estado mismatch + `--auto-fix`**: executa em ordem os 4 passos do roteiro,
    exit 0 ao final com log `OK: tema reaplicado após reinstall do Spotify`.
19. `DRACULA_DRY_RUN=1 bash scripts/atualizar_spicetify.sh --auto-fix` imprime
    os 4 comandos com prefixo `[dry-run]` e não executa.
20. **Sem `spicetify` no PATH**: exit 0, log `Spicetify não instalado, pulando`.
21. **Sem Spotify Flatpak instalado**: exit 0, log `Spotify (Flatpak) não detectado, pulando`.
22. `bash scripts/reaplicar_tema.sh` exit 0 com nova seção 7.6 imprimindo
    `Verificando Spicetify` e delegando para `atualizar_spicetify.sh`.

### Documentação (Gap 6)

23. `README.md` tem nova seção `### Dependências externas` listando
    Spellbook-OS para Spicetify e referenciando o caminho de busca em
    `instalar_app_themes.sh`.
24. `README.md` Troubleshooting "Spicetify reclama de versão mismatched"
    aponta para `bash scripts/atualizar_spicetify.sh --auto-fix` como
    one-liner primário, mantém referência ao Spellbook como fallback.
25. `docs/index.html` card "App themes integrados" tem nota explícita sobre
    Spicetify exigir Spellbook-OS (ou setup manual).
26. `app-themes/spicetify/README.md` tem seção `## Troubleshooting` com:
    - Sintoma textual (`Class name list not found`, `No marketplace theme installed`).
    - One-liner: `bash scripts/atualizar_spicetify.sh --auto-fix`.
    - Equivalente manual em 4 comandos.

### Logo (Gap 3)

27. **Sem mudança de código.** `assets/logo.png` permanece intocado. A decisão
    está documentada nesta sprint (seção "Gap 3 — Logo (decisão consciente)").

### Integração e regressão

28. `bash scripts/diagnostico.sh --quiet` exit 0 sem regressão.
29. `bash scripts/reaplicar_tema.sh` exit 0; logs em
    `~/.cache/dracula_os_theme/reaplicar_tema_*.log` continuam capados em ≤10
    (SPRINT 16, sem regressão).
30. **Acentuação**: varredura
    `grep -nE 'instalacao|aplicacao|deteccao|nao |execucao|funcao|configuracao|atualizacao|reaplicacao|reinstalacao'`
    em todos os arquivos modificados/criados retorna 0 hits relevantes.

---

## Invariantes a preservar

- `set -euo pipefail` nos 3 scripts novos (consistência com
  `atualizar_icones_steam.sh`).
- `set -uo pipefail` em `reaplicar_tema.sh` (linha 11) — não mudar; queremos
  seguir mesmo se uma seção falhar.
- Cada chamada nova em `install.sh`, `uninstall.sh` e `reaplicar_tema.sh` deve
  ser **não-fatal** (`|| _warn ...`).
- `_DRACULA_COMMON_SOURCED` guard em `lib/common.sh:11-12` — não duplicar.
- `validar_path_destrutivo` invocado antes de **todo** `rm -rf` desta sprint
  (são 2: cache do Spotify no `_resolver_spicetify_mismatch`, dir wallpapers no
  `desinstalar_wallpapers.sh`).
- Allowlist destrutiva: estender com **duas** entradas exatas, não generalizar.
- Logger pattern (`_info`, `_ok`, `_warn`, `_err`, `_dim`).
- Idempotência:
  - `instalar_wallpapers.sh`: cmp -s antes de copiar; mtime preservado em 2ª run.
  - `atualizar_spicetify.sh`: rodar N vezes em estado bom → sempre exit 0.
- Suporte a `DRACULA_DRY_RUN=1` em todos os 3 scripts novos.
- Sem sudo. Sem `requires-root`. MODO=user.
- CLAUDE.md §2 (simplicidade): scripts lineares, ~120 linhas cada.
- CLAUDE.md §3 (cirúrgico): não reformatar nada adjacente.
- Boundary externo preservado: `aplicar_spicetify` em `instalar_app_themes.sh`
  continua chamando `spicetify-setup.sh` do Spellbook-OS sem alteração.

---

## Plano de implementação

> Ordem proposta: Passo 1 (lib) → Passo 2 (atualizar_spicetify) → Passo 3
> (instalar/desinstalar_wallpapers) → Passo 4 (install/uninstall/reaplicar) →
> Passo 5 (docs) → Passo 6 (sprint/changelog/index). Cada passo é commitável
> isoladamente; recomenda-se commit único final por simplicidade.

### Passo 1 — `scripts/lib/common.sh` — allowlist + 2 helpers

**Edit cirúrgico A**: adicionar **duas** linhas à allowlist destrutiva, após
`~/.cache/dracula_os_backup` (linha 78) e antes de `/usr/share/icons` (linha 79):

```bash
    "$HOME/.var/app/com.spotify.Client/cache"
    "$HOME/.local/share/backgrounds/dracula"
```

**Edit cirúrgico B**: adicionar dois helpers ao final do arquivo, após
`_purgar_backups_antigos` (linha 198), antes do epígrafe `# "Nosce te ipsum."`
(linha 200):

```bash
# ─── Spicetify / Spotify Flatpak (SPRINT 17) ───
# Retorna 0 se com.spotify.Client está instalado via Flatpak (user OU system).
# Retorna 1 caso contrário. Sem stdout (silencioso).
_detectar_spotify_flatpak() {
    command -v flatpak >/dev/null 2>&1 || return 1
    flatpak list --app --columns=application 2>/dev/null \
        | grep -qx "com.spotify.Client"
}

# Resolve o estado "Spotify version and backup version are mismatched" do
# Spicetify executando, em ordem: kill do Spotify -> limpeza do cache web do
# Flatpak -> reinstall do bundle Flatpak -> spicetify apply. Não-fatal: cada
# passo loga _warn em falha mas não aborta o roteiro. Respeita
# DRACULA_DRY_RUN=1 (imprime os 4 comandos com prefixo [dry-run] e retorna 0).
#
# Pré-requisitos: caller já confirmou que (a) spicetify está instalado,
# (b) Spotify Flatpak está instalado, (c) o sintoma de mismatch foi detectado.
_resolver_spicetify_mismatch() {
    local spicetify_bin="${1:-$HOME/.spicetify/spicetify}"
    local cache_dir="$HOME/.var/app/com.spotify.Client/cache"
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] pgrep -f spotify | xargs -r kill -9"
        _dim "[dry-run] rm -rf -- ${cache_dir}/*"
        _dim "[dry-run] flatpak install --reinstall --noninteractive flathub com.spotify.Client"
        _dim "[dry-run] $spicetify_bin apply"
        return 0
    fi
    _info "Encerrando processos do Spotify (se houver)"
    pgrep -f spotify | xargs -r kill -9 2>/dev/null || true
    if [[ -d "$cache_dir" ]]; then
        if validar_path_destrutivo "$cache_dir" >/dev/null 2>&1; then
            _info "Limpando cache do Spotify Flatpak"
            rm -rf -- "${cache_dir:?}"/* 2>/dev/null || _warn "rm cache do Spotify falhou"
        else
            _warn "Cache do Spotify fora da allowlist; pulando"
        fi
    fi
    _info "Reinstalando bundle Flatpak (download ~150 MB)"
    flatpak install --reinstall --noninteractive flathub com.spotify.Client \
        || { _err "flatpak install --reinstall falhou"; return 1; }
    _info "Reaplicando Spicetify"
    "$spicetify_bin" apply || { _err "spicetify apply falhou após reinstall"; return 1; }
    return 0
}
```

### Passo 2 — `scripts/atualizar_spicetify.sh` (NOVO)

Esqueleto linear, ~115 linhas (idêntico ao spec anterior, reproduzido para
auto-suficiência deste documento):

```bash
#!/usr/bin/env bash
# atualizar_spicetify.sh — detecta dessincronia Spicetify x Spotify Flatpak
# após `flatpak update` e (opcionalmente) resolve. Idempotente. Sem sudo.
#
# Modo padrão: detecta, loga sugestão, exit 0 não-fatal.
# Modo --auto-fix (ou env DRACULA_SPOTIFY_AUTOFIX=1): executa o roteiro
# completo (kill Spotify -> limpa cache -> flatpak --reinstall -> apply).
#
# DRACULA_DRY_RUN=1: imprime comandos sem executar.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

AUTO_FIX=0
[[ "${DRACULA_SPOTIFY_AUTOFIX:-0}" == "1" ]] && AUTO_FIX=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto-fix) AUTO_FIX=1; shift ;;
        --help|-h)
            cat <<'EOF'
Uso: atualizar_spicetify.sh [--auto-fix]

Detecta o estado "Spotify version and backup version are mismatched" do
Spicetify após `flatpak update`. Sem flag, apenas sugere o fix. Com
--auto-fix (ou DRACULA_SPOTIFY_AUTOFIX=1), executa kill+cache+reinstall+apply.

Variáveis:
  DRACULA_DRY_RUN=1         imprime comandos sem executar
  DRACULA_SPOTIFY_AUTOFIX=1 equivalente a --auto-fix
EOF
            exit 0 ;;
        *) _warn "Argumento ignorado: $1"; shift ;;
    esac
done

SPICETIFY_BIN="$HOME/.spicetify/spicetify"

if [[ ! -x "$SPICETIFY_BIN" ]] && ! command -v spicetify >/dev/null 2>&1; then
    _info "Spicetify não instalado, pulando"
    exit 0
fi
[[ -x "$SPICETIFY_BIN" ]] || SPICETIFY_BIN="$(command -v spicetify)"

if ! _detectar_spotify_flatpak; then
    _info "Spotify (Flatpak) não detectado, pulando"
    exit 0
fi

_info "Verificando estado do Spicetify (spicetify apply)"
saida=""
status=0
if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
    _dim "[dry-run] $SPICETIFY_BIN apply"
else
    saida="$("$SPICETIFY_BIN" apply 2>&1)" || status=$?
fi

if [[ $status -ne 0 ]] && echo "$saida" | grep -q "version and backup version are mismatched"; then
    _warn "Spicetify reporta version mismatch (Spotify foi atualizado)"
    if [[ $AUTO_FIX -eq 1 ]]; then
        _info "AUTO-FIX ativo: vou matar Spotify, limpar cache, reinstalar Flatpak e reaplicar"
        if _resolver_spicetify_mismatch "$SPICETIFY_BIN"; then
            _ok "Tema reaplicado após reinstall do Spotify"
            exit 0
        else
            _err "Auto-fix falhou; rode os passos manualmente (ver app-themes/spicetify/README.md#troubleshooting)"
            exit 0
        fi
    else
        _warn "Para resolver: rode 'bash scripts/atualizar_spicetify.sh --auto-fix'"
        _warn "ou exporte DRACULA_SPOTIFY_AUTOFIX=1 antes do reaplicar_tema.sh."
        exit 0
    fi
elif [[ $status -ne 0 ]]; then
    _warn "spicetify apply retornou $status (não é mismatch — verifique manualmente)"
    echo "$saida" | head -20 >&2
    exit 0
fi

_ok "spicetify aplicado / tema OK"
exit 0
```

### Passo 3 — `scripts/instalar_wallpapers.sh` (NOVO)

Esqueleto linear, ~90 linhas:

```bash
#!/usr/bin/env bash
# instalar_wallpapers.sh — copia wallpapers Dracula para
# ~/.local/share/backgrounds/dracula/. NÃO troca o wallpaper atual a menos
# que `--apply <nome>` seja passado.
#
# Idempotente (cmp -s antes de copiar). Sem sudo.
#
# Variáveis:
#   DRACULA_DRY_RUN=1   imprime cópias com prefixo [dry-run] e não executa.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
REPO_ROOT="$(_repo_root "${BASH_SOURCE[0]}")"

ORIGEM="$REPO_ROOT/assets/wallpapers"
DESTINO="$HOME/.local/share/backgrounds/dracula"
APPLY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply) APPLY="${2:-}"; shift 2 ;;
        --help|-h)
            cat <<'EOF'
Uso: instalar_wallpapers.sh [--apply <nome>]

Copia assets/wallpapers/*.png para ~/.local/share/backgrounds/dracula/
(idempotente). Com --apply <nome>, troca o wallpaper atual via gsettings.

Variáveis:
  DRACULA_DRY_RUN=1   apenas loga, não executa.
EOF
            exit 0 ;;
        *) _warn "Argumento ignorado: $1"; shift ;;
    esac
done

if [[ ! -d "$ORIGEM" ]]; then
    _err "Origem não encontrada: $ORIGEM"
    exit 1
fi

if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
    _dim "[dry-run] mkdir -p $DESTINO"
else
    mkdir -p "$DESTINO"
fi

shopt -s nullglob
copiados=0
for src in "$ORIGEM"/*.png; do
    nome="$(basename "$src")"
    dst="$DESTINO/$nome"
    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        _dim "= $nome (já idêntico)"
        continue
    fi
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] cp $src $dst"
    else
        cp -f "$src" "$dst" && _ok "copiado: $nome"
        copiados=$((copiados+1))
    fi
done
shopt -u nullglob

_info "Wallpapers em $DESTINO: $(ls -1 "$DESTINO"/*.png 2>/dev/null | wc -l)"

if [[ -n "$APPLY" ]]; then
    alvo="$DESTINO/$APPLY"
    [[ "$APPLY" != *.png ]] && alvo="${alvo}.png"
    if [[ ! -f "$alvo" ]]; then
        _err "--apply: arquivo não encontrado: $alvo"
        exit 1
    fi
    if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
        _dim "[dry-run] gsettings set org.gnome.desktop.background picture-uri file://$alvo"
        _dim "[dry-run] gsettings set org.gnome.desktop.background picture-uri-dark file://$alvo"
    else
        gsettings set org.gnome.desktop.background picture-uri "file://$alvo" \
            && _ok "picture-uri = $alvo" || _warn "Falha ao setar picture-uri"
        gsettings set org.gnome.desktop.background picture-uri-dark "file://$alvo" \
            && _ok "picture-uri-dark = $alvo" || _warn "Falha ao setar picture-uri-dark"
    fi
fi

exit 0
```

### Passo 4 — `scripts/desinstalar_wallpapers.sh` (NOVO)

Esqueleto curto, ~35 linhas:

```bash
#!/usr/bin/env bash
# desinstalar_wallpapers.sh — remove ~/.local/share/backgrounds/dracula/
# com validar_path_destrutivo. Não-fatal se diretório não existe.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DESTINO="$HOME/.local/share/backgrounds/dracula"

if [[ ! -d "$DESTINO" ]]; then
    _info "Wallpapers Dracula não instalados em $DESTINO; nada a remover"
    exit 0
fi

if ! validar_path_destrutivo "$DESTINO"; then
    _err "Pulando $DESTINO por segurança"
    exit 1
fi

if [[ "${DRACULA_DRY_RUN:-0}" == "1" ]]; then
    _dim "[dry-run] rm -rf -- $DESTINO"
else
    rm -rf -- "$DESTINO" && _ok "removido: $DESTINO"
fi

exit 0
```

### Passo 5 — `scripts/reaplicar_tema.sh` — seção 7.6 (Spicetify apenas)

**Inserir** entre a atual seção 7.5 (linha 98, fim de `atualizar_icones_steam.sh`)
e a 7.7 (linha 100, início de keybindings):

```bash
# ─── 7.6 Spicetify / Spotify Flatpak (SPRINT 17) ───
# Detecta dessincronia pós flatpak update. Default: avisa.
# Para auto-fix: rode 'bash scripts/atualizar_spicetify.sh --auto-fix' manualmente.
_info "Verificando Spicetify"
"$REPO_ROOT/scripts/atualizar_spicetify.sh" || _warn "atualizar_spicetify.sh falhou (não-fatal)"
```

(5 linhas + linha em branco antes da próxima seção. Wallpapers **não** entram
aqui — são user files que não regridem em apt upgrade.)

### Passo 6 — `install.sh` — chamada de wallpapers

**Inserir** entre a seção "Ícones de jogos Steam" (linha 117 atual) e "Temas
GTK/Shell" (linha 119 atual):

```bash
# ─── Wallpapers Dracula (não-fatal; user-only) ───
if [[ "$MODO" == "user" ]]; then
    _info "Instalando wallpapers Dracula (não-fatal)"
    "$REPO_ROOT/scripts/instalar_wallpapers.sh" || _warn "instalar_wallpapers.sh falhou (não-fatal)"
fi
```

(5 linhas + linha em branco. Pattern idêntico ao `atualizar_icones_steam.sh`
acima.)

### Passo 7 — `uninstall.sh` — chamada de desinstalar_wallpapers

**Adicionar** após a remoção do tema de som (linha 75 atual), antes do `echo
"Desinstalação concluída..."`:

```bash
# Reverter wallpapers Dracula (se instalados)
if [[ -d "$HOME/.local/share/backgrounds/dracula" ]]; then
    echo "Removendo wallpapers Dracula..."
    "$REPO_ROOT/scripts/desinstalar_wallpapers.sh" || true
fi
```

(5 linhas + linha em branco.)

### Passo 8 — `app-themes/spicetify/README.md` — seção Troubleshooting

**Adicionar** após a atual seção "Por que não duplicar no Dracula_OS-Theme"
(linha 34, fim do arquivo):

````markdown

## Troubleshooting

### "Spotify version and backup version are mismatched"

Sintoma observado após `flatpak update` do `com.spotify.Client`:

```
warning Spotify version and backup version are mismatched.
info Spotify cannot be backed up at this state.
Please re-install Spotify then run "spicetify backup apply"
```

E no Theme Dev Tools dentro do Spotify:

```
Error: No marketplace theme installed
Error: Class name list not found; please create an issue
```

Resolução em uma linha:

```bash
bash scripts/atualizar_spicetify.sh --auto-fix
```

O script encerra processos do Spotify, limpa o cache do Flatpak em
`~/.var/app/com.spotify.Client/cache/`, executa
`flatpak install --reinstall --noninteractive flathub com.spotify.Client`
(download ~150 MB) e roda `spicetify apply`. Sem flag, o script apenas
avisa e sugere a flag.

### Equivalente manual

```bash
pgrep -f spotify | xargs -r kill -9
rm -rf ~/.var/app/com.spotify.Client/cache/*
flatpak install --reinstall --noninteractive flathub com.spotify.Client
~/.spicetify/spicetify apply
```

`spicetify apply` (não `backup apply`): após reinstall, o Spicetify
reconhece a versão limpa e re-cria o backup automaticamente.
````

> Atenção: o markdown acima usa fence externo de 4 backticks para envolver
> blocos de 3 backticks aninhados. Verificar com renderização local
> (`pandoc app-themes/spicetify/README.md -o /tmp/preview.html`).

### Passo 9 — `README.md` — Componentes, Dependências, Troubleshooting

**Edit A**: na seção `### Componentes instalados` (linha 136), adicionar
**após** a linha do tema GTK e **antes** do bloco "Com --pop-shell-css":

```
~/.local/share/backgrounds/dracula/             # wallpapers Dracula (não troca o atual)
```

**Edit B**: adicionar nova seção `### Dependências externas` **após** a seção
Componentes (linha 161, antes do `---` que precede "Arquitetura do repositório"):

```markdown

### Dependências externas

Alguns app-themes delegam a setups externos não embutidos neste repositório:

- **Spicetify** (Spotify Flatpak): a função `aplicar_spicetify` em
  `scripts/instalar_app_themes.sh` busca `spicetify-setup.sh` do
  [Spellbook-OS](https://github.com/AndreBFarias/Spellbook-OS) em quatro
  caminhos conhecidos (`$HOME/Desenvolvimento/Spellbook-OS/scripts/`,
  `$HOME/Spellbook-OS/scripts/`, `/opt/spellbook-os/scripts/`,
  `/usr/local/share/spellbook-os/scripts/`). Sem o Spellbook, o passo é
  pulado com warning. Alternativa: rodar manualmente o setup oficial do
  [Spicetify CLI](https://spicetify.app).

- Após `flatpak update`, o Spotify pode dessincronizar do Spicetify. Resolução:
  ```bash
  bash scripts/atualizar_spicetify.sh --auto-fix
  ```
  Detalhes em `app-themes/spicetify/README.md`.

---
```

**Edit C**: substituir o bloco "Spicetify reclama de versão mismatched" no
Troubleshooting (linhas 293-297 atuais):

```markdown
**Spicetify reclama de versão mismatched após `flatpak update`**

```bash
bash scripts/atualizar_spicetify.sh --auto-fix
```

O script mata o Spotify, limpa o cache em
`~/.var/app/com.spotify.Client/cache/`, reinstala o bundle Flatpak
(`flatpak install --reinstall`) e reaplica o tema. Sem flag, apenas avisa.
Como fallback, o setup completo do Spellbook-OS continua disponível em
`~/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh`.
```

### Passo 10 — `docs/index.html` — nota Spicetify no card

**Edit cirúrgico**: trocar a `<p>` interna do card "App themes integrados"
(linhas 60-62) por:

```html
            <p>Kitty, qBittorrent, GNOME Terminal (dconf), Spicetify/Spotify, Obsidian (itera vaults), Telegram, Discord (BetterDiscord/Vesktop/Vencord), OnlyOffice. <strong>Spicetify</strong> usa o setup do <a href="https://github.com/AndreBFarias/Spellbook-OS">Spellbook-OS</a>; recuperação pós <code>flatpak update</code> via <code>scripts/atualizar_spicetify.sh --auto-fix</code>.</p>
```

(Mantém estilo HTML adjacente: `<strong>`, `<a>`, `<code>` já usados em outros
cards. Sem refactor de CSS.)

### Passo 11 — `docs/sprints/INDEX.md`

**Adicionar** linha 25 nova após SPRINT 16:

```
| 17 | [Cobertura de gaps: wallpapers, Spicetify pós-update, dependências externas](SPRINT_17_COBERTURA_GAPS.md) | Em implementação | 2026-05-07 |
```

(Manter alinhamento da tabela; padding idêntico às linhas 22–24.)

### Passo 12 — `CHANGELOG.md`

Em `[Unreleased]` → `### Adicionado`, acrescentar como último item (após a
entrada SPRINT 16, linha 16 atual):

```
- **Sprint 17 — Cobertura de gaps (wallpapers, Spicetify pós-update, dependências externas)**: três entregas independentes sob a mesma sprint. (1) `scripts/instalar_wallpapers.sh` + `scripts/desinstalar_wallpapers.sh` instalam `assets/wallpapers/{dracula-base,dracula-os-default}.png` em `~/.local/share/backgrounds/dracula/` (idempotentes via `cmp -s`); por padrão **não trocam** o wallpaper atual, opção `--apply <nome>` aplica via `gsettings`. Integrados em `install.sh` (fase user, não-fatal) e `uninstall.sh`. Suporte a `DRACULA_DRY_RUN=1`. (2) `scripts/atualizar_spicetify.sh` detecta o estado `Spotify version and backup version are mismatched` que aparece quando `flatpak update` mexe em `com.spotify.Client` e dessincroniza o Spicetify. Default: avisa e sugere o fix. Com `--auto-fix` (ou `DRACULA_SPOTIFY_AUTOFIX=1`), executa o roteiro completo: encerra processos do Spotify, limpa cache em `~/.var/app/com.spotify.Client/cache/`, roda `flatpak install --reinstall --noninteractive flathub com.spotify.Client` e `spicetify apply`. Integrado em `scripts/reaplicar_tema.sh` (seção 7.6 nova, modo seguro sem auto-fix). Dois helpers novos em `scripts/lib/common.sh`: `_detectar_spotify_flatpak` e `_resolver_spicetify_mismatch`. Allowlist destrutiva estendida com `~/.var/app/com.spotify.Client/cache` e `~/.local/share/backgrounds/dracula`. (3) Documentação da dependência Spellbook-OS para Spicetify em três frentes: nova seção `### Dependências externas` no `README.md`, nota explícita no card "App themes integrados" de `docs/index.html`, e seção `## Troubleshooting` em `app-themes/spicetify/README.md` com one-liner e equivalente manual. Decisão consciente: `assets/logo.png` permanece doc-only (não vira pixmap; gap de polish sem demanda real). Boundary respeitado: o `spicetify-setup.sh` do Spellbook-OS continua sendo o orquestrador canônico de instalação; esta sprint cobre apenas recuperação pós-update.
```

---

## Aritmética

Sprint **adiciona** mais do que remove. Sem meta de redução. Faixas esperadas:

| Arquivo                                          | Antes (L) | Depois (L) | Delta              |
|--------------------------------------------------|-----------|------------|--------------------|
| `scripts/instalar_wallpapers.sh`                 | 0         | ~90        | criação            |
| `scripts/desinstalar_wallpapers.sh`              | 0         | ~35        | criação            |
| `scripts/atualizar_spicetify.sh`                 | 0         | ~115       | criação            |
| `scripts/lib/common.sh`                          | 200       | ~247       | +47 (allowlist +2, helpers +45) |
| `scripts/reaplicar_tema.sh`                      | 148       | ~153       | +5 (seção 7.6)     |
| `install.sh`                                     | 208       | ~213       | +5 (chamada wallpapers) |
| `uninstall.sh`                                   | 79        | ~84        | +5 (chamada desinstalar) |
| `app-themes/spicetify/README.md`                 | 34        | ~80        | +46 (Troubleshooting) |
| `README.md`                                      | 357       | ~390       | +33 (Componentes +1, Dependências +20, Troubleshooting reescrito ~12) |
| `docs/index.html`                                | 192       | 192        | 0 (edit in-place de uma `<p>`) |
| `docs/sprints/INDEX.md`                          | 44        | 45         | +1                 |
| `CHANGELOG.md`                                   | 200       | 201        | +1 linha em `### Adicionado` |
| `docs/sprints/SPRINT_17_COBERTURA_GAPS.md`       | 0         | novo       | criação            |

**Validação obrigatória antes do commit**:

- `wc -l scripts/instalar_wallpapers.sh` na faixa **80–105**.
- `wc -l scripts/desinstalar_wallpapers.sh` na faixa **30–45**.
- `wc -l scripts/atualizar_spicetify.sh` na faixa **100–135**.
- `wc -l scripts/lib/common.sh` na faixa **240–255**.
- `wc -l scripts/reaplicar_tema.sh` na faixa **151–158**.
- `wc -l install.sh` na faixa **211–218`.
- `wc -l uninstall.sh` na faixa **82–90**.
- `wc -l app-themes/spicetify/README.md` na faixa **75–90**.
- `wc -l README.md` na faixa **385–410**. Fora indica reformatação adjacente.

**Aritmética crítica (justificativa de uma das fronteiras)**:

`scripts/lib/common.sh`: `200 atual + 2 (allowlist) + 6 (`_detectar_spotify_flatpak` com comentário) + 32 (`_resolver_spicetify_mismatch` com comentário e dry-run) + 2 (separador) + 5 (linhas em branco) = 247`. Faixa **240–255** acomoda variação na quebra de linhas sem permitir refactor não solicitado.

---

## Testes / proof-of-work

### Sintaxe e source

```bash
for f in scripts/instalar_wallpapers.sh scripts/desinstalar_wallpapers.sh \
         scripts/atualizar_spicetify.sh scripts/lib/common.sh \
         scripts/reaplicar_tema.sh install.sh uninstall.sh; do
    bash -n "$f" && echo "OK $f"
done
( source scripts/lib/common.sh && declare -F _detectar_spotify_flatpak _resolver_spicetify_mismatch )
# esperado: ambas as funções declaradas
```

### Lint

```bash
shellcheck --severity=warning \
    scripts/instalar_wallpapers.sh \
    scripts/desinstalar_wallpapers.sh \
    scripts/atualizar_spicetify.sh \
    scripts/lib/common.sh \
    scripts/reaplicar_tema.sh \
    install.sh uninstall.sh
```

### Wallpapers

```bash
# Estado inicial
[[ -d ~/.local/share/backgrounds/dracula ]] && rm -rf ~/.local/share/backgrounds/dracula

# Instalação
bash scripts/instalar_wallpapers.sh
ls -la ~/.local/share/backgrounds/dracula/
# esperado: 2 PNGs com tamanho idêntico ao assets/wallpapers/

# Idempotência (mtime preservado)
mt1="$(stat -c %Y ~/.local/share/backgrounds/dracula/dracula-base.png)"
sleep 1
bash scripts/instalar_wallpapers.sh
mt2="$(stat -c %Y ~/.local/share/backgrounds/dracula/dracula-base.png)"
[[ "$mt1" == "$mt2" ]] && echo "idempotente OK" || echo "FALHA: mtime mudou"

# picture-uri NÃO mudou (sem --apply)
gsettings get org.gnome.desktop.background picture-uri

# Dry-run
DRACULA_DRY_RUN=1 bash scripts/instalar_wallpapers.sh
# esperado: prefixos [dry-run], sem cópia

# Apply
bash scripts/instalar_wallpapers.sh --apply dracula-os-default
gsettings get org.gnome.desktop.background picture-uri
# esperado: termina em dracula-os-default.png

# Desinstalação
bash scripts/desinstalar_wallpapers.sh
[[ ! -d ~/.local/share/backgrounds/dracula ]] && echo "removido OK"

# Desinstalação em ambiente sem o dir (no-op silencioso)
bash scripts/desinstalar_wallpapers.sh
echo "exit=$?"
```

### Spicetify — estado bom

```bash
~/.spicetify/spicetify apply   # garantir baseline limpo
bash scripts/atualizar_spicetify.sh
echo "exit=$?"
# esperado: exit 0; log "OK: spicetify aplicado / tema OK"
```

### Spicetify — sem spicetify no PATH

```bash
mv ~/.spicetify/spicetify ~/.spicetify/spicetify.bak
bash scripts/atualizar_spicetify.sh
echo "exit=$?"
# esperado: exit 0, log "Spicetify não instalado, pulando"
mv ~/.spicetify/spicetify.bak ~/.spicetify/spicetify
```

### Spicetify — estado mismatch (mock)

```bash
cat > /tmp/spicetify-mock.sh <<'EOF'
#!/usr/bin/env bash
echo "warning Spotify version and backup version are mismatched." >&2
exit 1
EOF
chmod +x /tmp/spicetify-mock.sh

mv ~/.spicetify/spicetify ~/.spicetify/spicetify.real
ln -s /tmp/spicetify-mock.sh ~/.spicetify/spicetify

# Default (sem auto-fix)
bash scripts/atualizar_spicetify.sh
echo "exit=$?"
# esperado: exit 0; saída contém "version mismatch" e "rode com --auto-fix"

# Dry-run + auto-fix
DRACULA_DRY_RUN=1 bash scripts/atualizar_spicetify.sh --auto-fix
# esperado: exit 0; 4 linhas [dry-run] (pgrep, rm -rf cache, flatpak install, apply)

# Limpeza
ln -snf ~/.spicetify/spicetify.real ~/.spicetify/spicetify
rm -f /tmp/spicetify-mock.sh
```

### Spicetify — auto-fix REAL (manual)

**Não automatizar**. Rodar manualmente quando o estado real de mismatch ocorrer
(custa ~150 MB download e mata Spotify). Critério: após o comando, abrir
Spotify, verificar tema Dracula carregado, marketplace funcional.

```bash
bash scripts/atualizar_spicetify.sh --auto-fix
# esperado: log das 4 etapas, exit 0, log "OK: tema reaplicado após reinstall do Spotify"
```

### Reaplicação completa

```bash
bash scripts/reaplicar_tema.sh
echo "exit=$?"
# esperado: exit 0; seção 7.6 imprime "Verificando Spicetify"
ls -1 ~/.cache/dracula_os_theme/reaplicar_tema_*.log | wc -l
# esperado: <= 10 (SPRINT 16)
```

### Diagnóstico (sem regressão)

```bash
bash scripts/diagnostico.sh --quiet
echo "exit=$?"
# esperado: exit 0
```

### Aritmética

```bash
wc -l scripts/instalar_wallpapers.sh        # esperado 80..105
wc -l scripts/desinstalar_wallpapers.sh     # esperado 30..45
wc -l scripts/atualizar_spicetify.sh        # esperado 100..135
wc -l scripts/lib/common.sh                 # esperado 240..255
wc -l scripts/reaplicar_tema.sh             # esperado 151..158
wc -l install.sh                            # esperado 211..218
wc -l uninstall.sh                          # esperado 82..90
wc -l app-themes/spicetify/README.md        # esperado 75..90
wc -l README.md                             # esperado 385..410
```

### Acentuação periférica

```bash
grep -nE 'instalacao|aplicacao|deteccao|nao |execucao|funcao|configuracao|atualizacao|reaplicacao|reinstalacao' \
    scripts/instalar_wallpapers.sh \
    scripts/desinstalar_wallpapers.sh \
    scripts/atualizar_spicetify.sh \
    scripts/lib/common.sh \
    scripts/reaplicar_tema.sh \
    install.sh uninstall.sh \
    app-themes/spicetify/README.md \
    README.md \
    docs/index.html \
    docs/sprints/SPRINT_17_COBERTURA_GAPS.md \
    docs/sprints/INDEX.md \
    CHANGELOG.md
# esperado: 0 hits relevantes (filtrar manualmente "nao" dentro de palavras)
```

### Hipótese verificada (lição 4)

Antes de iniciar, executor confirma identificadores via `rg`:

```bash
rg -n '_log_file|_repo_root|_purgar_antigos|validar_path_destrutivo|_allowlist_destrutiva' scripts/lib/common.sh
rg -n 'aplicar_spicetify|spicetify-setup' scripts/instalar_app_themes.sh
rg -n 'atualizar_icones_steam|7\.5|7\.7|DRACULA_DRY_RUN' scripts/atualizar_icones_steam.sh scripts/reaplicar_tema.sh
rg -n 'Componentes instalados|Troubleshooting|Spicetify reclama' README.md
rg -n 'App themes integrados|Spicetify/Spotify' docs/index.html
ls -la ~/.spicetify/spicetify
flatpak list --app --columns=application 2>/dev/null | grep -i spotify
ls -d ~/.var/app/com.spotify.Client/cache 2>/dev/null && du -sh ~/.var/app/com.spotify.Client/cache
ls -la assets/wallpapers/
```

Esperado: `_log_file:55`, `_repo_root:31`, `_purgar_antigos:172`,
`validar_path_destrutivo:86`, `_allowlist_destrutiva:69` em `lib/common.sh`.
`aplicar_spicetify:115`, `_buscar_spicetify_setup:96` em `instalar_app_themes.sh`.
`7.5` e `7.7` em `reaplicar_tema.sh`. `Componentes instalados:136`,
`Troubleshooting:261`, `Spicetify reclama de versão mismatched:293` em
`README.md`. `App themes integrados` no `index.html`. `~/.spicetify/spicetify`
executável. `com.spotify.Client` listado. `~/.var/app/com.spotify.Client/cache`
existe. `assets/wallpapers/` com 2 PNGs. **Tudo confirmado na exploração do planejador**.

---

## Riscos e mitigações

1. **`flatpak install --reinstall` requer rede e ~150 MB**. Sem rede, auto-fix
   falha; `_resolver_spicetify_mismatch` retorna 1 e o script loga `_err` mas
   mantém exit 0 no nível externo (contrato não-fatal). Aceitável.

2. **`pgrep -f spotify` pode pegar processos não relacionados**. Mitigação:
   padrão usado pelo próprio `spicetify-setup.sh` do Spellbook. Risco baixo no
   contexto desktop. Não tratar.

3. **Spotify rodando com música → kill -9 perde estado**. Por isso `--auto-fix`
   é opt-in. Documentado.

4. **`flatpak install --reinstall --noninteractive`** flag `--noninteractive`
   exige Flatpak ≥ 1.10. Pop!_OS 22.04 traz 1.12+ (baseline declarado em
   `SPRINT_07_PORTABILIDADE.md`). Em 20.04 antigo, erro explícito cai no
   `_warn`. Não tratar fallback automático.

5. **Em CI sem Flatpak**: `_detectar_spotify_flatpak` retorna 1 → script exit 0
   com `pulando`. CI passa.

6. **Spotify nativo (não-Flatpak)**: `_detectar_spotify_flatpak` retorna 1 →
   script pula. Trade-off explícito: usuário com Spotify nativo não é coberto.
   Fora de escopo (futura sprint se a demanda aparecer).

7. **Wallpapers do `--apply` em sessão sem GNOME**: `gsettings set
   org.gnome.desktop.background picture-uri` falha em desktops não-GNOME.
   Mitigação: `_warn` no falhão, exit 0 não-fatal.

8. **`picture-uri-dark` pode não existir em GNOME < 42**. Mitigação: o segundo
   `gsettings set` é tolerado com `|| _warn`, não-fatal.

9. **`spicetify apply` em estado bom toca mtime do `xpui.spa`**: invalida
   critério mtime estrito de idempotência **para Spicetify**. Aceitar — o
   critério prático é "exit 0 + sem warns novos", não mtime. Para wallpapers,
   mtime é estrito (cmp -s antes de copiar).

10. **Concorrência com APT hook chamando `reaplicar_tema.sh`**: APT hook
    segura lock dpkg; reaplicador roda serial. Mesmo argumento da SPRINT 16.
    Não tratar.

---

## Não-objetivos (fora de escopo)

- **Spicetify autônomo (sem Spellbook-OS)** — SPRINT 18 dedicada (gap 4 da
  auditoria).
- Hook nativo do Flatpak (avaliado e descartado: só dispara para apps
  system-wide; Spotify aqui é user-mode).
- systemd user timer / cron monitorando `flatpak update`.
- Cobertura de Spotify nativo (.deb), snap ou AppImage.
- Refactor do `spicetify-setup.sh` do Spellbook-OS.
- `spicetify upgrade` (atualizar a versão do binário Spicetify) — pode quebrar
  custom apps.
- Diagnóstico do estado Spicetify em `scripts/diagnostico.sh` (sprint futura).
- Cobertura de outros apps Flatpak (Discord-Vesktop, Chatterino, etc.).
- **Logo em `~/.local/share/pixmaps/`** — decisão consciente de não implementar
  (Gap 3, registrado como decisão).
- Validação anti-corrupção de keybindings (gap 7 da auditoria — baixa
  probabilidade, fora desta sprint).
- Trocar wallpaper atual no `install.sh --user --all` (default não-invasivo;
  apenas disponibilizar).
- UI de gerenciamento, dashboard, notificação desktop.
- Migrar mensagens de erro para um catálogo i18n.

---

## Achados colaterais (registrados; NÃO implementar nesta sprint)

### A1 — `scripts/diagnostico.sh` é silencioso sobre Spicetify e wallpapers

`diagnostico.sh --quiet` não verifica Spicetify nem presença dos wallpapers em
`~/.local/share/backgrounds/dracula/`. Sugestão para sprint futura: checks
read-only (`_detectar_spotify_flatpak && spicetify status`; `[[ -d
~/.local/share/backgrounds/dracula && $(ls *.png | wc -l) -ge 2 ]]`).
Custo/benefício baixo; não bloqueia esta sprint.

### A2 — Cache do Flatpak cresce indefinidamente

`~/.var/app/com.spotify.Client/cache/` chegou a 495 MB. Não é responsabilidade
deste tema gerenciar cache de outros apps. Registrado como housekeeping
pessoal.

### A3 — `aplicar_spicetify` em `instalar_app_themes.sh` não chama `atualizar_spicetify.sh`

Após esta sprint, `install.sh --user --all` continua usando `spicetify-setup.sh`
do Spellbook (já trata limpeza de cache parcial). Não há lacuna durante
instalação inicial — a lacuna estava pós-update. **Sem ação.**

### A4 — Wallpapers em XDG `picture-options`

A chave `org.gnome.desktop.background picture-options` (modo: `zoom`,
`stretched`, `centered`) não é tocada por `--apply`. Mitigação: usuário
configura visualmente uma vez; o `--apply` herda o modo atual. Aceitável.

### A5 — SPRINT 18 (Spicetify autônomo) precisa de detecção de Spellbook-OS ausente

Na próxima sprint, `aplicar_spicetify` precisará de fluxo alternativo quando
`_buscar_spicetify_setup` retornar vazio. Caminho proposto: instalar Spicetify
via `curl ... | sh` oficial e clonar `spicetify/spicetify-themes`.
Documentado aqui para coordenação inter-sprints.

---

## Referências

- `CLAUDE.md` global e local — §2 (simplicidade), §3 (cirúrgico), §4 (objetivos
  verificáveis).
- `docs/sprints/SPRINT_06_RESILIENCIA_POS_UPGRADE.md` — APT hook que invoca
  `reaplicar_tema.sh`.
- `docs/sprints/SPRINT_07_PORTABILIDADE.md` — baseline Pop!_OS 22.04+ (justifica
  `flatpak --noninteractive`).
- `docs/sprints/SPRINT_08_SEGURANCA_ROBUSTEZ.md` — `validar_path_destrutivo` e
  allowlist.
- `docs/sprints/SPRINT_13_STEAM_ICONS.md` — precedente direto: padrão
  `atualizar_<algo>.sh` chamado por seção decimal de `reaplicar_tema.sh`,
  com suporte a `DRACULA_DRY_RUN`.
- `docs/sprints/SPRINT_14_REAPLICAR_COBERTURA.md` — padrão de adicionar seções
  decimais ao reaplicador sem refatorar adjacente.
- `docs/sprints/SPRINT_16_HOUSEKEEPING_DESKTOPS_LOGS.md` — última sprint;
  estabelece estilo de comentários e aritmética obrigatória.
- `docs/sprints/SPRINT_17_SPICETIFY_RESILIENCIA.md` — spec anterior, **substituído**
  por este documento (manter o arquivo histórico até o commit final, depois
  pode ser removido ou marcado como `[Substituído por SPRINT_17_COBERTURA_GAPS]`
  no INDEX).
- `~/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh:195-211` —
  orquestrador canônico de instalação Spicetify; boundary preservado.
- `scripts/instalar_app_themes.sh:96-129` — `_buscar_spicetify_setup` e
  `aplicar_spicetify`; usados como estão.
- `CHANGELOG.md` — entrada `[Unreleased]` `### Adicionado` SPRINT 16
  (precedente imediato de estilo).

*"Quatro gaps, uma sprint. O que se reinstala no fundo da caverna volta a ouvir
a música; o que se documenta volta a ser encontrado." — adágio do `xpui.spa`
revisitado.*
