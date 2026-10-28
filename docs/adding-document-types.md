# Adding a document type

A document type is a small extension of the shared lifecycle, not a separate
application. Keep generic mechanics in the core and keep the extension focused
on its document schema and transformations.

## Contract

Add an entry to `engdoc-document-types` in `engdoc.el` with all of these keys:

```elisp
(design
 :filename "design.org"
 :description "Engineering design description."
 :template "design/template.org"
 :module "engdoc-design"
 :exporter engdoc-design-export
 :outputs ("design.pdf" "design.xlsx")
 :python-dependencies ("openpyxl"))
```

Create `documents/design/template.org` and
`documents/design/engdoc-design.el`. The module must provide the symbol named
by `:module`; its exporter accepts an optional source filename and must:

1. Resolve and save the source file.
2. Validate before producing artifacts.
3. Write artifacts to `(engdoc-export-directory source-file)`.
4. Use `engdoc-run-python` or `engdoc-run-process` for external programs.
5. Call `engdoc-verify-outputs` with every promised output.
6. Signal an error on failure rather than silently returning partial success.

Every template must include the shared metadata keywords documented in the
README. Python exporters should call `load_and_validate_metadata` and
`apply_workbook_metadata` from `documents/engdoc_metadata.py`. Org-native
exports should bind `engdoc--export-metadata` and add
`engdoc-insert-export-metadata` to
`org-export-before-processing-functions`, as the existing exporters do.

Headings that implement, verify, service, or otherwise derive from requirements
should use the shared `REQUIREMENTS` property. Do not introduce another
document-specific requirement-link field. Project-set validation and the
traceability exporter discover this property automatically in every controlled
Org document.

Acceptance procedures link to structured design items through the shared
`DESIGN_ITEMS` property. Types that generate execution templates must keep
blank templates beneath `exports/` and completed evidence beneath `records/`.
An exporter must never inspect, replace, migrate, or clean completed records.

Acceptance measurement dependencies use the shared `EQUIPMENT` property and
must resolve to controlled `EQ-*` entries. Calibration assets may identify
other equipment as standards through `REFERENCE_STANDARDS`; validation must
reject missing standards and reference cycles.

Hazards use stable `HAZ-*` IDs and link mitigation controls through the shared
`REQUIREMENTS`, `DESIGN_ITEMS`, and `ACCEPTANCE_PROCEDURES` properties. Safety
content in installation, service, and user-facing types should reference these
hazard IDs instead of creating independent warning identifiers.

Installation and commissioning activities use stable `INS-*` IDs and the
shared `HAZARDS` property in addition to existing requirement, design,
acceptance, and equipment links. Completed site and punch-list records remain
beneath `records/installation/`.

Service activities use stable `SVC-*` IDs. Scheduled inspection and preventive
tasks require a positive `INTERVAL_DAYS`; all service work should retain shared
requirement, design, hazard, and equipment links. Completed work orders remain
beneath `records/service/`.

User guidance uses stable `USR-*` IDs and shared requirement, design, and
hazard links. The `SERVICE_TASKS` property resolves operator escalation and
care boundaries to controlled `SVC-*` tasks. User-facing guidance is a
controlled document, not an execution-record store.

Use the exact filenames declared in `:outputs`. Do not embed project-specific
paths in an exporter.

## Org schema

Document each heading, property, permitted value, validation rule, and output
mapping in the template itself. A new copy of the template must pass its own
validation without requiring edits.

Use `documents/engdoc_org.py` for Python parsing. Extend the shared reader when
a construct is useful to multiple document types. Keep a specialized parser in
the document directory when its syntax is genuinely type-specific.

Validation should distinguish fatal structural errors from warnings about
incomplete engineering content. Fatal errors must precede artifact generation.

## Tests

Add a representative Org fixture and test:

- parsing and validation, including malformed input;
- the structure and important formatting of generated workbooks;
- successful loading of the Emacs exporter;
- creation of the registered template;
- every declared output.

Run `make check`. Tests must not depend on committed generated files, network
access, a hosted CI provider, or the user's Emacs configuration.

## Design boundaries

- `engdoc.el`: registration and reusable lifecycle infrastructure.
- document Emacs module: orchestration and Org-native exports.
- shared Org reader: common source interpretation.
- document Python modules: validation and format-specific transformation.
- `exports/`: disposable generated artifacts, never the authoritative record.
- `records/`: preserved execution evidence, never modified by export.

Prefer adding a narrow shared primitive over copying process, parsing, logging,
or verification logic into another document directory.
