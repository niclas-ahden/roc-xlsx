#!/usr/bin/env bash
# Put xmllint, which tests/integration_test.roc drives, on the PATH of a bare
# GitHub runner. The required gate gets it from the flake's dev shell, but the
# per operating system legs run ./tests.roc straight on the runner image.
#
# suite.yml hands this to bash, so it cannot be a .roc script.
set -euo pipefail

case "$(uname -s)" in
  Linux)
    sudo apt-get update -qq
    sudo apt-get install -y -qq libxml2-utils
    command -v xmllint > /dev/null
    ;;
  Darwin)
    # xmllint is on the macOS image already.
    command -v xmllint > /dev/null
    ;;
  *)
    # The Windows image has MSYS2. Its UCRT64 libxml2 is a native xmllint.exe,
    # and the PATH entry takes effect from the next step on.
    /c/msys64/usr/bin/bash.exe -lc "pacman -Sy --noconfirm --needed mingw-w64-ucrt-x86_64-libxml2"
    test -x /c/msys64/ucrt64/bin/xmllint.exe
    echo 'C:\msys64\ucrt64\bin' >> "$GITHUB_PATH"
    ;;
esac

command -v unzip > /dev/null
echo "unzip and xmllint are available"
