# roc-xlsx

Generate XLSX spreadsheets in Roc.

`Xlsx.create` takes headers and rows and returns the bytes of a minimal but valid XLSX file, ready to write to disk or serve on the fly. All cells are stored as inline strings.

View the API documentation at [https://niclas-ahden.github.io/roc-xlsx/](https://niclas-ahden.github.io/roc-xlsx/).

## Quick start

```roc
app [main!] {
    pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.28.0/AP9SGT1yrhCKcFxKcoA5tBkNCM6ibBjBxcQGMTb6krev.tar.zst",
    xlsx: "https://github.com/niclas-ahden/roc-xlsx/releases/download/0.2.2/9hco3vTWu7wGDvJAnAFDDEaGGpfvDPh5HrPcQcMUcqYW.tar.zst",
}

import pf.Path
import pf.Stdout
import xlsx.Xlsx

main! = |_args| {
    bytes = Xlsx.create({
        headers: ["Name", "Email", "Score"],
        rows: [
            ["Alice", "alice@example.com", "95"],
            ["Bob", "bob@example.com", "87"],
            ["Carol", "carol@example.com", "92"],
        ],
    })

    Path.write_bytes!(Path.utf8("example.xlsx"), bytes)?
    Stdout.line!("Wrote example.xlsx (${bytes.len().to_str()} bytes)")
}
```

See [examples](examples/) for a runnable program.

## Cell values

Any string is a valid cell value and Excel and most other readers shows it exactly as given. Leading and trailing whitespace and line endings are kept, carriage returns included. Characters XML cannot express, such as control characters, are written the way Excel writes them, as `_xHHHH_`, which Excel decodes on load.

## Limitations

- All cells are strings (no number/date formatting)
- Single sheet only ("Sheet1")
- No styling (fonts, colors, borders)
- No formulas
- Excel opens at most 1,048,576 rows and 16,384 columns per sheet

## How it is built

An XLSX file is a ZIP archive of XML parts. The XML comes from [roc-xml](https://github.com/niclas-ahden/roc-xml) and the archive from [roc-zip](https://github.com/niclas-ahden/roc-zip), so this package is pure Roc all the way down.
