# Sprint 13 — Patcher universal de ícones Steam (com robustez a upgrade do SO)

Materializar ícones de jogos Steam em alta resolução (256x256) a partir das artes de biblioteca já baixadas pelo cliente Steam, eliminando o fallback genérico do launcher Pop!_Cosmic. O patcher é idempotente, sem sudo, integrado ao pipeline de reaplicação pós-upgrade (SPRINT 06) e roda também na fase user do `install.sh`.

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 13 (10/11/12 já commitadas).
> - **Sem sudo**. Usuário-final em `MODO=user`.
> - **Square crop é OK** mesmo se source for retangular (decisão do usuário). Não preservar aspect ratio — `gravity center` + `extent` quadrado seguido de `resize 256x256`.
> - **Robustez pós-upgrade já está coberta pelo APT hook (SPRINT 06)**: a integração desta sprint é apenas adicionar uma seção nova ao `scripts/reaplicar_tema.sh` (entre seções 7 e 8). O hook `/etc/apt/apt.conf.d/99-dracula-os-theme` reexecuta `reaplicar_tema.sh` após `apt full-upgrade`.
> - **Não tocar `~/.steam/`**: apenas LER de `~/.steam/debian-installation/appcache/librarycache/<APPID>/`.
> - **Não tocar `/usr/share/`** nem `/etc/`.
> - **ImageMagick `convert` (legacy v6)** como única dependência runtime. Ausência do binário aborta o patcher com mensagem orientando `sudo apt install imagemagick`. Não-fatal para o `install.sh` e `reaplicar_tema.sh` (chamada protegida por `||`).
> - **Sem features especulativas** (CLAUDE.md §2): sem GUI, sem cron/timer, sem suporte a Epic/GOG/Heroic, sem limpeza de PNGs órfãos, sem geração de múltiplos tamanhos (16/32/48/128). Apenas 256x256 — GTK redimensiona para baixo conforme a necessidade do consumidor.
> - **Mudanças cirúrgicas** em `install.sh` e `scripts/reaplicar_tema.sh`.

## Contexto

### Causa-raiz observada

O usuário (Pop!_OS 22.04, GNOME 42.9, X11) tem jogos Steam instalados via cliente nativo. Eles aparecem no launcher Pop!_Cosmic mas **sem ícone próprio** — só fallback genérico.

Inspeção concreta do ambiente real (jogo `Mr. Sleepy Man`, APPID `1657740`):

- **`.desktop` do jogo**: `~/.local/share/applications/Mr. Sleepy Man.desktop` (nome com espaços e maiúsculas, não `steam_app_<APPID>.desktop`):
  ```
  Name=Mr. Sleepy Man
  Exec=steam steam://rungameid/1657740
  Icon=steam_icon_1657740
  Categories=Game;
  ```
- **Único ícone que o cliente Steam baixa**: `~/.local/share/icons/hicolor/32x32/apps/steam_icon_1657740.png` (32x32, baixa demais para o launcher).
- **Mas o cliente Steam baixa arte de biblioteca em alta resolução** em `~/.steam/debian-installation/appcache/librarycache/1657740/`:
  - `library_600x900.jpg` — capsule vertical 300x450 (medido com `identify`).
  - `library_header.jpg` — header horizontal 460x215.
  - `library_hero.jpg` — hero banner (1920x620).
  - `library_hero_blur.jpg` — hero blurred.
  - `<sha1>.jpg` — thumb 32x32 raw.

O launcher Pop!_Cosmic pede ícones em ~64x64 ou 96x96; com apenas o 32x32 disponível, GTK cai em fallback genérico.

### Solução estrutural

Gerar PNG 256x256 por APPID a partir da melhor fonte disponível (capsule 300x450 → header 460x215 → fallback 32x32 do hicolor), salvar em `~/.local/share/icons/hicolor/256x256/apps/steam_icon_<APPID>.png`, regenerar `icon-theme.cache` do hicolor user-level. GTK passa a encontrar o ícone na resolução solicitada e usa esse PNG.

A descoberta de APPIDs é dirigida pelos `.desktop` do usuário: varredura de `~/.local/share/applications/*.desktop` por linha que case `^Icon=steam_icon_([0-9]+)`. Para cada APPID extraído, processa.

### Robustez contra upgrade do SO

A infra de auto-restauração já existe (SPRINT 06):

- `scripts/instalar_apt_hook.sh` registra `/etc/apt/apt.conf.d/99-dracula-os-theme` que invoca `scripts/reaplicar_tema.sh` após cada `apt install`/`upgrade`/`full-upgrade`.
- `scripts/reaplicar_tema.sh` é o orquestrador idempotente; tem hoje 9 seções numeradas (1–9) — verificado em `head -100`.

