# Sprint 19 — `test_portabilidade.sh`: filtrar arquivos não-versionados

Sprint mínima e cirúrgica gerada como **achado colateral** da validação da
SPRINT 18: `tests/test_portabilidade.sh` falhava com falso-positivo em
`.claude/settings.local.json:7` (arquivo **não-versionado**, gerado pelo
runtime do Claude Code), apesar do comentário do próprio script declarar
"falha se algum arquivo **versionado** tem hardcoded username".

## Contexto

`tests/test_portabilidade.sh` (37 linhas, antes da sprint) usava
`grep -rn` com `--include`/`--exclude-dir` para varrer o repositório.
Como o `grep -r` não respeita `.gitignore`, qualquer `.json`/`.sh`/`.yml`
que casasse o padrão e estivesse em diretório não-excluído reportava
match — incluindo arquivos local-only criados pelo Claude Code, IDE,
ou ambiente do usuário.

O comentário do próprio script já declarava a intenção correta
("arquivos versionados") — esta sprint só alinha implementação à
intenção.

## Decisões fixas

- **Single fonte de verdade**: `git ls-files` define o conjunto.
  Não tentar manter listas paralelas de exclusão.
- **Mesmas extensões filtradas**: `*.sh`, `*.json`, `*.yml`, `*.yaml`.
- **Mesmos diretórios excluídos** via `grep -Ev` no resultado de
  `git ls-files`: `docs/`, `dist/`, `releases/` (consistente com o
  comportamento anterior de `--exclude-dir`).
- **`mapfile` + `grep -nH` em arquivos enumerados** em vez de `grep -r`.
- **Sem mudança de exit codes nem mensagens de saída**: contrato externo
  do test preservado (CI continua interpretando `exit 0`/`1` igual).

## Entregável único

`tests/test_portabilidade.sh` — substituir o bloco `grep -rn ... .` por:

```bash
mapfile -t arquivos < <(git ls-files \
    '*.sh' '*.json' '*.yml' '*.yaml' \
    | grep -Ev '^(docs/|dist/|releases/)' || true)

matches=""
if [[ ${#arquivos[@]} -gt 0 ]]; then
    matches="$(grep -nH "$PADRAO" -- "${arquivos[@]}" 2>/dev/null || true)"
fi
```

## Aritmética

`tests/test_portabilidade.sh`: 37 → 36 linhas (−1). O bloco
`grep -rn ... .` (12 linhas com `--include`/`--exclude-dir`) é substituído
por `mapfile` + `if`/`grep -nH` (11 linhas, mais conciso porque
`git ls-files` já filtra `.gitignore` sem precisar de exclude-dirs).

## Proof-of-work

```bash
bash -n tests/test_portabilidade.sh        # exit 0
bash tests/test_portabilidade.sh           # exit 0, sem FAIL
```

Estado pré-sprint: o teste rodava em foreground retornando exit 1 com
match em `.claude/settings.local.json:7`. Estado pós-sprint: exit 0
limpo, mensagem `OK: nenhum hardcoded ... em código versionado.`.

## Não-tocar

- Padrão dinâmico (`PADRAO="/home/$(echo -n 'andre' 'farias' | tr -d ' ')"`)
  preservado — evita auto-match deste próprio arquivo.
- Mensagens de saída idênticas — CI/scripts externos podem grepar.
- Exit codes idênticos: 0 OK, 1 FAIL.
- Outros tests em `tests/*.sh` — fora do escopo.

---

> "Quem não filtra o que mede, mede o ambiente."
