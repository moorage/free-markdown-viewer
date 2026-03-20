#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${0}")/../.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj"
SCHEME_NAME="Swift Markdown Viewer"
BUNDLE_IDENTIFIER="com.matthewpaulmoore.Swift-Markdown-Viewer"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"
XCODEBUILD_DIR="${ARTIFACTS_DIR}/xcodebuild"
TEST_RESULTS_DIR="${ARTIFACTS_DIR}/test-results"
CHECKPOINTS_DIR="${ARTIFACTS_DIR}/checkpoints"
DERIVED_DATA_DIR="${ARTIFACTS_DIR}/DerivedData"
FIXTURE_ROOT="${ROOT_DIR}/Fixtures/docs"
EXPECTED_ROOT="${ROOT_DIR}/Fixtures/expected"

MAC_DESTINATION="platform=macOS,arch=arm64"

ensure_dirs() {
  mkdir -p "${ARTIFACTS_DIR}" "${XCODEBUILD_DIR}" "${TEST_RESULTS_DIR}" "${CHECKPOINTS_DIR}" "${DERIVED_DATA_DIR}"
}

latest_sim_id() {
  local pattern="$1"
  python3 - "${pattern}" <<'PY'
import json
import re
import subprocess
import sys

preferred = re.compile(sys.argv[1])
payload = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "-j", "devices", "available"], text=True))
device_id = None

for runtime in sorted(payload.get("devices", {}).keys()):
    for device in payload["devices"][runtime]:
        if not device.get("isAvailable"):
            continue
        if preferred.search(device.get("name", "")):
            device_id = device.get("udid")

if device_id:
    print(device_id)
PY
}

preferred_sim_id() {
  python3 - "$@" <<'PY'
import json
import subprocess
import sys

preferred_names = sys.argv[1:]
payload = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "-j", "devices", "available"], text=True))
devices_by_runtime = payload.get("devices", {})

for runtime in sorted(devices_by_runtime.keys(), reverse=True):
    devices = [device for device in devices_by_runtime[runtime] if device.get("isAvailable")]
    names_to_ids = {device.get("name"): device.get("udid") for device in devices}
    for name in preferred_names:
        if name in names_to_ids:
            print(names_to_ids[name])
            raise SystemExit(0)
raise SystemExit(1)
PY
}

iphone_sim_id() {
  local id
  id="$(preferred_sim_id \
    "iPhone 17" \
    "iPhone 17 Pro" \
    "iPhone 16e" \
    "iPhone Air" \
    "iPhone 16" \
    "iPhone 15 Pro" \
    "iPhone 15" \
    "iPhone SE (3rd generation)")"
  if [[ -z "${id}" ]]; then
    return 1
  fi
  printf '%s\n' "${id}"
}

ipad_sim_id() {
  local id
  id="$(preferred_sim_id \
    "iPad (A16)" \
    "iPad Air 11-inch (M3)" \
    "iPad Pro 11-inch (M5)" \
    "iPad mini (A17 Pro)" \
    "iPad Pro 11-inch (M4)" \
    "iPad Pro (11-inch) (4th generation)" \
    "iPad Air 11-inch (M2)" \
    "iPad (10th generation)")"
  if [[ -z "${id}" ]]; then
    return 1
  fi
  printf '%s\n' "${id}"
}

result_bundle_path() {
  local name="$1"
  printf '%s/%s.xcresult\n' "${XCODEBUILD_DIR}" "${name}"
}

app_bundle_path() {
  printf '%s/Build/Products/Debug/Swift Markdown Viewer.app\n' "${DERIVED_DATA_DIR}"
}

ios_app_bundle_path() {
  printf '%s/Build/Products/Debug-iphonesimulator/Swift Markdown Viewer.app\n' "${DERIVED_DATA_DIR}"
}

app_binary_path() {
  printf '%s/Contents/MacOS/Swift Markdown Viewer\n' "$(app_bundle_path)"
}

ios_platform_installed() {
  xcodebuild -showdestinations -project "${PROJECT_PATH}" -scheme "${SCHEME_NAME}" 2>/dev/null | grep -q "platform:iOS Simulator"
}

require_project() {
  [[ -d "${PROJECT_PATH}" ]] || {
    echo "Missing project at ${PROJECT_PATH}" >&2
    exit 1
  }
}
