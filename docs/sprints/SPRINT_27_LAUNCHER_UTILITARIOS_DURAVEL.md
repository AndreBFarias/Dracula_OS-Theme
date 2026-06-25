# Sprint 27 — Pasta "Utilitários"/YaST: esconder de forma durável

A pasta "Utilitários" (`X-GNOME-Utilities`) e "YaST" (`X-SuSE-YaST`) reapareciam no launcher mesmo após a higiene (SPRINT 11). Causa-raiz: o fix antigo fazia `dconf reset` na pasta, o que **revertia ao default populado do Pop!_OS** em vez de escondê-la.

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 27.
> - **Sem sudo**: tudo via dconf de usuário.
> - **Esvaziar > resetar**: pasta com `apps=[]`/`categories=[]` é escondida pelo GNOME e o valor de usuário persiste no login.

## Causa-raiz (investigada ao vivo)

- `folder-children` estava de volta em `['Utilities', 'YaST']`.
- O default vem de `/usr/share/glib-2.0/schemas/50_pop-session.gschema.override` + do script `/usr/bin/pop-app-folders` (disparado por `/etc/xdg/autostart/pop-app-folders.desktop`).
- `pop-app-folders` é **cache-gated** (`~/.cache/pop-app-folders`, versão atual `6`): só roda em upgrade do `pop-default-settings`, e mexe apenas nas pastas `Pop-*` — **não** reseta Utilities/YaST.
- **Bug do fix antigo** (`instalar_higiene_launcher.sh:84`): `dconf reset -f /folders/<pasta>/` revertia a pasta ao default POPULADO. Como o GNOME mostra pasta com conteúdo, ela reaparecia.

## Solução

`instalar_higiene_launcher.sh` (Parte B): em vez de `dconf reset`, **esvaziar** cada pasta vendor:

```
dconf write /org/gnome/desktop/app-folders/folders/<pasta>/apps          "@as []"
dconf write /org/gnome/desktop/app-folders/folders/<pasta>/categories    "@as []"
dconf write /org/gnome/desktop/app-folders/folders/<pasta>/excluded-apps "@as []"
```

Pasta vazia é escondida pelo GNOME; o valor de usuário sobrevive ao login (nada o reseta — `pop-app-folders` é cache-gated e só toca `Pop-*`). Mantém também a remoção de `folder-children` (cinto e suspensório). Se um upgrade bumpar a versão do `pop-app-folders`, o APT hook (SPRINT 06) reaplica a higiene.

`desinstalar_higiene_launcher.sh`: a reversão agora faz `dconf reset` das pastas (restaura o conteúdo Pop default) além de re-adicionar a `folder-children`.

## Escopo (touches autorizados)

- `scripts/instalar_higiene_launcher.sh` — Parte B (reset → esvaziar) + mensagem.
- `scripts/desinstalar_higiene_launcher.sh` — reversão restaura conteúdo.
- `CHANGELOG.md`, `docs/sprints/INDEX.md`, `docs/sprints/SPRINT_27_LAUNCHER_UTILITARIOS_DURAVEL.md`.

## Proof-of-work runtime-real (executado ao vivo)

```bash
# Estado problemático reproduzido:
gsettings set ...app-folders folder-children "['Utilities', 'YaST']"
dconf write .../Utilities/categories "['X-GNOME-Utilities']"

bash scripts/instalar_higiene_launcher.sh
# => OK: Parte B — folder-children agora [] (pastas vendor esvaziadas)

gsettings get ...folder-children            # @as []
dconf read .../Utilities/apps               # @as []
dconf read .../Utilities/categories         # @as []
dconf read .../YaST/categories              # @as []

bash scripts/diagnostico.sh --quiet         # exit 0 (após shell estável)
```

Aplicado na sessão + reload do Shell. Persistência ao logout é por design (valor de usuário no dconf; nada repõe Utilities/YaST esvaziadas).

## Riscos conhecidos

- **Upgrade do `pop-default-settings`** com bump de versão do `pop-app-folders`: pode repor Pop-* (não Utilities/YaST). O APT hook reaplica a higiene. Mitigado.
- **Reversão**: `desinstalar` restaura via `dconf reset` (repopula Pop default).

---

*"Esvaziar é mais durável que apagar." — a pasta sem conteúdo simplesmente não aparece.*
