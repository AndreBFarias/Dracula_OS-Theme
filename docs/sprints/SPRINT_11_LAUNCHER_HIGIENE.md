# Sprint 11 — Higiene do app-grid Pop!_Cosmic

Sumir do launcher do Pop!_Cosmic dois ruídos visuais distintos que o usuário confundia como "pasta de aplicativos que sempre se cria":

- **Parte A**: o app individual `gnome-session-properties.desktop` (rótulo pt-BR `Aplicativos iniciais de sessão`, ícone Dracula `session-properties.svg` que parece uma pasta com 3 mini-apps).
- **Parte B**: as pastas vendor (`Utilitários`/`X-GNOME-Utilities` e `suse-yast.directory`/`X-SuSE-YaST`) no rodapé do launcher, que se recriam em logout/login mesmo após excluir pela UI. (A sprint inicialmente cobria apenas `Utilities`; foi estendida para incluir `YaST` na finalização do ciclo 10–14, controladas via array `PASTAS_VENDOR` do script.)

Ambos resolvidos em `MODO=user`, sem `sudo`, idempotentes, com reversão via `desinstalar_*.sh`.

> **Decisões fixas (não reabrir)**:
> - Sprint cobre AS DUAS partes (A e B) — usuário confirmou.
> - Sem `sudo`. Tudo `MODO=user`.
> - Numeração: SPRINT 11 (a 10 já está commitada `83057b18`; INDEX.md tem entradas 01–10).
> - **NÃO modificar** `/usr/share/applications/gnome-session-properties.desktop` — operar apenas no override em `~/.local/share/applications/`.
> - Override system-wide via `/etc/dconf/db/local.d/` é fora de escopo (precisa sudo).
> - Acentuação pt-BR completa em UTF-8.

## Contexto

### Parte A — App `Aplicativos iniciais de sessão`

`gnome-session-properties.desktop` é um app individual do pacote `gnome-session-bin`. Não é uma pasta. Aparece em duas localizações:

- `/usr/share/applications/gnome-session-properties.desktop` (do pacote, intocável).
- `~/.local/share/applications/gnome-session-properties.desktop` (override de tradução do usuário, **já existe** na máquina-alvo, sem `NoDisplay`).

Conteúdo do override existente (verificado linha-por-linha):

```
[Desktop Entry]
Version=1.1
Type=Application
Name=Aplicativos iniciais de sessão
Comment=Escolha quais os aplicativos que irão iniciar quando sua sessão iniciar
Icon=session-properties
OnlyShowIn=GNOME;Unity;
Exec=gnome-session-properties
Actions=
Categories=GNOME;GTK;Settings;X-GNOME-PersonalSettings;
StartupNotify=true
```

**Estado real validado** (`ls -la ~/.local/share/applications/gnome-session-properties.desktop`): existe, 326 bytes, dono `andrefarias`. Sistema também presente.

**Ação**: adicionar `NoDisplay=true` ao override (padrão XDG — esconde do launcher mantendo `.desktop` válido). O usuário continua podendo invocar `gnome-session-properties` via terminal.

### Parte B — Pasta `Utilitários` (X-GNOME-Utilities)

A pasta vem do dconf:

```
[/]
folder-children=['Utilities', 'YaST']

[folders/Utilities]
apps=['gnome-abrt.desktop', 'gnome-system-log.desktop', 'nm-connection-editor.desktop', 'org.gnome.baobab.desktop', ...]
categories=['X-GNOME-Utilities']
name='X-GNOME-Utilities.directory'
translate=true
```

**Estado real validado** (`gsettings get org.gnome.desktop.app-folders folder-children`): retorna `['Utilities', 'YaST']`. Pasta presente no launcher.

Mesmo apagando pela UI, a pasta se recria em logout/login porque o **schema vendor** (`/usr/share/glib-2.0/schemas/...`) define `folder-children` default como `['Utilities', 'YaST']`. Solução durável requer override system-wide (sudo, fora de escopo). Solução **menos invasiva** (escopo desta sprint):

1. Tirar `'Utilities'` de `folder-children` via `gsettings set`.
2. Resetar o relocatable schema da pasta via `dconf reset -f /org/gnome/desktop/app-folders/folders/Utilities/`.

