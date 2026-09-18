## Writes spreadsheets to disk and reads them back with a real `unzip` and
## `xmllint`: the archive has to pass its integrity check, hold every part an
## XLSX needs, every part has to parse as XML, and the worksheet has to hand
## back the cell values we put in.
app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.23.0-rc1/3hT3SoHZ6qbEsa9qVFLUW3547U5LeoNd1KbpqLpz4r1i.tar.zst",
	xlsx: "../package/main.roc",
}

import pf.Cmd
import pf.OsStr
import pf.Path
import pf.Stdout
import xlsx.Xlsx

main! = |_args| {
	run_test!("basic", test_basic!)?
	run_test!("empty spreadsheet", test_empty!)?
	run_test!("special characters", test_special_chars!)?
	run_test!("30 columns", test_many_columns!)?
	run_test!("unicode", test_unicode!)?
	run_test!("500 rows", test_many_rows!)?
	run_test!("control characters", test_control_chars!)?

	Stdout.line!("")?
	Stdout.line!("All integration tests passed.")
}

run_test! : Str, (() => Try({}, _)) => Try({}, _)
run_test! = |name, test!| {
	test!()?
	Stdout.line!("PASS: ${name}")
}

test_basic! : () => Try({}, _)
test_basic! = || {
	xlsx = Xlsx.create({
		headers: ["Name", "Email", "Score"],
		rows: [
			["Alice", "alice@example.com", "95"],
			["Bob", "bob@example.com", "87"],
		],
	})

	with_file!(
		"basic.xlsx",
		xlsx,
		|path| {
			verify_zip!(path)?
			verify_structure!(path)?
			verify_well_formed!(path)?
			verify_contains!(path, ["Name", "Alice", "Bob", "87"])
		},
	)
}

test_empty! : () => Try({}, _)
test_empty! = || {
	xlsx = Xlsx.create({ headers: ["A", "B"], rows: [] })

	with_file!(
		"empty.xlsx",
		xlsx,
		|path| {
			verify_zip!(path)?
			verify_structure!(path)?
			verify_well_formed!(path)
		},
	)
}

test_special_chars! : () => Try({}, _)
test_special_chars! = || {
	xlsx = Xlsx.create({
		headers: ["Text"],
		rows: [
			["Hello & goodbye"],
			["<script>alert('xss')</script>"],
			["\"quotes\""],
		],
	})

	with_file!(
		"special_chars.xlsx",
		xlsx,
		|path| {
			verify_zip!(path)?
			verify_well_formed!(path)?
			verify_contains!(path, ["&amp;", "&lt;script&gt;", "\"quotes\""])
		},
	)
}

test_many_columns! : () => Try({}, _)
test_many_columns! = || {
	numbers = List.repeat({}, 30).map_with_index(|_, index| (index + 1).to_str())
	headers = numbers.map(|n| "Col${n}")

	xlsx = Xlsx.create({ headers, rows: [numbers] })

	with_file!(
		"many_columns.xlsx",
		xlsx,
		|path| {
			verify_zip!(path)?
			verify_structure!(path)?
			verify_well_formed!(path)?
			# Column 27 onwards needs two letters
			verify_contains!(path, ["r=\"AA1\"", "r=\"AD2\"", ">Col30</t>"])
		},
	)
}

test_unicode! : () => Try({}, _)
test_unicode! = || {
	xlsx = Xlsx.create({
		headers: ["Lang", "Text"],
		rows: [
			["Chinese", "你好"],
			["Arabic", "مرحبا"],
			["Emoji", "🎉🚀💯"],
		],
	})

	with_file!(
		"unicode.xlsx",
		xlsx,
		|path| {
			verify_zip!(path)?
			verify_structure!(path)?
			verify_well_formed!(path)?
			verify_contains!(path, ["你好", "مرحبا", "🎉🚀💯"])
		},
	)
}

