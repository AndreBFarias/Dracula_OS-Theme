# Sprint 20 — GIMP (Flatpak) + PhotoGIMP autônomo

Instalar o GIMP via Flatpak e aplicar o [PhotoGIMP](https://github.com/Diolinux/PhotoGIMP) (layout/atalhos estilo Photoshop) de forma autônoma e idempotente, integrado ao `install.sh`. Documentação retroativa (a sprint foi implementada e registrada no `CHANGELOG.md`; este arquivo fecha a ponta solta de spec — SPRINT 28).

> **Decisões fixas**:
> - **Numeração**: SPRINT 20.
> - **Flatpak** `org.gimp.GIMP` via flathub; sem sudo.
> - **PhotoGIMP fixado** para reprodutibilidade: tag `3.0`, asset `PhotoGIMP-linux.zip`, **sha256 pinado** (`1af6e2a6…e54e`), cache em `~/.cache/dracula_os_theme/`.
> - **Versão-dir de config detectada dinamicamente** (host `~/.config/GIMP/<versão>` quando há override `xdg-config/GIMP`, senão sandbox `~/.var/app/org.gimp.GIMP/config/GIMP/<versão>`).

## Contexto

- O GIMP stock tem layout multi-janela e atalhos próprios, distantes do fluxo Photoshop. O PhotoGIMP reorganiza para single-window estilo Photoshop + splash + launcher próprio.
- Caso real do host: o Flatpak tem override `xdg-config/GIMP:create`, então a config ativa é `3.2` apesar de o pacote trazer `3.0` — a detecção dinâmica resolve isso (fix do commit `3c5be00c`: `Exec gimp-3.0` → `gimp` + remoção de `sessionrc` incompatível).

## Solução

`scripts/instalar_gimp.sh`:
1. Garante o remote flathub; instala/atualiza `org.gimp.GIMP`. O `flatpak update` preempta o relink de runtime pendente que fazia o primeiro start "não abrir".
2. Baixa o PhotoGIMP (sha256 verificado, cache) e remove `.DS_Store` do upstream.
3. Detecta a versão-dir de config ativa (host ou sandbox; em máquina nova, start headless `flatpak run … -i --quit` para gerá-la).
4. Backup da config atual com `backup_com_manifest` em `~/.cache/dracula_os_backup/gimp_<ts>/` (retém 10 via `_purgar_antigos`) antes de sobrescrever.
5. Aplica o PhotoGIMP; o launcher `org.gimp.GIMP.desktop` sombreia o do Flatpak via precedência de `XDG_DATA_HOME`.

Idempotente, sem sudo. `DRACULA_DRY_RUN=1`, flags `--apenas-detectar`/`--skip-photogimp`.

## Escopo

- `scripts/instalar_gimp.sh` — instalador.
- `install.sh` — flag `--gimp` (fase user, não-fatal), **incluída em `--all`** (e `--bootstrap`).
- `uninstall.sh` — reversão.
- `docs/sprints/SPRINT_20_GIMP.md` — este spec (retroativo, SPRINT 28).

## Proof-of-work

```bash
bash -n scripts/instalar_gimp.sh
flatpak info org.gimp.GIMP
bash scripts/instalar_gimp.sh --apenas-detectar   # estado do GIMP + versão-dir ativa
```

Validação visual original: splash "PhotoGIMP by Diolinux" e janela single-window estilo Photoshop capturados via CLI X11.

## Riscos conhecidos

- **Versão-dir divergente** (pacote 3.0 vs config 3.2): resolvido por detecção dinâmica.
- **GIMP aberto durante a aplicação**: aviso não-fatal (`flatpak ps`) para não perder estado ao sair.

---

*"A ferramenta certa, com a mão que já se conhece." — o GIMP com a memória muscular do Photoshop.*
