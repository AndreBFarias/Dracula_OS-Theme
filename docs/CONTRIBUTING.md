# Contribuindo com o Dracula_OS-Theme

Obrigado pelo interesse em contribuir. Este projeto segue princípios
estritos de simplicidade, acentuação completa em português e zero
emojis em código.

## Antes de começar

1. Leia o [README.md](../README.md) para entender a arquitetura.
2. Leia o [Índice de Sprints](sprints/INDEX.md) para ver o que já está em
   andamento.
3. Rode o projeto localmente:

```bash
./scripts/baixar_upstreams.sh
python3 scripts/extrair_mapeamento.py
./build.sh
./install.sh --user --all
```

## Padrão de commits

```
tipo: descrição imperativa em português

Tipos: feat, fix, refactor, docs, test, perf, chore
```

- Zero emojis.
- Zero menções a ferramentas de IA.
- Acentuação correta (PT-BR completo).

## Estrutura para novas features

Features não-triviais começam como uma sprint em `docs/sprints/`:

1. Criar `docs/sprints/SPRINT_NN_TITULO.md` com contexto, hipóteses,
   arquitetura, próximos passos.
2. Adicionar ao `docs/sprints/INDEX.md`.
3. Implementar em commits atômicos (um por sprint).
4. Registrar no `CHANGELOG.md` quando concluída.

## Antes de abrir um PR

- [ ] Testes locais passando (`./build.sh && ./install.sh --user --all`).
- [ ] `uninstall.sh` ainda reverte tudo corretamente.
- [ ] Zero warnings de acentuação (`grep -rnE '\b(nao|sao|esta|funcao|...)\b'
      scripts/ *.sh *.md`).
- [ ] Zero emojis no diff.
- [ ] CHANGELOG atualizado com a entrada da sprint.

## Licença

Contribuições são aceitas sob a licença **GPL-3.0**. Ao submeter um PR,
você concorda em licenciar sua contribuição nos mesmos termos.

*"Quem ensina, aprende ao ensinar; quem aprende, ensina ao aprender." — Paulo Freire*
