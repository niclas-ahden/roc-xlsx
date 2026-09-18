## Generate XLSX spreadsheets in Roc.
##
## Creates minimal but valid XLSX files with headers and data rows.
## All cells are stored as inline strings.
##
## ## Example
##
## ```roc
## Xlsx.create({
## 	headers: ["Name", "Email"],
## 	rows: [
## 		["Alice", "alice@example.com"],
## 		["Bob", "bob@example.com"],
## 	],
## })
## ```
import xml.Document
import xml.Element
import xml.Node exposing [Node]
import zip.Zip

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

## Create a cell with inline string value
create_inline_str_cell : Str, Str -> Node
create_inline_str_cell = |cell_ref, value|
	Node.element(
		"c",
		Dict.from_list([("r", cell_ref), ("t", "inlineStr")]),
		[
			Node.element(
				"is",
				Dict.empty(),
				[
					# Without xml:space, Excel trims leading and trailing whitespace
					Node.element("t", Dict.single("xml:space", "preserve"), [cell_text(value)]),
				],
			),
		],
	)

## The text of a cell, encoded the way Excel does so that any string
## round-trips.
##
## XML cannot express the control characters other than tab and newline,
## nor U+FFFE and U+FFFF. Excel writes those as `_xHHHH_` and decodes the
## sequence on load. Since it decodes every `_xHHHH_` it sees, a literal one
## in the input has its `_x` written as `_x005F_x` to keep it literal. So has
## a `_xHHHH` without the closing underscore, because the text after it may
## be encoded and would then supply that underscore.
##
## A carriage return is written as `_x000D_` too, although XML can express
## it as `&#13;`. OOXML says it shall be escaped (ST_Xstring, as Microsoft
## implements it), and Excel for Mac reads `&#13;` followed by a newline as
## a line break and a space.
##
## The carriage return and the literal `_xHHHH` are Excel's rules rather
## than XML's, so they are handled here first. What XML itself cannot express
## is then replaced by roc-xml, in the same `_xHHHH_` spelling. None of this
## can fail.
cell_text : Str -> Node
cell_text = |value|
	Node.text_lossy(escape_for_excel(value), ReplaceWith(excel_escape))

# Carriage returns encoded and a literal `_xHHHH` kept literal. Most cells
# hold neither and skip the byte walk.
escape_for_excel : Str -> Str
escape_for_excel = |value|
	if value.contains("\r") or value.contains("_x") {
		escape_for_excel_bytes(value.to_utf8())
	} else {
		value
	}

escape_for_excel_bytes : List(U8) -> Str
escape_for_excel_bytes = |bytes| {
	out = bytes.fold_with_index(
		List.with_capacity(bytes.len()),
		|acc, byte, index|
			if byte == 0xD {
				acc.concat(excel_escape(0xD).to_utf8())
			} else if byte == '_' and starts_excel_escape(bytes, index) {
				# Keep a literal _xHHHH literal: Excel decodes _x005F_ to _
				acc.concat("_x005F_".to_utf8())
			} else {
				acc.append(byte)
			},
	)
	# Only ASCII bytes were replaced, so no character was split
	Str.from_utf8_lossy(out)
}

## Whether `_xHHHH` starts at `index`. The closing underscore is not asked
## for: `_x005F` followed by a bell would otherwise be written as
## `_x005F_x0007_`, which Excel reads as `_` and a literal `x0007_`.
starts_excel_escape : List(U8), U64 -> Bool
starts_excel_escape = |bytes, index|
	match bytes.sublist({ start: index, len: 6 }) {
		['_', 'x', a, b, c, d] => [a, b, c, d].all(is_hex_digit)
		_ => Bool.False
	}

is_hex_digit : U8 -> Bool
is_hex_digit = |b|
	(b >= '0' and b <= '9') or (b >= 'A' and b <= 'F') or (b >= 'a' and b <= 'f')

