#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-0.1.0-alpha.1}"
APP_PATH="${APP_PATH:-$ROOT_DIR/build/unsigned/Build/Products/Release/MYTGS.app}"
DIST_DIR="$ROOT_DIR/dist"
WORK_DIR="$ROOT_DIR/build/dmg"
VOLNAME="MYTGS ${VERSION}"
RW_IMAGE="$WORK_DIR/MYTGS-${VERSION}.rw.dmg"
DMG_PATH="$DIST_DIR/MYTGS-${VERSION}-installer.dmg"
MOUNT_DIR=""
BACKGROUND_PATH="$WORK_DIR/background.png"

fail() {
    echo "error: $*" >&2
    exit 1
}

[[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"
command -v hdiutil >/dev/null || fail "hdiutil is required."
command -v osascript >/dev/null || fail "osascript is required."
command -v swift >/dev/null || fail "swift is required."

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

swift - "$BACKGROUND_PATH" <<'SWIFT'
import AppKit

let output = CommandLine.arguments[1]
let size = NSSize(width: 720, height: 440)
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
defer { NSGraphicsContext.restoreGraphicsState() }

let rect = NSRect(origin: .zero, size: size)
NSColor(calibratedWhite: 0.985, alpha: 1).setFill()
rect.fill()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.91, green: 0.96, blue: 1.0, alpha: 1),
    NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 1)
])!
gradient.draw(in: rect, angle: -18)

let topBand = NSBezierPath(roundedRect: NSRect(x: 34, y: 326, width: 652, height: 76), xRadius: 20, yRadius: 20)
NSColor.white.withAlphaComponent(0.72).setFill()
topBand.fill()
NSColor.black.withAlphaComponent(0.08).setStroke()
topBand.lineWidth = 1
topBand.stroke()

let title = "MYTGS"
let subtitle = "Drag MYTGS to Applications"
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

title.draw(
    in: NSRect(x: 0, y: 364, width: size.width, height: 28),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
        .foregroundColor: NSColor.labelColor,
        .paragraphStyle: paragraph
    ]
)

subtitle.draw(
    in: NSRect(x: 0, y: 338, width: size.width, height: 22),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 14, weight: .medium),
        .foregroundColor: NSColor.secondaryLabelColor,
        .paragraphStyle: paragraph
    ]
)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 294, y: 218))
arrow.line(to: NSPoint(x: 426, y: 218))
arrow.lineWidth = 10
arrow.lineCapStyle = .round
NSColor.controlAccentColor.withAlphaComponent(0.88).setStroke()
arrow.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: 426, y: 218))
head.line(to: NSPoint(x: 398, y: 238))
head.move(to: NSPoint(x: 426, y: 218))
head.line(to: NSPoint(x: 398, y: 198))
head.lineWidth = 10
head.lineCapStyle = .round
NSColor.controlAccentColor.withAlphaComponent(0.88).setStroke()
head.stroke()

let leftLabel = "1"
let rightLabel = "2"
for (label, x) in [(leftLabel, 178.0), (rightLabel, 542.0)] {
    let badge = NSBezierPath(ovalIn: NSRect(x: x - 12, y: 106, width: 24, height: 24))
    NSColor.controlAccentColor.withAlphaComponent(0.14).setFill()
    badge.fill()
    label.draw(
        in: NSRect(x: x - 12, y: 109, width: 24, height: 18),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.controlAccentColor,
            .paragraphStyle: paragraph
        ]
    )
}

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to render DMG background")
}

try png.write(to: URL(fileURLWithPath: output))
SWIFT

hdiutil create \
    -size 96m \
    -fs HFS+ \
    -volname "$VOLNAME" \
    -ov \
    "$RW_IMAGE" >/dev/null

ATTACH_OUTPUT="$(hdiutil attach "$RW_IMAGE" -nobrowse)"
MOUNT_DIR="$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F'\t' '/\/Volumes\// {print $NF; exit}')"
[[ -n "$MOUNT_DIR" && -d "$MOUNT_DIR" ]] || fail "Unable to mount temporary DMG."
cleanup() {
    if [[ -n "${MOUNT_DIR:-}" ]] && mount | grep -q "$MOUNT_DIR"; then
        hdiutil detach "$MOUNT_DIR" -quiet || true
    fi
}
trap cleanup EXIT

cp -R "$APP_PATH" "$MOUNT_DIR/MYTGS.app"
ln -s /Applications "$MOUNT_DIR/Applications"
mkdir -p "$MOUNT_DIR/.background"
cp "$BACKGROUND_PATH" "$MOUNT_DIR/.background/background.png"

osascript <<APPLESCRIPT &
tell application "Finder"
    tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {120, 120, 840, 560}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 104
    set background picture of viewOptions to file ".background:background.png"
    set position of item "MYTGS.app" of container window to {180, 224}
    set position of item "Applications" of container window to {540, 224}
    update without registering applications
    delay 1
    close
    end tell
end tell
APPLESCRIPT
OSA_PID=$!
for _ in {1..20}; do
    if ! kill -0 "$OSA_PID" 2>/dev/null; then
        wait "$OSA_PID" || true
        break
    fi
    sleep 0.5
done
if kill -0 "$OSA_PID" 2>/dev/null; then
    kill "$OSA_PID" 2>/dev/null || true
    wait "$OSA_PID" 2>/dev/null || true
fi

SetFile -a V "$MOUNT_DIR/.background" 2>/dev/null || true
sync
hdiutil detach "$MOUNT_DIR" -quiet || hdiutil detach "$MOUNT_DIR" -force
trap - EXIT

rm -f "$DMG_PATH"
hdiutil convert "$RW_IMAGE" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