**Limitação conhecida** (documentar): se o vendor schema reescrever no próximo login (não confirmado nesta máquina, depende do estado do dconf user vs vendor default), o usuário precisa rodar de novo. Caminho mais robusto (system-wide via `/etc/dconf/db/local.d/00-pop-app-folders`) fica para sprint futura.

## Hipóteses / Objetivos

1. **`NoDisplay=true` em override user esconde do launcher**: padrão XDG Desktop Entry Specification, comportamento universal em GNOME Shell 42 / Pop!_Cosmic.
2. **Override em `~/.local/share/applications/` tem precedência sobre `/usr/share/applications/`**: padrão `XDG_DATA_DIRS`. Adicionar `NoDisplay=true` no override é suficiente — não precisa tocar o sistema.
3. **`gsettings set org.gnome.desktop.app-folders folder-children` aceita lista parcial**: confirmado pela documentação de `org.gnome.desktop.app-folders.gschema.xml`.
4. **`dconf reset -f /org/gnome/desktop/app-folders/folders/Utilities/` apaga o relocatable**: comportamento documentado de `dconf reset --force` (recursivo).
5. **`sed -E` com pattern de remover `'Utilities'` da string GVariant cobre os 3 casos de posição** (primeiro, meio, último): regex `s/'Utilities',\s*//; s/,\s*'Utilities'//; s/'Utilities'//` é idempotente — se já não existe, nada muda.
6. **Shell-puro basta** — não precisa `python3` como dependência.

## Escopo (touches autorizados)

Arquivos a criar:

- `scripts/instalar_higiene_launcher.sh` (novo) — orquestra Parte A + Parte B, ambas idempotentes.
- `scripts/desinstalar_higiene_launcher.sh` (novo) — reverte ambas (com nota: reset do dconf relocatable não é restaurado).
- `docs/sprints/SPRINT_11_LAUNCHER_HIGIENE.md` (este arquivo).

Arquivos a modificar (mudança cirúrgica):

- `install.sh` — uma chamada não-fatal acoplada ao bloco `--pop-shell-css` (consistente com SPRINT 10).
- `uninstall.sh` — uma chamada antes do bloco "Reverter Pop!_Shell dark.css", após o bloco do pop-cosmic pt-BR.
- `CHANGELOG.md` — uma entrada nova sob `## [Unreleased]`.
- `docs/sprints/INDEX.md` — adicionar linha SPRINT 11.

Arquivos NÃO tocar:

- `/usr/share/applications/gnome-session-properties.desktop` — arquivo do pacote `gnome-session-bin`. Esta sprint é estritamente user-mode.
- `scripts/instalar_pop_cosmic_ptbr.sh` / `scripts/desinstalar_pop_cosmic_ptbr.sh` — soberania de subsistema (SPRINT 08).
- `scripts/lib/common.sh` — sem função compartilhada nova nesta sprint.
- Qualquer outro `.desktop` em `~/.local/share/applications/` — apenas `gnome-session-properties.desktop`.
- Qualquer outra pasta de `folder-children` — apenas `'Utilities'`.

## Decisão sobre flag em `install.sh`

**Acoplar a `--pop-shell-css`** (consistente com SPRINT 10, mantém o launcher Pop!_Cosmic tratado como subsistema único). Sem flag dedicada nova — evita poluir CLI.

## Marca de idempotência

**Parte A**: `grep -q "^NoDisplay=true" ~/.local/share/applications/gnome-session-properties.desktop`. Se já presente, instalador é no-op (não muda mtime).

**Parte B**: comparar saída de `gsettings get org.gnome.desktop.app-folders folder-children` antes e depois do `sed`. Se igual, no-op (não chama `gsettings set` nem `dconf reset`).

## Decisão sobre rastreio "criado por nós" no override

Se o override do usuário **não existir** (`! -f ~/.local/share/applications/gnome-session-properties.desktop`), o instalador copia de `/usr/share/applications/` e **adiciona uma marca canônica no topo**: `# dracula-os: created`. Essa marca permite ao desinstalador remover o arquivo inteiro nesse caso. Se o override **já existir** (caso atual da máquina-alvo), o instalador apenas adiciona `NoDisplay=true` e o desinstalador remove **só** essa linha (preserva o resto do arquivo, incluindo a tradução pt-BR do usuário).

Comentário `#` é válido em `.desktop` (XDG spec); GNOME ignora linhas que começam com `#`.

