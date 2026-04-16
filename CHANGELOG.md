# Changelog

Todos os ajustes notáveis deste projeto são documentados neste arquivo.
O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
e o versionamento semântico.

## [Não lançado]

### Adicionado
- Estrutura inicial do monorepo (ícones, cursor, GTK, shell, app-themes).
- Importação do tema custom atual (`~/.icons/Dracula-Icones/`).
- Importação dos 295 SVGs estilizados da `sessao_atual`.
- Upstreams vendored: `dracula-icons-main` e `dracula-icons-circle`.
- Ícones de projetos pessoais de `~/Desenvolvimento/`.
- `build.sh` com geração de PNGs em múltiplos tamanhos via `rsvg-convert`.
- `install.sh` com modo `--user` / `--system`.
- App themes: kitty, qBittorrent, GNOME Terminal, Spicetify, Obsidian, Telegram, Discord (BetterDiscord), OnlyOffice.
- Override `ZapZap` → `WhatsApp`.
- CSS custom do Pop!_OS Launcher (fundo Dracula, sem marrom).
- Integração com Spellbook-OS (`rebuild_dracula_theme`).
