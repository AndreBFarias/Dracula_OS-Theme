# Sprint 33 — Fontes de design (JetBrains Mono + Fira Code) + higiene Flatpak do Boxy SVG

Instalar as fontes de design **JetBrains Mono** e **Fira Code** no padrão do
`install.sh`, de forma autônoma e idempotente, para que o texto vivo de SVGs
(e do desktop) renderize e **exporte** correto. Corrige na raiz o bug em que a
exportação PNG de um `.svg` no Boxy SVG perdia o texto (`PROTOCOLO OUROBOROS`
sumia/quebrava) por ausência das fontes no sistema.

> **Decisões fixas**:
> - **Numeração**: SPRINT 33 (a 32 é a última; a 28 foi pulada).
> - **Escopo travado pelo usuário**: fontes + higiene do Flatpak. **Sem**
>   paleta `.gpl`, **sem** escrever `settings:theme`/`settings:accentColor` no
>   Local Storage (leveldb Chromium) do Boxy — editar leveldb binário com o app
>   fechado é frágil, o Boxy sobrescreve ao salvar e o formato pode mudar em
>   update. Ganho não justifica o risco de corromper a config.
> - **Fontes bundladas no repo** (`src/fontes-design/`), não baixadas no install:
>   offline, reprodutível. Ambas **OFL-1.1** (redistribuição permitida com o
>   `OFL.txt` incluído).
> - **Família completa**: todos os pesos estáticos de cada release
>   (JetBrains Mono: Thin→ExtraBold + itálicos; Fira Code: Light/Regular/Medium/
>   SemiBold/Bold), para render fiel em qualquer `font-weight` que o SVG pedir.

## Contexto

- **Causa raiz (com prova).** O Flatpak `com.boxy_svg.BoxySVG` **já enxerga** o
  diretório de fontes do usuário: `/run/host/fonts` e `~/.local/share/fonts`
  estão montados no sandbox e o `fc-list` de dentro dele lista 884 fontes. O
  sandbox **não** é o bloqueio. O problema é simples: **JetBrains Mono e Fira
  Code não estão instaladas** no host (existe apenas Fira *Sans* e um Fira
  *Mono* parcial). Sem a fonte, o Boxy rasteriza o `<text>` vivo com fallback →
  o texto "some"/quebra no PNG exportado.
- **Regra de ouro do designer** (contexto do caso): "manda contornado, guarda o
  editável" — o SVG entregue deve ter o texto vetorizado (`path`), mas o
  *source* editável usa `<text>` vivo. Para editar o source e ver/exportar igual
  ao vetorizado, as fontes precisam estar instaladas.
- **Padrão já existente.** `scripts/instalar_relatorio_mec.sh` faz exatamente
  esta mecânica para as fontes Liberation: bundle `.ttf` em `src/`, cópia para
  `~/.local/share/fonts/<Família>/`, `fc-cache` só quando algo muda, prova final
  com `fc-match`. Este spec replica esse molde.
- **Cache de fontconfig do sandbox.** O Boxy Flatpak tem cache de fontconfig
  próprio em `~/.var/app/com.boxy_svg.BoxySVG/cache/fontconfig`, que pode ficar
  velho e não ver a fonte recém-instalada até regenerar. É o único gotcha real —
  endereçado pela higiene Flatpak abaixo.

## Solução

`scripts/instalar_fontes_design.sh` (idempotente, sem sudo, user-mode):

1. Para cada família (`JetBrainsMono`, `FiraCode`), copia
   `src/fontes-design/<Família>/*.ttf` → `~/.local/share/fonts/<Família>/`
   usando `cmp -s` por arquivo (só copia o que divergiu). Marca `MUDOU=1` quando
   algo muda.
2. `fc-cache -f "$HOME/.local/share/fonts"` **só quando `MUDOU=1`** (operação
   cara — evita rodar à toa).
