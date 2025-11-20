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
TARGET="$ROOT/$VERSION"

# ---- Show current active version (if any) ----
echo "=== Current active SVF ==="

CURRENT_TARGET=""
if [[ -L "$ACTIVE" || -d "$ACTIVE" ]]; then
  CURRENT_TARGET="$(readlink -f "$ACTIVE" || true)"
  echo "solana-validator-failover -> ${CURRENT_TARGET:-$ACTIVE}"

  CURRENT_SVF_BIN="$ACTIVE/bin/solana-validator-failover"
  if [[ -x "$CURRENT_SVF_BIN" ]]; then
    echo
    echo "Current: $CURRENT_SVF_BIN --version"
    echo "--------------------------------------"
    "$CURRENT_SVF_BIN" --version || echo "(failed to run current solana-validator-failover --version)"
    echo "--------------------------------------"
  else
    echo "WARNING: $CURRENT_SVF_BIN not found or not executable"
  fi
else
  echo "No active symlink found at $ACTIVE"
fi

echo

# ---- Inspect requested version without changing anything ----
if [[ ! -d "$TARGET" ]]; then
  echo "ERROR: version directory not found: $TARGET" >&2
  exit 1
fi

NEW_SVF_BIN="$TARGET/bin/solana-validator-failover"
if [[ ! -x "$NEW_SVF_BIN" ]]; then
  echo "ERROR: $NEW_SVF_BIN not found or not executable" >&2
  exit 1
fi

echo "=== Candidate version to activate ==="
echo "Target directory: $TARGET"
echo
echo "Checking: $NEW_SVF_BIN --version"
echo "--------------------------------------"
if ! NEW_VERSION_OUTPUT="$("$NEW_SVF_BIN" --version 2>&1)"; then
  echo "ERROR: solana-validator-failover --version failed for candidate:" >&2
  echo "$NEW_VERSION_OUTPUT" >&2
  echo "No changes made."
  exit 1
fi

echo "$NEW_VERSION_OUTPUT"
echo "--------------------------------------"
echo

# ---- Check if already active ----
if [[ -n "$CURRENT_TARGET" && "$CURRENT_TARGET" == "$TARGET" ]]; then
  echo "ERROR: Version $VERSION is already active" >&2
  echo "       No changes needed."
  exit 1
fi

# ---- Ask user to confirm switch ----
read -r -p "Switch active SVF to $VERSION? [y/N] " REPLY
case "$REPLY" in
  [yY]|[yY][eE][sS])
    echo "Updating active symlink..."
    ln -sfn "$TARGET" "$ACTIVE"
    echo "Done."
    echo "  $ACTIVE -> $(readlink -f "$ACTIVE")"
    ;;
  *)
    echo "Aborted. No changes made."
    exit 1
    ;;
esac