Adicionar uma seção nova entre **7 (app themes)** e **8 (rebuild caches)** que invoca o patcher Steam. Como o patcher é idempotente por mtime, regenera apenas o necessário.

Cobertura de cenários:

- **`apt full-upgrade` (Pop!_OS 22.04 patches)**: hook dispara, seção 7.5 roda patcher, ícones permanecem.
- **`do-release-upgrade` para Pop!_OS 24.04**: cosmic-launcher nativo também consulta `hicolor`; PNGs continuam válidos.
- **Instalação de jogo Steam novo**: o cliente Steam grava `library_600x900.jpg` no `librarycache`. Próxima chamada do hook ou execução manual de `bash scripts/atualizar_icones_steam.sh` gera o PNG.
- **Sem jogos Steam instalados**: varredura encontra zero APPIDs, log informa "0 jogos detectados", exit 0.

## Estado real verificado (pré-sprint)

```
~/.steam/debian-installation/appcache/librarycache/1657740/
  library_600x900.jpg   (JPEG 300x450, 83.041 bytes)
  library_header.jpg    (JPEG 460x215, 59.696 bytes)
  library_hero.jpg
  library_hero_blur.jpg
  e168a5d5d27d46980353fac3756e8bef4cb46de8.jpg
  94fd612dad1b20b804b2fee0f610a54265cc04a7

~/.local/share/icons/hicolor/32x32/apps/
  steam_icon_1657740.png   (único)

~/.local/share/icons/hicolor/256x256/apps/
  (sem nenhum steam_icon_*)

/usr/bin/convert     ImageMagick 6.9.11-60
/usr/bin/identify    presente
```

## Hipóteses / Objetivos

1. **Capsule 300x450 → square crop center 300x300 → resize 256x256 produz ícone reconhecível** para todos os jogos Steam testados, mesmo perdendo as bordas verticais.
2. **`gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor` regenera o cache** sem precisar logout/login. GTK passa a achar o `steam_icon_<APPID>` em 256x256 imediatamente nas próximas queries (consumidor Pop!_Cosmic memoiza, então pode exigir `Alt+F2 r` para refletir visualmente — comportamento documentado, não-regressão).
3. **Idempotência por mtime**: comparar mtime do destino com mtime do source mais novo do APPID é suficiente. Se `dest` mais novo que `max(sources)`, pula. Flag `--force` ignora.
4. **Varredura de `~/.local/share/applications/*.desktop`** captura todos os APPIDs visíveis ao launcher. Não é preciso bisbilhotar `~/.steam/steamapps/libraryfolders.vdf`.
5. **`set -euo pipefail` + `for f in dir/*.desktop` + nullglob** é seguro mesmo em diretório vazio.

## Escopo (touches autorizados)

Arquivos a criar:

- `scripts/atualizar_icones_steam.sh` — patcher novo.
- `docs/sprints/SPRINT_13_STEAM_ICONS.md` — este spec.

Arquivos a modificar (mudança cirúrgica, sem refatorar adjacente):

- `install.sh` — uma chamada nova não-fatal na fase user (após o loop de instalação dos temas de ícones, antes de "Temas GTK/Shell"). Aproximadamente 4 linhas adicionadas, **0 removidas, 0 reformatadas**.
- `scripts/reaplicar_tema.sh` — uma seção nova `# ─── 7.5 ...` entre as seções 7 e 8 atuais. Aproximadamente 3 linhas adicionadas, **0 removidas, 0 reformatadas**.
- `CHANGELOG.md` — uma entrada nova sob `## [Unreleased]` → `### Adicionado`.
- `docs/sprints/INDEX.md` — uma linha nova `| 13 | ...`.

Arquivos NÃO tocar:

- `~/.steam/**` — apenas LER de `appcache/librarycache/<APPID>/`.
- `~/.local/share/icons/hicolor/32x32/apps/steam_icon_*.png` — apenas LER (fallback source).
- `/usr/share/**`, `/etc/**`.
- Outros scripts da pasta `scripts/`: `aplicar_overrides.sh`, `normalizar_desktops.sh`, `diagnostico.sh`, etc.
- `build.sh`, `dist/`, `src/`.
- Outros temas: `Dracula-Icones`, `Dracula-Cursor`, `dracula-icons-{main,circle}` — esta sprint atua só em `hicolor`.

## Plano de implementação

### Passo 1 — Novo `scripts/atualizar_icones_steam.sh`

Estrutura do script (seguir estilo de `scripts/instalar_higiene_launcher.sh` e `scripts/aplicar_overrides.sh`):

