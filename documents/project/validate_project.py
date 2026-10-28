#!/usr/bin/env python3
"""Validate the project, BOM, and schedule portions of a project Org file."""

import argparse
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path
import re
import sys


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from engdoc_org import read_headings
from engdoc_metadata import load_and_validate_metadata


TODO_STATES = {
    "TODO", "SPECIFY", "QUOTED", "ORDERED", "RECEIVED",
    "NEXT", "WAITING", "DONE", "CANCELLED",
}
SOURCE_VALUES = {"BUY", "ON-HAND", "MAKE", "PRINT"}
DATE = re.compile(r"(?:<|\[)(\d{4}-\d{2}-\d{2})(?:\s+[^]>]*)?(?:>|\])")


def planning_date(value):
    """Return the date in an Org timestamp VALUE, or None."""
    match = DATE.search(value)
    return datetime.strptime(match.group(1), "%Y-%m-%d").date() if match else None


def positive_integer(value, label):
    """Validate VALUE as a positive integer and return it."""
    try:
        number = Decimal(value)
    except InvalidOperation as exc:
        raise ValueError(f"{label}: expected a positive integer, got {value!r}") from exc
    if number != number.to_integral_value() or number <= 0:
        raise ValueError(f"{label}: expected a positive integer, got {value!r}")
    return int(number)


def nonnegative_decimal(value, label):
    """Validate VALUE as a nonnegative decimal and return it."""
    normalized = value.replace("$", "").replace(",", "").strip()
    try:
        number = Decimal(normalized)
    except InvalidOperation as exc:
        raise ValueError(f"{label}: expected a nonnegative cost, got {value!r}") from exc
    if number < 0:
        raise ValueError(f"{label}: expected a nonnegative cost, got {value!r}")
    return number


def validate_project(path):
    """Validate PATH and return a list of nonfatal warning messages."""
    _metadata, warnings = load_and_validate_metadata(path)
    headings = read_headings(path, TODO_STATES)
    bom = [heading for heading in headings if "BOM" in heading.tags]
    if not bom:
        raise ValueError("No BOM entries found (expected headings tagged :BOM:)")

    for heading in bom:
        label = f"BOM item {heading.title!r}"
        quantity = heading.properties.get("QTY", "").strip()
        if not quantity:
            raise ValueError(f"{label}: missing QTY")
        positive_integer(quantity, f"{label} QTY")

        cost = heading.properties.get("COST", "").strip()
        if cost:
            nonnegative_decimal(cost, f"{label} COST")

        source = heading.properties.get("SOURCE", "").strip().upper()
        if source and source not in SOURCE_VALUES:
            raise ValueError(
                f"{label}: invalid SOURCE {source!r}; expected one of "
                f"{', '.join(sorted(SOURCE_VALUES))}"
            )

    for heading in headings:
        start = planning_date(heading.planning.get("SCHEDULED", ""))
        end = planning_date(heading.planning.get("DEADLINE", ""))
        if start and end and end < start:
            raise ValueError(
                f"Task {heading.title!r}: DEADLINE {end} precedes SCHEDULED {start}"
            )
        if heading.todo and heading.todo not in {"DONE", "CANCELLED"} and not (start or end):
            warnings.append(f"{heading.title}: active task has no schedule")

    return warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Source project.org file")
    args = parser.parse_args()
    try:
        warnings = validate_project(args.input)
    except ValueError as exc:
        parser.exit(1, f"ERROR: {exc}\n")
    for warning in warnings:
        print(f"WARNING: {warning}")
    print(f"Validation passed: {len(warnings)} warning(s)")


if __name__ == "__main__":
    main()
