# Índice de Sprints

Registro histórico das sprints de desenvolvimento do Dracula_OS-Theme.
Cada sprint é um conjunto coeso de decisões + implementação; quando concluída,
vira commit/PR atômico e tem sua entrada referenciada no `CHANGELOG.md`.

| #  | Título                                   | Status        | Data       |
|----|------------------------------------------|---------------|------------|
| 01 | [Pós-upgrade do sistema](SPRINT_01_POS_UPGRADE.md)      | Em investigação (pseudo-código; absorvida pela SPRINT_06) | 2026-04-16 |
| 02 | [Transparência do launcher Pop!_Cosmic](SPRINT_02_TRANSPARENCIA.md)   | Concluída (alpha 0.45) | 2026-04-16 |
| 03 | [Tema de som Pop!_OS](SPRINT_03_POP_SOUNDS.md)   | Concluída     | 2026-04-16 |
| 04 | [Atalhos de teclado + som do PrintScreen](SPRINT_04_ATALHOS.md) | Concluída | 2026-04-16 |
| 05 | [Extensões GNOME Shell](SPRINT_05_GNOME_EXTENSIONS.md) | Concluída | 2026-04-16 |
| 06 | [Resiliência pós full-upgrade](SPRINT_06_RESILIENCIA_POS_UPGRADE.md) | Concluída | 2026-04-17 |
| 07 | [Portabilidade universal](SPRINT_07_PORTABILIDADE.md) | Concluída | 2026-04-17 |
| 08 | [Segurança e robustez dos scripts](SPRINT_08_SEGURANCA_ROBUSTEZ.md) | Concluída | 2026-04-17 |
| 09 | [Testes, CI e suporte 24.04/COSMIC](SPRINT_09_TESTES_CI_COSMIC.md) | Concluída | 2026-04-17 |
| 10 | [Localização pt-BR do launcher Pop!_Cosmic](SPRINT_10_LAUNCHER_PTBR.md) | Concluída | 2026-05-07 |
| 11 | [Higiene do app-grid Pop!_Cosmic](SPRINT_11_LAUNCHER_HIGIENE.md) | Concluída | 2026-05-07 |
| 12 | [Propagação completa dos symbolic icons no Dracula-Icones](SPRINT_12_DELETE_ICON.md) | Concluída | 2026-05-07 |
| 13 | [Patcher universal de ícones Steam](SPRINT_13_STEAM_ICONS.md) | Concluída | 2026-05-07 |
| 14 | [Cobertura completa do reaplicar_tema](SPRINT_14_REAPLICAR_COBERTURA.md) | Concluída | 2026-05-07 |
| 15 | [Housekeeping: rotação de backups e correções secundárias](SPRINT_15_HOUSEKEEPING.md) | Concluída | 2026-05-07 |
| 16 | [Housekeeping II: rotação de backups de .desktop e de logs](SPRINT_16_HOUSEKEEPING_DESKTOPS_LOGS.md) | Concluída | 2026-05-07 |
| 17 | [Cobertura de gaps: wallpapers, Spicetify pós-update, dependências externas](SPRINT_17_COBERTURA_GAPS.md) | Concluída | 2026-05-07 |
| 18 | [Spicetify autônomo (sem Spellbook-OS)](SPRINT_18_SPICETIFY_AUTONOMO.md) | Concluída | 2026-05-07 |
| 19 | [`test_portabilidade.sh`: filtrar arquivos não-versionados](SPRINT_19_TEST_PORTABILIDADE_FILTRO_UNTRACKED.md) | Concluída | 2026-05-07 |
| 22 | [Logo do Clapper no app e nos arquivos de vídeo](SPRINT_22_CLAPPER_ICONE_VIDEO.md) | Concluída | 2026-06-25 |
| 20 | [GIMP (Flatpak) + PhotoGIMP autônomo](SPRINT_20_GIMP.md) | Concluída | 2026-06-02 |
| 21 | [Wallpaper de vídeo (Hidamari)](SPRINT_21_WALLPAPER_VIDEO.md) | Concluída | 2026-06-25 |
| 25 | [Tema de som cyberpunk/sci-fi (Kenney CC0)](SPRINT_25_SONS_CYBERPUNK.md) | Concluída | 2026-06-25 |
| 23 | [Topbar em múltiplos monitores](SPRINT_23_TOPBAR_MULTI_MONITOR.md) | Concluída | 2026-06-25 |
| 24 | [Cobertura de ícones nativos via aliases técnicos](SPRINT_24_ICONES_NATIVOS_ALIASES.md) | Concluída | 2026-06-25 |
| 26 | [Captura da config completa do Obsidian](SPRINT_26_OBSIDIAN_CONFIG.md) | Concluída | 2026-06-25 |
| 27 | [Pasta "Utilitários"/YaST escondida de forma durável](SPRINT_27_LAUNCHER_UTILITARIOS_DURAVEL.md) | Concluída | 2026-06-25 |
| 29 | [Wire das logos curadas do depósito apps-global](SPRINT_29_LOGOS_APPS_GLOBAL.md) | Concluída | 2026-06-25 |
| 30 | [Wallpaper de vídeo via xwinwrap + mpv (substitui o Hidamari)](SPRINT_30_WALLPAPER_XWINWRAP.md) | Concluída | 2026-06-25 |
| 31 | [Hardening de infra: vendorização, install idempotente, exceção do santuário](SPRINT_31_INFRA_HARDENING.md) | Concluída | 2026-06-26 |
| 32 | [Fechamento do débito do estudo (resiliência, testes, docs)](SPRINT_32_DEBITO_ESTUDO.md) | Concluída | 2026-06-26 |

## Convenção de nomenclatura

`SPRINT_<NN>_<TITULO_EM_SNAKE_CASE>.md`

- `NN` é zero-padded (01, 02, ..., 12, ...).
- Título em português, sem acentos no nome do arquivo (por compatibilidade),
  mas acentos presentes no corpo.
- Status possíveis: **Aberta**, **Em investigação**, **Em implementação**,
  **Concluída**, **Arquivada**.

## Como criar uma sprint nova

1. Copiar o template da sprint anterior mais próxima em escopo.
2. Preencher: **Contexto** → **Hipóteses/Objetivos** → **Arquitetura** →
   **Próximos passos** → **Verificação**.
3. Adicionar linha nesta tabela.
4. Ao concluir, registrar no `CHANGELOG.md` na versão correspondente.

*"O começo é mais que a metade do todo." — Aristóteles*