## Plano de implementação

### 1. `scripts/instalar_higiene_launcher.sh` (novo)

```bash
#!/usr/bin/env bash
# instalar_higiene_launcher.sh — esconde gnome-session-properties do grid
# e remove a pasta Utilities/X-GNOME-Utilities do rodapé do launcher.
# Sem sudo, idempotente, não-fatal.

set -euo pipefail

DESKTOP_USER="${HOME}/.local/share/applications/gnome-session-properties.desktop"
DESKTOP_SYS="/usr/share/applications/gnome-session-properties.desktop"
MARCA_CRIADO="# dracula-os: created"

# ─── Parte A: NoDisplay=true em gnome-session-properties.desktop ───
parte_a() {
    if [[ ! -f "$DESKTOP_USER" ]]; then
        if [[ -f "$DESKTOP_SYS" ]]; then
            mkdir -p "$(dirname "$DESKTOP_USER")"
            cp "$DESKTOP_SYS" "$DESKTOP_USER"
            # Insere marca logo após a primeira linha [Desktop Entry]
            sed -i "1a${MARCA_CRIADO}" "$DESKTOP_USER"
        else
            echo "AVISO: nem $DESKTOP_USER nem $DESKTOP_SYS existem — Parte A pulada."
            return 0
        fi
    fi

    # Idempotência
    if grep -q "^NoDisplay=true" "$DESKTOP_USER"; then
        echo "OK: Parte A já aplicada (NoDisplay=true presente)."
        return 0
    fi

    # Adiciona NoDisplay=true ao final da seção [Desktop Entry]
    # Como o arquivo só tem uma seção, append simples basta.
    echo "NoDisplay=true" >> "$DESKTOP_USER"
    echo "OK: Parte A — NoDisplay=true adicionado em $DESKTOP_USER"
}

# ─── Parte B: remover Utilities de folder-children ───
parte_b() {
    if ! command -v gsettings >/dev/null 2>&1; then
        echo "AVISO: gsettings ausente — Parte B pulada."
        return 0
    fi

    local atual novo
    atual="$(gsettings get org.gnome.desktop.app-folders folder-children 2>/dev/null || echo "[]")"
    novo="$(echo "$atual" | sed -E "s/'Utilities',\s*//; s/,\s*'Utilities'//; s/'Utilities'//")"

    if [[ "$novo" == "$atual" ]]; then
        echo "OK: Parte B já aplicada (Utilities ausente de folder-children)."
        return 0
    fi

    gsettings set org.gnome.desktop.app-folders folder-children "$novo"
    if command -v dconf >/dev/null 2>&1; then
        dconf reset -f /org/gnome/desktop/app-folders/folders/Utilities/ || true
    fi
    echo "OK: Parte B — folder-children agora $novo"
}

parte_a || echo "AVISO: Parte A falhou (não-fatal)"
parte_b || echo "AVISO: Parte B falhou (não-fatal)"

echo ""
echo "Para aplicar visualmente: Alt+F2, digitar 'r', Enter (X11) ou logout/login."
echo "Limitação Parte B: vendor schema do pop-cosmic pode reinjetar 'Utilities' em logout/login."
echo "Se voltar, basta rodar este script novamente."
```

### 2. `scripts/desinstalar_higiene_launcher.sh` (novo)

