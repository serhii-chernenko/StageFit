#!/bin/zsh
set -euo pipefail
repo_dir="${0:A:h:h}"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/stagefit-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -framework AppKit -framework ServiceManagement \
  "$repo_dir/Sources/StageFit/LoginItemSettings.swift" "$repo_dir/Tests/main.swift" \
  -o "$test_dir/login-item-tests"
"$test_dir/login-item-tests"
