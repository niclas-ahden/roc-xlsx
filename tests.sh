#!/usr/bin/env bash
# Run all tests for roc-xlsx

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

echo "=== roc-xlsx Test Suite ==="
echo

# Track overall status
FAILED=0

# Unit tests (fast, inline expects)
echo "--- Unit Tests ---"
if roc test package/Xlsx.roc; then
    echo
else
    echo "Unit tests FAILED"
    FAILED=1
fi

# Integration tests (creates files, uses unzip)
echo "--- Integration Tests ---"
if roc run test/IntegrationTest.roc; then
    echo
else
    echo "Integration tests FAILED"
    FAILED=1
fi

# Summary
echo "=== Test Suite Complete ==="
if [[ $FAILED -eq 0 ]]; then
    echo "All tests passed!"
else
    echo "Some tests failed."
    exit 1
fi
