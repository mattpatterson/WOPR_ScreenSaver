#!/bin/zsh
# Builds WOPR.saver (universal), the preview app and the offscreen render tool.
#   ./build.sh            build everything into ./build
#   ./build.sh install    also copy WOPR.saver to ~/Library/Screen Savers
#   ./build.sh dist       also package dist/WOPR-ScreenSaver-<version>.zip for a GitHub release
set -e
cd "${0:A:h}"
BUILD=build
mkdir -p $BUILD
SRC=(Sources/*.swift)
FLAGS=(-O -swift-version 5)
# CLT on this Mac once shipped a duplicate SwiftBridging modulemap; work around it if it's still there.
BRIDGE=/Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap
if [[ -f $BRIDGE && "$(xcode-select -p)" == *CommandLineTools* ]]; then
  : > $BUILD/empty.modulemap
  cat > $BUILD/overlay.yaml <<YAML
{ "version": 0, "roots": [ { "type": "file", "name": "$BRIDGE", "external-contents": "$PWD/$BUILD/empty.modulemap" } ] }
YAML
  FLAGS+=(-vfsoverlay $BUILD/overlay.yaml -Xcc -ivfsoverlay -Xcc $BUILD/overlay.yaml)
fi

echo "==> WOPR.saver"
SAVER=$BUILD/WOPR.saver
rm -rf $SAVER
mkdir -p $SAVER/Contents/MacOS $SAVER/Contents/Resources
for arch in arm64 x86_64; do
  swiftc $FLAGS -target $arch-apple-macos13.0 -module-name WOPR -parse-as-library \
    -Xlinker -bundle -framework ScreenSaver -framework AppKit \
    $SRC -o $BUILD/WOPR-$arch
done
lipo -create $BUILD/WOPR-arm64 $BUILD/WOPR-x86_64 -output $SAVER/Contents/MacOS/WOPR
cp Resources/Info.plist $SAVER/Contents/Info.plist
[[ -f Resources/thumbnail.png ]] && cp Resources/thumbnail*.png $SAVER/Contents/Resources/
codesign --force --sign - $SAVER

echo "==> WOPR Preview.app"
APP="$BUILD/WOPR Preview.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc $FLAGS -module-name WOPRPreview -framework ScreenSaver -framework AppKit $SRC tools/Preview/main.swift -o "$APP/Contents/MacOS/WOPR Preview"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>WOPR Preview</string>
<key>CFBundleIdentifier</key><string>local.wopr.preview</string>
<key>CFBundleName</key><string>WOPR Preview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"

echo "==> render tool"
swiftc $FLAGS -module-name WOPRRender $SRC tools/Render/main.swift -o $BUILD/render

if [[ "$1" == "install" ]]; then
  mkdir -p ~/Library/Screen\ Savers
  rm -rf ~/Library/Screen\ Savers/WOPR.saver
  cp -R $SAVER ~/Library/Screen\ Savers/
  echo "Installed to ~/Library/Screen Savers/WOPR.saver"
fi
if [[ "$1" == "dist" ]]; then
  VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
  mkdir -p dist
  ZIP=dist/WOPR-ScreenSaver-$VERSION.zip
  rm -f $ZIP
  ditto -c -k --norsrc --keepParent $SAVER $ZIP
  shasum -a 256 $ZIP
  echo "Packaged $ZIP"
fi
echo "done"