1. **Cabeçalho**: shebang `#!/usr/bin/env bash`, comentário-bloco descrevendo propósito e suporte a `DRACULA_DRY_RUN=1` e `--force`.
2. **`set -euo pipefail`**.
3. **Source**: `source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"` para usar `_info`/`_ok`/`_warn`/`_err`/`_dim` (verificado: `scripts/lib/common.sh` linhas 23–27).
4. **Variáveis fixas**:
   ```bash
   readonly STEAM_LIBCACHE="$HOME/.steam/debian-installation/appcache/librarycache"
   readonly DESKTOP_DIR="$HOME/.local/share/applications"
   readonly ICONE_DEST_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
   readonly ICONE_FALLBACK_DIR="$HOME/.local/share/icons/hicolor/32x32/apps"
   readonly DRY_RUN="${DRACULA_DRY_RUN:-0}"
   ```
5. **Parsing de flags** (apenas `--force`):
   ```bash
   FORCE=0
   for arg in "$@"; do
       case "$arg" in
           --force) FORCE=1 ;;
           -h|--help) <imprime uso e exit 0> ;;
           *) _err "Argumento desconhecido: $arg"; exit 2 ;;
       esac
   done
   ```
6. **Pré-check de `convert`**:
   ```bash
   if ! command -v convert >/dev/null 2>&1; then
       _err "ImageMagick 'convert' não encontrado. Instale com: sudo apt install imagemagick"
       exit 3
   fi
   ```
   Exit 3 distingue de outros erros (2 = arg ruim, 1 = falha geral, 0 = OK).
7. **Garantir `ICONE_DEST_DIR`**:
   ```bash
   if [[ "$DRY_RUN" != "1" ]]; then
       mkdir -p "$ICONE_DEST_DIR"
   fi
   ```
8. **Varredura de APPIDs** dos `.desktop`:
   ```bash
   declare -a APPIDS=()
   if [[ -d "$DESKTOP_DIR" ]]; then
       shopt -s nullglob
       for desktop in "$DESKTOP_DIR"/*.desktop; do
           appid=$(grep -oE '^Icon=steam_icon_([0-9]+)' "$desktop" 2>/dev/null \
                   | head -n1 | sed -E 's/^Icon=steam_icon_//')
           if [[ -n "$appid" ]]; then
               APPIDS+=("$appid")
           fi
       done
       shopt -u nullglob
   fi
   # Deduplicar
   if [[ ${#APPIDS[@]} -gt 0 ]]; then
       mapfile -t APPIDS < <(printf '%s\n' "${APPIDS[@]}" | sort -u)
   fi

   _info "APPIDs detectados: ${#APPIDS[@]}"
   if [[ ${#APPIDS[@]} -eq 0 ]]; then
       _ok "Nenhum jogo Steam encontrado em $DESKTOP_DIR — nada a fazer"
       exit 0
   fi
   ```
9. **Loop principal**: para cada APPID, função `processar_appid <APPID>`:
   ```bash
   processar_appid() {
       local appid="$1"
       local dest="$ICONE_DEST_DIR/steam_icon_${appid}.png"
       local libdir="$STEAM_LIBCACHE/$appid"
       local fallback="$ICONE_FALLBACK_DIR/steam_icon_${appid}.png"

       # Encontra source primário em ordem de preferência
       local src="" tipo=""
       if [[ -f "$libdir/library_600x900.jpg" ]]; then
           src="$libdir/library_600x900.jpg"; tipo="capsule"
       elif [[ -f "$libdir/library_header.jpg" ]]; then
           src="$libdir/library_header.jpg"; tipo="header"
       elif [[ -f "$fallback" ]]; then
           src="$fallback"; tipo="fallback32"
       fi

       if [[ -z "$src" ]]; then
           _warn "appid $appid: nenhuma fonte disponível, pulando"
           return 0
       fi

       # Idempotência: pula se dest mais novo que src e --force não setado
       if [[ "$FORCE" != "1" && -f "$dest" ]]; then
           local mt_dest mt_src
           mt_dest=$(stat -c %Y "$dest" 2>/dev/null || echo 0)
           mt_src=$(stat -c %Y "$src" 2>/dev/null || echo 0)
           if [[ "$mt_dest" -ge "$mt_src" ]]; then
               _dim "appid $appid: ícone atualizado ($tipo) — pulando"
               return 0
           fi
       fi

       # Comando convert por tipo
       local cmd
       case "$tipo" in
           capsule)    cmd=(convert "$src" -gravity center -extent 300x300 -resize 256x256 -strip "$dest") ;;
           header)     cmd=(convert "$src" -gravity center -extent 215x215 -resize 256x256 -strip "$dest") ;;
           fallback32) cmd=(convert "$src" -filter point -resize 256x256 -strip "$dest") ;;
       esac

       if [[ "$DRY_RUN" = "1" ]]; then
           _dim "[dry-run] ${cmd[*]}"
           return 0
       fi

       if "${cmd[@]}" 2>/dev/null; then
           # Validar PNG gerado: > 1 KB
           local sz
           sz=$(stat -c %s "$dest" 2>/dev/null || echo 0)
           if [[ "$sz" -lt 1024 ]]; then
               _warn "appid $appid: PNG gerado < 1 KB ($sz bytes) — possivelmente corrompido"
               rm -f "$dest"
               return 1
           fi
           _ok "appid $appid: $tipo → 256x256 ($sz bytes)"
       else
           _warn "appid $appid: convert falhou"
           return 1
       fi
   }
   ```
