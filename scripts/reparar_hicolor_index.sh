#!/usr/bin/env bash
# reparar_hicolor_index.sh — mantém o index.theme do hicolor do usuário coerente
# com os diretórios que existem em disco.
#
# Problema que resolve:
#   ~/.local/share/icons/hicolor/index.theme costuma ser criado por instaladores
#   de terceiros declarando um punhado de tamanhos. A spec manda o GTK IGNORAR
#   qualquer diretório ausente de Directories=, então um ícone gravado em
#   64x64/apps ou 32x32/apps simplesmente não resolve — o arquivo existe, o
#   .desktop aponta certo, e Gtk.IconTheme.lookup_icon() devolve None. Pior:
#   gtk-update-icon-cache chega a indexar o arquivo, o que faz o cache parecer
#   correto e manda o diagnóstico para o lado errado.
#
#   Isto atinge este próprio repositório: atualizar_icones_steam.sh grava o
#   fallback em 32x32/apps.
#
# O que faz:
#   ACRESCENTA ao Directories= os diretórios presentes em disco que faltam, e
#   cria a seção de cada um. Nunca remove entrada nem seção: um index.theme que
#   declare mimetypes/, actions/ ou traga Inherits= sai intacto. Cobre também
#   diretórios HiDPI no formato <N>x<N>@<M>x.
#
# Idempotência:
#   recalcula sempre; só grava quando há diretório faltando. Escrita atômica
#   (tmp + rename), então morte no meio não deixa índice truncado. Guarda
#   index.theme.bak na primeira alteração. O cache é regenerado sempre que
#   estiver mais velho que o índice, não só quando o índice muda.
#
# Variáveis de ambiente:
#   DRACULA_DRY_RUN=1 — não grava; apenas informa o que mudaria.
#
# Saída:
#   exit 0 — OK (inclusive quando nada precisa mudar).
#   exit 1 — falha ao gravar o index.theme.
#
# Sem sudo. Toca apenas ~/.local/share/icons/hicolor/index.theme.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

readonly HICOLOR="$HOME/.local/share/icons/hicolor"
readonly INDEX="$HICOLOR/index.theme"
readonly DRY_RUN="${DRACULA_DRY_RUN:-0}"

if [[ ! -d "$HICOLOR" ]]; then
    _info "hicolor do usuário não existe; nada a reparar"
    exit 0
fi

saida=$(/usr/bin/python3 - "$HICOLOR" "$DRY_RUN" <<'PY'
import os, re, sys, tempfile

hicolor, dry = sys.argv[1], sys.argv[2] == "1"
index = os.path.join(hicolor, "index.theme")

# <N>x<N> e <N>x<N>@<M>x; scalable e symbolic entram como Scalable.
RE_TAM = re.compile(r"^(\d+)x\1(?:@(\d+)x)?$")

presentes = []
for nome in sorted(os.listdir(hicolor)):
    base = os.path.join(hicolor, nome)
    if not os.path.isdir(base):
        continue
    if not (RE_TAM.match(nome) or nome in ("scalable", "symbolic")):
        continue
    for ctx in sorted(os.listdir(base)):
        if os.path.isdir(os.path.join(base, ctx)):
            presentes.append(f"{nome}/{ctx}")

if not presentes:
    print("VAZIO")
    raise SystemExit(0)

linhas = []
declarados = []
if os.path.exists(index):
    linhas = open(index, encoding="utf-8").read().splitlines()
    for l in linhas:
        if l.startswith("Directories="):
            declarados = [d.strip() for d in l.split("=", 1)[1].split(",") if d.strip()]
            break

faltam = [d for d in presentes if d not in declarados]
if not faltam:
    print(f"OK {len(declarados)}")
    raise SystemExit(0)

CONTEXTO = {
    "apps": "Applications", "mimetypes": "MimeTypes", "actions": "Actions",
    "places": "Places", "status": "Status", "devices": "Devices",
    "categories": "Categories", "emblems": "Emblems", "emotes": "Emotes",
    "animations": "Animations", "intl": "International",
}

def secao(d):
    pasta, ctx = d.split("/", 1)
    contexto = CONTEXTO.get(ctx, "Applications")
    if pasta in ("scalable", "symbolic"):
        tam = 16 if pasta == "symbolic" else 48
        return (f"\n[{d}]\nSize={tam}\nMinSize=8\nMaxSize=512\n"
                f"Context={contexto}\nType=Scalable\n")
    m = RE_TAM.match(pasta)
    corpo = f"\n[{d}]\nSize={m.group(1)}\n"
    if m.group(2):
        corpo += f"Scale={m.group(2)}\n"
    return corpo + f"Context={contexto}\nType=Fixed\n"

if not linhas:
    linhas = ["[Icon Theme]", "Name=Hicolor", "Comment=Fallback Icon Theme",
              "Hidden=true", "Directories="]

novos = declarados + faltam
saida, achou = [], False
for l in linhas:
    if l.startswith("Directories="):
        saida.append("Directories=" + ",".join(novos))
        achou = True
    else:
        saida.append(l)
if not achou:
    # sem Directories=, insere logo após o cabeçalho [Icon Theme]
    pos = 1 if saida and saida[0].startswith("[Icon Theme]") else 0
    saida.insert(pos, "Directories=" + ",".join(novos))

texto = "\n".join(saida).rstrip("\n") + "\n" + "".join(secao(d) for d in faltam)

if dry:
    print("DRY " + ",".join(faltam))
    raise SystemExit(0)

if os.path.exists(index) and not os.path.exists(index + ".bak"):
    import shutil
    shutil.copy2(index, index + ".bak")

fd, tmp = tempfile.mkstemp(dir=hicolor, prefix=".index.theme.")
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(texto)
    os.replace(tmp, index)          # rename atômico: nunca deixa índice truncado
except BaseException:
    os.path.exists(tmp) and os.unlink(tmp)
    raise
print(f"GRAVADO {len(faltam)} {len(novos)}")
PY
) || { _err "falha ao reparar $INDEX"; exit 1; }

case "$saida" in
    VAZIO)
        _info "hicolor do usuário sem subdiretórios de ícone; nada a reparar" ;;
    OK*)
        _ok "index.theme do hicolor já declara os $(echo "$saida" | cut -d' ' -f2) diretórios existentes" ;;
    DRY*)
        _info "[dry-run] acrescentaria: $(echo "$saida" | cut -d' ' -f2-)" ;;
    GRAVADO*)
        _ok "index.theme do hicolor reparado (+$(echo "$saida" | cut -d' ' -f2) diretórios, $(echo "$saida" | cut -d' ' -f3) no total)" ;;
esac

# Cache regenerado sempre que estiver mais velho que o índice — não só quando o
# índice acabou de mudar. Sem isto, uma falha do gtk-update-icon-cache numa run
# ficaria para sempre, já que a run seguinte sairia cedo por "já declara".
if [[ "$DRY_RUN" != "1" ]] && command -v gtk-update-icon-cache &>/dev/null; then
    if [[ ! -f "$HICOLOR/icon-theme.cache" || "$INDEX" -nt "$HICOLOR/icon-theme.cache" ]]; then
        if gtk-update-icon-cache -f -t "$HICOLOR" &>/dev/null; then
            _ok "cache do hicolor regenerado"
        else
            _warn "gtk-update-icon-cache falhou (índice está correto; cache segue o antigo)"
        fi
    fi
fi
