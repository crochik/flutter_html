#!/bin/bash
# Provisions the Flutter toolchain and resolves the pub workspace so that
# `flutter analyze`, `flutter test` and `dart format` work from the first turn
# of a Claude Code on the web session.
set -euo pipefail

# Local machines are expected to bring their own Flutter install.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Keep in sync with the `revision`/`channel` recorded in .metadata.
FLUTTER_VERSION="3.47.2"
FLUTTER_HOME="${FLUTTER_HOME:-/opt/flutter-sdk}"

log() { echo "[session-start] $*"; }

project_dir() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    echo "$CLAUDE_PROJECT_DIR"
  else
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
  fi
}

install_flutter() {
  local url tmp archive
  url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tmp="$(mktemp -d)"
  archive="$tmp/flutter.tar.xz"

  log "Downloading Flutter ${FLUTTER_VERSION} (this only happens once per container)..."
  curl -fsSL --retry 4 --retry-delay 2 -o "$archive" "$url"

  log "Extracting to ${FLUTTER_HOME}..."
  rm -rf "$FLUTTER_HOME"
  mkdir -p "$FLUTTER_HOME"
  tar -xf "$archive" -C "$FLUTTER_HOME" --strip-components=1
  rm -rf "$tmp"
}

if [ -x "$FLUTTER_HOME/bin/flutter" ] &&
   "$FLUTTER_HOME/bin/flutter" --version 2>/dev/null | grep -q "Flutter ${FLUTTER_VERSION}"; then
  log "Flutter ${FLUTTER_VERSION} is already installed."
else
  install_flutter
fi

export PATH="$FLUTTER_HOME/bin:$PATH"

# The SDK ships as a git checkout whose owner differs from the user running the
# hook; without this git refuses to read it and every flutter command fails.
git config --global --add safe.directory "$FLUTTER_HOME" >/dev/null 2>&1 || true

flutter config --no-analytics >/dev/null 2>&1 || true

# Make the toolchain available to every later command in this session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"${FLUTTER_HOME}/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

cd "$(project_dir)"

# One resolution covers every package: the repo is a Dart pub workspace.
log "Resolving pub workspace..."
flutter pub get

# Warm the web artifacts here so they land in the cached container image rather
# than being downloaded mid-session on the first `flutter build web`.
log "Precaching web artifacts..."
flutter precache --web >/dev/null 2>&1 || log "warning: web precache failed, continuing"

log "Ready: Flutter ${FLUTTER_VERSION}"
