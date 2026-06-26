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

Não há automação. O OnlyOffice guarda a preferência de tema num formato
fechado e não expõe `gsettings` nem CSS editável. A função
`aplicar_onlyoffice()` do `instalar_app_themes.sh` apenas **imprime a
instrução manual acima** e segue — por isso o passo continua manual.

Não há CSS custom para commitar neste diretório — documentação apenas.
