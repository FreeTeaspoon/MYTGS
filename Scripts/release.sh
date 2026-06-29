#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/MYTGS.xcodeproj"
SCHEME="MYTGS"
CONFIGURATION="Release"
LOCAL_CONFIG="$ROOT_DIR/Config/Signing.local.xcconfig"
DIST_DIR="$ROOT_DIR/dist"
ARCHIVE_PATH="$ROOT_DIR/build/release/MYTGS.xcarchive"

usage() {
    cat <<'USAGE'
Usage: Scripts/release.sh [preflight|archive|notarize|release]

preflight  Check local signing, Sparkle, and notary prerequisites.
archive    Build a Developer ID signed MYTGS.xcarchive and zip.
notarize   Submit the existing archive zip, staple the app, and verify it.
release    Run preflight, archive, and notarize.
USAGE
}

fail() {
    echo "error: $*" >&2
    exit 1
}

read_xcconfig_value() {
    local key="$1"
    awk -v key="$key" '
        $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
            value = substr($0, index($0, "=") + 1)
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            print value
        }
    ' "$LOCAL_CONFIG" | tail -n 1
}

require_local_config() {
    [[ -f "$LOCAL_CONFIG" ]] || fail "Create Config/Signing.local.xcconfig from Config/Signing.local.xcconfig.example."
}

load_release_config() {
    require_local_config
    TEAM_ID="$(read_xcconfig_value MYTGS_DEVELOPMENT_TEAM)"
    SIGNING_IDENTITY="$(read_xcconfig_value MYTGS_CODE_SIGN_IDENTITY)"
    NOTARY_PROFILE="$(read_xcconfig_value MYTGS_NOTARY_PROFILE)"
    SPARKLE_PUBLIC_KEY="$(read_xcconfig_value MYTGS_SPARKLE_PUBLIC_ED_KEY)"

    [[ -n "${TEAM_ID:-}" ]] || fail "MYTGS_DEVELOPMENT_TEAM is missing in Config/Signing.local.xcconfig."
    [[ -n "${SIGNING_IDENTITY:-}" ]] || fail "MYTGS_CODE_SIGN_IDENTITY is missing in Config/Signing.local.xcconfig."
    [[ -n "${NOTARY_PROFILE:-}" ]] || fail "MYTGS_NOTARY_PROFILE is missing in Config/Signing.local.xcconfig."
    [[ -n "${SPARKLE_PUBLIC_KEY:-}" ]] || fail "MYTGS_SPARKLE_PUBLIC_ED_KEY is missing in Config/Signing.local.xcconfig."
}

preflight() {
    load_release_config
    command -v xcodebuild >/dev/null || fail "xcodebuild was not found. Select full Xcode first."
    command -v xcrun >/dev/null || fail "xcrun was not found. Select full Xcode first."
    security find-identity -v -p codesigning | grep -F "$SIGNING_IDENTITY" >/dev/null \
        || fail "Developer ID identity not found: $SIGNING_IDENTITY"

    xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --team-id "$TEAM_ID" >/dev/null \
        || fail "Notary profile '$NOTARY_PROFILE' is not valid. Store it with xcrun notarytool store-credentials."

    echo "Release prerequisites look ready."
}

version_string() {
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings \
        | awk -F= '/ MARKETING_VERSION = / { gsub(/[[:space:]]/, "", $2); print $2; exit }'
}

build_number() {
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings \
        | awk -F= '/ CURRENT_PROJECT_VERSION = / { gsub(/[[:space:]]/, "", $2); print $2; exit }'
}

archive_app() {
    load_release_config
    mkdir -p "$DIST_DIR" "$(dirname "$ARCHIVE_PATH")"
    rm -rf "$ARCHIVE_PATH"

    xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "generic/platform=macOS" \
        -archivePath "$ARCHIVE_PATH" \
        archive

    local app_path="$ARCHIVE_PATH/Products/Applications/MYTGS.app"
    [[ -d "$app_path" ]] || fail "Archive did not contain MYTGS.app."

    VERSION="$(version_string)"
    BUILD="$(build_number)"
    ZIP_PATH="$DIST_DIR/MYTGS-${VERSION}-${BUILD}.zip"
    rm -f "$ZIP_PATH"
    ditto -c -k --sequesterRsrc --keepParent "$app_path" "$ZIP_PATH"
    echo "Created $ZIP_PATH"
}

notarize_app() {
    load_release_config
    local app_path="$ARCHIVE_PATH/Products/Applications/MYTGS.app"
    [[ -d "$app_path" ]] || fail "Build the archive first with Scripts/release.sh archive."

    VERSION="$(version_string)"
    BUILD="$(build_number)"
    ZIP_PATH="$DIST_DIR/MYTGS-${VERSION}-${BUILD}.zip"
    [[ -f "$ZIP_PATH" ]] || fail "Archive zip not found: $ZIP_PATH"

    xcrun notarytool submit "$ZIP_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --team-id "$TEAM_ID" \
        --wait

    xcrun stapler staple "$app_path"
    spctl --assess --type execute --verbose=4 "$app_path"

    local stapled_zip="$DIST_DIR/MYTGS-${VERSION}-${BUILD}-notarized.zip"
    rm -f "$stapled_zip"
    ditto -c -k --sequesterRsrc --keepParent "$app_path" "$stapled_zip"
    echo "Created $stapled_zip"
}

case "${1:-preflight}" in
    preflight)
        preflight
        ;;
    archive)
        preflight
        archive_app
        ;;
    notarize)
        preflight
        notarize_app
        ;;
    release)
        preflight
        archive_app
        notarize_app
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage
        exit 64
        ;;
esac
