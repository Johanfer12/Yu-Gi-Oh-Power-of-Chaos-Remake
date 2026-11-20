"""Extrae las notas de una etiqueta del historial de versiones."""
import argparse
import re
from pathlib import Path


VERSION_HEADING = re.compile(r"^##[ \t]+(v\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)[ \t]*$", re.MULTILINE)


def notes_for(history: str, tag: str) -> str:
    history = history.replace("\r\n", "\n")
    headings = list(VERSION_HEADING.finditer(history))
    positions = [index for index, heading in enumerate(headings) if heading[1] == tag]
    if len(positions) != 1:
        raise ValueError(f"Se esperaba una sección para {tag}. Se encontraron {len(positions)}.")
    index = positions[0]
    following = headings[index + 1].start() if index + 1 < len(headings) else len(history)
    body = history[headings[index].end():following].strip()
    if not body:
        raise ValueError(f"La sección de {tag} no tiene notas.")
    return body + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("history", type=Path)
    parser.add_argument("tag")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        body = notes_for(args.history.read_text(encoding="utf-8-sig"), args.tag)
    except ValueError as error:
        parser.error(str(error))
    args.output.write_text(body, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
