# Sprint 06 — Resiliência pós `apt full-upgrade`

Implementação do que a SPRINT_01 desenhou em pseudo-código. O tema agora se auto-restaura após `apt upgrade`, `apt full-upgrade` e reboots, sem intervenção manual.

## Contexto

Auditoria pós `apt full-upgrade` (2026-04-17, Pop!_OS 22.04 + GNOME 42.9) identificou:

- ✅ Tema **sobrevive a reboot** — gsettings/dconf persistem.
- ⚠️ Tema **regride em componentes específicos** após upgrade:
  - `/usr/share/gnome-shell/extensions/pop-shell@system76.com/dark.css` volta ao original (laranja).
  - `/usr/share/gnome-shell/extensions/pop-cosmic@system76.com/dark.css` idem.
  - `gsettings org.gnome.desktop.sound theme-name` volta para `'freedesktop'` (**confirmado no diagnóstico real em 2026-04-17**).
  - `.desktop` de Flatpaks regridem `Icon=` absoluto após `flatpak update`.
  - Permissões 600 em `.desktop` reincidem após `update-desktop-database`.

A SPRINT_01 tinha pseudo-código em `SPRINT_01_POS_UPGRADE.md` mas nenhum script real foi criado. Esta sprint implementa de fato.

## Entregas

### `scripts/lib/common.sh` (nova biblioteca)

Biblioteca sourceable com:
- Cores e funções de log (`_info`, `_ok`, `_warn`, `_err`, `_dim`).
- `_repo_root` — detecta raiz do repo a partir de qualquer script (em `scripts/`, `scripts/lib/`, ou raiz).
- `_log_dir` / `_log_file` — log rotacionado em `~/.cache/dracula_os_theme/`.
- Guarda contra dupla importação.

Será expandida na SPRINT_08 com `validar_path_destrutivo`, `trap_cleanup_init`, `backup_com_manifest`.

### `scripts/diagnostico.sh` (health check read-only)

Verifica 28 pontos do tema aplicado:
- gsettings ativos (icon-theme, gtk-theme, cursor-theme, sound theme-name).
- Arquivos presentes (`~/.local/share/icons/Dracula-Icones`, tema GTK, cache válido).
- Pop!_Shell e Pop!_Cosmic `dark.css` contendo marcas Dracula (`bd93f9`, `rgba(40, 42, 54`).
- Overrides `.desktop` aplicados (ZapZap→WhatsApp, sem perm 600).
- kitty include, qBittorrent theme, pasta sons Pop.
- Cada UUID do `extensions.json` instalada; `user-theme` habilitada.

Exit code 0 = tudo OK; 1 = uma ou mais regressões. Flag `--quiet` para integração com outros scripts.

### `scripts/reaplicar_tema.sh` (idempotente)

Repara regressões sem rebuild de `dist/`:
1. Verifica tema instalado (se faltando, orienta `./build.sh && ./install.sh --all`).
2. Detecta Pop!_Shell/Pop!_Cosmic regredido (grep por marca Dracula) e reaplica só nesse caso.
3. `aplicar_overrides.sh` (ZapZap/WhatsApp).
4. `chmod 644` em `.desktop` fora do padrão.
5. `normalizar_desktops.sh` (Icon= absoluto de Flatpak).
6. **Tema de som**: se `gsettings` regrediu e pasta Pop existe, só reativa via gsettings (não recopia).
7. `instalar_app_themes.sh` (kitty/qBittorrent/Obsidian/Discord).
8. Rebuild de caches (`gtk-update-icon-cache`, `update-desktop-database`).
9. `diagnostico.sh --quiet` final para confirmar resolução.

Todo output é tee-ado para `~/.cache/dracula_os_theme/reaplicar_tema_<TS>.log`.

### `scripts/instalar_apt_hook.sh` (automação)

