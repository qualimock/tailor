#!/usr/bin/env python3
"""Cut the [Unreleased] section of CHANGELOG.md into a dated release,
and mirror it into the metainfo <releases> block as AppStream-safe XML."""

import argparse
import datetime
import html
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHANGELOG = ROOT / "CHANGELOG.md"
METAINFO = ROOT / "data" / "org.altlinux.Tailor.metainfo.xml.in.in"
MESON_BUILD = ROOT / "meson.build"
REPO_URL = "https://altlinux.space/qualimock/Tailor"


def split_unreleased(text: str):
    lines = text.splitlines()
    start = next(i for i, l in enumerate(lines) if l.startswith("## [Unreleased]"))
    end = next(
        (i for i in range(start + 1, len(lines)) if lines[i].startswith("## [")),
        len(lines),
    )
    body = lines[start + 1 : end]
    while body and body[0] == "":
        body.pop(0)
    while body and body[-1] == "":
        body.pop()
    return lines, start, end, body


def rewrite_changelog(lines, start, end, body, version, date):
    prev_link = next(l for l in lines if l.startswith("[Unreleased]:"))
    prev_version = prev_link.split("compare/v")[1].split("...HEAD")[0]

    new_section = ["## [Unreleased]", ""] + [f"## [{version}] - {date}"] + [""] + body + [""]
    out = lines[:start] + new_section + lines[end:]

    out = [
        f"[Unreleased]: {REPO_URL}/compare/v{version}...HEAD" if l.startswith("[Unreleased]:") else l
        for l in out
    ]
    idx = next(i for i, l in enumerate(out) if l.startswith("[Unreleased]:"))
    out.insert(idx + 1, f"[{version}]: {REPO_URL}/compare/v{prev_version}...v{version}")
    return "\n".join(out) + "\n"


def markdown_to_appstream(body_lines):
    """Flatten changelog markdown to the <p>/<ul><li> subset AppStream allows."""
    xml = []
    paragraph = []
    list_items = []

    def flush_paragraph():
        if paragraph:
            text = html.escape(" ".join(paragraph))
            xml.append(f"\t\t\t\t<p>{text}</p>")
            paragraph.clear()

    def flush_list():
        if list_items:
            xml.append("\t\t\t\t<ul>")
            for item in list_items:
                xml.append(f"\t\t\t\t\t<li>{html.escape(item)}</li>")
            xml.append("\t\t\t\t</ul>")
            list_items.clear()

    for raw in body_lines:
        line = raw.strip()
        if not line:
            flush_paragraph()
            continue
        if line.startswith("#"):
            flush_paragraph()
            flush_list()
            text = line.lstrip("#").strip()
            if text:
                xml.append(f"\t\t\t\t<p>{html.escape(text)}</p>")
            continue
        if line.startswith(("-", "*")):
            flush_paragraph()
            list_items.append(line[1:].strip())
            continue
        flush_list()
        paragraph.append(line)

    flush_paragraph()
    flush_list()
    return "\n".join(xml)


def bump_meson_version(text, version):
    marker = "version: '"
    start = text.index(marker) + len(marker)
    end = text.index("'", start)
    return text[:start] + version + text[end:]


def insert_release(metainfo_text, version, date, description_xml):
    release_block = (
        f'\t\t<release version="{version}" date="{date}">\n'
        f"\t\t\t<description>\n"
        f"{description_xml}\n"
        f"\t\t\t</description>\n"
        f"\t\t</release>\n"
    )
    marker = "<releases>\n"
    idx = metainfo_text.index(marker) + len(marker)
    return metainfo_text[:idx] + release_block + metainfo_text[idx:]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", help="release version, e.g. 1.1.0")
    parser.add_argument("--date", default=datetime.date.today().isoformat())
    args = parser.parse_args()

    changelog_text = CHANGELOG.read_text()
    lines, start, end, body = split_unreleased(changelog_text)
    if not body:
        sys.exit("Nothing under [Unreleased] to release")

    CHANGELOG.write_text(rewrite_changelog(lines, start, end, body, args.version, args.date))

    description_xml = markdown_to_appstream(body)
    metainfo_text = METAINFO.read_text()
    METAINFO.write_text(insert_release(metainfo_text, args.version, args.date, description_xml))

    MESON_BUILD.write_text(bump_meson_version(MESON_BUILD.read_text(), args.version))

    print(f"Released {args.version} ({args.date}): CHANGELOG.md, metainfo, meson.build updated")


if __name__ == "__main__":
    main()
