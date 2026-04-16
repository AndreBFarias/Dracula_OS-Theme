# Sprint 02 — Transparência do Pop!_OS Launcher

**Status: Concluída (2026-04-16)**.

Investigação resolvida: o launcher `.cosmic-applications-dialog` aceita
`background` com rgba, mas o alpha escolhido inicialmente (`0.70`) era
alto demais para deixar a transparência visualmente perceptível. Ajuste
final em `src/shell/pop-cosmic-dark.css`:

```css
.cosmic-applications-dialog {
    background: rgba(40, 42, 54, 0.45);  /* antes: 0.70 opaco */
    box-shadow: 0 4px 8px 2px rgba(0, 0, 0, 0.25);
    border: 1px solid #bd93f9;
    border-radius: 16px;
}
```

**Investigação registrada (mantida para referência)**:

- **H1 (extensões carregadas)**: ✓ `pop-cosmic` + `pop-shell` + `dash-to-dock-cosmic` ativas.
- **H2 (sessão)**: X11.
- **H3 (JS setters)**: ✓ descartado — `applications.js:721` só seta
  `height/width`, não `background`.
- **H4 (teste CSS vermelho)**: ✓ appended `.cosmic-applications-dialog {
  background: #ff0000 !important; }` ao `dark.css` da extensão. Launcher
  ficou vermelho puro → seletor correto.
- **H5 (alpha renderiza)**: ✓ appended `rgba(40,42,54,0.3)`. Launcher
  ficou transparente → compositor aceita alpha. Causa do "bug" original:
  valor 0.70 era alto demais.
- **H6 (dconf keys)**: descartado — sem keys de opacity/blur expostas.

Hipóteses H7–H10 não foram necessárias. Mantidas abaixo para referência
histórica caso o launcher volte a regredir após update do Pop!_Shell.

---

## Estado atual — o que foi feito

1. **`src/shell/pop-shell-dracula.css`** anexado ao `gnome-shell.css` do tema GTK via `build.sh`.
   - Regras: `.pop-shell-search`, `.pop-shell-search.modal-dialog`, `.pop-shell-entry`, `.pop-shell-overlay`, `.pop-shell-active-hint`, `.pop-shell-tab-*`.
   - `!important` em todas para vencer especificidade do tema base.

2. **`/usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css`** substituído (backup `.orig`) por `src/shell/pop-shell-dark.css`:
   - Troca `#FBB86C` (laranja) e `#9B8E8A` (cinza-rosado) pela paleta Dracula.
   - Define `.pop-shell-search { background: rgba(40,42,54,0.55); border: 1px solid #bd93f9; }`.

3. **`/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css`** substituído por `src/shell/pop-cosmic-dark.css`:
   - `.cosmic-applications-dialog { background-color: #36322f; }` (marrom) → `rgba(40,42,54,0.45)` + borda purple + radius 16px.
   - Esta é a extensão que controla de fato o launcher "Applications" visualizado.

**Resultado visual final**: fundo Dracula translúcido com papel de parede
visível por trás, borda purple, radius suave.

---

## 10 hipóteses ordenadas do mais barato ao mais agressivo

### H1. Cache do GNOME Shell não invalidou

GNOME Shell pode manter cache de CSS mesmo com `Alt+F2 r`.

**Teste:**
```bash
gnome-extensions disable pop-cosmic@system76.com
sleep 1
gnome-extensions enable pop-cosmic@system76.com
# Se não mudar, precisa logout completo
```

### H2. Compositor em Wayland bloqueia alpha no ModalDialog

No Pop!_OS 22.04 com Mutter/X11, a janela do ModalDialog pode não ter flag `RGBA` para aceitar transparência. Em Wayland, pode funcionar ou não.

**Teste:**
```bash
echo "Session type: $XDG_SESSION_TYPE"
# Logout → reentrar como X11 vs Wayland e comparar
```

### H3. Código JavaScript da extensão seta background explicitamente

`pop-cosmic/applications.js` pode definir `set_style` via Clutter ignorando o CSS. Nesse caso, correção não é só CSS — precisa editar o JS.

**Teste:**
```bash
grep -nE "set_style|background_color|Clutter\\.Color|StyleContext" \
    /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/*.js
```

### H4. Seletor CSS errado

O elemento real do dialog pode ter classe diferente. Nome `.cosmic-applications-dialog` deduzido do `dark.css` mas implementação pode usar wrapper diferente.

**Teste (CSS vermelho):**
```bash
sudo bash -c 'echo ".cosmic-applications-dialog { background: #ff0000 !important; }" \
    >> /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css'
gnome-extensions disable pop-cosmic@system76.com && gnome-extensions enable pop-cosmic@system76.com
# Abre launcher. Se ficar vermelho → seletor OK, problema é só alpha.
# Se continuar escuro → seletor errado ou JS sobrepõe.
sudo ./scripts/instalar_pop_shell_css.sh install  # reverter
```

### H5. Compositor sem RGBA visuals

Mesmo em X11, o compositor pode não estar ativando RGBA visuals. Sem isso, alpha no fundo não renderiza.

**Teste:**
```bash
# Verifica se há compositor ativo
xprop -root _NET_WM_CM_S0

# Confirma suporte a 32-bit depth
xdpyinfo | grep -i "depth"

# Se retornar apenas 24, o X não aceita alpha em janelas top-level
```

### H6. dconf/gsettings expõe opacidade diretamente

Algumas extensões têm schemas com keys como `launcher-opacity`, `blur-radius`, `background-alpha`. Se houver, basta `gsettings set` em vez de mexer em CSS.

