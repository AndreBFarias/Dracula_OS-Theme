# Sprint 22 — Logo do Clapper no app e nos arquivos de vídeo

Adotar a logo nova do Clapper como fonte tanto do ícone do **aplicativo** Clapper quanto dos **mimetypes de vídeo**, de modo que arquivos de vídeo no gerenciador de arquivos exibam o mesmo ícone do player. Substitui a fonte anterior dos mimetypes de vídeo (`mobile-game.svg`, um fliperama colorido fora da estética) e estende a cobertura para todos os formatos de vídeo comuns.

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 22 (20/21 ainda sem doc em `docs/sprints/`; 20 já registrada no CHANGELOG).
> - **Sem sudo**. Mudança no pipeline de build (`build.sh` + `mapping.json`); `install.sh` consome via `dist/`.
> - **Arquivos de vídeo usam a logo do Clapper** (decisão do usuário) — não um mimetype-icon distinto.
> - **`dist/` não é versionada** (`.gitignore:1`): o commit toca apenas `mapping.json`, `build.sh`, docs. O efeito chega ao usuário via `build.sh`/`--bootstrap`.
> - **Aspect ratio preservado** (sem square-crop): a logo é 842x868 (quase quadrada); `redimensionar_png` mantém proporção como no resto do pipeline de apps PNG.

## Contexto

### Estado anterior (verificado)

- Ícone do **app** Clapper vinha de `current/scalable/apps/clapper.png` (`mapping.json:232`), um PNG 4096x4096.
- O usuário adicionou a logo nova em `current/48x48/apps-global/Clapper.png` (842x868), mas a pasta `apps-global` **não é consumida** por `build.sh` (era depósito de logos de alta-res fora do pipeline) — a logo nova nunca entrava no tema.
- Mimetypes de vídeo eram gerados de `mobile-game.svg` (`build.sh:197`), cobrindo só `video-mp4,video-x-mp4,application-mp4`. Demais formatos (mkv/webm/avi/mov/wmv/flv) caíam no fallback dos heritages. Resultado visível: arquivos `.mp4` no Nautilus apareciam com um fliperama colorido.
- `gerar_mimetypes()` só sabia tratar fontes **SVG** (`converter_svg`); o pipeline de apps já tratava **PNG** (`redimensionar_png`, `build.sh:155-162`).

### Solução

1. `mapping.json`: trocar a `fonte` do Clapper para `current/48x48/apps-global/Clapper.png` (a logo nova). `origem` → `logo-usuario`.
2. `build.sh` / `gerar_mimetypes()`:
   - Resolver a fonte por caminho: com `/` é relativa a `src/icons/`; sem `/` assume `new-sessao-atual/` (mantém as 3 entradas SVG existentes).
   - Adicionar branch **PNG** (reusa `redimensionar_png`) ao lado do branch SVG.
   - Trocar a entrada de vídeo de `mobile-game.svg` para a logo do Clapper e estender para 10 nomes XDG.

## Escopo (touches autorizados)

Arquivos modificados (cirúrgico):
- `mapping.json` — 2 campos da entrada `com.github.rafostar.Clapper` (`fonte`, `origem`).
- `build.sh` — função `gerar_mimetypes()`: array `MIMETYPES` + loop (resolução de fonte + branch PNG/SVG).
- `CHANGELOG.md` — 1 bullet sob `## [Unreleased]` → `### Adicionado`.
- `docs/sprints/INDEX.md` — 1 linha.

Arquivos criados:
- `docs/sprints/SPRINT_22_CLAPPER_ICONE_VIDEO.md` — este spec.

NÃO tocar: `dist/` (regenerada por `build.sh`), demais entradas de `mapping.json`, demais funções de `build.sh`, outros scripts.

## Aritmética da mudança

- Mimetypes gerados: **23 nomes** (antes 16 — markdown 5 + shellscript 6 + desktop 2 + vídeo 3; agora vídeo 10).
- Nomes de vídeo: `3 → 10` (`video-x-generic, video-mp4, video-x-mp4, video-x-matroska, video-webm, video-quicktime, video-x-msvideo, video-x-flv, video-x-ms-wmv, application-mp4`).
- App Clapper: fonte `4096x4096` → `842x868`; ícones gerados em 8 tamanhos + scalable.

## Proof-of-work runtime-real

```bash
bash -n build.sh                      # sintaxe OK
./build.sh                            # "mimetypes gerados: 23 nomes", "0 falhas de conversão"

# Identidade de pixels (sem metadata; PNG do ImageMagick embute timestamp):
A=$(convert dist/icons/Dracula-Icones/256x256/apps/com.github.rafostar.Clapper.png -strip png:- | sha256sum)
B=$(convert dist/icons/Dracula-Icones/256x256/mimetypes/video-x-generic.png       -strip png:- | sha256sum)
C=$(convert dist/icons/Dracula-Icones/256x256/mimetypes/video-mp4.png             -strip png:- | sha256sum)
# A == B == C  → app, video-x-generic e video-mp4 são a MESMA logo do Clapper. (Verificado.)

# Cobertura de formatos:
ls dist/icons/Dracula-Icones/48x48/mimetypes/video-*   # 9 arquivos video-* + application-mp4

bash scripts/diagnostico.sh --quiet ; echo "exit=$?"   # esperado: 0
```

Resultado verificado: sha (strip) idêntico entre app Clapper, `video-x-generic` e `video-mp4` (`4f69139b…`); montagem visual confirma claquete gótica nos quatro alvos e a saída da `mobile-game` colorida.

## Validação visual

Montagem `128x128` de `[app Clapper | video-x-generic | video-mp4 | video-x-matroska | (antigo mobile-game)]` capturada e inspecionada: os 4 primeiros são a claquete escura (tema gótico/Dracula); o 5º é a `mobile-game` colorida que foi substituída. Para refletir no Nautilus em runtime: `./install.sh --user --activate` + `gtk-update-icon-cache` (já no install) e, se necessário, reload do Shell.

## Invariantes preservados

- Acentuação pt-BR completa nos arquivos modificados/criados.
- Mudança cirúrgica: só `gerar_mimetypes()` e 2 campos de `mapping.json`.
- Sem sudo; sem escrever em `/usr/share/`.
- Integração ao install herdada do pipeline (`dist/` ← `build.sh`).

## Riscos conhecidos

- **Ícone levemente não-quadrado** (842x868 → 248x256 em 256): aceitável; o grid do launcher/Nautilus centraliza. Decisão de não fazer square-crop.
- **Cache do GTK/Shell**: o Nautilus pode memoizar o ícone antigo até `gtk-update-icon-cache` + reload. Comportamento padrão, não regressão.
- **`scalable/mimetypes/*.png`**: a logo é PNG, então a versão "scalable" também é PNG (não SVG). Coerente com o pipeline de apps PNG (`build.sh:161`).

---

*"O mesmo gesto para abrir e para reconhecer." — o ícone do player também marca o arquivo.*
