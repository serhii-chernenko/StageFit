#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/stagefit-build.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
dist_dir="$repo_dir/dist"
app_dir="$build_dir/StageFit.app"
binary="$app_dir/Contents/MacOS/StageFit"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$repo_dir/Resources/Info.plist")"
dmg="$dist_dir/StageFit-$version-universal.dmg"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Build on macOS with Xcode Command Line Tools installed." >&2
  exit 1
fi

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources" "$dist_dir"
cp -X "$repo_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"

sdk="$(xcrun --sdk macosx --show-sdk-path)"
source="$repo_dir/Sources/StageFit/main.swift"
frameworks=(-framework AppKit -framework ApplicationServices -framework Carbon -framework ServiceManagement)
for architecture in arm64 x86_64; do
  xcrun swiftc -O -sdk "$sdk" -target "$architecture-apple-macos13.0" \
    "${frameworks[@]}" "$source" -o "$build_dir/StageFit-$architecture"
  if [[ "$architecture" == "$(uname -m)" ]]; then
    "$build_dir/StageFit-$architecture" --self-test
  fi
done
lipo -create "$build_dir/StageFit-arm64" "$build_dir/StageFit-x86_64" -output "$binary"

iconset="$build_dir/StageFit.iconset"
mkdir -p "$iconset"
xcrun swift "$repo_dir/Scripts/make-icon.swift" "$build_dir/icon-1024.png"
for size in 16 32 128 256 512; do
  sips -s format png -z "$size" "$size" "$build_dir/icon-1024.png" \
    --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$(( size * 2 ))
  sips -s format png -z "$double" "$double" "$build_dir/icon-1024.png" \
    --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app_dir/Contents/Resources/StageFit.icns"

# Ad-hoc signing makes the app internally consistent. It is not Developer ID signing.
xattr -cr "$app_dir"
codesign --force --sign - --identifier com.serhiichernenko.stagefit "$app_dir"
codesign --verify --deep --strict "$app_dir"

stage="$build_dir/dmg"
mkdir -p "$stage"
cp -RX "$app_dir" "$stage/StageFit.app"
xattr -cr "$stage/StageFit.app"
codesign --verify --deep --strict "$stage/StageFit.app"
ln -s /Applications "$stage/Applications"
cat > "$stage/READ ME FIRST.txt" <<'TEXT'
1. Drag StageFit.app to Applications.
2. Open StageFit from Applications. If macOS blocks it, follow the README on GitHub
   to use System Settings > Privacy & Security > Open Anyway.
3. Allow StageFit in Privacy & Security > Accessibility.
4. Press Control-Option-F to fit the front window.

StageFit is ad-hoc signed and not notarized. It does not require TestFlight or
an Apple Developer account to build or use.
TEXT

rm -f "$dmg"
hdiutil create -volname "StageFit $version" -srcfolder "$stage" -ov -format UDZO \
  -imagekey zlib-level=9 "$dmg" >/dev/null
shasum -a 256 "$dmg" > "$dist_dir/SHA256SUMS.txt"
echo "Built $dmg"
