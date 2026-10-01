#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$repo_dir/Resources/Info.plist")"
account=com.serhiichernenko.stagefit
sparkle_dir="$("$repo_dir/Scripts/fetch-sparkle.sh")"
expected_key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$repo_dir/Resources/Info.plist")"
actual_key="$("$sparkle_dir/bin/generate_keys" --account "$account" -p)"
if [[ "$actual_key" != "$expected_key" ]]; then
  echo "The StageFit update signing key is missing or does not match Info.plist." >&2
  exit 1
fi

"$repo_dir/Scripts/build-dmg.sh"
release_dir="$(mktemp -d "${TMPDIR:-/tmp}/stagefit-release.XXXXXX")"
trap 'rm -rf "$release_dir"' EXIT
archive="StageFit-$version-universal.zip"
cp "$repo_dir/dist/$archive" "$release_dir/$archive"
cp "$repo_dir/Resources/ReleaseNotes.html" "$release_dir/${archive:r}.html"
"$sparkle_dir/bin/generate_appcast" --account "$account" --maximum-deltas 0 \
  --download-url-prefix "https://github.com/serhii-chernenko/StageFit/releases/download/v$version/" \
  --link "https://github.com/serhii-chernenko/StageFit" --embed-release-notes "$release_dir"
"$sparkle_dir/bin/sign_update" --account "$account" --verify "$release_dir/appcast.xml"
cp "$release_dir/appcast.xml" "$repo_dir/dist/appcast.xml"
(cd "$repo_dir/dist" && shasum -a 256 "StageFit-$version-universal.dmg" "$archive" appcast.xml > SHA256SUMS.txt)
echo "Signed release $version ready in dist/. Upload the DMG, ZIP, appcast.xml and SHA256SUMS.txt together."
