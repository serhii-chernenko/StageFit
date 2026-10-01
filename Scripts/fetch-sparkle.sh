#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
version=2.10.0
checksum=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
archive="$repo_dir/.build/Sparkle-$version.tar.xz"
destination="$repo_dir/.build/sparkle-$version"
mkdir -p "$repo_dir/.build"
if [[ ! -f "$archive" ]]; then
  download="$(mktemp "$repo_dir/.build/sparkle-download.XXXXXX")"
  trap 'rm -f "$download"' EXIT
  curl --fail --location --silent --show-error --retry 3 \
    "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz" \
    -o "$download"
  mv "$download" "$archive"
fi
actual="$(shasum -a 256 "$archive")"
if [[ "${actual%% *}" != "$checksum" ]]; then
  echo "Sparkle archive checksum mismatch. Remove $archive and try again." >&2
  exit 1
fi
# Extract the verified archive each time rather than trusting an old framework cache.
rm -rf "$destination"
mkdir -p "$destination"
tar -xJf "$archive" -C "$destination"
echo "$destination"
