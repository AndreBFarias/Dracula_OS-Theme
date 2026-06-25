# Sprint 26 — Captura da config completa do Obsidian (settings + plugins)

Versionar a configuração completa do Obsidian do usuário (settings, hotkeys, snippets, themes e os **plugins de terceiros**) como padrão do projeto, e fazer o instalador aplicá-la em cada vault. Antes, só o tema CSS (`Dracula.theme.css`) era distribuído.

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 26.
> - **Escopo "tudo, inclusive o código dos plugins"** (escolha explícita do usuário, ciente de que o repo é público): captura todo o `.obsidian/` **exceto** os arquivos voláteis de sessão (`workspace.json`, `workspace-mobile.json`).
> - **Hook de tamanho desativado** (a pedido do usuário): `check-added-large-files` removido do `.pre-commit-config.yaml` — o projeto versiona mídia grande de propósito (vídeo do wallpaper + `quickadd/main.js` > 4 MB).
> - **Sem sudo**. Sem segredos: no host de captura, os `apiKey` dos plugins estavam vazios (verificado).

## Contexto

- Obsidian Flatpak (`md.obsidian.Obsidian`), vault `Controle de Bordo`.
- `.obsidian/` = **15 MB**, dos quais ~15 MB em `plugins/` (35 plugins).
- `aplicar_obsidian()` antigo só copiava `theme.css` + `manifest.json` para `<vault>/.obsidian/themes/Dracula`.

## Solução

1. Novo `scripts/capturar_obsidian.sh` (ferramenta de maintainer): detecta o vault via `obsidian.json` e espelha `<vault>/.obsidian/` → `app-themes/obsidian/config/` (rsync `--delete`), excluindo `workspace.json`/`workspace-mobile.json`.
2. `app-themes/obsidian/config/` versionado: **119 arquivos, 35 plugins** + `app.json`, `appearance.json`, `hotkeys.json`, `core-plugins.json`, `community-plugins.json`, `snippets/` (inclui `dracula_background.css`), `themes/`, etc.
3. `aplicar_obsidian()` (`instalar_app_themes.sh`) estendido: além do tema, faz **backup** do `.obsidian` existente em `~/.cache/dracula_os_backup/obsidian_<ts>/` (retém 10 via `_purgar_antigos`) e copia `config/.` → `<vault>/.obsidian/`, preservando o `workspace.json` do vault (não está na captura). Pular com `DRACULA_OBSIDIAN_SKIP_CONFIG=1`.
4. Hook `check-added-large-files` desativado.

## Escopo (touches autorizados)

- `scripts/capturar_obsidian.sh` — novo.
- `scripts/instalar_app_themes.sh` — `aplicar_obsidian()` estendido (deploy de config + backup).
- `.pre-commit-config.yaml` — remove `check-added-large-files`.
- `app-themes/obsidian/config/` — config capturada (119 arquivos).
- `CHANGELOG.md`, `docs/sprints/INDEX.md`, `docs/sprints/SPRINT_26_OBSIDIAN_CONFIG.md`.

## Privacidade / licenciamento (decisão informada do usuário)

O repo é público. A captura inclui:
- **Código de 35 plugins de terceiros** (redistribuição; nenhum trazia arquivo da blacklist anti-IA, `.git` aninhado ou trailer de IA — verificado, então a CI `anonymity-check` não quebra).
- **Dados do vault** (`bookmarks.json`, nomes de notas/templates de trabalho) — expostos por escolha do usuário.
- **Sem segredos**: `apiKey`/tokens vazios (verificado por scan).
- **Excluídos**: `workspace.json`, `workspace-mobile.json` (estado volátil de sessão).

## Proof-of-work

```bash
bash -n scripts/capturar_obsidian.sh scripts/instalar_app_themes.sh   # sintaxe OK
bash scripts/capturar_obsidian.sh
# => Capturado: 119 arquivos, 35 plugins ; voláteis (workspace*.json) ausentes
du -sh app-themes/obsidian/config        # 15M
ls app-themes/obsidian/config/plugins | wc -l   # 35
```

Deploy (`aplicar_obsidian`): backup do `.obsidian` + `cp -a config/. → vault/.obsidian/`, `workspace.json` preservado. Integra via `install.sh --app-themes`/`--all`.

## Riscos conhecidos

- **Re-captura**: `rsync --delete` mantém o repo idêntico ao vault — rode `capturar_obsidian.sh` após mudar a config para atualizar o padrão versionado.
- **Plugins desatualizados**: o código bundlado congela a versão; atualizações de plugin no Obsidian do usuário só entram no repo via nova captura.
- **Deploy invasivo**: sobrescreve a config do vault-alvo; mitigado por backup automático e `DRACULA_OBSIDIAN_SKIP_CONFIG=1`.

---

*"O mesmo cofre de anotações em qualquer máquina." — config reproduzível, não só o tema.*
