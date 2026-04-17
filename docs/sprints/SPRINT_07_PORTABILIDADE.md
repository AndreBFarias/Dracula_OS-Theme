# Sprint 07 — Portabilidade universal

Outro PC Pop!_OS (22.04 ou 24.04) consegue reproduzir o tema com um único comando após `git clone`. Zero caminhos hardcoded do user original no código versionado.

## Contexto

Auditoria pré-sprint identificou três obstáculos à portabilidade:

1. **1 hardcoded `/home/andrefarias/` versionado** em `scripts/limpar_duplicatas.sh:100` (corrigido como efeito colateral da SPRINT_08).
2. **Path fixo `$HOME/Desenvolvimento/Spellbook-OS/`** em `instalar_app_themes.sh:92` — em outro PC onde Spellbook está em outro lugar (ou ausente), Spicetify ficava silenciosamente pulado.
3. **Nenhuma validação de pré-requisitos** — se faltasse `jq` ou `rsvg-convert`, `build.sh` quebrava com mensagem críptica no meio do pipeline.

## Entregas

### `scripts/checar_ambiente.sh` (doctor, read-only)

Verifica antes de qualquer operação:

- **Binários críticos**: `bash`, `python3`, `jq`, `gtk-update-icon-cache`, `dconf`, `gsettings`, `gnome-extensions`, `git`, `curl`, `unzip`, `sha256sum`, `readlink`.
- **Ao menos um conversor SVG→PNG**: `rsvg-convert`, `inkscape`, `magick` ou `convert`.
- **Versões mínimas**: Python ≥ 3.10, GNOME Shell ≥ 42.
- **Distribuição**: `lsb_release -si` deve ser `Pop`, release 22.04 ou 24.04 (warn em outros).
- **Desktop atual**: reporta `$XDG_CURRENT_DESKTOP` (`pop:GNOME`, `COSMIC`, etc.).

Para cada binário faltante, mapeia para o pacote apt correspondente e **imprime a linha `sudo apt install <pkgs>` pronta para copiar**.

Exit 0 = pode rodar `build.sh`. Exit 1 = dependência/versão bloqueando.

### `install.sh --bootstrap` (rota completa)

Orquestra a instalação inteira em um comando, para máquina limpa:

```bash
git clone <repo>
cd Dracula_OS-Theme
./install.sh --bootstrap
```

Sequência interna:

1. `scripts/checar_ambiente.sh` — se falhar, aborta com lista de `apt install`.
2. `scripts/baixar_upstreams.sh` — clone shallow dos temas upstream.
3. `./build.sh` — gera `dist/`.
4. `./install.sh --user --all` — instala tudo (ícones, tema, apps, pop-shell CSS, sons, keybindings, extensões GNOME).

### Correções de hardcoded

- **`scripts/limpar_duplicatas.sh:100`** — `Icon=/home/andrefarias/.icons/Dracula-Icones` → `Icon=$HOME/.icons/Dracula-Icones`.
- **`scripts/instalar_app_themes.sh`** — nova função `_buscar_spicetify_setup` tenta quatro locais em ordem:
  1. `$REPO_ROOT/../Spellbook-OS/scripts/spicetify-setup.sh` (irmão do Dracula_OS-Theme)
  2. `$HOME/Desenvolvimento/Spellbook-OS/...`
  3. `${XDG_DATA_HOME:-$HOME/.local/share}/Spellbook-OS/...`
  4. `/opt/Spellbook-OS/...`

  Se nenhum bate, faz skip **com warning descritivo** listando os quatro locais testados (antes era warn genérico "não encontrado").

## Verificação end-to-end executada

1. **`./scripts/checar_ambiente.sh`** em Pop!_OS 22.04 atual → exit 0, todos os binários presentes, GNOME Shell 42.9 OK, Python 3.12 OK.
2. **`./install.sh --bootstrap`** com sintaxe validada (`bash -n`); não executado end-to-end porque o tema já está instalado.
3. **`grep -rE "/home/andrefarias" --include="*.sh" --include="*.json" Dracula_OS-Theme/`** (excluindo `docs/`): zero matches em código versionado.
4. Sintaxe bash de todos os scripts tocados passa em `bash -n`.

## Pontos de contribuição do usuário (learning mode)

1. **Lista de pacotes apt mapeados por binário** (`scripts/checar_ambiente.sh` linhas ~32-47, array `PACOTE_APT`): é o que determina a mensagem "execute isso" quando falta algo. Hoje mapeamento é 1:1 baseado em conhecimento genérico Debian/Ubuntu. Quer ajustar algum nome de pacote (ex.: `imagemagick-7` em vez de `imagemagick` em Pop!_OS 24.04)?
2. **Estratégia do bootstrap quando Spellbook-OS não existe**: atualmente `instalar_app_themes.sh` apenas pula Spicetify com warning. Alternativa seria oferecer `git clone` automático do Spellbook-OS como parte do bootstrap. Dependência externa — quer manter skip ou automatizar clone?

## Riscos conhecidos

- `checar_ambiente.sh` detecta só binários conhecidos; não verifica permissões de escrita em `~/.local/share/` (assume padrão).
- `--bootstrap` usa `exec` ao final para `install.sh --user --all` — isso não volta. Se houver necessidade de executar algo pós-install no bootstrap (ex.: `diagnostico.sh`), trocar `exec` por chamada normal + diagnóstico ao final.
- Pop!_OS 24.04 ainda não testado em máquina real; `checar_ambiente.sh` aceita 24.04 mas as dependências específicas dessa versão podem diferir — validação plena fica para SPRINT_09.

## Referências

- CLAUDE.md §3 "Paths relativos via Path/equivalente (nunca hardcoded absolutos)".
- CLAUDE.md §8 "Local First. Graceful Degradation".

---

*"Viam inveniam aut faciam." — encontrarei um caminho, ou farei um. (Aplicado a cada PC Pop!_OS novo.)*