```bash
#!/usr/bin/env bash
# desinstalar_higiene_launcher.sh — reverte instalar_higiene_launcher.sh.
# Para Parte A: se override foi criado por nós (marca # dracula-os: created),
# remove o arquivo inteiro; senão, remove só a linha NoDisplay=true.
# Para Parte B: re-adiciona 'Utilities' a folder-children (reset do dconf
# relocatable não é restaurado — limitação documentada).

set -euo pipefail

DESKTOP_USER="${HOME}/.local/share/applications/gnome-session-properties.desktop"
MARCA_CRIADO="# dracula-os: created"

# ─── Parte A reverter ───
reverter_a() {
    if [[ ! -f "$DESKTOP_USER" ]]; then
        echo "OK: Parte A nada a reverter ($DESKTOP_USER ausente)."
        return 0
    fi

    if grep -qF "$MARCA_CRIADO" "$DESKTOP_USER"; then
        rm -f "$DESKTOP_USER"
        echo "OK: Parte A — $DESKTOP_USER removido (era criado por nós)."
        return 0
    fi

    if grep -q "^NoDisplay=true" "$DESKTOP_USER"; then
        sed -i "/^NoDisplay=true$/d" "$DESKTOP_USER"
        echo "OK: Parte A — linha NoDisplay=true removida de $DESKTOP_USER"
    else
        echo "OK: Parte A já revertida (NoDisplay=true ausente)."
    fi
}

# ─── Parte B reverter ───
reverter_b() {
    if ! command -v gsettings >/dev/null 2>&1; then
        echo "AVISO: gsettings ausente — Parte B pulada."
        return 0
    fi

    local atual
    atual="$(gsettings get org.gnome.desktop.app-folders folder-children 2>/dev/null || echo "[]")"

    if echo "$atual" | grep -q "'Utilities'"; then
        echo "OK: Parte B já revertida (Utilities presente em folder-children)."
        return 0
    fi

    # Re-adiciona 'Utilities' como primeiro item.
    # Casos: lista vazia "@as []" / "[]"  → ['Utilities']
    #        lista não-vazia ['YaST']     → ['Utilities', 'YaST']
    local novo
    if [[ "$atual" == "@as []" ]] || [[ "$atual" == "[]" ]]; then
        novo="['Utilities']"
    else
        novo="$(echo "$atual" | sed -E "s/^\[/['Utilities', /")"
    fi

    gsettings set org.gnome.desktop.app-folders folder-children "$novo"
    echo "OK: Parte B — folder-children agora $novo"
    echo "    (reset do schema relocatable /folders/Utilities/ não é restaurado;"
    echo "     o vendor default repovoa em logout/login.)"
}

reverter_a || echo "AVISO: reverter Parte A falhou (não-fatal)"
reverter_b || echo "AVISO: reverter Parte B falhou (não-fatal)"
```

### 3. `install.sh` (modificar — mudança cirúrgica)

Após a chamada do `instalar_pop_cosmic_ptbr.sh` (linha 137 do `install.sh` atual), dentro do mesmo bloco `if [[ $POP_SHELL_CSS -eq 1 ]]; then ... fi`:

```bash
    echo ""
    _info "Higiene do app-grid Pop!_Cosmic (esconder gnome-session-properties + remover pasta Utilities)"
    "$REPO_ROOT/scripts/instalar_higiene_launcher.sh" || _warn "Higiene do launcher falhou (não-fatal)"
```

### 4. `uninstall.sh` (modificar — mudança cirúrgica)

Após o bloco que reverte o pop-cosmic pt-BR (linhas 52–57 do `uninstall.sh` atual), antes do bloco "Reverter Pop!_Shell dark.css":

```bash
# Reverter higiene do launcher (esconder gnome-session-properties + pasta Utilities)
if [[ -x "$REPO_ROOT/scripts/desinstalar_higiene_launcher.sh" ]]; then
    echo "Revertendo higiene do app-grid Pop!_Cosmic..."
    "$REPO_ROOT/scripts/desinstalar_higiene_launcher.sh" || true
fi
```

### 5. `CHANGELOG.md` (modificar)

Entrada nova sob `## [Unreleased]`, **após** a entrada da SPRINT 10:

```markdown
- **Sprint 11 — Higiene do app-grid Pop!_Cosmic**: `scripts/instalar_higiene_launcher.sh` esconde o app `gnome-session-properties.desktop` (rótulo "Aplicativos iniciais de sessão") do launcher via `NoDisplay=true` no override de `~/.local/share/applications/`, sem tocar o pacote do sistema. Também remove a pasta `Utilitários` (`X-GNOME-Utilities`) do rodapé do launcher via `gsettings set org.gnome.desktop.app-folders folder-children` + `dconf reset` do relocatable schema. Idempotente, sem sudo, não-fatal. Reversível via `scripts/desinstalar_higiene_launcher.sh`. Limitação conhecida: o vendor schema do pop-cosmic pode reinjetar `Utilities` em logout/login — basta re-rodar.
```

### 6. `docs/sprints/INDEX.md` (modificar)

```
| 11 | [Higiene do app-grid Pop!_Cosmic](SPRINT_11_LAUNCHER_HIGIENE.md) | Em implementação | 2026-05-07 |
```