test_many_rows! : () => Try({}, _)
test_many_rows! = || {
	rows = List.repeat({}, 500).map_with_index(|_, index| [(index + 1).to_str(), "row"])

	xlsx = Xlsx.create({ headers: ["ID", "Type"], rows })

	with_file!(
		"many_rows.xlsx",
		xlsx,
		|path| {
			verify_zip!(path)?
			verify_structure!(path)?
			verify_well_formed!(path)?
			# Data starts on row 2, so the 500th row is row 501
			verify_contains!(path, ["r=\"A501\"", ">500</t>"])
		},
	)
}

test_control_chars! : () => Try({}, _)
test_control_chars! = || {
	xlsx = Xlsx.create({
		headers: ["Log line"],
		rows: [
			["bell\u(7) and escape \u(1B)[0m"],
			["literal _x0041_ stays literal"],
			["unclosed _x005F\u(7) stays literal too"],
			["  padded  "],
			["windows\r\nline ending"],
		],
	})

	with_file!(
		"control_chars.xlsx",
		xlsx,
		|path| {
			verify_zip!(path)?
			# The point of the encoding: a real XML parser accepts the sheet
			verify_well_formed!(path)?
			verify_contains!(path, ["bell_x0007_ and escape _x001B_[0m", "_x005F_x0041_", "unclosed _x005F_x005F_x0007_ stays", "<t xml:space=\"preserve\">  padded  </t>", "windows_x000D_\nline ending"])
		},
	)
}

## Write `bytes` to `path`, run `check!` against it, then delete the file
## whether or not the check passed.
with_file! : Str, List(U8), (Str => Try({}, _)) => Try({}, _)
with_file! = |path, bytes, check!| {
	file = Path.utf8(path)
	Path.write_bytes!(file, bytes)?
	result = check!(path)
	Path.delete!(file)?
	result
}

## `unzip -t` walks every entry and checks its CRC.
verify_zip! : Str => Try({}, _)
verify_zip! = |path| {
	_ = unzip!(["-t", path]) ? |err| ZipIntegrityCheckFailed(path, err)
	Ok({})
}

## The parts every XLSX reader looks for are all listed in the archive.
verify_structure! : Str => Try({}, _)
verify_structure! = |path| {
	listing = unzip!(["-l", path]) ? |err| FailedToListArchive(path, err)
	required = ["[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/_rels/workbook.xml.rels", "xl/worksheets/sheet1.xml"]
	missing = required.keep_if(|part| !listing.contains(part))
	if missing.is_empty() {
		Ok({})
	} else {
		Err(MissingRequiredParts(path, missing))
	}
}

## Every XML part parses. This is what `xmllint --noout` checks, and it is
## strict about the characters XML forbids.
verify_well_formed! : Str => Try({}, _)
verify_well_formed! = |path| {
	parts = ["[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/_rels/workbook.xml.rels", "xl/worksheets/sheet1.xml"]
	_ = parts.map_try!(
		|part| {
			# unzip reads its member argument as a glob, so the brackets need escaping
			member = part.replace_each("[", "\\[").replace_each("]", "\\]")
			xml = unzip!(["-p", path, member]) ? |err| FailedToExtractPart(path, part, err)
			_ = Cmd.new(OsStr.utf8("xmllint")).args_str(["--noout", "-"]).stdin(Bytes(xml.to_utf8())).exec_output!() ? |err| NotWellFormed(path, part, err)
			Ok({})
		},
	)?
	Ok({})
}

## The worksheet, once unzip has inflated it, contains every expected string.
verify_contains! : Str, List(Str) => Try({}, _)
verify_contains! = |path, expected| {
	sheet = unzip!(["-p", path, "xl/worksheets/sheet1.xml"]) ? |err| FailedToExtractSheet(path, err)
	missing = expected.keep_if(|s| !sheet.contains(s))
	if missing.is_empty() {
		Ok({})
	} else {
		Err(MissingExpectedContent(path, missing))
	}
}

## Run unzip with the given arguments and return its stdout.
unzip! : List(Str) => Try(Str, _)
unzip! = |arguments| {
	output = Cmd.new(OsStr.utf8("unzip")).args_str(arguments).exec_output!()?
	Ok(output.stdout_utf8)
}
