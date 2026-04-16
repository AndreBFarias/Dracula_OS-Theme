# Sprint 03 — Tema de som Pop!_OS

## Contexto

O tema Dracula_OS-Theme até a versão 1.0.0 cobria ícones, cursor, GTK,
shell e ajustes em apps, mas deixava o som do sistema com o tema default
(`freedesktop` da maioria das instalações GNOME). O usuário pediu para
trazer o tema **Pop** oficial como parte da instalação.

## Fonte

- Pacote Debian: `pop-sound-theme` (produzido pelo source `pop-gtk-theme`
  do System76).
- Repositório upstream: `https://github.com/pop-os/gtk-theme` na pasta
  `sounds/`.
- Licença dos arquivos de áudio: **CC-BY-SA-4.0** (Mads Rosendahl, 2018).

Como o upstream declarado (`pop-os/pop-sounds`) não existe como repo
separado no GitHub, redistribuímos os 26 arquivos `.oga` diretamente em
`src/sounds/Pop/` (444 KB total — pequeno o bastante para commit).

## Arquitetura

```
src/sounds/Pop/
├── index.theme                   # [Sound Theme] Name=Pop
└── stereo/
    ├── action/                   # 6 .oga (camera-shutter, screen-capture, bell, ...)
    ├── alert/                    # 4 .oga (alarm-clock, battery-low, ...)
    └── notification/             # 16 .oga (message, complete, system-ready, ...)
```

- **Build** (`build.sh` → `preparar_extras`): copia `src/sounds/` →
  `dist/sounds/`.
- **Install** (`scripts/instalar_sons.sh`): copia `dist/sounds/Pop` →
  `~/.local/share/sounds/Pop/` (user) ou `/usr/share/sounds/Pop/`
  (system), depois roda `gsettings set org.gnome.desktop.sound theme-name
  'Pop'`.
- **Uninstall**: script aceita `--revert` que remove o diretório e reseta
  o `gsettings`.

## Integração no install.sh

Nova flag `--sounds`:
```bash
./install.sh --user --sounds          # só sons
./install.sh --user --all             # tudo inclusive sons
```

Ordem de execução: após Pop!_Shell CSS e antes dos app-themes — sons são
independentes dos temas visuais e instalar antes garante que o
`gsettings` já estará setado quando outros scripts tocarem em
`org.gnome.desktop.sound`.

## Verificação

```bash
# Após ./install.sh --user --sounds:
gsettings get org.gnome.desktop.sound theme-name        # → 'Pop'
ls ~/.local/share/sounds/Pop/stereo/notification/       # → lista 16 .oga

# Teste auditivo:
canberra-gtk-play --id=complete --description="teste"   # se canberra instalado
# ou: plugar/desplugar USB → som device-added/removed
```

## Reverter

```bash
./scripts/instalar_sons.sh --revert
# ou:
./uninstall.sh --user          # já remove automaticamente
```

## Status

**Concluída** em 2026-04-16. Próximos passos eventuais: considerar
tema `FreeDesktop` como fallback, ou criar variante Dracula customizada
(trocar `.oga` por versões com timbre roxo — projeto para outra sprint).

*"O mundo não é uma prisão, mas um playground de possibilidades." — Alan Watts*
