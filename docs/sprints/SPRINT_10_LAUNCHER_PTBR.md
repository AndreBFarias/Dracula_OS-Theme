# Sprint 10 — Localização pt-BR do launcher Pop!_Cosmic

Substituir as strings hardcoded em inglês da extensão GNOME Shell `pop-cosmic@system76.com` (rótulo `Library Home`, botões/diálogos de criar/excluir/renomear pasta) por equivalentes pt-BR via **cópia da extensão para `~/.local/share/gnome-shell/extensions/` e patch local** — sem `sudo`, sem mexer em `/usr/share/`. A precedência user-over-system do GNOME Shell garante que a cópia local é carregada e a do sistema é ignorada.

> **Decisões fixas (não reabrir)**:
> - **Estratégia**: cópia para user-dir, NÃO `sed` em `/usr/share` nem `dpkg-divert`. Justificativa: precedência oficial do GNOME (ver "Hipóteses"), sobrevive a `apt upgrade pop-cosmic`, fica inerte se o usuário migrar para Pop!_OS 24.04 (COSMIC nativo), dispensa privilégio de root.
> - **Tabela de strings pt-BR**: definida pelo usuário, acentuação UTF-8 obrigatória.
> - **Numeração**: SPRINT 10 (a SPRINT 09 já está ocupada por `SPRINT_09_TESTES_CI_COSMIC.md`).

## Contexto

