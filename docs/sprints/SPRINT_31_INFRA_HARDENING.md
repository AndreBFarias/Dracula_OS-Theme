# Sprint 31 — Hardening de infraestrutura: vendorização, install idempotente, exceção do santuário

Um estudo completo do projeto (mapeamento de todos os subsistemas + crítica de
completude) expôs lacunas de infraestrutura que comprometiam a **portabilidade**
(bootstrap quebrado em máquina limpa), a **integração com o santuário** (delegação
ao `install.sh` falhava) e a **integridade dos artefatos** (corrupção de plugins de
terceiros pelo sanitizer de emojis). Esta sprint fecha todas elas.

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 31.
> - **Tema GTK e cursor vendorizados** em `src/gtk/` (`Dracula-standard-buttons`, 6 MB)
>   e `src/cursors/` (`Dracula-Cursor`, 2.5 MB). Antes só existiam no host; o
>   fallback do `build.sh` os copiava de `~/.local/share/themes` e `/usr/share/icons`,
>   mascarando a dependência e quebrando o `--bootstrap` em PC limpo.
> - **`santuario Dracula_OS-Theme` instala tudo**: a função delega
>   `install.sh --user --all` (idempotente). Decisão do usuário: sempre `--all`
>   completo, pulando o que já está aplicado.
> - **`--all` cobre todas as features**: passou a incluir `--apt-hook`.
> - **Idempotência sem sudo**: as etapas que pedem sudo (`pop-shell-css`, `apt-hook`)
>   checam o estado antes e pulam sem pedir senha quando já aplicadas — para a
>   delegação do santuário não travar a abertura do projeto.

## Achados (verificados no código real)

1. **`src/gtk/` e `src/cursors/` continham só `.gitkeep`** — o tema GTK e o cursor
   nunca foram versionados. Num `--bootstrap` de máquina limpa o `dist/` sairia sem
   GTK nem cursor (apenas `_warn`), e o `install.sh` ativaria `gsettings` apontando
   para temas ausentes, resultando em tema quebrado. Contradizia a promessa de
   portabilidade da SPRINT 07.
2. **`santuario` falhava no projeto**: `~/.config/zsh/functions/projeto.zsh` delegava
   `bash install.sh` **sem argumentos**; o `install.sh` exige modo, imprimia o
   `Uso:` e saía com código 1, gerando `[!] Falha ao executar install.sh` a cada
   abertura.
3. **`instalar_app_themes.sh` abortava o `--all` inteiro** com
   `_purgar_antigos: command not found` (linha 215): o script não fazia `source` de
   `lib/common.sh`, mas chamava essa função. Com `set -e`, derrubava o
   `aplicar_obsidian` e — como `install.sh` chamava o app-themes **sem `|| _warn`** —
   abortava todo o install (gimp, extensões, keybindings, apt-hook e diagnóstico
   nem rodavam).
4. **O sanitizer de emojis corrompia plugins de terceiros**: o `emoji_guardian.py`
   (rodado pelo `santuario`) varria `app-themes/obsidian/config/plugins/*/main.js` e
   removia emojis que são **dados funcionais** (mapa glifo para nome do
   `obsidian-icon-folder`; `native` com emoji do `obsidian-emoji-toolbar`), além do
   glifo de check em `content` do CSS, corrompendo os plugins silenciosamente. Mesma
   classe do bug `vendor/xterm.js` que o próprio guardian já tratava via `IGNORE_DIRS`.
5. **Órfãos e duplicatas**: `assets/screenshots/` era cópia byte-a-byte de
   `docs/assets/screenshots/` (sem referência fora do site); `src/wallpaper/xwinwrap-UPSTREAM-README.md`
   era o README bruto do upstream (atribuição curada já em `UPSTREAM-README.md`).
6. **Lacunas de app-themes**: faltava `app-themes/kitty/current-theme.conf` (o
   `aplicar_kitty` adicionava `include` de um arquivo inexistente); o README do
   OnlyOffice afirmava uma automação por `gsettings` que não existe.