10. **Iterar APPIDs** chamando `processar_appid`. Não abortar no erro de um APPID:
    ```bash
    sucesso=0
    falha=0
    for appid in "${APPIDS[@]}"; do
        if processar_appid "$appid"; then
            sucesso=$((sucesso + 1))
        else
            falha=$((falha + 1))
        fi
    done
    ```
11. **Atualizar cache do hicolor user-level** (não-fatal):
    ```bash
    if [[ "$DRY_RUN" != "1" && $sucesso -gt 0 ]]; then
        gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null \
            && _ok "icon-theme.cache regenerado em ~/.local/share/icons/hicolor" \
            || _dim "gtk-update-icon-cache falhou (não-fatal)"
    fi
    ```
12. **Resumo**:
    ```bash
    _info "Resumo: ${#APPIDS[@]} APPIDs, $sucesso processados, $falha com falha"
    [[ $falha -eq 0 ]] && exit 0 || exit 1
    ```
13. **Permissão**: `chmod +x scripts/atualizar_icones_steam.sh`.

### Passo 2 — Modificar `install.sh`

Inserir logo após o loop `for tema in Dracula-Icones ...` (linha 110 atual `_ok "ícones instalados"`), antes de `# ─── Temas GTK/Shell ───` (linha 113):

```bash
# ─── Ícones de jogos Steam (não-fatal) ───
if [[ "$MODO" == "user" ]]; then
    _info "Atualizando ícones de jogos Steam (não-fatal)"
    "$REPO_ROOT/scripts/atualizar_icones_steam.sh" || _warn "atualizar_icones_steam.sh falhou (não-fatal)"
fi
```

Justificativa: roda apenas em `--user` (sem sudo); chamada protegida por `||` então uma falha (ex.: `convert` ausente, sem jogos) não interrompe a instalação.

### Passo 3 — Modificar `scripts/reaplicar_tema.sh`

Inserir entre seção 7 (linha ~80 — `instalar_app_themes.sh`) e seção 8 (linha ~82 — `# ─── 8. Rebuild caches ───`):

```bash
# ─── 7.5 Ícones de jogos Steam (re-gera se sources foram baixados após últimos ícones) ───
_info "Atualizando ícones de jogos Steam"
"$REPO_ROOT/scripts/atualizar_icones_steam.sh" || _warn "atualizar_icones_steam.sh falhou"
```

Justificativa: a seção 8 que vem logo depois já regenera `gtk-update-icon-cache` e `update-desktop-database` — a chamada interna de `gtk-update-icon-cache` no patcher é redundante mas barata (e necessária quando o patcher é executado standalone).

### Passo 4 — Atualizar `CHANGELOG.md`

Adicionar dentro do bloco `## [Unreleased]` → `### Adicionado` já existente, abaixo da entrada da Sprint 12:

