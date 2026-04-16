#!/usr/bin/env python3
"""
Extrai mapping.json a partir dos .desktop do sistema.

Prioriza o que o usuário já configurou (paths absolutos nos .desktop) e
combina com a lista de overrides manuais (apps que devem usar SVGs dos
295 novos em src/icons/new-sessao-atual/).

Uso:
    python3 scripts/extrair_mapeamento.py
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

HOME = Path.home()
REPO = Path(__file__).resolve().parent.parent
SRC_ICONS = REPO / "src" / "icons"
CURRENT_SCALABLE = SRC_ICONS / "current" / "scalable" / "apps"
CURRENT_48 = SRC_ICONS / "current" / "48x48" / "apps"
CURRENT_48_GLOBAL = SRC_ICONS / "current" / "48x48" / "apps-global"
NEW_SESSAO = SRC_ICONS / "new-sessao-atual"
PROJECTS = SRC_ICONS / "projects"
UPSTREAMS = [
    SRC_ICONS / "upstream" / "dracula-icons-circle",
    SRC_ICONS / "upstream" / "dracula-icons-main",
]

DESKTOP_DIRS = [
    Path("/usr/share/applications"),
    HOME / ".local/share/applications",
    HOME / ".local/share/flatpak/exports/share/applications",
    Path("/var/lib/flatpak/exports/share/applications"),
]

# Lista do usuario: apps que devem usar SVGs dos 295 novos (Fase 4 do plano)
OVERRIDES_NOVOS: dict[str, str] = {
    "com.github.tchx84.Flatseal": "chest.svg",
    "com.mattjakeman.ExtensionManager": "toolbox.svg",
    "io.github.flattool.Warehouse": "building.svg",
    "io.github.vikdevelop.SaveDesktop": "treasure-chest.svg",
    "LinuxToys": "toolbox.svg",
    "linuxtoys": "toolbox.svg",
    "menulibre": "scroll.svg",
    "org.kde.krita": "magic-wand-variant.svg",
    "io.gitlab.theevilskeleton.Upscaler": "telescope.svg",
    "best.ellie.StartupConfiguration": "gate.svg",
    "gnome-session-properties": "gate.svg",
    "qrcode-void-generator": "puzzle.svg",
    "org.onlyoffice.desktopeditors": "book.svg",
    "org.bleachbit.BleachBit": "broom.svg",
    "org.gnome.gitlab.somas.Apostrophe": "feather.svg",
    "com.freerdp.FreeRDP": "gate.svg",
    "io.github.dvlv.boxbuddyrs": "chest-variant.svg",
    "io.github.electronstudio.WeylusCommunityEdition": "wand.svg",
    "com.jwestall.Forecast": "full-moon.svg",
    "vlc": "cat.svg",
    "io.elementary.appcenter": "bag.svg",
    "foundryvtt": "dice.svg",
    "gparted": "saw.svg",
    "org.gnome.gThumb": "eye-ball.svg",
    "gnome-system-monitor": "hourglass.svg",
    "gnome-system-monitor-kde": "hourglass.svg",
    "setup-mozc": "tarot.svg",
    "com.system76.Popsicle": "lollipop.svg",
}

# Override especial: ZapZap vira WhatsApp
OVERRIDE_DESKTOPS: dict[str, dict[str, str]] = {
    "com.rtosta.zapzap": {
        "Name": "WhatsApp",
        "Name[pt_BR]": "WhatsApp",
        "Icon": "whatsapp-linux-app",
    },
}

# Aliases heurísticos: Icon= reverse-DNS ou nome simples → arquivo real no src/
# Preenchido observando que o user já possui os ícones com nomes diferentes.
ALIASES_HEURISTICOS: dict[str, str] = {
    # Flatpak reverse-DNS → arquivos em current/scalable/apps
    "com.microsoft.Edge": "current/scalable/apps/edge.png",
    "com.obsproject.Studio": "current/scalable/apps/Obs-Studio.png",
    "be.alexandervanhee.gradia": "current/scalable/apps/gradia.png",
    "md.obsidian.Obsidian": "current/scalable/apps/050-circle.svg",
    "com.rtosta.zapzap": "current/scalable/apps/Whatsapp.png",
    "com.discordapp.Discord": "current/scalable/apps/discord.png",
    "com.github.rafostar.Clapper": "current/scalable/apps/Clapper.png",
    "com.github.tchx84.Flatseal": "current/scalable/apps/Flatseal.png",
    "com.opera.Opera": "current/scalable/apps/opera.png",
    "com.spotify.Client": "current/scalable/apps/spotify.png",
    "net.waterfox.waterfox": "current/scalable/apps/firefox.png",
    "com.google.Chrome": "current/scalable/apps/chrome2.svg",
    "google-chrome": "current/scalable/apps/chrome2.svg",
    "org.qbittorrent.qBittorrent": "current/scalable/apps/qbtorrent.svg",
    "org.telegram.desktop": "current/scalable/apps/telegram.svg",
    "org.mozilla.Thunderbird": "current/scalable/apps/thunderbird.svg",
    "org.gimp.GIMP": "current/scalable/apps/gimp.png",
    "org.kde.krita": "current/scalable/apps/krita.png",
    "org.gnome.gedit": "current/scalable/apps/com.system76.CosmicEdit.svg",
    "org.gnome.Nautilus": "current/scalable/apps/gnome-folder.png",
    "org.gnome.Calendar": "current/scalable/apps/calendar.svg",
    "org.gnome.Extensions": "current/scalable/apps/gerenciadoor de extensões.png",
    "org.gnome.gitlab.somas.Apostrophe": "current/scalable/apps/ghostwritter.svg",
    "org.bleachbit.BleachBit": "current/scalable/apps/cleanner.svg",
    "whatsapp-linux-app": "current/scalable/apps/Whatsapp.png",
    "whatsapp-linux-app_whatsapp-linux-app": "current/scalable/apps/Whatsapp.png",
    "nvidia-settings": "current/scalable/apps/nvidia.svg",
    "io.github.dvlv.boxbuddyrs": "current/scalable/apps/io.github.dvlv.boxbuddyrs.svg",
    "io.elementary.appcenter": "current/scalable/apps/pop-shop.svg",
    "io.elementary.appcenter-daemon": "current/scalable/apps/pop-shop.svg",
    "stacer": "current/scalable/apps/stacer.svg",
    "kitty": "current/scalable/apps/terminal.svg",
    "org.gnome.Terminal": "current/scalable/apps/terminal.svg",
    "ulauncher": "current/scalable/apps/app-launcher.svg",
    "gparted": "current/scalable/apps/gparted.png",
    "weylus": "current/scalable/apps/weylus.png",
    "linuxtoys": "current/scalable/apps/linux-toys.png",
    "menulibre": "current/scalable/apps/gerenciador-de-menu.png",
    "best.ellie.StartupConfiguration": "current/48x48/apps-global/Tweaks.png",  # fallback
    # Projects (apps pessoais do user)
    "fogstripper": "projects/fogstripper.png",
    "com.beholder.app": "projects/beholder.png",
    "org.andrebfarias.Crononauta": "projects/chrononauta.png",
    "pdfforge": "projects/pdforge.png",
    "neurosonancy": "projects/neurosonancy.png",
    "ouroboros": "projects/protocolo-ouroboros.png",
    "arcanetab": "projects/arcanetab.png",
    "hemiciclo": "projects/hemiciclo.png",
    "scholarlens": "projects/scholarlens.png",
    "fusectl": "projects/fusectl.png",
    "dataloom": "projects/dataloom.png",
    "gaslighting": "projects/gaslighting.png",
    "doppelganger": "projects/doppelganger.png",
    "conversor-video-ascii": "projects/conversor-video-ascii.png",
    "qrcode-void-generator": "projects/qrcode-void-generator.png",
    # Path externo conhecido
    "foundryvtt": "projects/foundryvtt.png",
    "elden-ring-tracker": "projects/elden-ring-tracker.png",
    "Ubuntu": "projects/ubuntu-distrobox.png",
    # Correções finais apos revisao do user
    "luna": "projects/luna.png",
    "extase-em-4r73": "projects/conversor-video-ascii.png",
}


def parse_desktop(path: Path) -> dict[str, str]:
    """Extrai campos principais do .desktop. Retorna dict com Name, Icon, Exec."""
    campos: dict[str, str] = {}
    try:
        texto = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return campos
    em_secao = False
    for linha in texto.splitlines():
        s = linha.strip()
        if s.startswith("[Desktop Entry]"):
            em_secao = True
            continue
        if s.startswith("[") and em_secao and s != "[Desktop Entry]":
            break
        if em_secao and "=" in s:
            chave, _, valor = s.partition("=")
            if chave in {"Name", "Icon", "Exec", "Type", "Categories"}:
                campos.setdefault(chave, valor)
    return campos


def _existe(p: Path) -> bool:
    """Wrapper resiliente de p.exists() que engole OSError."""
    try:
        return p.exists()
    except OSError:
        return False


def localizar_fonte(nome_icone: str) -> tuple[str | None, str | None]:
    """Dado um Icon= (path absoluto ou nome), retorna (caminho_relativo_src, tipo_origem)."""
    if not nome_icone:
        return None, None
    # Sanitizar nome — remover caracteres suspeitos que quebram stat()
    nome_icone = nome_icone.strip()
    if "\n" in nome_icone or "|" in nome_icone or len(nome_icone) > 200:
        return nome_icone, "nome-invalido"
    # Path absoluto
    if nome_icone.startswith("/"):
        p = Path(nome_icone)
        if not _existe(p):
            return None, "path-quebrado"
        # Se aponta para .icons/Dracula-Icones — mapear pro src/icons/current/
        s = str(p)
        marcador = "/.icons/Dracula-Icones/"
        if marcador in s:
            rel = s.split(marcador, 1)[1]
            fonte = SRC_ICONS / "current" / rel
            if fonte.exists():
                return str(fonte.relative_to(REPO)), "current"
            return f"current/{rel}", "current-ausente"
        # Se aponta para ~/Desenvolvimento/.../assets/ — mapear pro src/icons/projects/
        if "/Desenvolvimento/" in s and "assets" in s:
            # Tentar match pelo nome do projeto
            partes = s.split("/")
            try:
                idx = partes.index("Desenvolvimento")
                projeto = partes[idx + 1].lower().replace("_", "-")
                # Slugs conhecidos
                mapa = {
                    "neurosonancy": "neurosonancy.png",
                    "protocolo-ouroboros": "protocolo-ouroboros.png",
                    "fogstripper-removedor-background": "fogstripper.png",
                    "dataloom": "dataloom.png",
                    "pdforge": "pdforge.png",
                    "detector-de-doppelganger": "doppelganger.png",
                    "scholarlens": "scholarlens.png",
                    "hemiciclo": "hemiciclo.png",
                    "conversor-video-para-ascii": "conversor-video-ascii.png",
                    "fusectl": "fusectl.png",
                    "chrononauta": "chrononauta.png",
                    "gaslighting-is-all-you-need": "gaslighting.png",
                    "qr-code-void-generator": "qrcode-void-generator.png",
                    "project-beholder": "beholder.png",
                    "arcanetab": "arcanetab.png",
                    "python-data-toolkit": "data-toolkit.png",
                }
                slug = mapa.get(projeto)
                if slug:
                    return f"projects/{slug}", "projects"
            except (ValueError, IndexError):
                pass
        # Outros paths absolutos externos (ex: /opt, ~/foundry, pixmaps)
        return s, "path-externo"
    # Nome simples — buscar em current/scalable/apps, current/48x48, upstreams
    for ext in (".svg", ".png"):
        p = CURRENT_SCALABLE / f"{nome_icone}{ext}"
        if _existe(p):
            return f"current/scalable/apps/{nome_icone}{ext}", "current-nome"
    for ext in (".svg", ".png"):
        p = CURRENT_48 / f"{nome_icone}{ext}"
        if _existe(p):
            return f"current/48x48/apps/{nome_icone}{ext}", "current-48"
    for ext in (".svg", ".png"):
        p = CURRENT_48_GLOBAL / f"{nome_icone}{ext}"
        if _existe(p):
            return f"current/48x48/apps-global/{nome_icone}{ext}", "current-48-global"
    for upstream in UPSTREAMS:
        for padrao in ("scalable/apps", "48/apps", "48@2x/apps", "32/apps", "24/apps"):
            for ext in (".svg", ".png"):
                p = upstream / padrao / f"{nome_icone}{ext}"
                if _existe(p):
                    return f"upstream/{upstream.name}/{padrao}/{nome_icone}{ext}", "upstream"
    return nome_icone, "nao-encontrado"


def main() -> None:
    mapeamento: dict[str, dict[str, Any]] = {}
    vistos_icones: dict[str, list[str]] = {}

    for d in DESKTOP_DIRS:
        if not d.is_dir():
            continue
        for f in sorted(d.glob("*.desktop")):
            campos = parse_desktop(f)
            icon = campos.get("Icon")
            name = campos.get("Name", "")
            app_id = f.stem
            if not icon:
                continue
            # Override manual (usa SVG dos 295 novos)
            if app_id in OVERRIDES_NOVOS:
                svg = OVERRIDES_NOVOS[app_id]
                entrada: dict[str, Any] = {
                    "name": name,
                    "fonte": f"new-sessao-atual/{svg}",
                    "aliases": [app_id],
                    "origem": "override-novo",
                    "icon_original": icon,
                }
            elif app_id in ALIASES_HEURISTICOS:
                entrada = {
                    "name": name,
                    "fonte": ALIASES_HEURISTICOS[app_id],
                    "aliases": [app_id],
                    "origem": "alias-heuristico",
                    "icon_original": icon,
                }
                if not icon.startswith("/") and icon != app_id:
                    entrada["aliases"].append(icon)
            elif icon in ALIASES_HEURISTICOS:
                entrada = {
                    "name": name,
                    "fonte": ALIASES_HEURISTICOS[icon],
                    "aliases": [app_id, icon] if icon != app_id else [app_id],
                    "origem": "alias-heuristico",
                    "icon_original": icon,
                }
            else:
                fonte, tipo = localizar_fonte(icon)
                entrada = {
                    "name": name,
                    "fonte": fonte,
                    "aliases": [app_id],
                    "origem": tipo,
                    "icon_original": icon,
                }
                # Se Icon era nome simples, adiciona ele como alias
                if not icon.startswith("/") and icon != app_id:
                    entrada["aliases"].append(icon)
            if app_id in OVERRIDE_DESKTOPS:
                entrada["override_desktop"] = OVERRIDE_DESKTOPS[app_id]
            mapeamento[app_id] = entrada
            vistos_icones.setdefault(str(entrada["fonte"]), []).append(app_id)

    # Adicionar override ZapZap explicitamente se nao foi pego
    if "com.rtosta.zapzap" not in mapeamento:
        mapeamento["com.rtosta.zapzap"] = {
            "name": "WhatsApp",
            "fonte": "current/scalable/apps/Whatsapp.png",
            "aliases": ["com.rtosta.zapzap", "whatsapp-linux-app"],
            "origem": "override-manual",
            "override_desktop": OVERRIDE_DESKTOPS["com.rtosta.zapzap"],
        }

    out = REPO / "mapping.json"
    out.write_text(json.dumps(mapeamento, ensure_ascii=False, indent=2, sort_keys=True))

    # Relatorio
    total = len(mapeamento)
    por_origem: dict[str, int] = {}
    ausentes: list[str] = []
    for app_id, e in mapeamento.items():
        origem = e.get("origem", "?")
        por_origem[origem] = por_origem.get(origem, 0) + 1
        if origem in {"nao-encontrado", "current-ausente", "path-quebrado"}:
            ausentes.append(f"  {app_id} [{origem}] Icon={e['icon_original']}")

    print(f"Total de apps mapeados: {total}")
    print("Distribuicao por origem:")
    for k, v in sorted(por_origem.items(), key=lambda x: -x[1]):
        print(f"  {v:4d}  {k}")
    if ausentes:
        print(f"\nApps com icone ausente ({len(ausentes)}):")
        for a in ausentes[:40]:
            print(a)
        if len(ausentes) > 40:
            print(f"  ... mais {len(ausentes) - 40}")

    print(f"\nArquivo gerado: {out}")


if __name__ == "__main__":
    main()

# "A verdade liberta, mas a verdade nao ajuda os ignorantes." -- Heraclito
