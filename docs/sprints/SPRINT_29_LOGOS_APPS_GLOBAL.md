# Sprint 29 — Wire das logos curadas do depósito apps-global

Preencher ícones de apps que ainda caíam no fallback usando as logos góticas que o usuário já tinha curado em `src/icons/current/48x48/apps-global/` (depósito fora do pipeline de build).

> **Decisões fixas (não reabrir)**:
> - **Numeração**: SPRINT 29.
> - **Usar os assets do usuário** (apps-global), não caçar SVGs aleatórios — as logos já são Dracula/gótico e combinam com a paleta.
> - **Só preencher fallback real**: apps já tematizados (Edge, Opera, Discord, Spotify, Obsidian, gparted, vscode, weylus, whatsapp-linux-app) ficam como estão; não sobrescrever ícone que já funciona.

## Contexto

- O depósito `apps-global/` tem ~34 logos góticas (PNG) que o `build.sh` não consumia.
- SPRINT 22 (Clapper) e SPRINT 24 (Firefox) já wire-aram duas delas.
- Cruzando o depósito com os `Icon=` de apps instalados que faltam no tema, os ganhos reais (fallback feio + logo disponível) são **photogimp**, **dbeaver** e os **10 ícones Citrix `Ubuntu-*`**.

## Solução

Três entradas novas em `mapping.json` (origem `logo-usuario`):

| Chave | Fonte (apps-global) | Nomes gerados |
|---|---|---|
| `photogimp` | `gimp.png` (coruja gótica) | photogimp |
| `dbeaver` | `dbeaver.png` (castor gótico) | dbeaver, io.dbeaver.DBeaverCommunity |
| `citrix` | `citrix.png` (aranha/teia) | citrix + 10 `Ubuntu-*` (configmgr, conncenter, fido2_llt, logmgr, nfcui, receiver, receiver_fido2, selfservice, sendfeedback, wfica) |

`photogimp` casa com o launcher do PhotoGIMP (SPRINT 20); os `Ubuntu-*` são o Citrix Workspace.

## Escopo (touches autorizados)

- `mapping.json` — 3 entradas novas (após a entrada `firefox`).
- `CHANGELOG.md`, `docs/sprints/INDEX.md`, `docs/sprints/SPRINT_29_LOGOS_APPS_GLOBAL.md`.

NÃO tocar: `dist/` (rebuild), entradas existentes (apps já tematizados preservados), `build.sh`.

## Proof-of-work runtime-real

```bash
jq empty mapping.json                                  # válido
./build.sh                                             # "172 apps processados, 0 falhas" (era 169)
ls dist/icons/Dracula-Icones/256x256/apps/{photogimp,dbeaver,citrix,Ubuntu-wfica}.png   # gerados
cp -r dist/icons/Dracula-Icones ~/.local/share/icons/ && gtk-update-icon-cache -f ...   # aplicado ao vivo
```

Validação visual: montagem confirma photogimp (coruja gótica), dbeaver (castor gótico) e Citrix (aranha/teia roxa) no estilo Dracula.

## Itens fora de escopo (registrados)

- Apps instalados ainda sem logo no depósito: `org.gnome.SystemMonitor`, `org.gnome.TextEditor`, `nyx`, `hefesto`, `syncthing`, `repoman`, painéis `preferences-pop-*`, `pop-cosmic-*`. Precisam de arte nova (SVG) — sprint futura se houver demanda.

---

*"As logos que já existiam, agora no lugar certo." — o depósito vira tema.*
