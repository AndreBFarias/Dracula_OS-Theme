# Spicetify — Spotify com tema Dracula

O Spotify (Flatpak) deste sistema é configurado com Spicetify + tema
**Sleek** + paleta **Dracula** via `scripts/instalar_spicetify.sh`,
autocontido neste repositório (SPRINT 18; antes da SPRINT 18, o setup
era delegado ao Spellbook-OS).

## Reaplicar

```bash
bash scripts/instalar_spicetify.sh
```

O script detecta automaticamente se o Spotify é Flatpak, snap ou nativo,
instala Spicetify (se necessário, via `curl | sh` oficial), clona o
repositório de temas (`spicetify/spicetify-themes`), configura
`prefs_path` para o Flatpak (rodando o Spotify uma vez se necessário),
aplica 13 chaves de config + extensions + custom apps (marketplace,
lyrics-plus, reddit, new-releases) e executa `spicetify backup apply`.

Idempotente: rodar 2× consecutivas é seguro. Suporta `DRACULA_DRY_RUN=1`,
`--apenas-detectar` (imprime tipo de Spotify e sai), e `--skip-marketplace`.

Como fallback, o setup mantido em
`~/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh` continua
disponível: `DRACULA_PREFER_SPELLBOOK_SPICETIFY=1 bash scripts/instalar_app_themes.sh`.

## Configuração atual ativa

```
current_theme = Sleek
color_scheme  = Dracula
inject_theme_js = 1
inject_css = 1
replace_colors = 1
```

## Boundary com Spellbook-OS

A SPRINT 18 internalizou o setup de Spicetify neste repositório
(`scripts/instalar_spicetify.sh`) para que o Dracula_OS-Theme não
dependa de outro repo para configurar o Spotify. O `spicetify-setup.sh`
mantido em Spellbook-OS continua reutilizável via
`DRACULA_PREFER_SPELLBOOK_SPICETIFY=1` quando o usuário já tem aquele
repo clonado e prefere a versão de lá. Os dois setups produzem o mesmo
estado final (mesmas 13 chaves de config, mesma lista de extensions
e custom apps, mesma sanitização de `custom_apps` espúrio).

## Troubleshooting

### "Spotify version and backup version are mismatched"

Sintoma observado após `flatpak update` do `com.spotify.Client`:

````
warning Spotify version and backup version are mismatched.
info Spotify cannot be backed up at this state.
Please re-install Spotify then run "spicetify backup apply"
````

E no Theme Dev Tools dentro do Spotify:

````
Error: No marketplace theme installed
Error: Class name list not found; please create an issue
````

Resolução em uma linha:

```bash
bash scripts/atualizar_spicetify.sh --auto-fix
```

O script encerra processos do Spotify, limpa o cache do Flatpak em
`~/.var/app/com.spotify.Client/cache/`, executa
`flatpak install --reinstall --noninteractive flathub com.spotify.Client`
(download ~150 MB) e roda `spicetify apply`. Sem flag, o script apenas
avisa e sugere a flag.

### Equivalente manual

```bash
pgrep -f spotify | xargs -r kill -9
rm -rf ~/.var/app/com.spotify.Client/cache/*
flatpak install --reinstall --noninteractive flathub com.spotify.Client
~/.spicetify/spicetify apply
```

`spicetify apply` (não `backup apply`): após reinstall, o Spicetify
reconhece a versão limpa e re-cria o backup automaticamente.
