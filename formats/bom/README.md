# BOM format adapters

The built-in `default` format is implemented by `export_bom.py`. A named
adapter lives at `bom/<name>/adapter.py` beneath a configured format directory
and exports this function:

```python
def export(rows, output, metadata):
    ...
```

`rows` is the normalized BOM model, independent of any ERP column layout.
Adapters own the exact workbook or CSV contract and must write `output`.