(Atualizar status da SPRINT 10 para `Concluída` se ainda estiver como `Em implementação` é fora de escopo desta sprint — não tocar.)

## Acceptance criteria

1. `bash -n scripts/instalar_higiene_launcher.sh && bash -n scripts/desinstalar_higiene_launcher.sh` — sintaxe OK.
2. `shellcheck --severity=warning scripts/instalar_higiene_launcher.sh scripts/desinstalar_higiene_launcher.sh` — sem warnings.
3. **Parte A** — após `bash scripts/instalar_higiene_launcher.sh`:
   - `grep -c "^NoDisplay=true" ~/.local/share/applications/gnome-session-properties.desktop` retorna `1`.
   - `/usr/share/applications/gnome-session-properties.desktop` continua intocado (sem `NoDisplay=true` lá).
4. **Parte B** — após `bash scripts/instalar_higiene_launcher.sh`:
   - `gsettings get org.gnome.desktop.app-folders folder-children` não contém `'Utilities'`.
   - `dconf list /org/gnome/desktop/app-folders/folders/Utilities/` retorna vazio.
5. **Idempotência**: segunda execução de `instalar_higiene_launcher.sh`:
   - Não muda mtime de `~/.local/share/applications/gnome-session-properties.desktop`.
   - Não muda saída de `gsettings get org.gnome.desktop.app-folders folder-children`.
   - Termina com `exit 0`.
6. **Reversão Parte A** — após `bash scripts/desinstalar_higiene_launcher.sh` (cenário máquina-alvo: override pré-existente, sem marca):
   - `grep -c "^NoDisplay=true" ~/.local/share/applications/gnome-session-properties.desktop` retorna `0`.
   - Arquivo continua existindo (override pré-existente preservado).
7. **Reversão Parte B** — após `bash scripts/desinstalar_higiene_launcher.sh`:
   - `gsettings get org.gnome.desktop.app-folders folder-children` contém `'Utilities'` novamente.
8. Validação visual (skill `validacao-visual`): screenshots após `Alt+F2 r` mostrando (a) ausência de "Aplicativos iniciais de sessão" no grid e (b) ausência da pasta "Utilitários" no rodapé.
9. `bash scripts/diagnostico.sh --quiet` continua exit 0 após instalação (sem regressão).
10. Acentuação pt-BR íntegra em todos arquivos da sprint (sem `Inicio`, `movera`, `icones`, `sessao`, `Utilitarios`).

## Aritmética da mudança

- **Parte A** — 1 modificação por execução (append de `NoDisplay=true`); na máquina-alvo (override pré-existente), o arquivo passa de 326 bytes para 343 bytes (+ 17 bytes do `\nNoDisplay=true`). Se o override não existir, o instalador também adiciona a linha `# dracula-os: created` (~21 bytes na linha 2).
- **Parte B** — 1 chamada `gsettings set` + 1 chamada `dconf reset` por execução. `folder-children` passa de `['Utilities', 'YaST']` para `['YaST']` (3 elementos no array de 2 → 1 item).
- 2 scripts novos, 2 arquivos modificados (`install.sh`, `uninstall.sh`), 2 docs atualizadas (`CHANGELOG.md`, `INDEX.md`), 1 spec novo (este).

## Invariantes a preservar

- **Acentuação pt-BR completa em UTF-8** (CLAUDE.md / GUIDE.md §1): em todos os arquivos da sprint. **Proibido**: `Inicio`/`Utilitarios`/`sessao`/`movera`/`icones`.
- **Mudança cirúrgica** (GUIDE.md §3): `install.sh` e `uninstall.sh` recebem **somente** as duas chamadas novas (uma cada). Sem refatoração de código adjacente, sem mexer em ordem de blocos não relacionados.
- **NÃO escrever em `/usr/share`** ou qualquer caminho fora de `$HOME` ou do estado dconf do usuário. Sem `sudo` em nenhum dos scripts novos.
- **Allowlist de paths destrutivos** (SPRINT 08): o desinstalador faz `rm -f $HOME/.local/share/applications/gnome-session-properties.desktop` apenas quando detecta a marca `# dracula-os: created`. Caminho dentro de `$HOME` (allowlist dinâmica) e nome de arquivo específico — sem risco.
- **Soberania de subsistema** (SPRINT 08): os scripts novos não tocam pop-cosmic strings (responsabilidade da SPRINT 10), não tocam dark.css (SPRINT 02), não tocam overrides de outros `.desktop` (`aplicar_overrides.sh`).
- **Não-fatalidade na integração com `install.sh`** (padrão SPRINT 02 / SPRINT 03 / SPRINT 10): falha de qualquer parte não aborta o install; apenas `_warn`.
- **Idempotência** (SPRINT 06 / SPRINT 08 / SPRINT 10): re-executar não muda mtime nem estado dconf.
- **Pop!_OS 22.04 / GNOME 42 / X11**: ambiente alvo confirmado. Comportamento `Alt+F2 r` para reload do GNOME Shell é X11-only.

