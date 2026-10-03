app [main!] {
	pf: platform "https://github.com/niclas-ahden/basic-cli/releases/download/0.28.0/AP9SGT1yrhCKcFxKcoA5tBkNCM6ibBjBxcQGMTb6krev.tar.zst",
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
