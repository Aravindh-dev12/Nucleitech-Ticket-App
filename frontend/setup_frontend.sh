#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or is not in PATH." >&2
  exit 1
fi

flutter create --platforms=android,ios,web,windows .
flutter pub get

echo "Frontend platform folders are ready."
echo "Set apiBaseUrl in lib/config.dart, then run: flutter run"
