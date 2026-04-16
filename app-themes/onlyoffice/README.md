# OnlyOffice — tema escuro Dracula

O OnlyOffice Desktop Editors não oferece temas de estilo CSS editáveis
como Obsidian ou Discord. O projeto fornece um conjunto fechado de temas
(Light, Dark, Classic Light, Contrast Dark). Para aproximar da paleta
Dracula:

## Configuração manual

1. Abrir OnlyOffice
2. Menu → Preferências → Aparência
3. Selecionar o tema **Dark** ou **Contrast Dark**
4. Em "Interface Theme", pode-se ajustar algumas cores pontuais via
   `DocumentServer` config (somente quando auto-hospedado).

## Automação via `instalar_app_themes.sh`

O script de instalação de app themes **define o tema escuro built-in
como default** via `gsettings` (quando aplicável) ou manipulando o
arquivo de configuração em
`~/.var/app/org.onlyoffice.desktopeditors/config/`.

Não há CSS custom para commitar neste diretório — documentação apenas.
