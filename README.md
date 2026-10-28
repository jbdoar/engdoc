# engdoc

`engdoc` is an Emacs/Org workflow for engineering documents whose generated
artifacts include LaTeX/PDF, HTML, and Excel workbooks. Org files remain the
editable source of truth; Emacs Lisp coordinates document lifecycles and
Python handles structured parsing and spreadsheet generation.

The project is in early development. The current document types are:

| Type | Source | Outputs |
| --- | --- | --- |
| Project | `project.org` | BOM and schedule XLSX; project and agenda HTML |
| Requirements | `requirements.org` | specification PDF/TeX, register XLSX, FAT and SAT XLSX |
| Design | `design.org` | engineering design PDF/TeX and design register XLSX |
| Acceptance | `acceptance.org` | controlled procedure PDF/TeX and blank execution XLSX |
| Calibration | `calibration.org` | calibration program PDF/TeX and equipment/execution XLSX |
| Risk | `risk.org` | risk and hazard analysis PDF/TeX and hazard register XLSX |
| Installation | `installation.org` | installation/commissioning PDF/TeX and blank site workbook |
| Service manual | `service.org` | service PDF/TeX, maintenance schedule, and blank records XLSX |
| User manual | `user-manual.org` | user guidance PDF/TeX/HTML and content register XLSX |

When project and requirements sources coexist, export also produces the
project-level `traceability.xlsx` workbook.

## Setup

Requirements are Emacs 29.1 or newer, Python 3, and a LaTeX installation for
PDF exports. Create the local Python environment with:

```sh
make setup
```

Load `engdoc.el` from Emacs. For example:

```elisp
(add-to-list 'load-path "/path/to/engdoc")
(require 'engdoc)
```

If the desired Python is not Emacs's `python-shell-interpreter`, customize
`engdoc-python-interpreter`; a typical repository-local value is
`/path/to/engdoc/.venv/bin/python`.

Run `M-x engdoc-check-setup` to verify registrations, templates, exporters,
Python, and required Python modules.

## Workflow

- `M-x engdoc-init` creates a project directory, standard subdirectories, and
  `project.org`.
- `M-x engdoc-add-document` adds any registered document type to an existing
  project.
- `M-x engdoc-new-document` creates one selected document without initializing
  the surrounding project structure.
- `M-x engdoc-export` exports every recognized document in a directory.

The same pipeline is available without an interactive Emacs session:

```sh
make export PROJECT=/path/to/engineering-project
```

Generated files are written beneath the project's `exports/` directory. The
templates document their Org headings, properties, and editing conventions.
Generated acceptance checklists are blank execution templates; preserve
completed records outside `exports/` before re-exporting.

Exports are transactional per document type. A complete new artifact set is
built and checked in a staging directory before existing outputs are replaced;
replacement failures restore the previous set.

## Document metadata

Every source document uses the same controlled identity keywords:

```org
#+TITLE: System Requirements
#+AUTHOR: Engineering Team
#+ENGDOC_PROJECT_NAME: Engineering Project
#+ENGDOC_PROJECT_ID: ENG-0001
#+ENGDOC_DOCUMENT_ID: ENG-0001-REQ
#+ENGDOC_REVISION: A
#+ENGDOC_STATUS: DRAFT
#+ENGDOC_ISSUE_DATE:
#+ENGDOC_RELATED_DOCUMENTS:
```

Project and document IDs are stable identifiers. Status is one of `DRAFT`,
`REVIEW`, `RELEASED`, or `OBSOLETE`; released documents require an ISO
`YYYY-MM-DD` issue date. Related document IDs may be space- or comma-separated.

## Profiles and external formats

Presentation and external data contracts are independent. Set a presentation
profile with `#+ENGDOC_PROFILE: name`; it may supply a LaTeX header, branding,
and document styling without changing engineering content. Profiles are loaded
from a project's `.engdoc/profiles/` directory first, then from directories in
`engdoc-profile-directories`. The built-in `default` profile preserves the
neutral repository styling.

Machine-facing outputs use format adapters. For example,
`#+ENGDOC_BOM_FORMAT: work-erp` selects
`bom/work-erp/adapter.py` from `.engdoc/formats/` or a directory in
`engdoc-format-directories`. The adapter receives the normalized BOM model and
owns the exact ERP workbook layout. This keeps vendor column names, worksheet
rules, and import conventions out of the Org source and canonical parser.

Company profiles and adapters may be kept in a private repository and added to
the two directory variables from Emacs configuration. See
[`docs/profiles-and-formats.md`](docs/profiles-and-formats.md).

Every target must exist in the same project directory, use the same project
ID, and not refer to itself.

The metadata is validated before export, inserted into PDF and HTML document
control tables, and written into Excel core properties and a visible
`Metadata` worksheet. These keywords are authoritative; do not maintain a
second editable revision or identity table in the document body.

## Cross-document traceability

Downstream Org headings link to requirements with a property drawer:

```org
** TODO Integrate safety interlock
:PROPERTIES:
:REQUIREMENTS: REQ-SAFE-001 REQ-CTRL-004
:END:
```

`REQUIREMENTS` accepts space- or comma-separated stable requirement IDs.
Unknown IDs are fatal. Requirements without a downstream reference produce a
warning and are marked `UNLINKED` in `traceability.xlsx`; referenced
requirements are marked `LINKED` with their document IDs and full heading
paths. Structured design IDs such as `DES-SYS-001` are included as referenced
items. The workbook also contains a controlled-document index and project
metadata.

