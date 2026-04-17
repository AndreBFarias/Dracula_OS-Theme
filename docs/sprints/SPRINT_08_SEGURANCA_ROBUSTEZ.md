# Sprint 08 — Segurança e robustez dos scripts

Torna impossível deixar o sistema em estado inconsistente por falha parcial. Toda operação destrutiva valida o destino, todo backup é verificado por checksum antes do `rm -rf` seguinte.

## Contexto

Auditoria revelou três classes de risco nos scripts existentes:

1. **`rm -rf` sem validação defensiva do destino** — `uninstall.sh:33-36` e `limpar_duplicatas.sh:73-77` confiam que variáveis como `$DEST_ICONS` estão corretas. Se corrompidas, `rm -rf "/$tema"` (com `DEST_ICONS=""`) vira `rm -rf /`.
2. **Backups sem verificação de integridade** — `limpar_duplicatas.sh` fazia `cp ... || _warn "falhou" && rm -rf`. Se `cp` falhasse silenciosamente (disco cheio, permissão), o `rm -rf` depois perdia os dados.
3. **Idempotência frágil do kitty include** — `grep -q "^include current-theme.conf"` aceitava qualquer linha começando com isso; múltiplas execuções podiam acumular duplicatas ou colidir com edições do usuário.

## Entregas

### Expansão do `scripts/lib/common.sh`

Três funções novas (além do stub de logging da SPRINT_06):

#### `validar_path_destrutivo <path>`

Aborta o script se `<path>` (resolvido via `readlink -m`, sem seguir symlinks inseguros) não estiver na allowlist:

```
$HOME/.local/share/{icons,themes,applications,sounds,gnome-shell/extensions}
$HOME/.icons
$HOME/.themes
$HOME/.cache/dracula_os_theme
$HOME/.cache/dracula_os_backup
/usr/share/{icons,themes,sounds,gnome-shell/extensions}
/tmp/dracula_os_theme
```

Rejeita explicitamente `/`, `/home`, `$HOME` puro, qualquer path vazio. Testado com 7 cenários (4 pass, 3 fail) — todos corretos.

**Invariante:** `rm -rf` em path fora dessa allowlist é proibido em qualquer script do projeto.

#### `trap_cleanup_init <função>`

Registra `trap` para `EXIT`, `INT`, `TERM`. A função de cleanup recebe o exit code e pode reverter estado parcial. Substitui o padrão atual (sem trap) que deixava scripts abortando no meio com estado sujo.

#### `backup_com_manifest <origem> <destino_dir>`

Copia origem (arquivo ou diretório) para `destino_dir/` E gera `destino_dir/<nome>.sha256` com checksums de todos os arquivos. Ao final, executa `sha256sum -c` na cópia — se algum hash não bate, a função retorna não-zero e o chamador deve **abortar** o `rm -rf` pendente.

### Modificações nos scripts existentes

- **`uninstall.sh`** — source `scripts/lib/common.sh`; antes de `rm -rf` nos loops de ícones/temas, chama `validar_path_destrutivo` e continua só se validou.
- **`scripts/limpar_duplicatas.sh`** — substitui `cp ... && rm -rf` por `backup_com_manifest && validar_path_destrutivo && rm -rf`. Move `BACKUP_DIR` para `$HOME/.cache/dracula_os_backup/$TS` (antes era `dracula_os_backup_$TS` solto) para ficar sob allowlist e agrupado.
- **`scripts/instalar_app_themes.sh:46-57`** — reescreve check do kitty include: `grep -Fxq "include current-theme.conf"` (match exato, linha inteira). Garante que arquivo termina com newline antes de anexar. **Verificado:** rodando 2x consecutivas, `kitty.conf` mantém exatamente 1 linha de include.

## Verificação end-to-end executada

1. **Sintaxe bash** — `bash -n` em `lib/common.sh`, `uninstall.sh`, `limpar_duplicatas.sh`, `instalar_app_themes.sh` passou.
2. **`validar_path_destrutivo` em 7 cenários:**
   - ✅ aceita `$HOME/.local/share/icons/Dracula-Icones`, `/usr/share/gnome-shell/extensions/pop-shell@system76.com`.
   - ✅ rejeita `/tmp/qualquer`, `/`, `$HOME` puro, `$HOME/Documentos`, string vazia.
3. **`backup_com_manifest`** — cria cópia + `.sha256`, validação sha256sum -c passa.
4. **Idempotência kitty** — `instalar_app_themes.sh` rodado 2x em sequência; `grep -c "^include current-theme.conf$" ~/.config/kitty/kitty.conf` = 1.
5. **`diagnostico.sh --quiet`** após todas as mudanças continua exit 0.

## Pontos de contribuição do usuário (learning mode)

1. **Allowlist de paths destrutivos em `lib/common.sh`** (array `_allowlist_destrutiva`, linhas ~51-67): é a superfície de segurança do projeto. Quer adicionar algum caminho (por exemplo `$HOME/.var/app` se em algum momento for limpar arquivos Flatpak)? Remover algum (por exemplo `/usr/share/sounds` se nunca deletar temas de som sistêmicos)?
2. **Função de cleanup por script** (via `trap_cleanup_init`): ainda não está aplicada em nenhum script individual. Candidatos óbvios para adicionar: `instalar_keybindings.sh` (restaurar backup dconf se interrompido), `instalar_pop_shell_css.sh` (se `cp` falha no meio, reverter `.orig` antes de sair). Quer priorizar algum?

## Riscos conhecidos

- `readlink -m` resolve symlinks — se um atacante plantar symlink `$HOME/.local/share/icons/Dracula-Icones → /etc`, a validação falha (rejeitaria `/etc`). Defesa correta, mas cenário real improvável em sistema single-user.
- Backup em `$HOME/.cache/dracula_os_backup/` cresce ao longo do tempo; nenhuma rotação automática. Proposta para SPRINT_09: limpar backups > 30 dias em `reaplicar_tema.sh`.
- Trap registrado via `trap_cleanup_init` é sobrescrito se o script redefinir `trap` depois. Boa prática: chamar `trap_cleanup_init` o mais tarde possível no fluxo de inicialização.

## Referências

- Meta-regra §9.3 "Soberania de subsistema" (CLAUDE.md) — justificativa para allowlist restrita.
- Padrão "Graceful Degradation" (CLAUDE.md §8) — cleanup em trap cumpre esse princípio.

---

*"Cave quid dicis, quando et cui." — cuidado com o que dizes, quando e a quem. (Aplicado a scripts que tocam o sistema: cuidado com o que remove, quando e onde.)*