A extensão `pop-cosmic@system76.com` (pacote APT `pop-cosmic` da System76) renderiza o launcher cheio do Pop!_OS sobre o GNOME 42. O rótulo do rodapé "Library Home", o botão "Create Folder" e os diálogos de criar/excluir/renomear pasta estão **hardcoded em `applications.js`** — não há `po/`, `LINGUAS`, nem chamadas a `Shell.util_get_translated()` para essas strings. Isso é confirmado pelo upstream nas issues [#22 do `gnome-shell-extension-pop-cosmic`](https://github.com/pop-os/gnome-shell-extension-pop-cosmic/issues/22) e [#1388 do `pop-os/shell`](https://github.com/pop-os/shell/issues/1388): a System76 redirecionou esforço de i18n para o COSMIC nativo (Rust) em Pop!_OS 24.04, e a extensão JS não receberá suporte oficial a tradução.

### Estratégia: user-dir override

O GNOME Shell carrega extensões em **ordem inversa** de prioridade dos `XDG_DATA_DIRS`. Em `js/misc/fileUtils.js` (`collectFromDatadirs`), o GNOME faz `dataDirs.unshift(GLib.get_user_data_dir())` colocando `~/.local/share` no índice 0. Em `js/ui/extensionSystem.js` (`_loadExtensions`), se uma extensão com mesmo UUID aparece em mais de um path, o GNOME loga `"Extension ${uuid} already installed in ${existing.path}. ${dir.get_path()} will not be loaded"` e ignora as ocorrências posteriores. **Resultado**: copiar `pop-cosmic@system76.com` para `~/.local/share/gnome-shell/extensions/pop-cosmic@system76.com/` faz a versão do usuário ser carregada e a do sistema ser ignorada — comportamento documentado e suportado.

Vantagens em relação a `sed -i` em `/usr/share/`:

- **Sem `sudo`** — o patch roda no `MODO=user` do `install.sh`.
- **Sobrevive a `apt upgrade pop-cosmic`** — a cópia local é independente do pacote do sistema; nenhuma mexida em `dpkg-divert`.
- **Sobrevive a `apt-get install --reinstall pop-cosmic`** pelo mesmo motivo.
- **Inerte em upgrade para Pop!_OS 24.04 (COSMIC nativo)** — a extensão JS deixa de existir e o diretório local fica como lixo benigno (recomendamos remoção manual; documentar).
- **Reversão trivial**: `rm -rf ~/.local/share/gnome-shell/extensions/pop-cosmic@system76.com`.

A inspeção prévia confirmou os identificadores e linhas-alvo no `applications.js` da máquina do autor (versão `0.1.0~1765823448~22.04~07b06d4`):

```
 90:// Button for a folder, or "Library Home"   (comentário, não substituir)
211:            this._name = 'Library Home';
707:        create_button.label.text = "Create Folder";
771:        new CosmicFolderEditDialog("New Folder", "Folder Name", "Create", true, (dialog) => {
779:        const desc = "Deleting this folder will move the application icons to Library Home.";
780:        new CosmicFolderEditDialog("Delete Folder?", desc, "Delete", false, (dialog) => {
786:    open_rename_folder_dialog() {
794:        const dialog = new CosmicFolderEditDialog("Rename Folder", null, "Rename", true, (dialog) => {
```

## Hipóteses / Objetivos

1. **Precedência user > system do GNOME Shell**: validada por inspeção do código fonte (`fileUtils.js` `collectFromDatadirs` faz `dataDirs.unshift(user_data_dir)`; `extensionSystem.js` `_loadExtensions` descarta UUID duplicado posterior). Ver `https://gitlab.gnome.org/GNOME/gnome-shell/-/raw/gnome-42/js/misc/fileUtils.js`.
2. **JavaScript em UTF-8 aceita strings com acentos pt-BR sem escape** (`'Início'`, `'Excluir pasta?'`, `"moverá os ícones"`).
3. **Cópia recursiva preserva execução**: copiar todo o diretório `pop-cosmic@system76.com` (não só `applications.js`) garante que as importações relativas (`extension.js`, `dark.css`, `metadata.json`, etc.) continuem funcionando.
4. **`sed -i` com delimitador `|` é suficiente** — não há regex complexa nas strings-alvo. Cuidado especial com `?` em "Delete Folder?" (em BRE o `?` é literal; confirmar com `grep -F` antes do patch).

## Escopo (touches autorizados)

Arquivos a criar:
- `scripts/instalar_pop_cosmic_ptbr.sh` (novo) — copia + patcha a extensão no user-dir.
- `scripts/desinstalar_pop_cosmic_ptbr.sh` (novo) — remove a cópia local.
- `docs/sprints/SPRINT_10_LAUNCHER_PTBR.md` (este arquivo).

Arquivos a modificar (mudança cirúrgica):
- `install.sh` — uma chamada não-fatal ao instalador, no bloco apropriado.
- `uninstall.sh` — uma chamada ao desinstalador antes da remoção do tema.
- `CHANGELOG.md` — uma entrada nova sob a versão em desenvolvimento.
- `docs/sprints/INDEX.md` — adicionar linha da SPRINT 10.

Arquivos NÃO tocar:
- `scripts/instalar_pop_shell_css.sh` — gerencia o CSS, não as strings; mantém soberania de subsistema (GUIDE.md §3 / SPRINT 08).
- `scripts/lib/common.sh` — sem função compartilhada nova.
- Qualquer arquivo dentro de `/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/` — esta sprint não toca o sistema.
- Qualquer outro `.js` / `.css` / `metadata.json` da extensão pop-cosmic além do `applications.js` da cópia local (próprio para o patch).

## Substituições (decisão fixa do usuário, UTF-8 obrigatório)

| # | Linha | Original (literal, com aspas) | Substituir por (literal, com aspas) |
|---|-----:|---|---|
| 1 | 211 | `'Library Home'` | `'Início'` |
| 2 | 707 | `"Create Folder"` | `"Criar pasta"` |
| 3 | 771 | `"New Folder"` | `"Nova pasta"` |
| 4 | 771 | `"Folder Name"` | `"Nome da pasta"` |
| 5 | 771 | `"Create"` | `"Criar"` |
| 6 | 779 | `"Deleting this folder will move the application icons to Library Home."` | `"Excluir esta pasta moverá os ícones para Início."` |
| 7 | 780 | `"Delete Folder?"` | `"Excluir pasta?"` |
| 8 | 780 | `"Delete"` | `"Excluir"` |
| 9 | 794 | `"Rename Folder"` | `"Renomear pasta"` |
| 10 | 794 | `"Rename"` | `"Renomear"` |

**Marca canônica de idempotência**: presença de `'Início'` (com aspas simples — substituição #1, distintiva). `instalar` e `desinstalar` se baseiam nessa marca para detectar estado.

**Estratégia para strings ambíguas (`"Create"`, `"Delete"`, `"Rename"`)**: substituir a linha inteira do construtor `CosmicFolderEditDialog(...)` em uma única operação `sed` por linha-alvo, usando contexto âncora suficiente (ex: `'new CosmicFolderEditDialog("New Folder", "Folder Name", "Create", true,'`). Isso evita substituir ocorrências dessas strings em outras posições do arquivo.

## Plano de implementação

### 1. `scripts/instalar_pop_cosmic_ptbr.sh` (novo)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Caminhos canônicos (configuráveis via env)
SYS_EXT="${POP_COSMIC_SYSTEM_DIR:-/usr/share/gnome-shell/extensions/pop-cosmic@system76.com}"
USER_EXT="${POP_COSMIC_USER_DIR:-$HOME/.local/share/gnome-shell/extensions/pop-cosmic@system76.com}"
APP_JS="$USER_EXT/applications.js"
DRACULA_DRY_RUN="${DRACULA_DRY_RUN:-0}"

# Guard 1: extensão do sistema presente?
if [[ ! -d "$SYS_EXT" ]]; then
    echo "AVISO: pop-cosmic não está instalado em $SYS_EXT — nada a fazer."
    exit 0
fi

# Guard 2: idempotência — já localizado?
if [[ -f "$APP_JS" ]] && grep -q "'Início'" "$APP_JS"; then
    echo "OK: pop-cosmic pt-BR já instalado em $USER_EXT (idempotente)."
    exit 0
fi

# Cópia recursiva (preserva timestamps e permissões)
mkdir -p "$(dirname "$USER_EXT")"
if [[ "$DRACULA_DRY_RUN" = "1" ]]; then
    echo "DRY-RUN: cp -r --preserve=timestamps,mode $SYS_EXT $USER_EXT"
else
    cp -r --preserve=timestamps,mode "$SYS_EXT" "$USER_EXT"
fi

# Aplicar substituições no applications.js da cópia local
apply_sed() {
    local pattern="$1" replacement="$2"
    if [[ "$DRACULA_DRY_RUN" = "1" ]]; then
        echo "DRY-RUN: sed -i \"s|$pattern|$replacement|\" $APP_JS"
    else
        sed -i "s|$pattern|$replacement|" "$APP_JS"
    fi
}

apply_sed "'Library Home'" "'Início'"
apply_sed 'create_button.label.text = "Create Folder";' 'create_button.label.text = "Criar pasta";'
apply_sed 'new CosmicFolderEditDialog("New Folder", "Folder Name", "Create", true,' \
          'new CosmicFolderEditDialog("Nova pasta", "Nome da pasta", "Criar", true,'
apply_sed '"Deleting this folder will move the application icons to Library Home."' \
          '"Excluir esta pasta moverá os ícones para Início."'
apply_sed 'new CosmicFolderEditDialog("Delete Folder?", desc, "Delete", false,' \
          'new CosmicFolderEditDialog("Excluir pasta?", desc, "Excluir", false,'
apply_sed 'new CosmicFolderEditDialog("Rename Folder", null, "Rename", true,' \
          'new CosmicFolderEditDialog("Renomear pasta", null, "Renomear", true,'

# Verificação pós-aplicação (dry-run pula)
if [[ "$DRACULA_DRY_RUN" != "1" ]]; then
    err=0
    for marca in "'Início'" "Criar pasta" "Nova pasta" "Nome da pasta" "Excluir pasta?" "Renomear pasta" "moverá os ícones"; do
        if ! grep -qF "$marca" "$APP_JS"; then
            echo "ERRO: marca pt-BR ausente após patch: $marca"
            err=1
        fi
    done
    if grep -qF "'Library Home'" "$APP_JS"; then
        echo "ERRO: 'Library Home' ainda presente em $APP_JS"
        err=1
    fi
    [[ $err -ne 0 ]] && exit 1
    echo "OK: pop-cosmic pt-BR instalado em $USER_EXT"
    echo "    Reinicie o GNOME Shell: Alt+F2, digite 'r', Enter (X11) ou logout/login (Wayland)."
fi
```

### 2. `scripts/desinstalar_pop_cosmic_ptbr.sh` (novo)

```bash
#!/usr/bin/env bash
set -euo pipefail

USER_EXT="${POP_COSMIC_USER_DIR:-$HOME/.local/share/gnome-shell/extensions/pop-cosmic@system76.com}"

if [[ ! -d "$USER_EXT" ]]; then
    echo "OK: nada a desinstalar (pop-cosmic pt-BR não está em $USER_EXT)."
    exit 0
fi

rm -rf "$USER_EXT"
echo "OK: pop-cosmic pt-BR removido de $USER_EXT"
echo "    GNOME Shell volta a usar a versão original do sistema após reload (Alt+F2 r)."
```

### 3. `install.sh` (modificar)

Inserir após o bloco do Pop!_Shell CSS (mesma seção condicional que já existe), seguindo o padrão de chamada não-fatal:

```bash
# ─── Pop!_Cosmic strings pt-BR (sem sudo, instalação user-local) ───
if [[ $POP_SHELL_CSS -eq 1 ]]; then
    echo ""
    _info "Localizando launcher Pop!_Cosmic em pt-BR (cópia para ~/.local/share)"
    "$REPO_ROOT/scripts/instalar_pop_cosmic_ptbr.sh" || _warn "Localização pt-BR do pop-cosmic falhou (não-fatal)"
fi
```

Decisão: acoplar a `--pop-shell-css` (Opção A do briefing) — coerente com SPRINT 02, mantém o launcher tratado como subsistema único.

### 4. `uninstall.sh` (modificar)

Inserir antes do bloco "Reverter Pop!_Shell dark.css":

```bash
# Reverter localização pt-BR do pop-cosmic se cópia local existir
if [[ -d "$HOME/.local/share/gnome-shell/extensions/pop-cosmic@system76.com" ]]; then
    echo "Removendo cópia pt-BR local do launcher Pop!_Cosmic..."
    "$REPO_ROOT/scripts/desinstalar_pop_cosmic_ptbr.sh" || true
fi
```

### 5. `CHANGELOG.md` (modificar)

Entrada nova sob `## [Unreleased]`:

```markdown
### Adicionado

- **Sprint 10 — Localização pt-BR do launcher Pop!_Cosmic**: `scripts/instalar_pop_cosmic_ptbr.sh` instala uma cópia da extensão `pop-cosmic@system76.com` em `~/.local/share/gnome-shell/extensions/` (sem sudo, com precedência user-over-system do GNOME) com strings traduzidas: `Library Home` → `Início`, `Create Folder` → `Criar pasta`, `New Folder`/`Folder Name`/`Create` → `Nova pasta`/`Nome da pasta`/`Criar`, `Delete Folder?`/`Delete` → `Excluir pasta?`/`Excluir`, `Rename Folder`/`Rename` → `Renomear pasta`/`Renomear`, e descrição do diálogo de exclusão localizada. Sobrevive a `apt upgrade pop-cosmic`. Removível via `scripts/desinstalar_pop_cosmic_ptbr.sh`.
```

### 6. `docs/sprints/INDEX.md` (modificar)

```
| 10 | [Localização pt-BR do launcher Pop!_Cosmic](SPRINT_10_LAUNCHER_PTBR.md) | Em implementação | 2026-05-07 |
```

## Acceptance criteria

1. `bash -n scripts/instalar_pop_cosmic_ptbr.sh && bash -n scripts/desinstalar_pop_cosmic_ptbr.sh` — sintaxe OK.
2. `shellcheck --severity=warning scripts/instalar_pop_cosmic_ptbr.sh scripts/desinstalar_pop_cosmic_ptbr.sh` — sem warnings.
3. Após `bash scripts/instalar_pop_cosmic_ptbr.sh` em ambiente real (sem sudo):
   - `[[ -d ~/.local/share/gnome-shell/extensions/pop-cosmic@system76.com ]]` — true.
   - `[[ -f ~/.local/share/gnome-shell/extensions/pop-cosmic@system76.com/applications.js ]]` — true.
   - `grep -c "'Library Home'" ~/.local/share/gnome-shell/extensions/pop-cosmic@system76.com/applications.js` retorna `0`.
   - `grep -c "'Início'" .../applications.js` retorna `≥ 1`.
   - `grep -c "Criar pasta" .../applications.js` retorna `≥ 1`.
   - `grep -c "Excluir pasta?" .../applications.js` retorna `≥ 1`.
   - `grep -c "Renomear pasta" .../applications.js` retorna `≥ 1`.
   - `grep -c "moverá os ícones" .../applications.js` retorna `≥ 1`.
   - O arquivo do sistema (`/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/applications.js`) **continua intocado** (`grep -c "'Library Home'"` ≥ 1 lá).
4. Idempotência: segunda execução de `instalar_pop_cosmic_ptbr.sh` não muda mtime de `~/.local/share/...applications.js` e termina com `exit 0`.
5. `bash scripts/desinstalar_pop_cosmic_ptbr.sh` remove `~/.local/share/gnome-shell/extensions/pop-cosmic@system76.com/`.
6. Validação visual (skill `validacao-visual`): screenshots após `Alt+F2 r` mostrando rótulos pt-BR no rodapé do launcher e diálogo de criar pasta.
7. `diagnostico.sh --quiet` continua exit 0 após instalação (sem regressão).

## Aritmética da mudança

- 6 invocações `sed` cobrem as 10 substituições de strings (linhas 211, 707, 771, 779, 780, 794).
- `grep -c` sobre 7 marcadores principais (`'Início'`, `Criar pasta`, `Nova pasta`, `Nome da pasta`, `Excluir pasta?`, `Renomear pasta`, `moverá os ícones`) deve somar `≥ 7` após instalação e `0` após desinstalação (todos somem com `rm -rf`).

## Invariantes a preservar

- **Acentuação pt-BR completa em UTF-8** (CLAUDE.md / GUIDE.md §1): no `applications.js` da cópia, no `CHANGELOG.md`, em comentários e nesta documentação. **Proibido** `Inicio`/`movera`/`icones`.
- **Mudança cirúrgica** (GUIDE.md §3): `install.sh` e `uninstall.sh` recebem **somente** a chamada nova; sem refatoração de código adjacente.
- **NÃO escrever em `/usr/share`**: esta sprint é estritamente user-mode. Nenhum comando deve exigir `sudo`.
- **Allowlist de paths destrutivos** (SPRINT 08): `desinstalar_pop_cosmic_ptbr.sh` faz `rm -rf` em path dentro de `$HOME/.local/share/gnome-shell/extensions/pop-cosmic@system76.com`. Caminho está dentro de `$HOME` (allowlist dinâmica) e tem UUID específico — sem risco. Se executor decidir reforçar com `validar_path_destrutivo`, é defesa em profundidade.
- **Soberania de subsistema** (SPRINT 08): nova script trata apenas localização do pop-cosmic; CSS e demais aspectos continuam em scripts separados.
- **Não-fatalidade na integração com `install.sh`** (padrão SPRINT 02 / SPRINT 03): falha do localizador não aborta o install; apenas warn.
- **Idempotência** (SPRINT 06 / SPRINT 08): re-executar não muda estado nem mtime.

## Proof-of-work runtime-real

```bash
# Pré-condição
test -d /usr/share/gnome-shell/extensions/pop-cosmic@system76.com && echo SYS_PRESENT
test ! -d ~/.local/share/gnome-shell/extensions/pop-cosmic@system76.com && echo USER_ABSENT

# Hipótese: precedência user > system (validar lendo gnome-shell se possível)
test -f /usr/share/gnome-shell/js/misc/fileUtils.js && \
    grep -n "unshift.*get_user_data_dir" /usr/share/gnome-shell/js/misc/fileUtils.js
# alternativa: gnome-shell-major-version (esperado: 42)
gnome-shell --version

# Sintaxe + lint
bash -n scripts/instalar_pop_cosmic_ptbr.sh
bash -n scripts/desinstalar_pop_cosmic_ptbr.sh
shellcheck --severity=warning scripts/instalar_pop_cosmic_ptbr.sh scripts/desinstalar_pop_cosmic_ptbr.sh

# Dry-run
DRACULA_DRY_RUN=1 bash scripts/instalar_pop_cosmic_ptbr.sh
test ! -d ~/.local/share/gnome-shell/extensions/pop-cosmic@system76.com && echo "DRY_RUN_OK"

# Instalação real (sem sudo)
bash scripts/instalar_pop_cosmic_ptbr.sh

# Verificações pós-instalação
USER_JS=~/.local/share/gnome-shell/extensions/pop-cosmic@system76.com/applications.js
SYS_JS=/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/applications.js

test -f "$USER_JS" && echo USER_JS_PRESENT
grep -c "'Library Home'" "$USER_JS"     # esperado: 0
grep -c "'Início'" "$USER_JS"           # esperado: ≥ 1
grep -c "Criar pasta" "$USER_JS"        # esperado: ≥ 1
grep -c "Nova pasta" "$USER_JS"         # esperado: ≥ 1
grep -c "Nome da pasta" "$USER_JS"      # esperado: ≥ 1
grep -c "Excluir pasta?" "$USER_JS"     # esperado: ≥ 1
grep -c "Renomear pasta" "$USER_JS"     # esperado: ≥ 1
grep -c "moverá os ícones" "$USER_JS"   # esperado: ≥ 1

# Sistema intocado
grep -c "'Library Home'" "$SYS_JS"      # esperado: ≥ 1 (intacto)

# Idempotência: segunda execução não muda mtime
mtime1=$(stat -c %Y "$USER_JS")
bash scripts/instalar_pop_cosmic_ptbr.sh
mtime2=$(stat -c %Y "$USER_JS")
test "$mtime1" = "$mtime2" && echo IDEMPOTENT || echo MUTATED   # esperado: IDEMPOTENT

# Reversão
bash scripts/desinstalar_pop_cosmic_ptbr.sh
test ! -d ~/.local/share/gnome-shell/extensions/pop-cosmic@system76.com && echo REMOVED

# Reinstalar para estado final (validação visual)
bash scripts/instalar_pop_cosmic_ptbr.sh
bash scripts/diagnostico.sh --quiet ; echo "exit=$?"   # esperado: exit=0

# Acentuação periférica nos arquivos da sprint
for f in scripts/instalar_pop_cosmic_ptbr.sh scripts/desinstalar_pop_cosmic_ptbr.sh \
         install.sh uninstall.sh CHANGELOG.md \
         docs/sprints/SPRINT_10_LAUNCHER_PTBR.md docs/sprints/INDEX.md; do
  echo "== $f =="
  grep -n -E "Inicio|movera|icones( |\\.|$)" "$f" || true
done
# esperado: nenhuma forma sem acento
```

## Validação visual (skill `validacao-visual` auto-invocada)

Após instalação:

1. **Restart do GNOME Shell**: `Alt+F2`, digitar `r`, Enter (X11 — confirmado pelo `gsettings get org.gnome.shell ...` ou pelo neofetch da máquina). Em Wayland (não é o caso aqui), seria logout/login.
2. **Screenshot 1** — launcher aberto (`Super+A`):
   - Rodapé com `Início` (não `Library Home`) e `Criar pasta` (não `Create Folder`).
3. **Screenshot 2** — diálogo de criar pasta (clicar em `Criar pasta`):
   - Título `Nova pasta`, label `Nome da pasta`, botão `Criar`.
4. **Screenshot 3 (opcional)** — diálogo de excluir pasta:
   - Título `Excluir pasta?`, descrição com `moverá os ícones para Início.`, botão `Excluir`.

Cada screenshot vai com `sha256` do PNG no relato final.

## Riscos conhecidos

- **Drift de versão da extensão (apt upgrade)**: se a System76 lançar uma atualização que mude estrutura de `applications.js`, a cópia local fica defasada (sem novas funcionalidades). Não é blocker — o launcher continua funcionando, só com a versão local. Mitigação: o `reaplicar_tema.sh` (SPRINT 06) pode ganhar uma sprint futura para detectar versão divergente entre `/usr/share` e `~/.local/share` e re-copiar.
- **`gnome-extensions` CLI**: a extensão já está habilitada no schema `org.gnome.shell.enabled-extensions`; a cópia em user-dir herda esse estado automaticamente. Não há comando explícito de habilitar.
- **Wayland**: caso a máquina mude para Wayland, restart in-place não funciona; o usuário precisa relogar. Documentado na seção visual.
- **`sed` e `?`**: em BRE, `?` é literal. Padrão `"Delete Folder?"` casa literalmente. Confirmado por `grep -F` na verificação.
- **Permissões de `~/.local/share/gnome-shell/extensions/`**: criada se ausente via `mkdir -p`. Sem permissão especial.

## Não-objetivos / Fora de escopo

- Detecção/reaplicação automática quando `apt upgrade pop-cosmic` muda a versão de origem — **SPRINT futura** (modificação em `reaplicar_tema.sh`).
- Localização das strings de outros `.js` da extensão (`overview.js`, `prefs.js`, `topBarButton.js`, `dbus_service.js`, `settings.js`).
- PR upstream (não viável: System76 declarou que i18n da extensão JS está fora de escopo).
- Tradução do COSMIC nativo (cosmic-launcher / cosmic-app-library) — fora do ambiente atual (Pop!_OS 22.04 GNOME).
- Suporte a outros idiomas além de pt-BR.

Sprints derivadas da temática inicial (mantidas no roadmap):
- **SPRINT 11** — pasta `Utilities` auto-recriada pelo launcher.
- **SPRINT 12** — ícone do botão "excluir pasta" aparecendo como lápis.
- **SPRINT 13** — ícones de jogos Steam.

## Referências

- `docs/sprints/SPRINT_02_TRANSPARENCIA.md` — precedente de patch em `pop-cosmic` (CSS, não strings).
- `docs/sprints/SPRINT_06_RESILIENCIA_POS_UPGRADE.md` — `reaplicar_tema.sh` (relevante para sprint futura de re-cópia).
- `docs/sprints/SPRINT_08_SEGURANCA_ROBUSTEZ.md` — `validar_path_destrutivo`, allowlist.
- `docs/sprints/SPRINT_09_TESTES_CI_COSMIC.md` — convenção de manifesto / shell-version.
- GNOME Shell 42, `js/misc/fileUtils.js` (`collectFromDatadirs` faz `unshift(user_data_dir)`).
- GNOME Shell 42, `js/ui/extensionSystem.js` (`_loadExtensions` descarta UUID duplicado).
- Issue [pop-os/gnome-shell-extension-pop-cosmic#22](https://github.com/pop-os/gnome-shell-extension-pop-cosmic/issues/22) — i18n da extensão JS sem caminho oficial.
- Issue [pop-os/shell#1388](https://github.com/pop-os/shell/issues/1388) — System76 redirecionou i18n para COSMIC nativo.
- `CLAUDE.md` (raiz) §1, §3 — pensar antes de codificar e mudanças cirúrgicas.

---

*"Vires acquirit eundo." — adquire forças seguindo. (Aplicado: a cada sprint o tema fica mais robusto, e desta vez ganha cidadania pt-BR no launcher sem precisar nem do `sudo`.)*
