# roc-xlsx

Generate XLSX spreadsheets in Roc.

Creates minimal but valid XLSX files with headers and data rows. All cells are stored as inline strings.

View the API documentation at [https://niclas-ahden.github.io/roc-xlsx/](https://niclas-ahden.github.io/roc-xlsx/).

## Quick start

```roc
app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.20.0/X73hGh05nNTkDHU06FHC0YfFaQB1pimX7gncRcao5mU.tar.br",
    xlsx: "https://github.com/niclas-ahden/roc-xlsx/releases/download/0.1.0/REPLACE_WITH_HASH.tar.br",
}

import pf.File
import pf.Stdout
import xlsx.Xlsx

main! = |_args|
    spreadsheet = Xlsx.create({
        headers: ["Name", "Email", "Score"],
        rows: [
            ["Alice", "alice@example.com", "95"],
            ["Bob", "bob@example.com", "87"],
            ["Carol", "carol@example.com", "92"],
        ],
    })

    when spreadsheet is
        Ok(bytes) ->
            File.write_bytes!(bytes, "output.xlsx")?
            Stdout.line!("Created output.xlsx")

        Err(_) ->
            Stdout.line!("Error creating spreadsheet")
```

## Limitations

- All cells are strings (no number/date formatting)
- Single sheet only ("Sheet1")
- No styling (fonts, colors, borders)
- No formulas

## Contributing

Run all tests:

```bash
./tests.sh
```

Or run individual suites:

```bash
roc test package/Xlsx.roc      # Unit tests (fast)
roc run test/IntegrationTest.roc   # Integration tests (creates files, uses unzip)
```

## Status

`roc-xlsx` uses the Roc compiler. The API may change as Roc evolves.

## Documentation

View the API documentation at [https://niclas-ahden.github.io/roc-xlsx/](https://niclas-ahden.github.io/roc-xlsx/).

### Generating documentation locally

```bash
./docs.sh 0.1.0
```

This will generate HTML documentation and place it in `www/0.1.0/`.
