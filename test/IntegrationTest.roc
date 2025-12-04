app [main!] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.20.0/X73hGh05nNTkDHU06FHC0YfFaQB1pimX7gncRcao5mU.tar.br",
    xlsx: "../package/main.roc",
}

import pf.Stdout
import pf.File
import pf.Cmd
import xlsx.Xlsx

main! = |_args|
    run_test!("basic", test_basic!)?
    run_test!("empty spreadsheet", test_empty!)?
    run_test!("special characters", test_special_chars!)?
    run_test!("30 columns", test_many_columns!)?
    run_test!("unicode", test_unicode!)?
    run_test!("500 rows", test_many_rows!)?

    Stdout.line!("\nAll tests passed!")

run_test! : Str, ({} => Result {} _) => Result {} _
run_test! = |name, test!|
    test!({})?
    Stdout.line!("PASS: ${name}")

test_basic! : {} => Result {} _
test_basic! = |{}|
    xlsx = Xlsx.create({
        headers: ["Name", "Email", "Score"],
        rows: [
            ["Alice", "alice@example.com", "95"],
            ["Bob", "bob@example.com", "87"],
        ],
    })?

    File.write_bytes!(xlsx, "test.xlsx")?
    verify_zip!("test.xlsx")?
    verify_structure!("test.xlsx")?
    verify_contains!("test.xlsx", ["Name", "Alice", "Bob", "87"])?
    File.delete!("test.xlsx")

test_empty! : {} => Result {} _
test_empty! = |{}|
    xlsx = Xlsx.create({ headers: ["A", "B"], rows: [] })?

    File.write_bytes!(xlsx, "test.xlsx")?
    verify_zip!("test.xlsx")?
    verify_structure!("test.xlsx")?
    File.delete!("test.xlsx")

test_special_chars! : {} => Result {} _
test_special_chars! = |{}|
    xlsx = Xlsx.create({
        headers: ["Text"],
        rows: [
            ["Hello & goodbye"],
            ["<script>alert('xss')</script>"],
            ["\"quotes\""],
        ],
    })?

    File.write_bytes!(xlsx, "test.xlsx")?
    verify_zip!("test.xlsx")?
    verify_contains!("test.xlsx", ["&amp;", "&lt;script&gt;", "&quot;"])?
    File.delete!("test.xlsx")

test_many_columns! : {} => Result {} _
test_many_columns! = |{}|
    headers = List.range({ start: At(1), end: At(30) })
        |> List.map(|n| "Col${Num.to_str(n)}")
    row = List.range({ start: At(1), end: At(30) })
        |> List.map(|n| "${Num.to_str(n)}")

    xlsx = Xlsx.create({ headers, rows: [row] })?

    File.write_bytes!(xlsx, "test.xlsx")?
    verify_zip!("test.xlsx")?
    verify_structure!("test.xlsx")?
    File.delete!("test.xlsx")

test_unicode! : {} => Result {} _
test_unicode! = |{}|
    xlsx = Xlsx.create({
        headers: ["Lang", "Text"],
        rows: [
            ["Chinese", "你好"],
            ["Arabic", "مرحبا"],
            ["Emoji", "🎉🚀💯"],
        ],
    })?

    File.write_bytes!(xlsx, "test.xlsx")?
    verify_zip!("test.xlsx")?
    verify_contains!("test.xlsx", ["你好", "مرحبا", "🎉🚀💯"])?
    File.delete!("test.xlsx")

test_many_rows! : {} => Result {} _
test_many_rows! = |{}|
    rows = List.range({ start: At(1), end: At(500) })
        |> List.map(|n| ["${Num.to_str(n)}", "row"])

    xlsx = Xlsx.create({ headers: ["ID", "Type"], rows })?

    File.write_bytes!(xlsx, "test.xlsx")?
    verify_zip!("test.xlsx")?
    verify_structure!("test.xlsx")?
    File.delete!("test.xlsx")

verify_zip! : Str => Result {} _
verify_zip! = |path|
    result = Cmd.new("unzip") |> Cmd.args(["-t", path]) |> Cmd.exec_output!
    when result is
        Ok(_) -> Ok({})
        Err(_) -> crash("ZIP integrity check failed: ${path}")

verify_structure! : Str => Result {} _
verify_structure! = |path|
    result = Cmd.new("unzip") |> Cmd.args(["-l", path]) |> Cmd.exec_output!
    when result is
        Ok({ stdout_utf8 }) ->
            required = ["[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/worksheets/sheet1.xml"]
            if List.all(required, |f| Str.contains(stdout_utf8, f)) then
                Ok({})
            else
                crash("Missing required files in: ${path}")

        Err(_) -> crash("Failed to list: ${path}")

verify_contains! : Str, List Str => Result {} _
verify_contains! = |path, expected|
    result = Cmd.new("unzip") |> Cmd.args(["-p", path, "xl/worksheets/sheet1.xml"]) |> Cmd.exec_output!
    when result is
        Ok({ stdout_utf8 }) ->
            if List.all(expected, |s| Str.contains(stdout_utf8, s)) then
                Ok({})
            else
                crash("Missing expected content in: ${path}")

        Err(_) -> crash("Failed to extract: ${path}")
