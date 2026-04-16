# Sprint 05 — Extensões GNOME Shell

## Contexto

O usuário mantém 13 extensões GNOME Shell customizadas em
`~/.local/share/gnome-shell/extensions/`. Cada reinstalação manual do
Pop!_OS obriga a baixar e configurar todas uma a uma. Esta sprint cria
manifesto + instalador para restaurar o conjunto completo em um comando.

## Estrutura

```
app-themes/gnome-extensions/
├── extensions.json          # manifesto (13 entradas com uuid/repo/dconf)
└── dconf/
    ├── big-avatar.dconf
    ├── color-picker.dconf
    ├── dash-to-dock-pop.dconf      # namespace usado por dash-to-dock-cosmic
    ├── pano.dconf
    ├── pop-shell.dconf             # ext. do sistema, mas config do usuário
    ├── pop-cosmic.dconf
    ├── spotify-controller.dconf
    ├── sp-tray.dconf
    ├── user-theme.dconf
    └── ...                         # 12 arquivos total
```

## As 13 extensões user

| UUID | Nome | Versão | Dconf |
|------|------|--------|-------|
| `big-avatar@gustavoperedo.org` | Big Avatar | 16 | sim |
| `bluetooth-quick-connect@bjarosze.gmail.com` | Bluetooth Quick Connect | 34 | não |
| `color-picker@tuberry` | Color Picker | 30 | sim |
| `dash-to-dock-cosmic-@halfmexicanhalfamazing@gmail.com` | Dash to Dock for COSMIC | 23 | sim (namespace dash-to-dock-pop) |
| `drive-menu@gnome-shell-extensions.gcampax.github.com` | Removable Drive Menu | 51 | não |
| `impatience@gfxmonk.net` | Impatience | 22 | não |
| `killapp@adam.gadmz` | Kill App | 5 | não |
| `pano@elhan.io` | Pano Clipboard Manager | 19 | sim |
| `sound-output-device-chooser@kgshank.net` | Sound Device Chooser | 43 | não |
| `spotify-controller@koolskateguy89` | Spotify Controller | 17 | sim |
| `sp-tray@sp-tray.esenliyim.github.com` | spotify-tray | 22 | sim |
| `transparent-top-bar@zhanghai.me` | Transparent Top Bar | 16 | não |
| `user-theme@gnome-shell-extensions.gcampax.github.com` | User Themes | 49 | sim |

## Scripts

- **`scripts/capturar_gnome_extensions.sh`** — roda `dconf dump` em todos
  os namespaces `/org/gnome/shell/extensions/*/` e grava em
  `app-themes/gnome-extensions/dconf/`. Remove os sem customização.
- **`scripts/instalar_gnome_extensions.sh`** — itera o manifesto:
  1. Se já presente em `~/.local/share/gnome-shell/extensions/<uuid>/` → pula.
  2. Tenta `gnome-extensions install --force <uuid>` (via EGO).
  3. Fallback: clone git shallow do `repo` (+ `repo_branch`/`repo_subdir`
     do manifesto se necessário) para `~/.local/share/gnome-shell/extensions/<uuid>/`.
  4. `gnome-extensions enable <uuid>`.
  5. `dconf load /org/gnome/shell/extensions/<ns>/ < dconf/<ns>.dconf`.

Flags:
- `--only-dconf` — só aplica configurações (quando extensões já estão
  instaladas).
- `--revert` — desativa todas as extensões do manifesto via
  `gnome-extensions disable`.

## Integração no install.sh

```bash
./install.sh --user --gnome-extensions   # só extensões
./install.sh --user --all                # tudo inclusive extensões
```

Ordem: após Pop!_Shell CSS e Sounds, antes de Keybindings. Keybindings
depende de algumas extensões já ativas (ex: Gradia não é extensão, mas
atalhos de extensão como Pano `<Super>v` precisam da extensão instalada).

## Riscos conhecidos

1. **EGO x versão GNOME**: extensions.gnome.org pode recusar instalar se
   `shell-version` no metadata não cobrir a versão atual. Fallback git
   clone contorna isso.
2. **Repos multi-extension**: `gnome-shell-extensions` (GNOME oficial)
   hospeda várias; manifesto usa `repo_subdir` para apontar a pasta certa.
3. **Reload do shell**: após instalar via git, o shell precisa recarregar
   (Alt+F2 → r em X11, logout em Wayland). Mensagem final do script avisa.

## Verificação

```bash
# Após ./install.sh --user --gnome-extensions + logout/login:
gnome-extensions list --enabled | sort
# deve listar as 13 UUIDs (+ pop-shell + pop-cosmic do sistema)

# Confirmar uma config foi aplicada:
dconf read /org/gnome/shell/extensions/pano/history-length
# deve retornar o valor do snapshot capturado

dconf read /org/gnome/shell/extensions/user-theme/name
# deve retornar 'Dracula-standard-buttons'
```

## Recapturar após instalar nova extensão

```bash
# 1. Instale a extensão via extensions.gnome.org normalmente
# 2. Configure no Extensions Manager
# 3. Rode:
./scripts/capturar_gnome_extensions.sh
# 4. Edite app-themes/gnome-extensions/extensions.json manualmente
#    adicionando o novo UUID e o repo upstream
# 5. git commit -m "feat(extensions): adiciona <nome>"
```

## Status

**Concluída** em 2026-04-16.

*"O conhecimento que não se adquire por esforço próprio não é nunca
inteiramente nosso." — Santo Agostinho*