Project-set validation runs before individual document export, so broken
document and requirement links cannot publish a newly generated artifact set.

Acceptance procedures may also reference design items with `DESIGN_ITEMS`.
The traceability workbook validates those IDs and provides a `Design Coverage`
sheet showing the acceptance procedures that cover each design item.

Acceptance procedures identify required measuring equipment through the
`EQUIPMENT` property. Equipment IDs must resolve to active, in-calibration
`EQ-*` items from `calibration.org`. Traceability includes an `Equipment
Coverage` sheet showing which acceptance procedures use each instrument.

## Acceptance records

`acceptance.org` defines reusable controlled procedures. The generated
`exports/acceptance.xlsx` is a blank execution template, not an executed test
record. Its first worksheet carries that warning, and all execution fields are
blank by construction.

Before testing, copy the workbook to a unique filename beneath `records/`, for
example:

```text
records/acceptance/FAT-ENG-0001-2026-10-27.xlsx
```

Record executor, date, configuration or serial number, result, observations,
evidence, deviations, disposition, and approval in that preserved copy.
`engdoc-init` creates `records/`; export code never writes to or removes content
from it. Everything beneath `exports/` remains reproducible and replaceable.

## Calibration records

`calibration.org` controls the equipment register, calibration intervals, due
dates, procedures, and reference-standard chains. Reference standards are
themselves controlled `EQ-*` items; unknown standards, self-reference, and
cycles are invalid. Overdue active equipment is reported and cannot be used by
an acceptance procedure.

`exports/calibration.xlsx` contains the current equipment register and a blank
calibration execution sheet. Preserve completed calibration records and
certificates beneath `records/calibration/`. As with acceptance records,
regeneration never reads or changes that directory.

## Risk and hazard analysis

`risk.org` controls `HAZ-*` hazard items. Each hazard records an owner, status,
five-level severity and likelihood scores, residual scores, and the controlled
requirements, design items, and acceptance procedures that implement and
verify its mitigations.

Initial and residual risk are calculated as severity multiplied by likelihood.
Scores must be integers from 1 through 5, and residual risk may not exceed the
initial score. The generated workbook includes a color-coded hazard register
and five-by-five risk matrix. Project-set validation resolves every mitigation
link before export, while `traceability.xlsx` provides a `Hazard Coverage`
sheet with risk reduction and control completeness.

## Installation and commissioning

`installation.org` controls `INS-*` activities across site readiness,
receiving, installation, commissioning, and handover. Activities trace to
requirements, design items, hazards, acceptance procedures, and calibrated
equipment. Unknown references stop the project export.

The generated workbook contains the activity register, a blank site execution
sheet, and a preallocated punch list. Completed site records, evidence, punch
dispositions, and approvals belong beneath `records/installation/`; export
never modifies them. The project traceability workbook provides an
`Installation Coverage` sheet identifying activities with complete or
incomplete control chains.

## Service and maintenance

`service.org` controls `SVC-*` inspection, preventive, diagnostic, and
corrective tasks. Each task defines its required skill, owner, interval where
applicable, hazards, design basis, equipment, procedure, and objective as-left
criteria.

The service workbook contains a maintenance register, recurring schedule, and
blank work-record sheet. Completed work orders, parts usage, measurements,
evidence, and approvals belong beneath `records/service/`. `traceability.xlsx`
includes a `Service Coverage` sheet so maintenance instructions cannot silently
lose their requirement, design, or hazard basis.

## User manual

`user-manual.org` controls `USR-*` safety, startup, operation, shutdown,
recovery, and operator-care topics. Each topic identifies its audience and
traces to requirements, design items, hazards, and relevant `SVC-*` escalation
tasks. Unknown references stop project export.

Exports include printable PDF/TeX, accessible HTML, and a user-content
register. `traceability.xlsx` includes a `User Guidance Coverage` sheet so
operating instructions remain visibly tied to their engineering basis.

## Local verification

The complete local check does not depend on a hosted CI service:

```sh
make check
```

It runs Python parser/export tests, Emacs ERT tests, and strict byte-compilation
of the Emacs Lisp sources. Tests use `.venv/bin/python` when it exists.

## Architecture

Document types are entries in `engdoc-document-types`. Each registration owns
its filename, description, template, Emacs module, exporter function, expected
outputs, and Python dependencies. The core owns discovery, creation, process
execution, logging, dependency checks, and output verification.

Document-specific Emacs modules orchestrate a single type. Python exporters
share `documents/engdoc_org.py`, which defines the supported Org subset:
headings, TODO keywords, tags, property drawers, planning timestamps, heading
paths, and body text. It is intentionally smaller and more predictable than a
complete Org implementation.

Project validation requires a positive integer quantity for every `:BOM:`
heading, nonnegative numeric costs, recognized sourcing values, and schedule
deadlines that do not precede their start dates. Requirements validation
enforces unique IDs and recognized verification stages. Incomplete but usable
engineering content is reported as a warning where appropriate.

See [docs/adding-document-types.md](docs/adding-document-types.md) for the
extension contract.

## Repository layout

```text
engdoc.el                         core registry and lifecycle
documents/engdoc_org.py          shared Org reader
documents/<type>/template.org    source template and user guide
documents/<type>/engdoc-*.el     export orchestration
documents/<type>/export_*        format-specific exporters
test/                            fixtures, ERT, and Python tests
```
