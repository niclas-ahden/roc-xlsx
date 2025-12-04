## Generate XLSX spreadsheets in Roc.
##
## Creates minimal but valid XLSX files with headers and data rows.
## All cells are stored as inline strings.
##
## ## Example
##
## ```roc
## Xlsx.create({
##     headers: ["Name", "Email"],
##     rows: [
##         ["Alice", "alice@example.com"],
##         ["Bob", "bob@example.com"],
##     ],
## })
## ```
module [
    Row,
    CreateError,
    create,
]

import xml.Node
import xml.Document
import zip.Zip

## A row of cells in the spreadsheet.
##
## Each element in the list represents a cell value as a string.
## The order corresponds to the column order defined by the headers.
Row : List Str

## Errors that can occur when creating an XLSX file.
##
## These wrap errors from the underlying ZIP creation and should
## rarely occur in practice. You *could* create an XLSX file over
## 4 GB in size to trigger `FileTooLarge`, but the other errors
## should not happen. We expose them anyway to avoid a crash on
## unintended behaviour:
##
## - `ZipErr EmptyPath` - An internal archive path was empty (should never happen)
## - `ZipErr PathTooLong` - An internal archive path exceeded 65535 bytes (should never happen)
## - `ZipErr FileTooLarge` - The total spreadsheet data exceeded 4GB (can happen)
CreateError : [ZipErr Zip.CreateError]

## XML namespace constants
xmlns_package : Str
xmlns_package = "http://schemas.openxmlformats.org/package/2006/content-types"

xmlns_relationships : Str
xmlns_relationships = "http://schemas.openxmlformats.org/package/2006/relationships"

xmlns_spreadsheetml : Str
xmlns_spreadsheetml = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"

xmlns_office_document : Str
xmlns_office_document = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

## Content type constants
content_type_relationships : Str
content_type_relationships = "application/vnd.openxmlformats-package.relationships+xml"

content_type_xml : Str
content_type_xml = "application/xml"

content_type_sheet_main : Str
content_type_sheet_main = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"

content_type_worksheet : Str
content_type_worksheet = "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"

## Convert XML node to document string with declaration
xml_document : Node.Node -> Str
xml_document = |node|
    Document.render(Document.with_declaration(node))

## Create a cell with inline string value
create_inline_str_cell : Str, Str -> Node.Node
create_inline_str_cell = |cell_ref, value|
    Node.element(
        "c",
        [
            Node.attribute("r", cell_ref),
            Node.attribute("t", "inlineStr"),
        ],
        [
            Node.element(
                "is",
                [],
                [
                    Node.element("t", [], [Node.text(value)]),
                ],
            ),
        ],
    )

## Create an XLSX file from headers and data rows.
##
## Returns the XLSX file as a byte array that can be written to disk
## or served on the fly. The spreadsheet will have a single sheet
## named "Sheet1" with the headers in the first row and data in
## subsequent rows.
##
## ## Example
##
## ```roc
## when Xlsx.create({ headers: ["A", "B"], rows: [["1", "2"]] }) is
##     Ok(bytes) -> File.write_bytes!(bytes, "output.xlsx")
##     Err(_) -> # handle error
## ```
##
## ## Limitations
##
## - All cells are stored as strings (no number or date formatting)
## - No styling, formulas, or multiple sheets
create : { headers : List Str, rows : List Row } -> Result (List U8) CreateError
create = |{ headers, rows }|
    # Generate all XML files
    content_types = generate_content_types({})
    rels = generate_rels({})
    workbook = generate_workbook({})
    workbook_rels = generate_workbook_rels({})
    sheet = generate_sheet(headers, rows)

    # Create ZIP entries
    entries = [
        { path: "[Content_Types].xml", content: Str.to_utf8(content_types) },
        { path: "_rels/.rels", content: Str.to_utf8(rels) },
        { path: "xl/workbook.xml", content: Str.to_utf8(workbook) },
        { path: "xl/_rels/workbook.xml.rels", content: Str.to_utf8(workbook_rels) },
        { path: "xl/worksheets/sheet1.xml", content: Str.to_utf8(sheet) },
    ]

    # Create ZIP file
    Zip.create(entries)
    |> Result.map_err(ZipErr)

## Generate [Content_Types].xml
generate_content_types : {} -> Str
generate_content_types = |{}|
    node =
        Node.element(
            "Types",
            [Node.attribute("xmlns", xmlns_package)],
            [
                Node.element(
                    "Default",
                    [
                        Node.attribute("Extension", "rels"),
                        Node.attribute("ContentType", content_type_relationships),
                    ],
                    [],
                ),
                Node.element(
                    "Default",
                    [
                        Node.attribute("Extension", "xml"),
                        Node.attribute("ContentType", content_type_xml),
                    ],
                    [],
                ),
                Node.element(
                    "Override",
                    [
                        Node.attribute("PartName", "/xl/workbook.xml"),
                        Node.attribute("ContentType", content_type_sheet_main),
                    ],
                    [],
                ),
                Node.element(
                    "Override",
                    [
                        Node.attribute("PartName", "/xl/worksheets/sheet1.xml"),
                        Node.attribute("ContentType", content_type_worksheet),
                    ],
                    [],
                ),
            ],
        )

    xml_document(node)

