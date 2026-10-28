"""Small, dependency-free Org reader for engdoc exporters.

This is deliberately not a complete Org parser.  It provides one shared
interpretation of the subset used by engdoc: headings, TODO keywords, tags,
property drawers, planning lines, and heading body text.
"""

from dataclasses import dataclass, field
from pathlib import Path
import re


HEADING = re.compile(r"^(?P<stars>\*+)\s+(?P<text>.*?)\s*$")
TAGS = re.compile(r"^(?P<title>.*?)(?:\s+:(?P<tags>[^:]+(?::[^:]+)*):)?$")
PROPERTY = re.compile(r"^:(?P<key>[A-Za-z_][A-Za-z0-9_-]*):\s*(?P<value>.*?)\s*$")
PLANNING = re.compile(r"(?:^|\s)(CLOSED|SCHEDULED|DEADLINE):\s*(<[^>]+>|\[[^]]+\])")
KEYWORD = re.compile(r"^#\+(?P<key>[A-Za-z0-9_-]+):\s*(?P<value>.*?)\s*$", re.IGNORECASE)


@dataclass
class Heading:
    """An Org heading and the content belonging directly to it."""

    level: int
    title: str
    todo: str = ""
    tags: list[str] = field(default_factory=list)
    properties: dict[str, str] = field(default_factory=dict)
    planning: dict[str, str] = field(default_factory=dict)
    body: list[str] = field(default_factory=list)
    path: list[str] = field(default_factory=list)


def read_keywords(path):
    """Return top-level Org keywords from PATH with uppercase keys."""
    keywords = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        match = KEYWORD.match(line)
        if match:
            keywords[match.group("key").upper()] = match.group("value")
    return keywords


def read_headings(path, todo_keywords=()):
    """Read PATH and return a flat list of :class:`Heading` objects."""
    lines = Path(path).read_text(encoding="utf-8").splitlines()
    headings = []
    titles = []
    current = None
    in_properties = False
    todo_keywords = set(todo_keywords)
    if not todo_keywords:
        declared = read_keywords(path).get("TODO", "")
        todo_keywords = {
            re.sub(r"\(.*\)$", "", word)
            for word in declared.split()
            if word != "|"
        }

    for line in lines:
        match = HEADING.match(line)
        if match:
            level = len(match.group("stars"))
            parsed = TAGS.match(match.group("text"))
            title = parsed.group("title").strip()
            tags = [tag for tag in (parsed.group("tags") or "").split(":") if tag]
            words = title.split(maxsplit=1)
            todo = words[0] if words and words[0] in todo_keywords else ""
            if todo:
                title = words[1] if len(words) == 2 else ""

            titles = titles[: level - 1]
            current = Heading(level, title, todo, tags, path=list(titles))
            headings.append(current)
            titles.append(title)
            in_properties = False
            continue

        if current is None:
            continue

        stripped = line.strip()
        if stripped == ":PROPERTIES:":
            in_properties = True
            continue
        if in_properties and stripped == ":END:":
            in_properties = False
            continue
        if in_properties:
            prop = PROPERTY.match(stripped)
            if prop:
                current.properties[prop.group("key").upper()] = prop.group("value")
            continue

        for name, value in PLANNING.findall(stripped):
            current.planning[name] = value
        current.body.append(line)

    return headings
