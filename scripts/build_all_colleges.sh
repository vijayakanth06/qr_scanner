#!/usr/bin/env bash
# Usage: bash scripts/build_all_colleges.sh
# Builds one release APK per college defined in COLLEGES array.
# Output: build/outputs/{collegeId}/app-release.apk
set -euo pipefail

COLLEGES=("kec" "psg" "cbe")

for COLLEGE in "${COLLEGES[@]}"; do
  echo ""
  echo "════════════════════════════════════════"
  echo " Building APK for college: $COLLEGE"
  echo "════════════════════════════════════════"

  CONFIG_FILE="assets/configs/${COLLEGE}.json"
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Missing config file: $CONFIG_FILE — skipping $COLLEGE"
    continue
  fi

  flutter build apk \
    --release \
    --dart-define=COLLEGE_ID="$COLLEGE" \
    --build-name="1.0.0" \
    --build-number="$(date +%Y%m%d%H)"

  OUT_DIR="build/outputs/$COLLEGE"
  mkdir -p "$OUT_DIR"
  cp build/app/outputs/flutter-apk/app-release.apk "$OUT_DIR/app-release.apk"
  echo "✓ Saved: $OUT_DIR/app-release.apk"
done

echo ""
echo "All builds complete."
