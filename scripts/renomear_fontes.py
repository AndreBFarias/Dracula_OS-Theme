#!/usr/bin/env python3
"""
Renomeia arquivos-fonte em src/icons/ para corrigir typos e dar nomes mais
claros. Atualiza automaticamente os paths em mapping.json.

Renomeacoes aplicadas:
- ghostwritter.svg  -> ghostwriter.svg     (typo tt -> t)
- qbtorrent.svg     -> qbittorrent.svg     (faltava 'i')
- cleanner.svg      -> cleaner.svg         (typo nn -> n)
- "gerenciadoor de extensões.png" -> "gerenciador-de-extensoes.png"
  (typo + espaco + acento)

Idempotente: pode ser rodado multiplas vezes sem efeito colateral.
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "src" / "icons"
MAPPING = REPO / "mapping.json"

# Relativo a src/icons/
RENOMEACOES: dict[str, str] = {
    "current/scalable/apps/ghostwritter.svg": "current/scalable/apps/ghostwriter.svg",
    "current/scalable/apps/ghostwritter2.svg": "current/scalable/apps/ghostwriter2.svg",
    "current/scalable/apps/qbtorrent.svg": "current/scalable/apps/qbittorrent.svg",
    "current/scalable/apps/cleanner.svg": "current/scalable/apps/cleaner.svg",
    "current/scalable/apps/gerenciadoor de extensões.png": "current/scalable/apps/gerenciador-de-extensoes.png",
    "current/scalable/apps/Obs-Studio.png": "current/scalable/apps/obs-studio.png",
    "current/scalable/apps/Whatsapp.png": "current/scalable/apps/whatsapp.png",
    "current/scalable/apps/Clapper.png": "current/scalable/apps/clapper.png",
    "current/scalable/apps/Flatseal.png": "current/scalable/apps/flatseal.png",
    "current/scalable/apps/chrome2.svg": "current/scalable/apps/google-chrome.svg",
}


def main() -> None:
    renomeados = 0
    ignorados = 0

    for antigo_rel, novo_rel in RENOMEACOES.items():
        antigo = SRC / antigo_rel
        novo = SRC / novo_rel

        if novo.exists() and not antigo.exists():
            # Ja foi renomeado
            ignorados += 1
            continue

        if not antigo.exists():
            print(f"  [skip] fonte nao existe: {antigo_rel}")
            ignorados += 1
            continue

        if novo.exists():
            print(f"  [!] destino ja existe, pulando: {novo_rel}")
            ignorados += 1
            continue

        print(f"  {antigo_rel} -> {novo_rel}")
        shutil.move(str(antigo), str(novo))
        renomeados += 1

    # Atualiza mapping.json
    if MAPPING.exists():
        m = json.loads(MAPPING.read_text())
        ajustes = 0
        for app_id, entry in m.items():
            fonte = entry.get("fonte", "")
            if not fonte:
                continue
            for antigo_rel, novo_rel in RENOMEACOES.items():
                if fonte == antigo_rel:
                    entry["fonte"] = novo_rel
                    ajustes += 1
                    break
        if ajustes > 0:
            MAPPING.write_text(json.dumps(m, ensure_ascii=False, indent=2, sort_keys=True))
            print(f"  mapping.json: {ajustes} entradas atualizadas")

    print(f"\nResultado: {renomeados} arquivos renomeados, {ignorados} ignorados")


if __name__ == "__main__":
    main()

# "Nomina sunt consequentia rerum." -- os nomes sao consequencia das coisas.
