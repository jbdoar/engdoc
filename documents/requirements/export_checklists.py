#!/usr/bin/env python3
"""Generate FAT and SAT checklists from an Org requirements document."""

import argparse
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.worksheet.page import PageMargins

from export_requirements import (
    parse_requirements,
    parse_stages,
    validate_requirements,
)


HEADERS = [
    "Requirement ID",
    "Category",
    "Requirement",
    "Acceptance Criteria",
    "Verification Method",
    "Result",
    "Measured Value / Observation",
    "Evidence Reference",
    "Comments",
]

WIDTHS = [22, 30, 65, 60, 20, 16, 45, 30, 45]


def export_checklist(requirements, stage, output):
    """Export requirements applicable to STAGE as an XLSX checklist."""

    selected = [
        req
        for req in requirements
        if stage in parse_stages(req["stage"])
    ]

    wb = Workbook()
    ws = wb.active
    ws.title = stage

    ws.append(HEADERS)

    # Header formatting.
    for cell in ws[1]:
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = PatternFill(
            fill_type="solid",
            fgColor="243746",
        )
        cell.alignment = Alignment(
            vertical="center",
            wrap_text=True,
        )

    ws.row_dimensions[1].height = 32

    for index, width in enumerate(WIDTHS, start=1):
        ws.column_dimensions[
            get_column_letter(index)
        ].width = width

    # Requirements.
    for req in selected:
        ws.append([
            req["id"],
            req["category"],
            req["requirement"],
            req["acceptance"],
            req["verification"],
            None,
            None,
            None,
            None,
        ])

        row_number = ws.max_row

        for cell in ws[row_number]:
            cell.alignment = Alignment(
                vertical="top",
                wrap_text=True,
            )

        # Minimum space for handwritten or electronic observations.
        # Long requirements may still require Excel's AutoFit.
        ws.row_dimensions[row_number].height = 72

    # Result dropdown.
    results = DataValidation(
        type="list",
        formula1='"PASS,FAIL,N/A,NOT RUN"',
        allow_blank=True,
    )
    results.error = "Select a result from the list."
    results.errorTitle = "Invalid result"
    results.showErrorMessage = True
    results.errorStyle = "stop"

    ws.add_data_validation(results)

    # Include additional blank rows for future use.
    # Only populated requirements are part of the printed checklist.
    if selected:
        results.add(f"F2:F{ws.max_row}")

    ws.freeze_panes = "C2"
    ws.auto_filter.ref = ws.dimensions

    # Print settings.
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.page_setup.orientation = "landscape"
    ws.page_setup.paperSize = ws.PAPERSIZE_LETTER
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0

    ws.page_margins = PageMargins(
        left=0.25,
        right=0.25,
        top=0.5,
        bottom=0.5,
        header=0.2,
        footer=0.2,
    )

    ws.print_title_rows = "1:1"

    output.parent.mkdir(parents=True, exist_ok=True)
    wb.save(output)

    print(
        f"Exported {stage} checklist: "
        f"{len(selected)} requirements to {output}",
        flush=True,
    )


def main():
    parser = argparse.ArgumentParser(
        description="Generate FAT and SAT requirements checklists."
    )

    parser.add_argument(
        "input",
        type=Path,
        help="Source requirements.org file",
    )

    parser.add_argument(
        "output_dir",
        type=Path,
        help="Directory for generated XLSX files",
    )

    args = parser.parse_args()

    requirements = parse_requirements(args.input)
    validate_requirements(requirements)

    export_checklist(
        requirements,
        "FAT",
        args.output_dir / "fat.xlsx",
    )

    export_checklist(
        requirements,
        "SAT",
        args.output_dir / "sat.xlsx",
    )


if __name__ == "__main__":
    main()
