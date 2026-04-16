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