## Solução

- **`src/gtk/`** e **`src/cursors/`**: vendorizados a partir do host; `.gitkeep`
  removidos; o `gnome-shell.css` vendorizado teve o bloco de overrides de build
  removido (mantida só a base; o `build.sh` re-concatena de forma idempotente).
- **`~/.config/zsh/functions/projeto.zsh`** (fora deste repo): exceção para o
  `Dracula_OS-Theme` na delegação — `bash install.sh --user --all`.
- **`install.sh`**: `--all` inclui `--apt-hook`; guards idempotentes
  (`_pop_css_ja_aplicado` via `cmp`; check de existência do hook APT) pulam o sudo
  quando já aplicado; app-themes agora é `|| _warn` (não-fatal); resumo final via
  `diagnostico.sh`; comentários e `_info` de runtime "Hidamari" corrigidos para
  xwinwrap+mpv (a linha 198 mentia ao usuário).
- **`scripts/instalar_app_themes.sh`**: passa a fazer `source lib/common.sh`
  (corrige `_purgar_antigos`).
- **`~/.config/zsh/scripts/emoji_guardian.py`** (fora deste repo):
  `EXCLUDED_PATH_SUBSTRINGS` (`/obsidian/config/plugins/`, `/.obsidian/plugins/`)
  aplicado em `scan_directory` e `clean_file` — plugins de terceiros nunca são
  varridos.
- **`app-themes/kitty/current-theme.conf`** (novo): tema Dracula oficial.
- **`app-themes/onlyoffice/README.md`**: corrigido o doc drift (ativação é manual).
- **Limpeza**: removidos `assets/screenshots/` e `src/wallpaper/xwinwrap-UPSTREAM-README.md`.
- **Plugins do Obsidian**: revertidos ao estado íntegro (`git checkout`) após a
  corrupção do sanitizer.

## Proof-of-work runtime-real (executado ao vivo)

```bash
./build.sh                                  # "Copiando cursor de src/cursors/" + "tema GTK de src/gtk/"
grep -c 'Dracula_OS-Theme overrides' dist/themes/Dracula-standard-buttons/gnome-shell/gnome-shell.css  # 1 (sem duplicar)
bash -n install.sh scripts/instalar_app_themes.sh    # sintaxe OK
zsh -n ~/.config/zsh/functions/projeto.zsh           # sintaxe OK
python3 -m py_compile ~/.config/zsh/scripts/emoji_guardian.py   # OK
python3 ~/.config/zsh/scripts/emoji_guardian.py check app-themes/obsidian/config/plugins  # "Nenhum emoji encontrado"
bash tests/test_portabilidade.sh            # OK (nenhum hardcoded apos vendorizar)
bash tests/test_diagnostico_exit_codes.sh   # OK
bash tests/test_reaplicar_idempotencia.sh   # OK
bash install.sh --user --all                # EXIT 0; completa ate o diagnostico final; pop-css/apt-hook "skip - sem sudo"
```

## Riscos conhecidos

- **`santuario` sempre roda `--all`**: por escolha do usuário, abrir o projeto dispara
  o install completo. É idempotente e os guards evitam sudo, mas etapas com rede
  (`flatpak update` do GIMP, EGO das extensões) rodam a cada abertura — custo aceito.
- **Sanitizer de emojis é infra global**: a exclusão dos plugins foi adicionada ao
  `emoji_guardian.py`; se houver teste de paridade com o `universal-sanitizer`, espelhar
  `EXCLUDED_PATH_SUBSTRINGS` lá também.
- **Vendorização aumenta o repo em ~7 MB líquidos** (8.5 MB de tema/cursor menos 1.5 MB
  da duplicata de screenshots removida) — decisão consciente por bootstrap reproduzível.

---

*"O que funciona só na minha máquina ainda não funciona." — a vendorização como contrato.*
