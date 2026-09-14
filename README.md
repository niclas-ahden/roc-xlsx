# roc-xlsx

Generate XLSX spreadsheets in Roc.

`Xlsx.create` takes headers and rows and returns the bytes of a minimal but valid XLSX file, ready to write to disk or serve on the fly. All cells are stored as inline strings.

View the API documentation at [https://niclas-ahden.github.io/roc-xlsx/](https://niclas-ahden.github.io/roc-xlsx/).

## Quick start

```roc
app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.23.0-rc1/3hT3SoHZ6qbEsa9qVFLUW3547U5LeoNd1KbpqLpz4r1i.tar.zst",
    xlsx: "https://github.com/niclas-ahden/roc-xlsx/releases/download/0.1.0/qMTvhJjHIr9mX48Te9F7xMfalEo_yxThuIbSDV-_IrY.tar.br",
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
    })?

    Path.write_bytes!(Path.utf8("example.xlsx"), bytes)?
    Stdout.line!("Wrote example.xlsx (${bytes.len().to_str()} bytes)")
}
```

See [examples](examples/) for a runnable program.

## Limitations

- All cells are strings (no number/date formatting)
- Single sheet only ("Sheet1")
- No styling (fonts, colors, borders)
- No formulas

## How it is built

An XLSX file is a ZIP archive of XML parts. The XML comes from [roc-xml](https://github.com/niclas-ahden/roc-xml) and the archive from [roc-zip](https://github.com/niclas-ahden/roc-zip), so this package is pure Roc all the way down.
