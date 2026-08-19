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

## Parte 2 — Por que o heal não teria curado isso

Trocar a arte-mestre corrige o caso concreto, mas o caminho de auto-cura não
detectava a regressão. Três achados, dois corrigidos:

### Build não era reprodutível (corrigido)

Duas rodadas de `build.sh` sobre o **mesmo** source produziam **784 de 4414
arquivos** com bytes diferentes. Causa: `redimensionar_png` chama o ImageMagick
sem excluir os chunks de data, e o `convert` carimba a hora da conversão dentro
do PNG. Os pixels eram idênticos (mesma assinatura em `identify -format "%#"`);
só o metadata mudava. O `rsvg-convert`, usado para as fontes SVG, já é
determinístico — por isso a divergência ficava restrita às fontes PNG.

Correção: `-define png:exclude-chunk=date,tIME` em `redimensionar_png` e no ramo
`magick` de `converter_svg`. Verificado: duas rodadas consecutivas, 4414
arquivos byte-idênticos.

Isso não era cosmético — sem build determinístico, nenhuma verificação por hash
entre `dist/` e o tema instalado consegue distinguir "arte regrediu" de "buildou
de novo".

### Heal não ressincronizava os ícones (corrigido)

`reaplicar_tema.sh` conferia apenas a **existência** de
`~/.local/share/icons/Dracula-Icones` e, adiante, regenerava o cache e reativava
o `gsettings`. Nenhuma comparação de conteúdo: um arquivo de arte que regredisse
no destino sobreviveria a quantos heals rodassem — e o cache regenerado a partir
de arte errada continua errado.

Nova seção 1.5: `rsync -rlc` (checksum) de `dist/icons/<tema>/` para o destino,
nos quatro temas. Detalhes que custaram uma iteração:

- **`-l` é obrigatório**: os upstreams trazem os diretórios `@2x` como symlink e
  o `rsync` sem `-l` imprime `skipping non-regular file` **em stdout**, o que
  inflava a contagem para 9438 (main) e 13342 (circle) a cada rodada.
- **`--exclude=icon-theme.cache`**: o cache é gerado localmente pela seção 8;
  comparar contra a cópia do `dist/` daria divergência eterna de 1 arquivo.
- **Sem `--delete`**: mesmo contrato do `install.sh` — arquivos extras no
  destino não são removidos.

Verificado: regressão injetada (arte antiga escrita por cima do ícone instalado)
foi detectada como `1 arquivo(s) divergiam do dist/` e curada; rodada seguinte
reporta `Temas de ícones em sincronia com dist/` sem escrever nada.

### Órfãos no tema instalado (corrigido com --delete guardado)

Nem o `install.sh` (`cp -r`) nem a primeira versão da seção 1.5 removiam
arquivos que deixaram de existir no `dist/`. Eram 32 no
`~/.local/share/icons/Dracula-Icones`: `antigravity*`, `com.obsproject.Studio`,
`guvcview`, três mimetypes `.svg` de vídeo substituídos por `.png` na SPRINT 22,
e o `scalable/apps/protocolo-ouroboros.svg` copiado à mão na tentativa de
correção das 20:20 de 2026-08-18.

Nenhum sombreava nada naquele momento, mas arte que sobra de um mapping antigo
continua sendo servida pelo tema — é exatamente a classe de problema desta
sprint, só que com a regressão latente em vez de visível.

A seção 1.5 passa a usar `--delete`. Os quatro diretórios são 100% gerados pelo
`build.sh`, então o destino tem que **convergir** para o `dist/`. Duas guardas
antes de remover qualquer coisa:

1. `validar_path_destrutivo` (allowlist de `lib/common.sh`, onde
   `~/.local/share/icons` já constava);
2. **razão dist/destino**: se o `dist/` tem menos de 90% dos arquivos do destino,
   é build parcial ou interrompido — ressincroniza sem deletar e avisa.

Sem backup a cada rodada de propósito: o conteúdo é integralmente regenerável
por `./build.sh && ./install.sh --user`. Os 32 órfãos desta primeira remoção
foram respaldados em
`~/.cache/dracula_os_backup/icones_orfaos_20260818-225250/` (tar + manifest
sha256, 32/32 conferidos) antes da execução.

Verificado:

- passada 1 removeu os 32 órfãos; passada 2 reporta sincronia sem escrever;
- destino e `dist/` passam a ter as **mesmas 4413 entradas**;
- guarda dos 90% testada removendo 10 dos 49 arquivos do `dist/` do
  `Dracula-Cursor`: `dist/ tem 39 arquivos contra 49 instalados — build parcial?
  sincronizo sem --delete`, e os 49 do destino ficaram intactos.

## Proof-of-work (parte 2)

```
$ ./build.sh && snapshot1 && ./build.sh && snapshot2
IDEMPOTENTE: 4414 arquivos byte-identicos em 2 rodadas

$ ./install.sh --user (x2)
INSTALL IDEMPOTENTE: 4445 arquivos identicos em 2 rodadas

$ ./tests/test_reaplicar_idempotencia.sh
OK: idempotência verificada (arquivos críticos inalterados entre execuções).

$ ./scripts/diagnostico.sh --quiet
exit 0
```