```markdown
- **Sprint 13 — Patcher universal de ícones Steam**: `scripts/atualizar_icones_steam.sh` varre `~/.local/share/applications/*.desktop` por entradas `Icon=steam_icon_<APPID>`, gera PNG 256x256 em `~/.local/share/icons/hicolor/256x256/apps/steam_icon_<APPID>.png` a partir da capsule 300x450 do `librarycache` da Steam (com fallback para header 460x215 e, em último caso, upscale do 32x32 já presente em `hicolor`), e regenera `icon-theme.cache`. Idempotente por mtime, sem sudo, com flag `--force` e suporte a `DRACULA_DRY_RUN=1`. Integrado ao `install.sh` (fase user, não-fatal) e à seção 7.5 nova de `scripts/reaplicar_tema.sh`, herdando assim a robustez pós-`apt full-upgrade` do APT hook (Sprint 06). Dependência runtime: `imagemagick` (`convert`). Substitui o ícone genérico exibido no launcher Pop!_Cosmic por arte real do jogo.
```

### Passo 5 — Atualizar `docs/sprints/INDEX.md`

Adicionar uma linha após a linha 20 (Sprint 12):

```
| 13 | [Patcher universal de ícones Steam](SPRINT_13_STEAM_ICONS.md) | Em implementação | 2026-05-07 |
```

## Aritmética da mudança

### No código

| Arquivo | Linhas adicionadas | Linhas removidas | Linhas reformatadas |
|---|---|---|---|
| `scripts/atualizar_icones_steam.sh` (novo) | ~110 | 0 | 0 |
| `install.sh` | 4 | 0 | 0 |
| `scripts/reaplicar_tema.sh` | 3 | 0 | 0 |
| `CHANGELOG.md` | 1 entrada nova (1 linha de bullet) | 0 | 0 |
| `docs/sprints/INDEX.md` | 1 linha de tabela | 0 | 0 |
| `docs/sprints/SPRINT_13_STEAM_ICONS.md` (novo) | ~este arquivo | 0 | 0 |

### Na saída runtime

Estado antes da sprint (medido):

```
COUNT_256_BEFORE = $(ls ~/.local/share/icons/hicolor/256x256/apps/steam_icon_*.png 2>/dev/null | wc -l)
# esperado: 0
```

Estado após primeira execução do patcher (no host de validação, com Mr. Sleepy Man instalado):

```
COUNT_256_AFTER = 1
TARGET_PNG      = ~/.local/share/icons/hicolor/256x256/apps/steam_icon_1657740.png
TARGET_DIM      = 256x256 (via identify)
TARGET_SIZE     > 1024 bytes
SOURCE_USED     = capsule (library_600x900.jpg)
```

Conta-corrente: `COUNT_256_AFTER - COUNT_256_BEFORE = N_APPIDS_DETECTADOS`. No host de validação: 1.

### Idempotência por mtime

- 1ª execução: `mtime1 = stat -c %Y <dest>`.
- 2ª execução sem `--force`: `mtime2 = mtime1` (não toca).
- 3ª execução com `--force`: `mtime3 > mtime1`.

## Acceptance criteria

1. `bash -n scripts/atualizar_icones_steam.sh` — sintaxe OK.
2. `shellcheck --severity=warning scripts/atualizar_icones_steam.sh` — sem novos warnings.
3. `bash -n install.sh` e `bash -n scripts/reaplicar_tema.sh` — sintaxe OK após edições.
4. `shellcheck --severity=warning install.sh scripts/reaplicar_tema.sh` — delta zero (sem novos warnings em relação ao baseline).
5. **Pré-check ImageMagick**: rodar `PATH=/usr/bin:/bin bash -c 'PATH=/tmp scripts/atualizar_icones_steam.sh'` (simula `convert` ausente removendo do PATH) → exit 3 com mensagem clara.
6. **Sem jogos Steam**: em diretório `~/.local/share/applications/` sem `.desktop` com `Icon=steam_icon_*` → exit 0, log informa "Nenhum jogo Steam encontrado".
7. **Execução real (host de validação com Mr. Sleepy Man)**:
   - Antes: `ls ~/.local/share/icons/hicolor/256x256/apps/steam_icon_*.png 2>/dev/null | wc -l` = 0.
   - Após `bash scripts/atualizar_icones_steam.sh`:
     - `[[ -f ~/.local/share/icons/hicolor/256x256/apps/steam_icon_1657740.png ]]` → true.
     - `identify ~/.local/share/icons/hicolor/256x256/apps/steam_icon_1657740.png | grep -oE '256x256'` retorna `256x256`.
     - `stat -c %s ~/.local/share/icons/hicolor/256x256/apps/steam_icon_1657740.png` > 1024.
     - Log indica `tipo=capsule` (porque `library_600x900.jpg` está presente).
8. **Idempotência**:
   - `mt1 = $(stat -c %Y .../steam_icon_1657740.png)`.
   - Roda novamente sem `--force`: `mt2 = stat -c %Y ...` → `mt1 == mt2`.
   - Roda com `--force`: `mt3 = stat -c %Y ...` → `mt3 > mt1`.
9. **Dry-run**: `DRACULA_DRY_RUN=1 bash scripts/atualizar_icones_steam.sh` em ambiente sem `dest` → não cria arquivo (`COUNT_AFTER == COUNT_BEFORE`), log mostra `[dry-run]`.
10. **Integração com `reaplicar_tema.sh`**:
    - `bash scripts/reaplicar_tema.sh` exit 0 e log contém a string "Atualizando ícones de jogos Steam".
    - Diagnóstico final (`scripts/diagnostico.sh --quiet`) exit 0.
11. **Integração com `install.sh`**:
    - `bash install.sh --user` exit 0; log contém "Atualizando ícones de jogos Steam".
12. **Não-regressão**:
    - `~/.local/share/icons/hicolor/32x32/apps/steam_icon_1657740.png` permanece intacto (`sha256sum` antes/depois — devem coincidir).
    - `~/.steam/debian-installation/appcache/librarycache/1657740/library_600x900.jpg` permanece intacto (`sha256sum` antes/depois).
    - `~/.local/share/icons/Dracula-Icones/` intacto (a sprint não toca o tema próprio).
    - `bash scripts/diagnostico.sh --quiet` exit 0.
13. **Validação visual** (skill `validacao-visual`): após reload do GNOME Shell (`Alt+F2` → `r` — X11 confirmado), abrir launcher (`Super+A`), buscar "Mr. Sleepy Man". O ícone exibido é a capsule do jogo (não mais o fallback genérico). PNG capturado com `sha256` antes/depois.

## Invariantes a preservar

- **Acentuação pt-BR completa em UTF-8** (CLAUDE.md §1, BRIEF check 1) em `CHANGELOG.md`, `INDEX.md`, neste spec, e em comentários novos do `atualizar_icones_steam.sh`. **Proibido** `Inicio` (sem acento), `automatica`, `icones` (palavra isolada), `instalacao`, `propagacao` em todos os arquivos modificados/criados. Varredura obrigatória.
- **Mudança cirúrgica** (CLAUDE.md §3, BRIEF check 2): `install.sh` recebe **apenas** o bloco descrito; `reaplicar_tema.sh` recebe **apenas** a seção 7.5; sem reflow, sem renomear variáveis, sem ajustar logs adjacentes, sem reordenar seções.
- **Idempotência** (BRIEF check 3): segunda execução do patcher sem `--force` não muda mtime do PNG gerado.
- **Não escrever em `/usr/share/`** (BRIEF check 5): patcher é estritamente user-level.
- **Não tocar `~/.steam/`**: apenas leitura. Validar via `inotifywait` é exagero — basta `sha256sum` dos sources antes/depois.
- **Sem features especulativas** (CLAUDE.md §2): apenas o necessário. Sem GUI, sem timer, sem suporte a outras lojas.
- **Soberania de subsistema**: a sprint mexe apenas no patcher novo + integração mínima nos dois orquestradores existentes. Não toca `build.sh`, `diagnostico.sh`, `lib/common.sh`, `aplicar_overrides.sh`, `normalizar_desktops.sh`.
- **Reversibilidade implícita**: remoção dos PNGs gerados é trivial — `rm ~/.local/share/icons/hicolor/256x256/apps/steam_icon_*.png && gtk-update-icon-cache -f ~/.local/share/icons/hicolor`. Não criar `desinstalar_icones_steam.sh` (fora de escopo).

## Proof-of-work runtime-real

```bash
# ─── Pré-condições e baseline ───
test -f ~/.steam/debian-installation/appcache/librarycache/1657740/library_600x900.jpg \
    && echo MR_SLEEPY_CAPSULE_OK
identify ~/.steam/debian-installation/appcache/librarycache/1657740/library_600x900.jpg \
    | grep -oE '300x450' && echo CAPSULE_DIM_OK
test -f ~/.local/share/icons/hicolor/32x32/apps/steam_icon_1657740.png \
    && echo FALLBACK_32_OK
COUNT_BEFORE=$(ls ~/.local/share/icons/hicolor/256x256/apps/steam_icon_*.png 2>/dev/null | wc -l)
echo "COUNT_256_BEFORE=$COUNT_BEFORE"  # esperado: 0
SHA_FALLBACK_BEFORE=$(sha256sum ~/.local/share/icons/hicolor/32x32/apps/steam_icon_1657740.png | awk '{print $1}')
SHA_CAPSULE_BEFORE=$(sha256sum ~/.steam/debian-installation/appcache/librarycache/1657740/library_600x900.jpg | awk '{print $1}')

# ─── Sintaxe / lint ───
bash -n scripts/atualizar_icones_steam.sh
bash -n install.sh
bash -n scripts/reaplicar_tema.sh
shellcheck --severity=warning scripts/atualizar_icones_steam.sh
shellcheck --severity=warning install.sh
shellcheck --severity=warning scripts/reaplicar_tema.sh

# ─── Pré-check de convert ausente (exit 3) ───
PATH=/tmp bash scripts/atualizar_icones_steam.sh; ec=$?; echo "exit_no_convert=$ec"  # esperado: 3

# ─── Dry-run ───
DRACULA_DRY_RUN=1 bash scripts/atualizar_icones_steam.sh
COUNT_DRY=$(ls ~/.local/share/icons/hicolor/256x256/apps/steam_icon_*.png 2>/dev/null | wc -l)
test "$COUNT_DRY" = "$COUNT_BEFORE" && echo DRY_RUN_NO_OP || echo DRY_RUN_LEAKED

# ─── Execução real ───
bash scripts/atualizar_icones_steam.sh
test -f ~/.local/share/icons/hicolor/256x256/apps/steam_icon_1657740.png && echo PNG_CRIADO
identify ~/.local/share/icons/hicolor/256x256/apps/steam_icon_1657740.png 2>&1 | head -1
SZ=$(stat -c %s ~/.local/share/icons/hicolor/256x256/apps/steam_icon_1657740.png)
test "$SZ" -gt 1024 && echo PNG_TAMANHO_OK || echo "PNG_PEQUENO=$SZ"

# ─── Idempotência ───
mt1=$(stat -c %Y ~/.local/share/icons/hicolor/256x256/apps/steam_icon_1657740.png)
sleep 1
bash scripts/atualizar_icones_steam.sh
mt2=$(stat -c %Y ~/.local/share/icons/hicolor/256x256/apps/steam_icon_1657740.png)
test "$mt1" = "$mt2" && echo IDEMPOTENT || echo "DRIFT mt1=$mt1 mt2=$mt2"

# ─── --force regenera ───
sleep 1
bash scripts/atualizar_icones_steam.sh --force
mt3=$(stat -c %Y ~/.local/share/icons/hicolor/256x256/apps/steam_icon_1657740.png)
test "$mt3" -gt "$mt1" && echo FORCE_REGEN || echo "FORCE_FAIL mt1=$mt1 mt3=$mt3"

# ─── Não-regressão dos sources e fallback ───
SHA_FALLBACK_AFTER=$(sha256sum ~/.local/share/icons/hicolor/32x32/apps/steam_icon_1657740.png | awk '{print $1}')
SHA_CAPSULE_AFTER=$(sha256sum ~/.steam/debian-installation/appcache/librarycache/1657740/library_600x900.jpg | awk '{print $1}')
test "$SHA_FALLBACK_BEFORE" = "$SHA_FALLBACK_AFTER" && echo FALLBACK_INTACT
test "$SHA_CAPSULE_BEFORE"  = "$SHA_CAPSULE_AFTER"  && echo CAPSULE_INTACT

# ─── Integração reaplicar_tema.sh ───
bash scripts/reaplicar_tema.sh 2>&1 | tee /tmp/reaplicar_log.txt
grep -q "Atualizando ícones de jogos Steam" /tmp/reaplicar_log.txt && echo REAPLICAR_INTEGRADO

# ─── Diagnóstico ───
bash scripts/diagnostico.sh --quiet ; echo "exit=$?"  # esperado: 0

# ─── Acentuação periférica ───
for f in scripts/atualizar_icones_steam.sh install.sh scripts/reaplicar_tema.sh \
         CHANGELOG.md docs/sprints/INDEX.md docs/sprints/SPRINT_13_STEAM_ICONS.md; do
  echo "== $f =="
  grep -nE "Inicio[[:space:]]|movera|icones( |\.|$|,|:)|automatica|instalacao|propagacao" "$f" || true
done
# esperado: nenhuma forma sem acento (palavras isoladas)
```

## Validação visual (skill `validacao-visual` auto-invocada)

Após `bash scripts/atualizar_icones_steam.sh` e reload do GNOME Shell (`Alt+F2` → `r` → Enter — X11 confirmado pelo BRIEF):

1. **Screenshot 1 (antes — opcional, se reproduzível)**: launcher mostrando "Mr. Sleepy Man" com ícone genérico.
2. **Screenshot 2 (depois)**: `Super+A` → buscar `Mr. Sleepy Man` (ou navegar) → o ícone exibido é a arte da capsule da Steam library, não mais o genérico.
3. PNG capturado com `sha256` no relato final do executor.

## Riscos conhecidos

- **Cache do GTK/GNOME Shell**: mesmo após `gtk-update-icon-cache`, o Shell em execução pode continuar usando lookup memoizado até `Alt+F2 r` (X11). Comportamento padrão do Shell, não regressão da sprint.
- **ImageMagick policy `PNG` desabilitada**: em hosts com `/etc/ImageMagick-6/policy.xml` restritivo, `convert` pode rejeitar saída PNG. Comportamento esperado: log de warning por APPID, exit 1 final, instalação principal continua (não-fatal). Documentado.
- **JPEG corrupto no `librarycache`**: se Steam baixou parcialmente, `convert` falha; o patcher loga warning e segue para o próximo APPID. Próxima execução tenta de novo (mtime do source mudou).
- **Steam Snap/Flatpak**: o script assume o caminho `~/.steam/debian-installation/appcache/librarycache/`. Em instalações Snap/Flatpak, esse caminho não existe e os APPIDs caem todos no fallback 32x32 (upscale pixelado, mas reconhecível). Aceitável; não é objetivo cobrir esses casos nesta sprint.
- **Square crop perde topo/base da capsule 300x450**: decisão consciente do usuário. Aspect ratio sacrificado em favor de simplicidade.
- **APPID extraído de nome com aspas/espaços no `.desktop`**: o regex `^Icon=steam_icon_([0-9]+)` é estrito; APPIDs não-numéricos (Steam non-game, ex.: "media") são ignorados (escopo declarado).
- **Cosmic nativo (Pop!_OS 24.04)**: cosmic-launcher também consulta `hicolor`; PNGs gerados continuam servindo. Sem regressão prevista.
- **Crescimento de `~/.local/share/icons/hicolor/256x256/apps/`**: ~30–80 KB por jogo. Para 100 jogos, ~5 MB. Irrisório.

## Não-objetivos / Fora de escopo

- Suporte a Epic, GOG, Heroic Games Launcher, Lutris — apenas Steam nativo via `steam://rungameid/`.
- Ícones para shortcuts Steam não-game (serviços, ferramentas) — apenas APPIDs numéricos casados pelo regex `Icon=steam_icon_<NÚMERO>`.
- Geração de ícones em múltiplos tamanhos (16/32/48/128/512). Apenas 256x256; GTK redimensiona para baixo.
- Suporte a Steam instalado via Snap (`~/snap/steam/...`) ou Flatpak (`~/.var/app/com.valvesoftware.Steam/...`). Apenas a instalação debian-installation atual.
- Limpeza automática de PNGs órfãos em `~/.local/share/icons/hicolor/256x256/apps/steam_icon_<APPID>.png` quando o jogo é desinstalado. Fora de escopo (PNG órfão é benigno).
- Conversão respeitando aspect ratio com letterbox/pillarbox.
- GUI ou TUI para configurar prioridades de fonte.
- Integração com `instalar_apt_hook.sh` direta (não precisa: o hook chama `reaplicar_tema.sh`, que herda a chamada via seção 7.5).
- Documentação em `README.md` (entrada no `CHANGELOG.md` cobre).
- Testes em `tests/` automatizados (a sprint usa apenas validação manual + diagnóstico). Pode ser sprint futura (`SPRINT_14_TESTS_STEAM_ICONS`).

## Pontos resolvidos pelo planejador

- **Onde EXATAMENTE em `install.sh` chamar o patcher**: imediatamente após o loop `for tema in Dracula-Icones ...` que termina em `_ok "ícones instalados"` (linha 111 atual), guardado por `if [[ "$MODO" == "user" ]]; then` para não rodar em modo system. Não conflita com o bloco "Temas GTK/Shell" que vem em seguida.
- **Gtk-update-icon-cache duplicado**: o patcher chama `gtk-update-icon-cache -f ~/.local/share/icons/hicolor` para funcionar standalone. A seção 8 do `reaplicar_tema.sh` chama `gtk-update-icon-cache -f ~/.local/share/icons/Dracula-Icones` (alvo diferente: tema próprio). Não há duplicação real.
- **Nome do flag de força**: `--force` (consistente com `git push --force`, `gtk-update-icon-cache -f`).
- **Mapping APPID → source**: o único APPID instalado neste host é `1657740` (Mr. Sleepy Man). Documentado como evidência primária; para usuários sem jogos Steam, exit 0 silencioso.
- **Outros sources em `~/.steam/`**: `library_hero.jpg` (1920x620) é tentadoramente alta-res, mas é landscape extremo e o square crop center perderia a maior parte do conteúdo útil. Capsule 300x450 (3:2 quase quadrada) é a melhor escolha. Decisão final fixada nas três fontes do spec original (capsule > header > fallback 32x32).
- **Convert v6 vs v7**: o host tem v6 (`ImageMagick 6.9.11-60`). Comandos usam apenas opções compatíveis com ambos (`-gravity`, `-extent`, `-resize`, `-strip`, `-filter point`). Sem `magick` namespace v7.

## Referências

- Pré-condições do ambiente medidas: `~/.steam/debian-installation/appcache/librarycache/1657740/{library_600x900.jpg,library_header.jpg}` presentes; `/usr/bin/convert` ImageMagick 6.9.11-60.
- `scripts/lib/common.sh` linhas 23–27 — helpers de log (`_info`, `_ok`, `_warn`, `_err`, `_dim`).
- `scripts/instalar_higiene_launcher.sh` — padrão `DRACULA_DRY_RUN`, idempotência, sem sudo.
- `scripts/reaplicar_tema.sh` linhas 78–86 — local de inserção da seção 7.5 (entre seção 7 "App themes" e seção 8 "Rebuild caches").
- `install.sh` linhas 102–111 — loop de instalação dos temas de ícones; ponto de inserção da chamada nova.
- `docs/sprints/SPRINT_06_RESILIENCIA_POS_UPGRADE.md` — APT hook que dispara `reaplicar_tema.sh`.
- `docs/sprints/SPRINT_12_DELETE_ICON.md` — sprint imediatamente anterior (referência de formato).
- `VALIDATOR_BRIEF.md` §"[CORE] Contratos de runtime" e "[CORE] Checks universais ativados" — comandos universais e invariantes 1–5.
- `CLAUDE.md` (raiz) §1, §2, §3 — pensar antes, simplicidade primeiro, mudanças cirúrgicas.

---

*"O ícone certo no lugar certo." — e o que o cliente Steam não entrega em alta resolução, o tema entrega via librarycache.*