Instala `/etc/apt/apt.conf.d/99-dracula-os-theme` com:
- `DPkg::Post-Invoke` que chama `reaplicar_tema.sh` após toda operação apt.
- `$SUDO_USER` detectado dinamicamente (**zero hardcoded** `andrefarias`).
- Log sistêmico em `/var/log/dracula-theme-reaplicar.log`.
- Flag `--revert` remove o hook.

**Decisão de design:** o hook dispara em todo apt operation porque `reaplicar_tema.sh` é idempotente e barato (~1s quando nada regrediu). Filtrar por pacote exigiria `DPkg::Pre-Invoke` para capturar a lista — complexidade não justificada agora. A lista de pacotes-gatilho está documentada nos metadados do script para evolução futura.

### `install.sh --apt-hook` (flag nova)

Nova flag integra a instalação do hook ao fluxo principal. Não entra em `--all` por padrão (requer sudo e decisão do usuário).

## Verificação end-to-end executada

1. `./scripts/diagnostico.sh` → detectou **1 regressão real**: `theme-name='freedesktop'` em vez de `'Pop'` (causada pelo full-upgrade recente).
2. `./scripts/reaplicar_tema.sh` → exit 0; `gsettings get org.gnome.desktop.sound theme-name` agora retorna `'Pop'`.
3. `./scripts/diagnostico.sh` final → exit 0, 28/28 checks OK.
4. Log gravado em `~/.cache/dracula_os_theme/reaplicar_tema_<TS>.log`.

Validação do APT hook (instalação/remoção) fica para quando o usuário confortar rodar `sudo`.

## Pontos de contribuição do usuário (learning mode)

Dois ajustes ficam em aberto para sua decisão — ambos em `scripts/instalar_apt_hook.sh`:

1. **Lista `PACOTES_GATILHO`** (linhas 52-63): hoje serve só como metadado. Se quiser evoluir para hook condicional (só dispara quando pacote dessa lista é tocado), a lógica entra em `DPkg::Pre-Invoke` com captura de `APT::Install-Packages`. Quais pacotes adicionar/remover da lista atual?
2. **`DPkg::Post-Invoke` vs `Post-Invoke-Success`** (linha 93): `Post-Invoke` roda mesmo se o apt falhou no meio — bom para robustez. `Post-Invoke-Success` só roda em sucesso — bom para evitar reaplicar quando o sistema está inconsistente. Trade-off de segurança vs reatividade.

## Troubleshooting

| Sintoma | Comando |
|---|---|
| Tema degradou após upgrade | `./scripts/diagnostico.sh` depois `./scripts/reaplicar_tema.sh` |
| Hook APT não disparou | `cat /var/log/dracula-theme-reaplicar.log` |
| Remover hook | `sudo ./scripts/instalar_apt_hook.sh --revert` |
| Log de uma reaplicação | `ls -lt ~/.cache/dracula_os_theme/ | head` |

## Riscos conhecidos (herdados do design SPRINT_01)

- Pop!_Shell pode trazer mudanças estruturais no `dark.css` que quebrem a substituição Dracula → mitigação: script detecta via grep de marca Dracula, só reaplica quando marca sumiu (não sobrescreve versão mais nova se estrutura mudou).
- `flatpak update` não dispara APT hook → usuário precisa chamar `./scripts/reaplicar_tema.sh` manual após flatpak updates, OU rodar `./scripts/diagnostico.sh` periodicamente.
- Spicetify reaplicar falha quando versão do Spotify muda (observado no teste real) — não-fatal, já tratado com `_warn` dentro de `instalar_app_themes.sh`.

## Referências

- Desenho original: [SPRINT_01_POS_UPGRADE.md](SPRINT_01_POS_UPGRADE.md)
- Padrão de logging: CLAUDE.md §3
- Incidente base (GIMP Flatpak 600): [SPRINT_01:23-25](SPRINT_01_POS_UPGRADE.md)

---

*"Quod nocet saepe docet." — o que fere, muitas vezes ensina.*