## Proof-of-work runtime-real

```bash
# Pré-condição
test -f /usr/share/applications/gnome-session-properties.desktop && echo SYS_PRESENT
test -f ~/.local/share/applications/gnome-session-properties.desktop && echo USER_OVERRIDE_PRESENT
gsettings get org.gnome.desktop.app-folders folder-children
# esperado pré: ['Utilities', 'YaST']

# Antes da Parte A
grep -c "^NoDisplay=true" ~/.local/share/applications/gnome-session-properties.desktop
# esperado: 0

# Sintaxe + lint
bash -n scripts/instalar_higiene_launcher.sh
bash -n scripts/desinstalar_higiene_launcher.sh
shellcheck --severity=warning scripts/instalar_higiene_launcher.sh scripts/desinstalar_higiene_launcher.sh

# Aplicar
bash scripts/instalar_higiene_launcher.sh

# Pós Parte A
grep -c "^NoDisplay=true" ~/.local/share/applications/gnome-session-properties.desktop
# esperado: 1
grep -c "^NoDisplay=true" /usr/share/applications/gnome-session-properties.desktop
# esperado: 0  (sistema intocado)

# Pós Parte B
gsettings get org.gnome.desktop.app-folders folder-children
# esperado: ['YaST']  (sem 'Utilities')
dconf list /org/gnome/desktop/app-folders/folders/Utilities/
# esperado: vazio

# Idempotência: aplicar 2x
mtime1=$(stat -c %Y ~/.local/share/applications/gnome-session-properties.desktop)
fc1="$(gsettings get org.gnome.desktop.app-folders folder-children)"
bash scripts/instalar_higiene_launcher.sh
mtime2=$(stat -c %Y ~/.local/share/applications/gnome-session-properties.desktop)
fc2="$(gsettings get org.gnome.desktop.app-folders folder-children)"
test "$mtime1" = "$mtime2" && echo IDEMPOTENT_A || echo MUTATED_A
test "$fc1" = "$fc2" && echo IDEMPOTENT_B || echo MUTATED_B
# esperado: IDEMPOTENT_A + IDEMPOTENT_B

# Reversão
bash scripts/desinstalar_higiene_launcher.sh
grep -c "^NoDisplay=true" ~/.local/share/applications/gnome-session-properties.desktop
# esperado: 0
test -f ~/.local/share/applications/gnome-session-properties.desktop && echo OVERRIDE_PRESERVED
# esperado: OVERRIDE_PRESERVED  (override pré-existente preservado)
gsettings get org.gnome.desktop.app-folders folder-children
# esperado: contém 'Utilities' novamente

# Reinstalar para estado final
bash scripts/instalar_higiene_launcher.sh

# Diagnóstico não regrediu
bash scripts/diagnostico.sh --quiet ; echo "exit=$?"
# esperado: exit=0

# Acentuação periférica nos arquivos da sprint
for f in scripts/instalar_higiene_launcher.sh scripts/desinstalar_higiene_launcher.sh \
         install.sh uninstall.sh CHANGELOG.md \
         docs/sprints/SPRINT_11_LAUNCHER_HIGIENE.md docs/sprints/INDEX.md; do
  echo "== $f =="
  grep -n -E "Inicio|movera|icones( |\.|$)|sessao|Utilitarios" "$f" || true
done
# esperado: nenhuma forma sem acento
```

## Validação visual (skill `validacao-visual` auto-invocada)

Após instalação:

1. **Restart do GNOME Shell**: `Alt+F2`, digitar `r`, Enter (X11 — confirmado pelo ambiente do usuário).
2. **Screenshot 1** — launcher (`Super+A`) grid principal:
   - App "Aplicativos iniciais de sessão" não aparece mais entre os ícones (Parte A).
