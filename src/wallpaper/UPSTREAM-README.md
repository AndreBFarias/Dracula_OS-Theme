# src/wallpaper — origem do xwinwrap

`xwinwrap.c` é vendorizado do fork **ujjwal96/xwinwrap**
(<https://github.com/ujjwal96/xwinwrap>), descendente do `xwinwrap` original
de Shantanu Goel. Licença **GPL**.

É um único arquivo C (~738 linhas) que cria uma janela "stamp" na área de
trabalho do X11 e roda um comando dentro dela (aqui, `mpv`). Usado pelo
backend de wallpaper de vídeo (SPRINT 30), compilado no install com:

```
gcc xwinwrap.c -lX11 -lXext -lXrender -o ~/.local/bin/dracula-xwinwrap
```

Pré-requisitos de build (apt): `libx11-dev libxext-dev libxrender-dev gcc`.

Não modificamos o fonte; é redistribuído sob a GPL com esta atribuição.