## Generate _rels/.rels
generate_rels : {} -> Str
generate_rels = |{}|
    node =
        Node.element(
            "Relationships",
            [Node.attribute("xmlns", xmlns_relationships)],
            [
                Node.element(
                    "Relationship",
                    [
                        Node.attribute("Id", "rId1"),
                        Node.attribute("Type", "${xmlns_office_document}/officeDocument"),
                        Node.attribute("Target", "xl/workbook.xml"),
                    ],
                    [],
                ),
            ],
        )

    xml_document(node)

## Generate xl/workbook.xml
generate_workbook : {} -> Str
generate_workbook = |{}|
    node =
        Node.element(
            "workbook",
            [
                Node.attribute("xmlns", xmlns_spreadsheetml),
                Node.attribute("xmlns:r", xmlns_office_document),
            ],
            [
                Node.element(
                    "sheets",
                    [],
                    [
                        Node.element(
                            "sheet",
                            [
                                Node.attribute("name", "Sheet1"),
                                Node.attribute("sheetId", "1"),
                                Node.attribute("r:id", "rId1"),
                            ],
                            [],
                        ),
                    ],
                ),
            ],
        )

    xml_document(node)

## Generate xl/_rels/workbook.xml.rels
generate_workbook_rels : {} -> Str
generate_workbook_rels = |{}|
    node =
        Node.element(
            "Relationships",
            [Node.attribute("xmlns", xmlns_relationships)],
            [
                Node.element(
                    "Relationship",
                    [
                        Node.attribute("Id", "rId1"),
                        Node.attribute("Type", "${xmlns_office_document}/worksheet"),
                        Node.attribute("Target", "worksheets/sheet1.xml"),
                    ],
                    [],
                ),
            ],
        )

    xml_document(node)

## Generate xl/worksheets/sheet1.xml
generate_sheet : List Str, List Row -> Str
generate_sheet = |headers, rows|
    # Build header row (row 1)
    header_cells =
        headers
        |> List.map_with_index(
            |header, index|
                col_letter = column_letter(index)
                cell_ref = "${col_letter}1"
                create_inline_str_cell(cell_ref, header),
        )

    header_row =
        Node.element(
            "row",
            [Node.attribute("r", "1")],
            header_cells,
        )

    # Build data rows (starting from row 2)
    data_rows =
        rows
        |> List.map_with_index(
            |row, row_index|
                row_num = row_index + 2 # Rows start at 1, and headers are row 1

                cells =
                    row
                    |> List.map_with_index(
                        |cell_value, col_index|
                            col_letter = column_letter(col_index)
                            cell_ref = "${col_letter}${Num.to_str(row_num)}"
                            create_inline_str_cell(cell_ref, cell_value),
                    )

                Node.element(
                    "row",
                    [Node.attribute("r", Num.to_str(row_num))],
                    cells,
                ),
        )

    # Combine header and data rows
    all_rows = List.prepend(data_rows, header_row)

    node =
        Node.element(
            "worksheet",
            [Node.attribute("xmlns", xmlns_spreadsheetml)],
            [
                Node.element("sheetData", [], all_rows),
            ],
        )

    xml_document(node)

