# Spicetify — Spotify com tema Dracula

O Spotify (Flatpak) deste sistema já está configurado com Spicetify + tema
**Sleek** + paleta **Dracula** via o script `spicetify-setup.sh` mantido em
Spellbook-OS.

## Reaplicar

```bash
~/Desenvolvimento/Spellbook-OS/scripts/spicetify-setup.sh
```

O script detecta automaticamente se o Spotify é Flatpak, snap ou nativo,
instala Spicetify (se necessário), clona o repositório de temas
(`spicetify/spicetify-themes`), configura `prefs_path` para o Flatpak,
aplica extensions + custom apps (marketplace, lyrics-plus, reddit,
new-releases) e executa `spicetify backup apply`.

## Configuração atual ativa

```
current_theme = Sleek
color_scheme  = Dracula
inject_theme_js = 1
inject_css = 1
replace_colors = 1
```

## Por que não duplicar no Dracula_OS-Theme

Evitar divergência: a lógica do Spellbook-OS já trata os edge cases
(limpeza de cache do Flatpak, geração de prefs na primeira execução,
validação pós-instalação). `scripts/instalar_app_themes.sh` apenas chama
essa rotina.

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
