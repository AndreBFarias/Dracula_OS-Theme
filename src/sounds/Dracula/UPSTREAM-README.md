# Tema de som Dracula — origem dos efeitos

Os 25 efeitos sonoros (`stereo/{action,alert,notification}/*.oga`) são curados a
partir do pacote **Kenney "Sci-fi Sounds"** (73 sons), licença **CC0 1.0**
(domínio público, sem atribuição obrigatória).

- Fonte: <https://kenney.nl/assets/sci-fi-sounds>
- Licença: CC0 1.0 Universal (`License.txt`).

Curadoria: foram escolhidos os sons curtos e sutis (0,24 s–0,95 s) adequados a
eventos de sistema (`laserRetro`, `laserSmall`, `impactMetal`, `doorOpen/Close`,
`forceField`), excluindo explosões, lasers grandes e loops de engine de 5 s.
Os arquivos `.ogg` (Ogg Vorbis) do pacote foram copiados sem reencode para
`.oga` (mesmo container/codec). O mapeamento evento→som está documentado no
spec `docs/sprints/SPRINT_25_SONS_CYBERPUNK.md`.

Para trocar um som: substitua o `.oga` correspondente (qualquer Ogg Vorbis curto)
e reinstale com `scripts/instalar_sons.sh --user --theme Dracula`.