## Convert column index to column letter (A, B, C, ..., Z, AA, AB, ..., ZZ, AAA, ...)
column_letter : U64 -> Str
column_letter = |index|
    if index < 26 then
        byte = Num.to_u8(index) + 'A'
        Str.from_utf8([byte]) |> Result.with_default("A")
    else
        prefix = column_letter((index // 26) - 1)
        suffix_byte = Num.to_u8(index % 26) + 'A'
        suffix = Str.from_utf8([suffix_byte]) |> Result.with_default("A")
        "${prefix}${suffix}"

# Column letters
expect column_letter(0) == "A"
expect column_letter(1) == "B"
expect column_letter(25) == "Z"
expect column_letter(26) == "AA"
expect column_letter(27) == "AB"
expect column_letter(51) == "AZ"
expect column_letter(52) == "BA"
expect column_letter(701) == "ZZ"
expect column_letter(702) == "AAA"
expect column_letter(703) == "AAB"

# Create returns Ok for valid input
expect
    result = create({ headers: ["A"], rows: [] })
    Result.is_ok(result)

# Create with headers and rows returns Ok
expect
    result = create(
        {
            headers: ["Name", "Age"],
            rows: [["Alice", "30"], ["Bob", "25"]],
        },
    )
    Result.is_ok(result)

# Create produces non-empty output
expect
    result = create({ headers: ["Test"], rows: [] })
    when result is
        Ok(bytes) -> List.len(bytes) > 0
        Err(_) -> Bool.false

# Generate_sheet includes header cells with correct references
expect
    sheet = generate_sheet(["Name", "Age"], [])
    # Should contain cell references A1 and B1 for headers
    Str.contains(sheet, "r=\"A1\"") and Str.contains(sheet, "r=\"B1\"")

# Generate_sheet includes header values
expect
    sheet = generate_sheet(["Name", "Age"], [])
    Str.contains(sheet, "<t>Name</t>") and Str.contains(sheet, "<t>Age</t>")

# Generate_sheet includes data rows with correct row numbers
expect
    sheet = generate_sheet(["Name"], [["Alice"], ["Bob"]])
    # Row 1 is header, rows 2 and 3 are data
    Str.contains(sheet, "r=\"A2\"") and Str.contains(sheet, "r=\"A3\"")

# Generate_sheet includes data values
expect
    sheet = generate_sheet(["Name"], [["Alice"], ["Bob"]])
    Str.contains(sheet, "<t>Alice</t>") and Str.contains(sheet, "<t>Bob</t>")

# Generate_sheet with multiple columns
expect
    sheet = generate_sheet(["A", "B", "C"], [["1", "2", "3"]])
    Str.contains(sheet, "r=\"A2\"")
    and Str.contains(sheet, "r=\"B2\"")
    and Str.contains(sheet, "r=\"C2\"")

# Generate_sheet has XML declaration
expect
    sheet = generate_sheet(["Test"], [])
    Str.starts_with(sheet, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")

# Generate_sheet has worksheet element with correct namespace
expect
    sheet = generate_sheet(["Test"], [])
    Str.contains(sheet, "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">")

# Generate_content_types has correct structure
expect
    content = generate_content_types({})
    Str.contains(content, "<Types xmlns=")
    and Str.contains(content, "Extension=\"rels\"")
    and Str.contains(content, "Extension=\"xml\"")

# Generate_rels references workbook
expect
    rels = generate_rels({})
    Str.contains(rels, "Target=\"xl/workbook.xml\"")

# Generate_workbook has sheet reference
expect
    workbook = generate_workbook({})
    Str.contains(workbook, "name=\"Sheet1\"")
    and Str.contains(workbook, "sheetId=\"1\"")

# Generate_workbook_rels references worksheet
expect
    rels = generate_workbook_rels({})
    Str.contains(rels, "Target=\"worksheets/sheet1.xml\"")

# Empty headers and rows still produces valid structure
expect
    sheet = generate_sheet([], [])
    Str.contains(sheet, "<sheetData>") and Str.contains(sheet, "</sheetData>")

# Special characters in cell values are escaped
expect
    sheet = generate_sheet(["Test"], [["<script>alert('xss')</script>"]])
    # The XML should escape < and >
    Str.contains(sheet, "&lt;script&gt;") and Str.contains(sheet, "&lt;/script&gt;")

# Ampersand in cell values is escaped
expect
    sheet = generate_sheet(["Company"], [["Ben & Jerry's"]])
    Str.contains(sheet, "Ben &amp; Jerry")

# Cells are marked as inline strings
expect
    sheet = generate_sheet(["Test"], [["Value"]])
    Str.contains(sheet, "t=\"inlineStr\"")

# Unicode characters (emoji, non-ASCII)
expect
    sheet = generate_sheet(["Name"], [["Héllo 世界 🎉"]])
    Str.contains(sheet, "Héllo 世界 🎉")

# Empty string cell values
expect
    sheet = generate_sheet(["A", "B", "C"], [["", "middle", ""]])
    Str.contains(sheet, "<t></t>") and Str.contains(sheet, "<t>middle</t>")

# Newlines in cell values are preserved
expect
    sheet = generate_sheet(["Notes"], [["Line1\nLine2\nLine3"]])
    Str.contains(sheet, "Line1\nLine2\nLine3")

# Whitespace is preserved (leading/trailing spaces)
expect
    sheet = generate_sheet(["Data"], [["  padded  "]])
    Str.contains(sheet, "  padded  ")

# Row with fewer cells than headers (sparse row)
expect
    sheet = generate_sheet(["A", "B", "C"], [["only one"]])
    # Should still produce valid XML with just one cell
    Str.contains(sheet, "<t>only one</t>")

# Row with more cells than headers (extra cells)
expect
    sheet = generate_sheet(["A"], [["one", "two", "three"]])
    # All cells should be included
    Str.contains(sheet, "<t>one</t>")
    and Str.contains(sheet, "<t>two</t>")
    and Str.contains(sheet, "<t>three</t>")