3. **Higiene Flatpak (não-fatal, só se o Boxy existir).** Se
   `flatpak info com.boxy_svg.BoxySVG` tem sucesso **e** as fontes mudaram nesta
   execução:
   - Remove o cache de fontconfig do sandbox
     (`~/.var/app/com.boxy_svg.BoxySVG/cache/fontconfig` — é cache, seguro
     apagar; regenera no próximo start) para forçar o Boxy a ver as novas fontes.
   - Avisa: "reinicie o Boxy SVG para as fontes aparecerem".
   - Prova opcional (com `timeout`): `flatpak run --command=fc-match
     com.boxy_svg.BoxySVG "JetBrains Mono"` resolvendo para a fonte certa =
     garantia de que o export do Boxy passa a funcionar.
4. **Verificação (prova de resolução).** `fc-match "JetBrains Mono"` e
   `fc-match "Fira Code"` no host devem resolver para as fontes certas, não
   fallback.

`scripts/desinstalar_fontes_design.sh`: remove as duas pastas de fonte +
`fc-cache -f` (reversível).

## Escopo

Arquivos autorizados (limite rígido):

- `src/fontes-design/JetBrainsMono/*.ttf` + `src/fontes-design/JetBrainsMono/OFL.txt`
- `src/fontes-design/FiraCode/*.ttf` + `src/fontes-design/FiraCode/OFL.txt`
- `scripts/instalar_fontes_design.sh` — **novo** (instalador).
- `scripts/desinstalar_fontes_design.sh` — **novo** (reversão).
- `install.sh` — flag `--fontes-design` (fase user, não-fatal), **incluída em
  `--all`**; atualizar cabeçalho de uso e string de `Uso:`.
- `docs/sprints/SPRINT_33_FONTES_DESIGN_BOXY.md` — este spec.
- `docs/sprints/INDEX.md` — linha nova (#33).
- `CHANGELOG.md` — entrada (comportamento visível ao usuário: nova flag).
- `README.md` — linha na tabela de flags/funcionalidades.

**NÃO tocar**: `scripts/instalar_relatorio_mec.sh`, leveldb/Local Storage do
Boxy, `config.json` do Boxy, nenhum outro `instalar_*.sh`.

## Proof-of-work

```bash
# Sintaxe + lint dos scripts novos
bash -n scripts/instalar_fontes_design.sh
bash -n scripts/desinstalar_fontes_design.sh
shellcheck --severity=warning scripts/instalar_fontes_design.sh scripts/desinstalar_fontes_design.sh

# Execução + prova de resolução (host)
bash scripts/instalar_fontes_design.sh
fc-match "JetBrains Mono"   # -> JetBrainsMono-*.ttf (não fallback)
fc-match "Fira Code"        # -> FiraCode-*.ttf     (não fallback)

# Prova in-sandbox: o Boxy VAI renderizar (export corrigido na raiz)
flatpak run --command=fc-match com.boxy_svg.BoxySVG "JetBrains Mono"
flatpak run --command=fc-match com.boxy_svg.BoxySVG "Fira Code"

# Idempotência: 2ª execução não muda mtime nem estado (só "já em dia (skip)")
bash scripts/instalar_fontes_design.sh

# Diagnóstico geral do tema
bash scripts/diagnostico.sh --quiet   # exit 0
```

## Riscos conhecidos

- **Cache de fontconfig do sandbox velho**: o Boxy pode não ver a fonte nova até
  reiniciar. Mitigado por apagar o cache do sandbox na higiene + aviso de
  restart.
- **`flatpak run --command=fc-match` lento/indisponível**: guardado por
  `timeout` e tratado como não-fatal — a prova de resolução no host já é
  suficiente; a in-sandbox é bônus.
- **Boxy não instalado como Flatpak**: a higiene é pulada silenciosamente; a
  instalação de fontes é agnóstica de Boxy (beneficia terminal e qualquer app).

---

*"O tipo certo, montado na fôrma que já se conhece." — a fonte instalada, e o
texto que sobrevive ao export.*
