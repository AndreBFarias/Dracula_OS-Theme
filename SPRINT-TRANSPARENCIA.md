# Sprint isolada — Transparência do Pop!_OS Launcher

Esta sprint documenta a investigação em andamento para resolver a transparência do launcher "Applications" do Pop!_OS, que continua opaco apesar das substituições já realizadas.

## Estado atual

**O que foi feito:**

1. **`src/shell/pop-shell-dracula.css`** anexado ao `gnome-shell.css` do tema GTK via `build.sh`.
   - Regras: `.pop-shell-search`, `.pop-shell-search.modal-dialog`, `.pop-shell-entry`, `.pop-shell-overlay`, `.pop-shell-active-hint`, `.pop-shell-tab-*`.
   - `!important` em todas para vencer especificidade do tema base.

2. **`/usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css`** substituído (com backup `.orig`) por `src/shell/pop-shell-dark.css`:
   - Troca `#FBB86C` (laranja) e `#9B8E8A` (cinza-rosado) pela paleta Dracula.
   - Define `.pop-shell-search { background: rgba(40,42,54,0.55); border: 1px solid #bd93f9; }`.

3. **`/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css`** substituído por `src/shell/pop-cosmic-dark.css`:
   - Troca `.cosmic-applications-dialog { background-color: #36322f; }` (marrom) por `rgba(40,42,54,0.70)` + borda purple + border-radius 16px.
   - Esta é a extensão que controla de fato o launcher "Applications" visualizado na screenshot do usuário.

**Resultado visual**: as cores parecem ter sido aplicadas (fundo escuro neutro vs marrom original), mas **o fundo continua opaco**. Transparência não está sendo renderizada.

## Hipóteses prováveis

### H1. Cache do GNOME Shell não invalidou

GNOME Shell em alguns cenários mantém cache de CSS mesmo com `Alt+F2 r`. Evidência: modificar o CSS e recarregar extensões pop-shell + pop-cosmic não aplicou a transparência.

**Teste:** logout/login completo ou `gnome-extensions disable pop-cosmic@system76.com && gnome-extensions enable pop-cosmic@system76.com`.

### H2. Compositor + Wayland bloqueia alpha no ModalDialog

No Pop!_OS 22.04 com Mutter/X11, a janela do ModalDialog pode não ter flag `RGBA` para aceitar transparência. Em Wayland, pode funcionar ou não dependendo de como a extensão cria a janela.

**Teste:** inspecionar via Looking Glass (`Alt+F2` → `lg`) → `inspect()` no launcher para ver se tem `use-alpha` e background real.

### H3. Código JavaScript da extensão seta o background explicitamente

`pop-cosmic@system76.com/applications.js` pode definir `set_style` via `clutter` ignorando o CSS. Neste caso, a correção não é só CSS — precisa editar o JS.

**Teste:** `grep -rnE "set_style|background-color|Clutter\\.Color" /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/*.js` e ver se há setters em runtime.

### H4. Seletor CSS errado

O elemento real do dialog pode ter uma classe diferente. O nome `.cosmic-applications-dialog` foi deduzido do `dark.css` mas talvez a implementação use wrapper diferente.

**Teste:** Looking Glass → `it` (inspect tool) → clicar no fundo do launcher → ver `style_class` real.

## Próximas tentativas (quando retomar)

Ordem sugerida:

1. **Fazer logout/login** — exclui H1. Se já tentou, exclui.
2. **Looking Glass** — abre no Alt+F2 → `lg`, roda `imports.ui.main.layoutManager.keyboardBox` ou similar para encontrar o widget e ver `style_class` + background atual. Esse é o caminho mais direto para validar H4.
3. **`grep` nos JS do pop-cosmic** — procurar `set_style` ou `set_background_color` em `applications.js` / `overview.js`. Se achar, H3 confirmada — precisa patchear o JS.
4. **Teste isolado** — criar um CSS mínimo em `/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css` com `.cosmic-applications-dialog { background: red !important; }` e recarregar. Se fundo ficar vermelho, o CSS carrega e o seletor é correto — o problema é só o alpha. Se continuar escuro, H3 ou H4.
5. **dconf keys** — `gsettings list-recursively | grep -i cosmic` e `gsettings list-recursively | grep -i pop-shell` para ver se há `launcher-opacity` ou similar.
6. **Alternativa radical**: editar `applications.js` da extensão pop-cosmic para injetar `set_style('background-color: rgba(40,42,54,0.70);')` no widget raiz. Isso é patch intrusivo e quebra em updates, mas funciona.

## Arquivos relevantes

- `/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/applications.js` — provavel local do código que renderiza o launcher
- `/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css` — (já substituído, com `.orig` preservado)
- `src/shell/pop-cosmic-dark.css` — nossa versão Dracula
- `scripts/instalar_pop_shell_css.sh` — substitui e reverte

## Reaplicar/reverter

```bash
# aplicar nossa versao
sudo ./scripts/instalar_pop_shell_css.sh install

# reverter para originais
sudo ./scripts/instalar_pop_shell_css.sh --revert

# recarregar extensoes (X11)
gnome-extensions disable pop-cosmic@system76.com
gnome-extensions enable pop-cosmic@system76.com
gnome-extensions disable pop-shell@system76.com
gnome-extensions enable pop-shell@system76.com
```

## Comando de inspeção para a próxima sessão

```bash
# 1. Inspecionar JS da extensao
grep -nE "set_style|background_color|Clutter\.Color|StyleContext" \
    /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/*.js

# 2. Listar seletores reais em uso
grep -hE "style_class\s*[:=]\s*['\"]" \
    /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/*.js | sort -u

# 3. Testar CSS minimo
sudo bash -c 'echo ".cosmic-applications-dialog { background: #ff0000 !important; }" >> /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css'
gnome-extensions disable pop-cosmic@system76.com && gnome-extensions enable pop-cosmic@system76.com
# abrir launcher e ver se fica vermelho. reverter:
sudo ./scripts/instalar_pop_shell_css.sh install
```
