# Sprint 09 — Testes, CI e suporte a Pop!_OS 24.04 / COSMIC

Proteção mecânica contra regressões das sprints 06-08 e adaptação preventiva para o próximo salto do Pop!_OS.

## Contexto

As sprints anteriores entregaram scripts críticos (reaplicar_tema, diagnostico, instalar_apt_hook, checar_ambiente, lib/common). Sem CI, qualquer edit humano pode quebrá-las silenciosamente. Além disso, Pop!_OS 24.04 muda para GNOME 46 e o novo desktop COSMIC (escrito em Rust, sem shell-extensions tradicionais) — o projeto precisa detectar essas variações ou falhar com mensagem clara.

## Entregas

### `.github/workflows/ci.yml` — 4 jobs

1. **shellcheck** — `--severity=warning` em `build.sh`, `install.sh`, `uninstall.sh`, `scripts/*.sh`, `scripts/lib/*.sh`, `tests/*.sh`.
2. **lint-manifesto** — valida `app-themes/gnome-extensions/extensions.json` é JSON válido E tem schema mínimo (`uuid`, `name`, `repo`, regex do uuid).
3. **portabilidade** — roda `tests/test_portabilidade.sh`; falha se hardcoded `/home/andrefarias` aparecer em `.sh`, `.json`, `.yml`.
4. **smoke-build** — em container Ubuntu 22.04 instala deps mínimas, roda `checar_ambiente.sh`, `baixar_upstreams.sh`, `build.sh`, valida `dist/` populado (>50 PNGs em 48x48, >50 SVGs em scalable).

### `tests/` — 3 scripts

- **`test_portabilidade.sh`** — grep por hardcoded usernames em arquivos versionados. Padrão montado dinamicamente (`"$(echo -n 'andre' 'farias' | tr -d ' ')"`) para evitar auto-match do próprio teste.
- **`test_reaplicar_idempotencia.sh`** — roda `reaplicar_tema.sh` duas vezes; compara `sha256sum` de `kitty.conf` e `.desktop` críticos antes vs depois. Falha se segunda execução muda qualquer hash.
- **`test_diagnostico_exit_codes.sh`** — verifica exit 0 quando tema OK, força regressão via `gsettings set icon-theme 'Adwaita'` e verifica exit 1, restaura estado original.

### `extensions.json` — schema ampliado

Toda entrada do manifesto agora carrega:

```json
{
  "uuid": "...",
  "shell-version-min": 42,
  "shell-version-max": 46
}
```

Valores default (42/46) cobrem Pop!_OS 22.04 LTS (GNOME 42) até 24.04 (GNOME 46). Atualizar individualmente quando upstream da extensão suportar versão diferente.

### `scripts/instalar_gnome_extensions.sh` — 3 defesas novas

1. **Detecta COSMIC** via `$XDG_CURRENT_DESKTOP`. Se match, aborta com mensagem explicativa — não tenta instalar extensões que não funcionam.
2. **Consome `shell-version-min/max`** — se GNOME Shell atual fora da faixa declarada para a extensão, pula com warning (em vez de instalar silenciosamente versão incompatível que depois o Shell desabilita).
3. **Source `lib/common.sh`** — usa logging unificado.

## Verificação end-to-end executada

1. `bash -n` em todos os scripts modificados → OK.
2. `test_portabilidade.sh` em Pop!_OS 22.04 atual → OK (0 matches).
3. `diagnostico.sh --quiet` continua exit 0 após todas as mudanças.
4. Manifesto `extensions.json` validado: `jq '.extensions | all(has("shell-version-min"))'` → `true`.
5. **CI em GitHub Actions**: não executado ainda (requer push para branch de teste — fica para o usuário decidir quando).

## Suporte Pop!_OS 24.04 / COSMIC — estado atual

| Cenário | Status | Nota |
|---|---|---|
| Pop!_OS 22.04 GNOME 42 | ✅ Testado | Ambiente do autor; todo o pipeline validado. |
| Pop!_OS 24.04 GNOME 46 | ⚠️ Preparado, não testado | `extensions.json` declara `shell-version-max: 46`; `checar_ambiente.sh` aceita; falta teste em VM real. |
| Pop!_OS 24.04 COSMIC | ⚠️ Detecção graciosa | `instalar_gnome_extensions.sh` aborta com mensagem clara; ícones/GTK/sons aplicam normalmente. Pop!_Shell/Pop!_Cosmic CSS pode precisar ajuste (paths talvez mudem em COSMIC). |

O teste real em 24.04 requer VM e fica como item não-bloqueante pós-sprint. Todos os mecanismos de detecção e fallback já estão prontos.

## Pontos de contribuição do usuário (learning mode)

1. **Severidade do shellcheck** (`.github/workflows/ci.yml` linha 20): hoje `--severity=warning`. Subir para `--severity=error` começa permissivo e endurece progressivamente; descer para `--severity=info` expõe estilo/convenções. Preferência?
2. **`shell-version-min/max` individuais**: os defaults 42/46 são genéricos. Se quiser refinar, dá pra consultar o `metadata.json` de cada extensão em `~/.local/share/gnome-shell/extensions/<uuid>/metadata.json` (campo `shell-version`) e preencher os valores reais por extensão. Tarefa de ~15 min; quer que faça?

## Riscos conhecidos

- `smoke-build` usa `ubuntu-22.04` no GitHub Actions — não é Pop!_OS. Diferenças reais entre os dois são mínimas para o que o `build.sh` faz (lê arquivos, chama `rsvg-convert`), mas uma regressão específica de Pop! passaria despercebida.
- `test_diagnostico_exit_codes.sh` mexe em `gsettings` real; se executado em CI headless falha (SKIP automático implementado). Em ambiente do autor, mexe no tema por alguns segundos e restaura — possível efeito visual transitório.
- Em 24.04 COSMIC a hierarquia de paths de `pop-shell@system76.com` pode não existir (o Pop!_Shell original é GNOME extension; em COSMIC o equivalente é integrado ao compositor). `instalar_pop_shell_css.sh` já tem guard `[[ ! -d "$(dirname "$destino")" ]] && return` — degrada sem erro.

## Referências

- [shellcheck wiki](https://www.shellcheck.net/wiki/)
- [GNOME Shell extensions versioning](https://gjs.guide/extensions/overview/anatomy.html#metadata-json)
- Auditoria inicial do projeto (resposta em `/home/andrefarias/.claude/plans/dei-um-full-dist-streamed-sutton.md`).

---

*"Quod non vetat lex, hoc vetat fieri pudor." — o que a lei não proíbe, o pudor proíbe. (Aplicado: o linter não proíbe, mas o bom-senso do teste proíbe.)*
