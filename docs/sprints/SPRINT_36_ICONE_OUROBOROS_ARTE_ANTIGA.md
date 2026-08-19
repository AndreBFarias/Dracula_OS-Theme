# Sprint 36 — Ícone do Protocolo Ouroboros: arte antiga sombreando a marca

O menu de aplicativos passou a mostrar um brasão antigo ("AV" dentro de escudo,
sobre disco preto) no lugar da marca atual do Protocolo Ouroboros (o anel de
serpente rosa/roxo). Correção na raiz: a arte-mestre versionada no tema estava
defasada desde abril.

## Causa raiz

`src/icons/projects/protocolo-ouroboros.png` contém, desde `30f826c9`
(2026-04-16), o **brasão antigo** do projeto. O arquivo nunca foi atualizado
quando a marca do app mudou. Enquanto o `mapping.json` não tinha entrada para o
app, isso era inofensivo — o tema simplesmente não cobria o nome.

A SPRINT 35 (`32d35ec2`, 2026-08-18 19:40) adicionou `protocolo-ouroboros` e o
alias `ouroboros` ao `mapping.json` apontando para essa arte. O `build.sh`
materializou os PNGs em `Dracula-Icones/*/apps/`, e como **o tema de ícones ativo
é varrido antes do `hicolor`**, a arte antiga passou a sombrear a marca que o
`install.sh` do próprio app instala em `~/.local/share/icons/hicolor/`.

O `install.sh` do Protocolo Ouroboros documenta essa armadilha nas linhas 228-243
e escolheu o nome `protocolo-ouroboros` justamente por ser um nome que *nenhum
tema define*. A SPRINT 35 anulou a proteção ao definir exatamente esse nome.

Timeline verificada nos mtimes de `~/.local/share/icons/`:

| Hora (2026-08-18) | Evento |
|---|---|
| 19:40 | `32d35ec2` mapeia `protocolo-ouroboros` para a arte de abril |
| 20:14 / 20:20 | `install.sh` do app reinstala a marca correta no `hicolor` |
| 22:04 | `build.sh` grava a arte antiga em `Dracula-Icones` e sombreia o `hicolor` |

## Correção

`src/icons/projects/protocolo-ouroboros.png` passa a ser cópia byte-a-byte de
`protocolo-ouroboros/assets/icon.png` — a **mesma** fonte que o `install.sh` do
app usa. Um único ponto de verdade para a arte: tema e app não podem mais
divergir sem que a divergência seja visível como diff neste arquivo.

Escolha deliberada de `assets/icon.png` e não de `assets/app-icon.png`: o
segundo embute o anel num disco opaco e ocupa só 68,8% do canvas, o que faz o
traço colapsar por antialiasing nos tamanhos em que o lançador desenha (o
`install.sh` do app mede 6,7% contra 17,4% de cobertura da cor da marca). O
mesmo raciocínio vale aqui.

Nome do arquivo-fonte mantido: trocar para `.svg` deixaria o
`protocolo-ouroboros.png` antigo órfão em `scalable/apps/` do tema já instalado
(o `install.sh --user` copia, não sincroniza), e `.png` **vence** `.svg` na
ordem de extensões do lookup freedesktop. O órfão continuaria mandando.

## Invariante

Arte de projeto autoral versionada em `src/icons/projects/` é cópia da
arte-mestre do repositório do app, não uma segunda arte-mestre. Quando o app
muda a marca, a cópia tem que ser atualizada junto — senão o tema sombreia o
`hicolor` e regride o ícone.

## Proof-of-work

```
$ python3 -c "gi ... Gtk.IconTheme.lookup_icon('protocolo-ouroboros', 48, 0)"
/home/andrefarias/.local/share/icons/Dracula-Icones/48x48/apps/protocolo-ouroboros.png
```

Lookup resolvido pelo tema (confirmando o sombreamento do `hicolor`), com a arte
correta no destino. Ícone conferido visualmente em 48px e 256px: anel de
serpente rosa/roxo.
