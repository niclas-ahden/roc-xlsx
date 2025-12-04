app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.20.0/X73hGh05nNTkDHU06FHC0YfFaQB1pimX7gncRcao5mU.tar.br",
    xlsx: "../package/main.roc",
}

import pf.File
import pf.Stdout
import xlsx.Xlsx

main! = |_args|
    _ = Stdout.line!("Creating spreadsheet...")?

    spreadsheet = Xlsx.create(
        {
            headers: ["Name", "Email"],
            rows: [
                ["Alice Smith", "alice@example.com"],
                ["Bob Johnson", "bob@example.com"],
                ["Carol Williams", "carol@example.com"],
                ["David Brown", "david@example.com"],
            ],
        },
    )

    when spreadsheet is
        Ok(bytes) ->
            File.write_bytes!(bytes, "employees.xlsx")?
            Stdout.line!("Created employees.xlsx")

        Err(ZipErr(_)) ->
            Stdout.line!("Error creating spreadsheet")