**Teste:**
```bash
gsettings list-recursively 2>/dev/null | grep -iE "pop-cosmic|pop-shell|cosmic-dock|launcher"
# Procurar keys relacionadas a opacity, alpha, blur, transparency
```

### H7. Injeção via Looking Glass em runtime

Usar `imports.ui.main.layoutManager` para localizar o widget e aplicar `set_style` em tempo real. Se funcionar, confirma H3 (JS setters) ou H4 (seletor errado) e dá pista do seletor correto.

**Teste (abrir Alt+F2 → `lg`):**
```js
// No console "Evaluator" do Looking Glass
const Main = imports.ui.main;
const app = Main.layoutManager.uiGroup.get_children()
    .find(c => c.style_class && c.style_class.includes('cosmic'));
if (app) {
    app.style_class_list.forEach(c => print('Classe:', c));
    app.set_style('background-color: rgba(40,42,54,0.55); border-radius: 16px;');
    print('Style aplicado');
} else {
    print('Widget não encontrado — procurar em modalDialog');
}
```

### H8. Patch no `applications.js` da extensão

Se H3 se confirmar, editar o JS diretamente. Abordagem invasiva, quebra em updates do Pop!_Shell, mas funciona.

**Fluxo:**
1. Backup: `sudo cp /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/applications.js{,.orig}`
2. Identificar linha com `set_style` ou `set_background_color`
3. Substituir valor para `rgba(40, 42, 54, 0.55)`
4. Adicionar ao `scripts/instalar_pop_shell_css.sh` como novo alvo (com seu próprio `.orig`)
5. `--revert` restaura todos os `.orig`

### H9. Override com seletor genérico `.modal-dialog`

Seletor mais genérico no `gnome-shell.css` do tema. Risco: afeta outros dialogs (logout, confirmação). Mitigação: combinar com pseudo-class ou ancestor.

**Teste:**
```css
/* Adicionar em pop-shell-dracula.css */
.modal-dialog.cosmic-applications-dialog,
#popupMenuContent.modal-dialog {
    background-color: rgba(40, 42, 54, 0.55) !important;
}
```

Se sobrepuser, evolui; se afetar logout/kb-shortcuts, reverte.

### H10. Substituir extensão pop-cosmic por alternativa

Se H1-H9 falharem, trocar de launcher. Opções:

- **Ulauncher** (já instalado) — temas próprios em `~/.config/ulauncher/user-themes/` (JSON + CSS) com transparência e blur nativos. Criar tema Dracula e mapear Super-key.
- **Nothing Launcher** (via extensão GNOME) — moderno, transparente por padrão.
- **Albert** (launcher Qt) — suporta CSS pleno.

Documentar o switch como "opção nuclear" no README e manter como última alternativa.

---

## Scripts de debug

Crie `scripts/debug_launcher.sh` com o conteúdo abaixo para rodar H1-H6 automaticamente:

```bash
#!/usr/bin/env bash
# debug_launcher.sh — roda H1-H6 da SPRINT-TRANSPARENCIA e imprime resultado
set -u

echo "=== H1: extensões carregadas ==="
gnome-extensions list --enabled | grep -iE "pop|cosmic" || echo "  nenhuma"

echo ""
echo "=== H2/H5: display server + compositor ==="
echo "  XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
xprop -root _NET_WM_CM_S0 2>/dev/null | head -3
echo "  Depth(s): $(xdpyinfo 2>/dev/null | grep "depth of root" | awk '{print $NF}')"

echo ""
echo "=== H3: setters programáticos em JS ==="
grep -nE "set_style|background_color|Clutter\\.Color" \
    /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/*.js 2>/dev/null | head -10 \
    || echo "  nenhum setter óbvio"

echo ""
echo "=== H6: dconf keys relacionadas ==="
gsettings list-recursively 2>/dev/null | grep -iE "pop-cosmic|pop-shell|launcher.*opacity|blur" | head -10 \
    || echo "  nenhuma key com opacity/blur"

echo ""
echo "=== dark.css instalado ==="
grep -c "Dracula_OS-Theme\|rgba(40" /usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css \
    && echo "  Dracula CSS aplicado" \
    || echo "  dark.css NÃO é nosso (reverter ou reinstalar)"
```

---

## Arquivos relevantes

- `/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/applications.js` — provável local do código que renderiza o launcher (investigar em H3/H8)
- `/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css` — já substituído, com `.orig`
- `src/shell/pop-cosmic-dark.css` — nossa versão Dracula
- `scripts/instalar_pop_shell_css.sh` — substitui e reverte

---

## Reaplicar/reverter

```bash
# aplicar nossa versão
sudo ./scripts/instalar_pop_shell_css.sh install

# reverter para originais
sudo ./scripts/instalar_pop_shell_css.sh --revert

# recarregar extensões (X11)
gnome-extensions disable pop-cosmic@system76.com && gnome-extensions enable pop-cosmic@system76.com
gnome-extensions disable pop-shell@system76.com && gnome-extensions enable pop-shell@system76.com
```

---

## Priorização das próximas tentativas

Ordem custo/benefício decrescente quando retomar:

1. **H4 (CSS vermelho)** — confirma ou elimina seletor errado em 2 minutos
2. **H6 (dconf keys)** — se houver, basta um `gsettings set`
3. **H3 + H7 (Looking Glass)** — descobre se JS faz setters hardcoded
4. **H5 (compositor RGBA)** — checa pré-requisito de alpha
5. **H8 (patch do JS)** — caminho certo se H3 se confirmar
6. **H9 (seletor genérico)** — último recurso antes de trocar de launcher
7. **H10 (Ulauncher)** — opção nuclear se Pop!_Cosmic for irredutível