## `_xHHHH_` for a code point. Four digits cover everything this is called
## with: control characters and the two non-characters.
excel_escape : U32 -> Str
excel_escape = |code_point|
	Str.from_utf8_lossy([
		'_',
		'x',
		hex_digit(code_point // 0x1000),
		hex_digit((code_point // 0x100) % 16),
		hex_digit((code_point // 0x10) % 16),
		hex_digit(code_point % 16),
		'_',
	])

hex_digit : U32 -> U8
hex_digit = |n|
	if n < 10 {
		'0' + n.to_u8_wrap()
	} else {
		'A' + (n - 10).to_u8_wrap()
	}

## [Content_Types].xml, rendered and proven well-formed at compile time
content_types_xml : Str
content_types_xml = {
	Ok(root) = Element.new(
		"Types",
		Dict.single("xmlns", xmlns_package),
		[
			Node.element("Default", Dict.from_list([("Extension", "rels"), ("ContentType", content_type_relationships)]), []),
			Node.element("Default", Dict.from_list([("Extension", "xml"), ("ContentType", content_type_xml)]), []),
			Node.element("Override", Dict.from_list([("PartName", "/xl/workbook.xml"), ("ContentType", content_type_sheet_main)]), []),
			Node.element("Override", Dict.from_list([("PartName", "/xl/worksheets/sheet1.xml"), ("ContentType", content_type_worksheet)]), []),
		],
	)

	Document.render(root)
}

## _rels/.rels, rendered and proven well-formed at compile time
rels_xml : Str
rels_xml = {
	Ok(root) = Element.new(
		"Relationships",
		Dict.single("xmlns", xmlns_relationships),
		[
			Node.element(
				"Relationship",
				Dict.from_list([
					("Id", "rId1"),
					("Type", "${xmlns_office_document}/officeDocument"),
					("Target", "xl/workbook.xml"),
				]),
				[],
			),
		],
	)

	Document.render(root)
}

## xl/workbook.xml, rendered and proven well-formed at compile time
workbook_xml : Str
workbook_xml = {
	Ok(root) = Element.new(
		"workbook",
		Dict.from_list([("xmlns", xmlns_spreadsheetml), ("xmlns:r", xmlns_office_document)]),
		[
			Node.element(
				"sheets",
				Dict.empty(),
				[
					Node.element("sheet", Dict.from_list([("name", "Sheet1"), ("sheetId", "1"), ("r:id", "rId1")]), []),
				],
			),
		],
	)

	Document.render(root)
}

## xl/_rels/workbook.xml.rels, rendered and proven well-formed at compile time
workbook_rels_xml : Str
workbook_rels_xml = {
	Ok(root) = Element.new(
		"Relationships",
		Dict.single("xmlns", xmlns_relationships),
		[
			Node.element(
				"Relationship",
				Dict.from_list([
					("Id", "rId1"),
					("Type", "${xmlns_office_document}/worksheet"),
					("Target", "worksheets/sheet1.xml"),
				]),
				[],
			),
		],
	)

	Document.render(root)
}

## Generate xl/worksheets/sheet1.xml
##
## The other four parts of the archive are built from literals alone, so the
## compiler builds them while type checking and proves the `Ok`. The
## worksheet holds the caller's cells, so it is built at runtime, with
## `Element.new_lossy`, which cannot fail. There is nothing in it for roc-xml
## to repair: cell values go in through `Node.text_lossy`, every name is a
## constant, and cell references are letters and digits. A test below gives
## the same tree to `Element.new` to prove it.
generate_sheet : List(Str), List(Xlsx.Row) -> Str
generate_sheet = |headers, rows|
	Document.render(Element.new_lossy("worksheet", worksheet_attributes, worksheet_children(headers, rows), Drop))

worksheet_attributes : Dict(Str, Str)
worksheet_attributes = Dict.single("xmlns", xmlns_spreadsheetml)

## What the worksheet element holds: the sheet data, with the headers as row
## 1 and the data rows after it.
worksheet_children : List(Str), List(Xlsx.Row) -> List(Node)
worksheet_children = |headers, rows| {
	# Build header row (row 1)
	header_cells = headers.map_with_index(
		|header, index| {
			col_letter = column_letter(index)
			cell_ref = "${col_letter}1"
			create_inline_str_cell(cell_ref, header)
		},
	)

	header_row = Node.element("row", Dict.single("r", "1"), header_cells)

	# Build data rows (starting from row 2)
	data_rows = rows.map_with_index(
		|row, row_index| {
			row_num = row_index + 2 # Rows start at 1, and headers are row 1

			cells = row.map_with_index(
				|cell_value, col_index| {
					col_letter = column_letter(col_index)
					cell_ref = "${col_letter}${row_num.to_str()}"
					create_inline_str_cell(cell_ref, cell_value)
				},
			)

			Node.element("row", Dict.single("r", row_num.to_str()), cells)
		},
	)

	# Combine header and data rows
	all_rows = data_rows.prepend(header_row)

	[Node.element("sheetData", Dict.empty(), all_rows)]
}

## Convert column index to column letter (A, B, C, ..., Z, AA, AB, ..., ZZ, AAA, ...)
column_letter : U64 -> Str
column_letter = |index|
	if index < 26 {
		# A single ASCII byte is always valid UTF-8
		Str.from_utf8_lossy([index.to_u8_wrap() + 'A'])
	} else {
		prefix = column_letter((index // 26) - 1)
		suffix = Str.from_utf8_lossy([(index % 26).to_u8_wrap() + 'A'])
		"${prefix}${suffix}"
	}

Xlsx := [].{

	## A row of cells in the spreadsheet.
	##
	## Each element in the list represents a cell value as a string.
	## The order corresponds to the column order defined by the headers.
	Row : List(Str)

	## Create an XLSX file from headers and data rows.
	##
	## Returns the XLSX file as a byte array that can be written to disk
	## or served on the fly. The spreadsheet will have a single sheet
	## named "Sheet1" with the headers in the first row and data in
	## subsequent rows.
	##
	## ```roc
	## bytes = Xlsx.create({ headers: ["A", "B"], rows: [["1", "2"]] })
	## Path.write_bytes!(Path.utf8("output.xlsx"), bytes)?
	## ```
	##
	## ## Cell values
	##
	## Any string is a valid cell value, and Excel shows it exactly as given:
	##
	## - Leading and trailing whitespace and line endings are kept, carriage
	##   returns included.
	## - Characters XML cannot express (control characters other than tab and
	##   newline, and U+FFFE and U+FFFF) are written the way Excel writes
	##   them, as `_xHHHH_`, which Excel decodes on load.
	##   Other readers show the sequence literally.
	##
	## ## Limitations
	##
	## - All cells are stored as strings (no number or date formatting)
	## - No styling, formulas, or multiple sheets
	## - Excel opens at most 1,048,576 rows and 16,384 columns per sheet
	create : { headers : List(Str), rows : List(Row) } -> List(U8)
	create = |{ headers, rows }| {
		# Generate all XML files
		sheet = generate_sheet(headers, rows)

		# Create ZIP entries
		entries = [
			{ path: "[Content_Types].xml", content: content_types_xml.to_utf8() },
			{ path: "_rels/.rels", content: rels_xml.to_utf8() },
			{ path: "xl/workbook.xml", content: workbook_xml.to_utf8() },
			{ path: "xl/_rels/workbook.xml.rels", content: workbook_rels_xml.to_utf8() },
			{ path: "xl/worksheets/sheet1.xml", content: sheet.to_utf8() },
		]

		# Every path above is a constant that roc-zip accepts
		match Zip.create(entries, Balanced) {
			Ok(archive) => archive
			Err(_) => crash "roc-xlsx bug: the archive paths are constants, yet roc-zip refused one"
		}
	}
}

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

# Create produces non-empty output
expect Xlsx.create({ headers: ["A"], rows: [] }).len() > 0

# Create with headers and rows produces non-empty output
expect {
	bytes = Xlsx.create({
		headers: ["Name", "Age"],
		rows: [["Alice", "30"], ["Bob", "25"]],
	})
	bytes.len() > 0
}

# Generate_sheet includes header cells with correct references
expect {
	sheet = generate_sheet(["Name", "Age"], [])
	# Should contain cell references A1 and B1 for headers
	sheet.contains("r=\"A1\"") and sheet.contains("r=\"B1\"")
}

# Generate_sheet includes header values
expect {
	sheet = generate_sheet(["Name", "Age"], [])
	sheet.contains(">Name</t>") and sheet.contains(">Age</t>")
}

# Generate_sheet includes data rows with correct row numbers
expect {
	sheet = generate_sheet(["Name"], [["Alice"], ["Bob"]])
	# Row 1 is header, rows 2 and 3 are data
	sheet.contains("r=\"A2\"") and sheet.contains("r=\"A3\"")
}

# Generate_sheet includes data values
expect {
	sheet = generate_sheet(["Name"], [["Alice"], ["Bob"]])
	sheet.contains(">Alice</t>") and sheet.contains(">Bob</t>")
}

# Generate_sheet with multiple columns
expect {
	sheet = generate_sheet(["A", "B", "C"], [["1", "2", "3"]])
	sheet.contains("r=\"A2\"")
		and sheet.contains("r=\"B2\"")
			and sheet.contains("r=\"C2\"")
}

# Generate_sheet has XML declaration
expect {
	sheet = generate_sheet(["Test"], [])
	sheet.starts_with("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
}

# Generate_sheet has worksheet element with correct namespace
expect {
	sheet = generate_sheet(["Test"], [])
	sheet.contains("<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">")
}

# Content types cover both defaults and both overrides
expect
	content_types_xml.contains("<Types xmlns=")
		and content_types_xml.contains("Extension=\"rels\"")
			and content_types_xml.contains("Extension=\"xml\"")

# The package relationships point at the workbook
expect rels_xml.contains("Target=\"xl/workbook.xml\"")

# The workbook lists the one sheet
expect workbook_xml.contains("name=\"Sheet1\"") and workbook_xml.contains("sheetId=\"1\"")

# The workbook relationships point at the worksheet
expect workbook_rels_xml.contains("Target=\"worksheets/sheet1.xml\"")

# Empty headers and rows still produces valid structure
expect {
	sheet = generate_sheet([], [])
	sheet.contains("<sheetData>") and sheet.contains("</sheetData>")
}

# Special characters in cell values are escaped
expect {
	sheet = generate_sheet(["Test"], [["<script>alert('xss')</script>"]])
	# The XML should escape < and >
	sheet.contains("&lt;script&gt;") and sheet.contains("&lt;/script&gt;")
}

# Ampersand in cell values is escaped
expect {
	sheet = generate_sheet(["Company"], [["Ben & Jerry's"]])
	sheet.contains("Ben &amp; Jerry")
}

# Cells are marked as inline strings
expect {
	sheet = generate_sheet(["Test"], [["Value"]])
	sheet.contains("t=\"inlineStr\"")
}

# Unicode characters (emoji, non-ASCII)
expect {
	sheet = generate_sheet(["Name"], [["Héllo 世界 🎉"]])
	sheet.contains("Héllo 世界 🎉")
}

# Empty string cell values
expect {
	sheet = generate_sheet(["A", "B", "C"], [["", "middle", ""]])
	sheet.contains("<t xml:space=\"preserve\"></t>") and sheet.contains(">middle</t>")
}

# Every text element asks Excel to keep whitespace as it is
expect {
	sheet = generate_sheet(["Notes"], [["Line1\nLine2\nLine3"], ["  padded  "]])
	sheet.contains("<t xml:space=\"preserve\">Line1\nLine2\nLine3</t>")
		and sheet.contains("<t xml:space=\"preserve\">  padded  </t>")
}

# Row with fewer cells than headers (sparse row)
expect {
	sheet = generate_sheet(["A", "B", "C"], [["only one"]])
	# Should still produce valid XML with just one cell
	sheet.contains(">only one</t>")
}

# Row with more cells than headers (extra cells)
expect {
	sheet = generate_sheet(["A"], [["one", "two", "three"]])
	# All cells should be included
	sheet.contains(">one</t>")
		and sheet.contains(">two</t>")
			and sheet.contains(">three</t>")
}

# Cell values without anything to encode come back as they are
expect cell_text("") == Node.text("")
expect cell_text("plain text, tabs\tand\nnewlines\n") == Node.text("plain text, tabs\tand\nnewlines\n")
expect cell_text("snake_xylophone") == Node.text("snake_xylophone")
expect cell_text("Héllo 世界 🎉") == Node.text("Héllo 世界 🎉")

# Control characters become Excel's _xHHHH_ sequences
expect cell_text("bell\u(7)") == Node.text("bell_x0007_")
expect cell_text("\u(0)") == Node.text("_x0000_")
expect cell_text("a\u(1B)[0m") == Node.text("a_x001B_[0m")
expect cell_text("\u(1)\u(2)") == Node.text("_x0001__x0002_")

# A carriage return is encoded too, as OOXML asks and Excel does
expect cell_text("a\r\nb") == Node.text("a_x000D_\nb")

# So do the two non-characters, which are three bytes each
expect cell_text("a\u(FFFE)b") == Node.text("a_xFFFE_b")
expect cell_text("\u(FFFF)") == Node.text("_xFFFF_")

# A literal _xHHHH in the input is kept literal for Excel, closed or not
expect cell_text("_x0041_") == Node.text("_x005F_x0041_")
expect cell_text("see _xBEEF_ here") == Node.text("see _x005F_xBEEF_ here")
expect cell_text("_xbeef_") == Node.text("_x005F_xbeef_")
expect cell_text("_x0041") == Node.text("_x005F_x0041")
expect cell_text("_x0041z") == Node.text("_x005F_x0041z")

# An unclosed one cannot be closed by the encoding of what follows it
expect cell_text("_x005F\u(7)") == Node.text("_x005F_x005F_x0007_")
expect cell_text("_x0041\r") == Node.text("_x005F_x0041_x000D_")
expect cell_text("_x0041\u(FFFE)") == Node.text("_x005F_x0041_xFFFE_")

# Without four hex digits after `_x` there is nothing for Excel to decode
expect cell_text("_x41_") == Node.text("_x41_")
expect cell_text("_x004") == Node.text("_x004")
expect cell_text("_xZZZZ_") == Node.text("_xZZZZ_")

# Encoded values reach the sheet, so the worksheet is well-formed XML
expect {
	sheet = generate_sheet(["Log"], [["line\u(7)"]])
	sheet.contains(">line_x0007_</t>")
}

# The worksheet is repaired rather than checked, so nothing at runtime would
# report a name XML cannot express. This does: the same tree passes the
# check, with cells holding everything XML cannot express, so there is
# nothing for roc-xml to repair and the two agree on the XML.
expect {
	headers = ["Log", "_x0041_"]
	rows = [["bell\u(7)", "\u(0)\u(1B)\u(FFFE)\u(FFFF)"], ["a\r\nb", "<&>\"'", "extra"], []]
	match Element.new("worksheet", worksheet_attributes, worksheet_children(headers, rows)) {
		Ok(checked) => Document.render(checked) == generate_sheet(headers, rows)
		Err(_) => Bool.False
	}
}