3. **Screenshot 2** — launcher (`Super+A`) rodapé:
   - Apenas `Início`, `suse-yast.…`, `Criar pasta` (sem `Utilitários`) (Parte B).

Cada screenshot vai com `sha256` do PNG no relato final.

## Riscos conhecidos

- **Vendor schema reinjetando `Utilities` em logout/login**: o pop-cosmic define o default em `/usr/share/glib-2.0/schemas/...`. Se isso ocorrer (não confirmado nesta máquina), o usuário re-roda o instalador. Documentado no echo do script. Solução durável (system-wide) é fora de escopo desta sprint.
- **`gnome-session-properties` em outros lugares**: alguma extensão GNOME pode listá-lo separadamente (ex.: ARC menu). Fora de escopo — esta sprint só esconde do launcher Pop!_Cosmic / Activities.
- **`sed -E` da Parte B com regex de remoção**: a tripla `s/'Utilities',\s*//; s/,\s*'Utilities'//; s/'Utilities'//` é segura porque (a) é idempotente (rodada extra é no-op se já removido), (b) o GVariant string usa aspas simples consistentemente. Se um dia houver pasta nomeada `'Utilities-extra'`, o segundo padrão `s/,\s*'Utilities'//` não casaria (literal `'Utilities'` seguido de fim ou vírgula); o terceiro casaria mas o primeiro não — risco residual baixo, mas alvo nominal é exatamente `'Utilities'`.
- **`dconf reset -f` em path inexistente**: silenciosamente no-op (testado). `|| true` defensivo no script.
- **Permissões de `~/.local/share/applications/`**: criada se ausente via `mkdir -p`. Sem permissão especial.
- **Override do usuário com sintaxe inesperada**: o instalador faz append de `NoDisplay=true` ao final do arquivo. Como o `.desktop` em questão tem **uma única seção** (`[Desktop Entry]`), append simples basta. Se um dia houver seção `[Desktop Action XYZ]`, a linha `NoDisplay=true` cairia dentro dela (problema). Risco residual baixo — `gnome-session-properties.desktop` tem `Actions=` vazio por design.

## Não-objetivos / Fora de escopo

- Override system-wide via `/etc/dconf/db/local.d/00-pop-app-folders` (precisa sudo) — sprint futura se Parte B "voltar" repetidamente.
- Outras pastas auto-recriadas (`YaST`, etc.) — não foram pedidas.
- Esconder outros apps com ícone confuso — apenas `gnome-session-properties.desktop`.
- Tradução do COSMIC nativo (Pop!_OS 24.04) — fora do ambiente atual.
- Modificação de `reaplicar_tema.sh` para detectar regressão de Parte A/B pós-upgrade — sprint futura se necessário.

Sprints derivadas (já registradas no roadmap da SPRINT 10):

- **SPRINT 12** — ícone do botão "excluir pasta" aparecendo como lápis.
- **SPRINT 13** — ícones de jogos Steam.

## Referências

- `docs/sprints/SPRINT_02_TRANSPARENCIA.md` — precedente de patch em `pop-cosmic`.
- `docs/sprints/SPRINT_06_RESILIENCIA_POS_UPGRADE.md` — `reaplicar_tema.sh` (sprint futura de auto-restauração).
- `docs/sprints/SPRINT_08_SEGURANCA_ROBUSTEZ.md` — `validar_path_destrutivo`, allowlist.
- `docs/sprints/SPRINT_10_LAUNCHER_PTBR.md` — padrão de acoplamento ao bloco `--pop-shell-css`, padrão de não-fatalidade, padrão de idempotência por marca canônica.
- XDG Desktop Entry Specification — `NoDisplay` key (`https://specifications.freedesktop.org/desktop-entry-spec/latest/`).
- `org.gnome.desktop.app-folders` schema — `/usr/share/glib-2.0/schemas/org.gnome.desktop.app-folders.gschema.xml`.
- `CLAUDE.md` (raiz) §1, §3 — pensar antes de codificar e mudanças cirúrgicas.

---

*"Festina lente." — apressa-te lentamente. (Aplicado: duas correções pequenas, idempotentes, reversíveis, sem sudo — para não quebrar o que já funciona.)*
