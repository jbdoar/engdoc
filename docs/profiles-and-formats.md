# Presentation profiles and artifact formats

Profiles control presentation. Format adapters control external file
contracts. Do not combine them: changing a logo should not select an ERP
schema, and changing an ERP schema should not alter a PDF.

## Presentation profile

A profile directory contains `profile.json` and its assets:

```text
work/
  profile.json
  latex/
    header.tex
    company.sty
    logo.pdf
```

```json
{
  "name": "work",
  "latex_header": "latex/header.tex"
}
```

Select it with `#+ENGDOC_PROFILE: work`. The LaTeX header may load a class or
package, configure page geometry, and define title/header/footer behavior.
Keep paths inside the profile relative so the profile remains portable.

Project-local profiles live in `.engdoc/profiles/`. Shared or private profile
roots are added to `engdoc-profile-directories`:

```elisp
(add-to-list 'engdoc-profile-directories "/path/to/private/profiles")
```

## Output adapter

A BOM adapter resides at `bom/<name>/adapter.py` under a format root and
provides:

```python
def export(rows, output, metadata):
    # Write the exact external contract to output.
    ...
```

Select it with `#+ENGDOC_BOM_FORMAT: name`. Project-local adapters live in
`.engdoc/formats/`; shared roots are added to `engdoc-format-directories`.
Adapters receive normalized rows using the canonical fields documented in
`documents/project/export_bom.py`. They should map those values into the
external system rather than changing the Org schema.

Each production adapter should include a representative fixture and a test
that asserts exact sheet names, column order, types, required constants,
value mappings, and filename behavior. Treat the receiving system's import
template as a versioned interface contract.
