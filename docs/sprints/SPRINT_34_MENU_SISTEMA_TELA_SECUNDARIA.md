# Sprint 34 — Menu de sistema na tela secundária + índice do hicolor + arte própria no tema

Três correções que nasceram do mesmo relato: ícone errado no lançador do Sigilo,
app estranho no menu e ausência da área de gerenciamento na segunda tela.

> **Decisões fixas**:
> - **Numeração**: SPRINT 34 (a 33 é a última).
> - **Instanciar, não transferir.** O menu de sistema da tela secundária é uma
>   instância nova. `transferIndicators()` da extensão usa `remove_child`, o que
>   tiraria o menu do monitor primário — o oposto do pedido.
> - **Dash to Panel descartado.** É a única extensão que reinstancia o menu em
>   todos os monitores, mas exigiria desabilitar `pop-cosmic`,
>   `dash-to-dock-cosmic`, `transparent-top-bar` e `multi-monitors-add-on` para
>   entregar um menu *stock* na tela 2. Custo alto, ganho parcial.
> - **Arte própria em vez do catálogo.** Os apps do usuário já têm ícone no
>   padrão Dracula (`mnemo.svg` usa `#BD93F9`/`#282A36`/`#FF79C6`). Mapear para
>   SVG genérico do catálogo trocaria arte específica por arte pior.

## Contexto

- **Causa raiz do ícone do Sigilo (com prova).** Não era o `.desktop`. O
  `~/.local/share/icons/hicolor/index.theme` declarava só
  `48x48,128x128,256x256,512x512`; o instalador do Sigilo gravava em
  `64x64/apps`, diretório fora de `Directories=`. Pela spec XDG o GTK ignora
  diretório não declarado, então `Gtk.IconTheme.lookup_icon('sigilo', 48, 0)`
  devolvia `None` com o PNG presente em disco. `gtk-update-icon-cache` chegava a
  indexar o arquivo (`strings icon-theme.cache | grep sigilo` acusava), o que
  fazia o cache parecer correto e mandava o diagnóstico para o lado errado.
- **O mesmo bug atingia este repositório.** `scripts/atualizar_icones_steam.sh`
  grava o fallback em `32x32/apps`, também não declarado.
- **Limite do GNOME Shell 42.** `ui/layout.js` faz
  `panelBox.set_position(primaryMonitor.x, primaryMonitor.y)` — existe um único
  painel, preso ao primário. Não há gsettings que duplique.
- **Por que o `multi-monitors-add-on` não bastava.** Ele desenha o painel na
  tela secundária, mas `MULTI_MONITOR_PANEL_ITEM_IMPLEMENTATIONS` só registra
  `activities`, `appMenu` e `dateMenu`; sem construtor para `aggregateMenu`,
  `_ensureIndicator()` desiste e o painel nasce sem o canto de gerenciamento.

## Entregas

1. **`scripts/reparar_hicolor_index.sh`** — acrescenta ao `Directories=` os
   diretórios presentes em disco que faltam, cobrindo `<N>x<N>`, `<N>x<N>@<M>x`
   (com `Scale=`), `scalable` e `symbolic`. Nunca remove entrada: um índice com
   `mimetypes/`, `actions/` ou `Inherits=` sai intacto. Escrita atômica
   (`tmp` + `os.replace`). Roda **depois** dos escritores de ícone no
   `install.sh`, senão o `mkdir -p` do script do Steam criaria `256x256/apps`
   após o índice e exigiria duas passadas.
2. **`scripts/instalar_patch_multi_monitors.sh` + `src/shell/mm-status-extras.js`**
   — registra `'aggregateMenu': Panel.AggregateMenu` no mapa da extensão e
   replica no menu secundário o que outras extensões acrescentam ao primário.
   Backup em `mmpanel.js.dracula-orig` com a versão da extensão ao lado;
   `--reverter` recusa restaurar sobre versão diferente.
3. **`mapping.json` + `src/icons/projects/`** — Mnemo, Nyx, Protocolo Ouroboros,
   Sigilo e UAD-NG com `origem: "arte-propria"`, incluindo o alias técnico do
   flatpak `io.github.andrebfarias.Mnemo`.
4. **`build.sh`** — normaliza espaço para hífen ao derivar nome de arquivo de
   `aliases_humanos`. Espaço no nome faz `gtk-update-icon-cache` descartar o
   cache **inteiro** (`The generated cache was invalid`), não só a entrada.

## O que NÃO dá para replicar na tela secundária

Em GJS só `var`/`function` de topo viram propriedade importável do módulo:

| Extensão | Resultado | Motivo |
|---|---|---|
| `sound-output-device-chooser` | replicado | exporta `var SDCInstance` |
| `big-avatar` | replicado | refeito localmente, sem tocar no global dela |
| `bluetooth-quick-connect` | só primário | `class` não exportada (`extension.js:36`) |
| `system76-power` | só primário | guarda `if (null === ext)` (`extension.js:62`) |

O desmonte **não** chama `SDCInstance.disable()`: ele abre removendo
`cycle-output-forward` e irmãs por nome global (`extension.js:319-322`), que
pertencem à instância do primário — desmontar a tela secundária apagaria os
atalhos de áudio da outra. `_removeStatusExtras` repete só a parte por instância.

## Proof-of-work

```bash
# índice: conserta, é idempotente e preserva seções alheias
DRACULA_DRY_RUN=1 ./scripts/reparar_hicolor_index.sh
./scripts/reparar_hicolor_index.sh && ./scripts/reparar_hicolor_index.sh

# patch: ciclo completo
./scripts/instalar_patch_multi_monitors.sh
./scripts/instalar_patch_multi_monitors.sh --reverter
./scripts/instalar_patch_multi_monitors.sh

# resolução real do ícone (usar /usr/bin/python3: o do PATH cai em venv sem gi)
/usr/bin/python3 -c "import gi; gi.require_version('Gtk','3.0'); from gi.repository import Gtk; \
  print(Gtk.IconTheme.get_default().lookup_icon('sigilo',48,0).get_filename())"

# visual: Alt+F2 r, clicar no canto direito da tela secundária
import -window root -crop 700x800+3140+0 +repage /tmp/menu_tela2.png
```

Evidência visual registrada: menu da tela secundária com avatar, seletor de saída
de áudio, seletor de microfone, rede, Bluetooth, bateria e desligar — com o menu
do primário intacto.
