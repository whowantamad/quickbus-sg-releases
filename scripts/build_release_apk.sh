#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="$REPO_ROOT/flutter_project"
RELEASES_DIR="$REPO_ROOT/releases"

VERSION="$(grep -E '^version:' "$FLUTTER_DIR/pubspec.yaml" | awk '{print $2}')"
echo "Building QuickBus SG v$VERSION (Universal ARM APK)..."

mkdir -p "$RELEASES_DIR"
export TMPDIR="${TMPDIR:-$HOME/.cache/tmp}"
export GRADLE_OPTS="-Djava.io.tmpdir=$TMPDIR"
mkdir -p "$TMPDIR"

cd "$FLUTTER_DIR"
flutter build apk --release --target-platform android-arm,android-arm64 --dart-define-from-file=.env

TARGET_APK="$RELEASES_DIR/quickbus-sg-v$VERSION-arm-universal.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$TARGET_APK"
echo "Copied: $TARGET_APK"

# Retention policy: keep only the 5 most recent APKs in releases/
cd "$RELEASES_DIR"
ls -t *.apk | sed -e '1,5d' | xargs -r rm -f --
echo "Current APKs retained in releases/:"
ls -lh *.apk

