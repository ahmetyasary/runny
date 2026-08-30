#!/usr/bin/env bash
# Önce iPhone, sonra Watch — Runny simülatör başlatma.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

IPHONE_BUNDLE="${IPHONE_BUNDLE:-com.smartlogy.runny}"
WATCH_BUNDLE="${WATCH_BUNDLE:-com.smartlogy.runny.watchkitapp}"

pick_iphone() {
  # Booted iPhone first, else any available iPhone
  local id
  id="$(xcrun simctl list devices available 2>/dev/null | awk -F '[()]' '/iPhone/ && /Booted/{print $2; exit}')"
  if [[ -z "${id:-}" ]]; then
    id="$(xcrun simctl list devices available 2>/dev/null | awk -F '[()]' '/iPhone/ && /Shutdown/{print $2; exit}')"
  fi
  echo "$id"
}

pick_paired_watch() {
  local phone_id="$1"
  # Prefer watch paired with this phone
  local watch
  watch="$(xcrun simctl list pairs 2>/dev/null | awk -v p="$phone_id" '
    /Watch:/ { w=$0 }
    /Phone:/ {
      if (index($0, p) && w != "") {
        if (match(w, /\(([A-F0-9-]+)\)/)) { print substr(w, RSTART+1, RLENGTH-2); exit }
      }
      w=""
    }
  ')"
  if [[ -z "${watch:-}" ]]; then
    watch="$(xcrun simctl list devices available 2>/dev/null | awk -F '[()]' '/Watch/ && /Booted/{print $2; exit}')"
  fi
  if [[ -z "${watch:-}" ]]; then
    watch="$(xcrun simctl list devices available 2>/dev/null | awk -F '[()]' '/Watch/ && /Shutdown/{print $2; exit}')"
  fi
  echo "$watch"
}

find_phone_app() {
  find "$ROOT/build/ios-sim/Build/Products/Debug-iphonesimulator" \
       "$ROOT/build/ios/iphonesimulator" \
       "$ROOT/build/ios/Debug-iphonesimulator" \
       -name 'Runner.app' -type d 2>/dev/null | head -1
}

find_watch_app() {
  find "$ROOT/build/watch-sim/Build/Products/Debug-watchsimulator" \
       "$ROOT/build/ios/archive" \
       -name 'RunnyWatch.app' -type d 2>/dev/null | head -1
}

echo "==> 1/2 iPhone"
open -a Simulator >/dev/null 2>&1 || true
IPHONE_ID="$(pick_iphone)"
if [[ -z "${IPHONE_ID:-}" ]]; then
  echo "Hata: iPhone simülatör bulunamadı." >&2
  exit 1
fi
xcrun simctl boot "$IPHONE_ID" 2>/dev/null || true
echo "iPhone: $IPHONE_ID"

PHONE_APP="$(find_phone_app || true)"
if [[ -n "${PHONE_APP:-}" && -d "$PHONE_APP" ]]; then
  xcrun simctl install "$IPHONE_ID" "$PHONE_APP"
  xcrun simctl launch "$IPHONE_ID" "$IPHONE_BUNDLE"
  echo "iPhone: kurulu build ile başlatıldı"
else
  echo "iPhone: flutter run başlıyor…"
  # Kısa süre flutter run; kullanıcıya hot reload için arka planda bırakılabilir
  nohup flutter run -d "$IPHONE_ID" > /tmp/runny-iphone-sim.log 2>&1 &
  FLUTTER_PID=$!
  for i in $(seq 1 90); do
    if rg -q "Flutter run key commands|Syncing files to device" /tmp/runny-iphone-sim.log 2>/dev/null; then
      echo "iPhone: Flutter ayağa kalktı (pid $FLUTTER_PID)"
      break
    fi
    if ! kill -0 "$FLUTTER_PID" 2>/dev/null; then
      echo "Hata: flutter run çıktı. Log: /tmp/runny-iphone-sim.log" >&2
      tail -30 /tmp/runny-iphone-sim.log >&2 || true
      exit 1
    fi
    sleep 2
  done
fi

# iPhone UI settle
sleep 2

echo "==> 2/2 Watch"
WATCH_ID="$(pick_paired_watch "$IPHONE_ID")"
if [[ -z "${WATCH_ID:-}" ]]; then
  echo "Uyarı: Watch simülatör bulunamadı; sadece iPhone çalışıyor." >&2
  exit 0
fi
xcrun simctl boot "$WATCH_ID" 2>/dev/null || true
echo "Watch: $WATCH_ID"

WATCH_APP="$(find_watch_app || true)"
if [[ -z "${WATCH_APP:-}" || ! -d "$WATCH_APP" ]]; then
  echo "Watch: build ediliyor…"
  xcodebuild -workspace ios/Runner.xcworkspace -scheme RunnyWatch -configuration Debug \
    -destination "platform=watchOS Simulator,id=$WATCH_ID" \
    -derivedDataPath build/watch-sim \
    CODE_SIGNING_ALLOWED=NO build >/tmp/runny-watch-sim.log 2>&1 \
    || { echo "Hata: Watch build. /tmp/runny-watch-sim.log" >&2; tail -40 /tmp/runny-watch-sim.log >&2; exit 1; }
  WATCH_APP="$(find_watch_app)"
fi

xcrun simctl install "$WATCH_ID" "$WATCH_APP"
xcrun simctl launch "$WATCH_ID" "$WATCH_BUNDLE"
echo "Watch: başlatıldı"
echo "Tamam: iPhone → Watch"
