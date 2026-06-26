# Sprint 32 — Fechamento do débito do estudo (resiliência, testes, docs)

O estudo completo do projeto (que originou a SPRINT 31) deixou um conjunto de
achados menores registrados, sem urgência mas com a filosofia anti-débito do
projeto pedindo resolução. Esta sprint zera esse débito: três correções de risco
real, dois testes reforçados, a auditoria do README e a tag faltante.

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 32.
> - **`mapping.json` não-destrutivo**: regenerar via `extrair_mapeamento.py` passa a
>   fazer **merge**, preservando entradas curadas à mão (origem `logo-usuario` ou
>   campo `"curado": true`). As 5 entradas curadas (firefox, citrix, dbeaver,
>   photogimp, Clapper) deixam de ser apagadas.
> - **34 apps `nao-encontrado` ficam no fallback por design**: são apps internos /
>   de sistema (`gnome-*-panel`, `xdg-desktop-portal-*`, `pop-cosmic-*`) ou de
>   terceiros sem arte Dracula (Citrix/`Ubuntu-receiver`, Antigravity, openjdk).
>   Não há ícone Dracula para eles; herdam Adwaita/upstream. Documentado, não há
>   correção de código sensata.

## Achados e solução

1. **Regenerar `mapping.json` era destrutivo** (`extrair_mapeamento.py:401` fazia
   `write_text` do zero). → Merge antes de escrever: carrega o JSON atual e preserva
   entradas com origem `logo-usuario` ou `"curado": true`. Verificado: regenerar
   reporta "5 entrada(s) curada(s) preservada(s)".
2. **`diagnostico.sh` dava falso-positivo sem `pop-cosmic`/`pop-shell`** — o `cmp`
   não tinha o guard `[[ -f ]]` que o `reaplicar_tema.sh` tem; numa máquina sem a
   extensão, acusava regressão (exit 1). → Guard `[[ ! -f <dst> ]] || cmp ...` em
   ambos os checks (pop-shell e pop-cosmic).
3. **Testes com asserção fraca**:
   - `test_reaplicar_idempotencia.sh` passava trivialmente se os arquivos-alvo não
     existissem (snapshot vazio == vazio). → SKIP honesto quando nenhum alvo existe.
   - `test_diagnostico_exit_codes.sh` não testava o caso saudável. → Cenário 3:
     após restaurar, o diagnóstico deve voltar ao estado original; confirma exit 0
     explicitamente quando o ambiente está saudável.
4. **README com drift vs código** — auditoria linha-a-linha (13 itens corrigidos):
   contagens (208 apps, ~4324 arquivos, 53 aliases humanos, 14 extensões, ~1.574
   symbolic, 3399 SVGs, 20 projetos), a flag `--video-wallpaper` ausente, `--all`
   agora incluindo `--apt-hook`, som default Pop->Dracula, a árvore `src/` sem
   `gtk/`/`cursors/`/`wallpaper/`, e o bloco de componentes do wallpaper de vídeo.
5. **`v1.2.0` sem git tag** — só `v1.0.0` e `v1.1.0` estavam tagueados. → Criada a
   tag anotada `v1.2.0` retroativa no commit `76de89dc`.

## Proof-of-work runtime-real (executado ao vivo)

```bash
python3 -m py_compile scripts/extrair_mapeamento.py            # OK
python3 scripts/extrair_mapeamento.py                          # "Merge: 5 entrada(s) curada(s) preservada(s)."
git checkout mapping.json                                      # dado revertido (regeneracao depende do host)
bash -n scripts/diagnostico.sh tests/*.sh                      # OK
bash tests/test_reaplicar_idempotencia.sh                      # OK exit 0
bash tests/test_diagnostico_exit_codes.sh                      # "caso saudavel confirmado (exit 0)" + regressao->1->0
bash scripts/diagnostico.sh                                    # exit 0 (sem falso-positivo pop-cosmic)
grep -nE '2235|203 apps|13 extens|3437|1\.558' README.md       # nenhum drift remanescente
git tag -l                                                     # v1.0.0 v1.1.0 v1.2.0
```

## Riscos conhecidos

- **Merge preserva por origem `logo-usuario`/`"curado": true`**: se o usuário editar
  uma entrada à mão sem marcá-la, a regeneração ainda a sobrescreve. O contrato é
  explícito: marcar `"curado": true` (ou origem `logo-usuario`) para preservar.
- **Os 34 apps no fallback** continuam sem ícone Dracula próprio (sem arte
  disponível); é uma decisão, não um bug. Se surgir arte, basta adicionar a entrada
  curada no `mapping.json`.

---

*"O débito que não se nomeia, se acumula. Nomeado, fecha-se." — anti-débito, na prática.*
