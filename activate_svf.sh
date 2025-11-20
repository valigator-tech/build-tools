#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"

BASE_DIR="/home/sol/releases"
APP_NAME="svf"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>" >&2
  echo "  version: e.g. v0.1.10" >&2
  exit 1
fi

if [[ "$VERSION" == "list" ]]; then
  echo "Available SVF versions for activation:"
  echo "======================================"
  echo

  releases_dir="$BASE_DIR/$APP_NAME"

  if [[ -d "$releases_dir" ]]; then
    # Find all version directories (exclude the 'solana-validator-failover' symlink)
    versions=()
    while IFS= read -r -d '' dir; do
      basename_dir=$(basename "$dir")
      # Skip the symlink
      if [[ "$basename_dir" != "solana-validator-failover" ]]; then
        versions+=("$basename_dir")
      fi
    done < <(find "$releases_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

    # Display versions if any found
    if [[ ${#versions[@]} -gt 0 ]]; then
      echo "[$APP_NAME]"
      for version in "${versions[@]}"; do
        echo "  - $version"
      done
      echo
    else
      echo "No versions found. Deploy packages first to create versions."
    fi
  else
    echo "No versions found. Deploy packages first to create versions."
  fi

  exit 0
fi

ROOT="$BASE_DIR/$APP_NAME"
ACTIVE="$BASE_DIR/solana-validator-failover"
VERSION_DIR="$ROOT/$VERSION"
TARGET_BINARY="$VERSION_DIR/bin/solana-validator-failover"

# ---- Show current active version (if any) ----
echo "=== Current active SVF ==="

CURRENT_TARGET=""
if [[ -L "$ACTIVE" ]]; then
  CURRENT_TARGET="$(readlink -f "$ACTIVE" || true)"
  echo "solana-validator-failover -> ${CURRENT_TARGET:-$ACTIVE}"

  if [[ -x "$ACTIVE" ]]; then
    echo
    echo "Current: $ACTIVE --version"
    echo "--------------------------------------"
    "$ACTIVE" --version || echo "(failed to run current solana-validator-failover --version)"
    echo "--------------------------------------"
  else
    echo "WARNING: $ACTIVE not found or not executable"
  fi
elif [[ -e "$ACTIVE" ]]; then
  echo "WARNING: $ACTIVE exists but is not a symlink"
else
  echo "No active symlink found at $ACTIVE"
fi

echo

# ---- Inspect requested version without changing anything ----
if [[ ! -d "$VERSION_DIR" ]]; then
  echo "ERROR: version directory not found: $VERSION_DIR" >&2
  exit 1
fi

if [[ ! -x "$TARGET_BINARY" ]]; then
  echo "ERROR: $TARGET_BINARY not found or not executable" >&2
  exit 1
fi

echo "=== Candidate version to activate ==="
echo "Target binary: $TARGET_BINARY"
echo
echo "Checking: $TARGET_BINARY --version"
echo "--------------------------------------"
if ! NEW_VERSION_OUTPUT="$("$TARGET_BINARY" --version 2>&1)"; then
  echo "ERROR: solana-validator-failover --version failed for candidate:" >&2
  echo "$NEW_VERSION_OUTPUT" >&2
  echo "No changes made."
  exit 1
fi

echo "$NEW_VERSION_OUTPUT"
echo "--------------------------------------"
echo

# ---- Check if already active ----
if [[ -n "$CURRENT_TARGET" && "$CURRENT_TARGET" == "$TARGET_BINARY" ]]; then
  echo "ERROR: Version $VERSION is already active" >&2
  echo "       No changes needed."
  exit 1
fi

# ---- Ask user to confirm switch ----
read -r -p "Switch active SVF to $VERSION? [y/N] " REPLY
case "$REPLY" in
  [yY]|[yY][eE][sS])
    echo "Updating active symlink..."
    ln -sfn "$TARGET_BINARY" "$ACTIVE"
    echo "Done."
    echo "  $ACTIVE -> $(readlink -f "$ACTIVE")"
    ;;
  *)
    echo "Aborted. No changes made."
    exit 1
    ;;
esac
