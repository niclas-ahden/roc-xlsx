app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.23.0/GNN5tt2gKdX4dhawg4915C4YB193woHFdcCkz31fhGxv.tar.zst",
	xlsx: "../package/main.roc",
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
