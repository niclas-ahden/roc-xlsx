#!/usr/bin/env roc
## All roc-xlsx tests: the package's `expect` blocks, then the integration
## test.
##
## The `expect` blocks in Xlsx.roc cover column lettering, the XML each part
## of the archive is made of, and escaping. tests/integration_test.roc covers
## what those cannot: it writes spreadsheets to disk and hands them to a real
## `unzip`, which verifies the archive and reads the worksheet back. unzip is
## the only external tool, and the flake's dev shell provides it:
##
##     nix develop -c ./tests.roc
app [main!] {
	pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.23.0-rc1/3hT3SoHZ6qbEsa9qVFLUW3547U5LeoNd1KbpqLpz4r1i.tar.zst",
}

import pf.Cmd
import pf.OsStr
import pf.Stdout

main! = |_| {
	Stdout.line!("== unit tests")?
	run!("roc", ["test", "package/main.roc"])?

	Stdout.line!("== integration tests against a real ZIP reader")?
	run!("roc", ["tests/integration_test.roc"])?
	Ok({})
}

# Run a command with inherited stdio, failing the script on a nonzero exit.
run! : Str, List(Str) => Try({}, [Exit(I32), ..])
run! = |program, arguments| {
	Cmd.exec!(OsStr.utf8(program), arguments.map(OsStr.utf8)) ? |_| Exit(1)
	Ok({})
}
