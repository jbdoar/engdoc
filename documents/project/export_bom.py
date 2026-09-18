#!/usr/bin/env python3

# ~/.emacs.d/python/org/export_bom.py

import argparse
import csv
import re
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Font


TODO_STATES = r"TODO|SPECIFY|QUOTED|ORDERED|RECEIVED|WAITING|DONE|CANCELLED"

HEADING_RE = re.compile(
    rf"^(?P<stars>\*+)\s+"
    rf"(?:(?P<todo>{TODO_STATES})\s+)?"
    rf"(?P<title>.*?)"
    rf"(?:\s+:(?P<tags>[^:]+(?::[^:]+)*):)?\s*$"
)

PROPERTY_RE = re.compile(
    r"^:(?P<key>[A-Za-z0-9_]+):\s*(?P<value>.*)$"
)

ORG_LINK_RE = re.compile(
    r"^\[\[(?P<target>[^\]]+)\](?:\[(?P<label>[^\]]*)\])?\]$"
)


FIELDS = [
    "LEVEL",
    "ITEM",
    "STATE",
    "QTY",
    "PN",
    "MPN",
    "MFR",
    "VENDOR",
    "VENDOR_PN",
    "SOURCE",
    "COST",
    "URL",
]


def parse_cost(value):
    return float(
        str(value)
        .replace("$", "")
        .replace(",", "")
        .strip()
    )


NUMERIC_FIELDS = {
    "LEVEL": int,
    "QTY": int,
    "COST": parse_cost,
}


def parse_bom(path):
    lines = Path(path).read_text(encoding="utf-8").splitlines()
    rows = []

    i = 0

    while i < len(lines):
        match = HEADING_RE.match(lines[i])

        if not match:
            i += 1
            continue

        level = len(match.group("stars"))
        title = match.group("title").strip()
        state = match.group("todo") or ""
        tags = set((match.group("tags") or "").split(":"))

        if "BOM" not in tags:
            i += 1
            continue

        props = {}
        j = i + 1

        # Skip Org planning lines such as CLOSED:, SCHEDULED:, DEADLINE:.
        while j < len(lines) and not HEADING_RE.match(lines[j]):
            text = lines[j].strip()

            if text == ":PROPERTIES:":
                break

            j += 1

        if (
                j < len(lines)
                and lines[j].strip() == ":PROPERTIES:"
        ):

            j += 1

            while (
                j < len(lines)
                and lines[j].strip() != ":END:"
            ):
                prop = PROPERTY_RE.match(lines[j].strip())

                if prop:
                    key = prop.group("key").upper()
                    value = prop.group("value").strip()
                    props[key] = value

                j += 1

        row = {
            "LEVEL": level,
            "ITEM": title,
            "STATE": state,
        }

        for field in FIELDS[3:]:
            row[field] = props.get(field, "")

        rows.append(row)
        i += 1

    return rows


def parse_org_link(value):
    value = value.strip()
    match = ORG_LINK_RE.match(value)

    if not match:
        return value, None

    target = match.group("target")
    label = match.group("label") or target

    return label, target


def write_csv(rows, path):
    try:
        with open(
            path,
            "w",
            newline="",
            encoding="utf-8-sig",
        ) as f:
            writer = csv.DictWriter(
                f,
                fieldnames=FIELDS,
            )

            writer.writeheader()

            for row in rows:
                output_row = {}

                for field in FIELDS:
                    value = str(row.get(field, ""))
                    label, target = parse_org_link(value)

                    output_row[field] = (
                        target if target else value
                    )

                writer.writerow(output_row)

    except PermissionError:
        raise SystemExit(
            f"Cannot write {path}: the file may be open "
            "in another application. Close it and run "
            "the export again."
        )


def write_xlsx(rows, path):
    wb = Workbook()
    ws = wb.active
    ws.title = "BOM"

    # Preserve Org hierarchy using Excel row outlines.
    ws.sheet_properties.outlinePr.summaryBelow = False

    # Header
    for column_number, field in enumerate(
        FIELDS,
        start=1,
    ):
        cell = ws.cell(
            row=1,
            column=column_number,
            value=field,
        )
        cell.font = Font(bold=True)

    # Data
    for row_number, row in enumerate(
        rows,
        start=2,
    ):
        level = int(row["LEVEL"])

        ws.row_dimensions[row_number].outlineLevel = min(
            max(level - 1, 0),
            7,
        )

        for column_number, field in enumerate(
            FIELDS,
            start=1,
        ):
            value = row.get(field, "")
            target = None

            # Convert only fields that should genuinely be numeric.
            if field in NUMERIC_FIELDS and value not in ("", None):
                try:
                    value = NUMERIC_FIELDS[field](value)
                except (ValueError, TypeError):
                    pass

            # Everything else stays textual, including PN/MPN/vendor PNs.
            if isinstance(value, str):
                value, target = parse_org_link(value)

            cell = ws.cell(
                row=row_number,
                column=column_number,
                value=value,
            )

            if field == "QTY" and isinstance(value, int):
                cell.number_format = "0"

            if field == "COST" and isinstance(value, (int, float)):
                cell.number_format = "$#,##0.00"

            if target:
                cell.hyperlink = target
                cell.style = "Hyperlink"

    ws.freeze_panes = "A2"
    ws.auto_filter.ref = ws.dimensions

    # Auto-size columns.
    for column in ws.columns:
        width = max(
            len(str(cell.value or ""))
            for cell in column
        )

        ws.column_dimensions[
            column[0].column_letter
        ].width = min(width + 2, 40)

    try:
        wb.save(path)

    except PermissionError:
        raise SystemExit(
            f"Cannot write {path}: the file may be open "
            "in Excel. Close it and run the export again."
        )


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "input",
        help="Org project/BOM file",
    )

    parser.add_argument(
        "output",
        help="Output .xlsx or .csv file",
    )

    args = parser.parse_args()

    rows = parse_bom(args.input)
    output = Path(args.output)

    match output.suffix.lower():
        case ".csv":
            write_csv(rows, output)

        case ".xlsx":
            write_xlsx(rows, output)

        case _:
            parser.error(
                "output must end in .csv or .xlsx"
            )


if __name__ == "__main__":
    main()
