#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"

BASE_DIR="/home/sol/releases"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>" >&2
  echo "  version: e.g. v3.0.10-bam_patch1 | v3.0.10-jito | v3.0.10" >&2
  exit 1
fi

if [[ "$VERSION" == "list" ]]; then
  echo "Available versions for activation:"
  echo "===================================="
  echo

  found_any=false

  # Check each package type
  for app_name in agave bam-client jito-solana; do
    releases_dir="$BASE_DIR/$app_name"

    if [[ -d "$releases_dir" ]]; then
      # Find all version directories (exclude the 'active' symlink)
      versions=()
      while IFS= read -r -d '' dir; do
        basename_dir=$(basename "$dir")
        # Skip the 'active' symlink/directory
        if [[ "$basename_dir" != "active" ]]; then
          versions+=("$basename_dir")
        fi
      done < <(find "$releases_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

      # Display versions if any found
      if [[ ${#versions[@]} -gt 0 ]]; then
        found_any=true
        echo "[$app_name]"
        for version in "${versions[@]}"; do
          echo "  - $version"
        done
        echo
      fi
    fi
  done

  if [[ "$found_any" == false ]]; then
    echo "No versions found. Deploy packages first to create versions."
  fi

  exit 0
fi

# Detect package type from version tag
if [[ "$VERSION" == *"bam"* ]]; then
  APP_NAME="bam-client"
elif [[ "$VERSION" == *"jito"* ]]; then
  APP_NAME="jito-solana"
elif [[ $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  APP_NAME="agave"
else
  echo "ERROR: unable to determine package type from version: $VERSION" >&2
  echo "       Expected formats: v3.0.10-bam_patch1 | v3.0.10-jito | v3.0.10" >&2
  exit 1
fi

ROOT="$BASE_DIR/$APP_NAME"
ACTIVE="$BASE_DIR/active"
TARGET="$ROOT/$VERSION"

# ---- Show current active version (if any) ----
echo "=== Current active $APP_NAME ==="

CURRENT_TARGET=""
if [[ -L "$ACTIVE" || -d "$ACTIVE" ]]; then
  CURRENT_TARGET="$(readlink -f "$ACTIVE" || true)"
  echo "active -> ${CURRENT_TARGET:-$ACTIVE}"

  CURRENT_SOLANA_BIN="$ACTIVE/bin/solana"
  if [[ -x "$CURRENT_SOLANA_BIN" ]]; then
    echo
    echo "Current: $CURRENT_SOLANA_BIN --version"
    echo "--------------------------------------"
    "$CURRENT_SOLANA_BIN" --version || echo "(failed to run current solana --version)"
    echo "--------------------------------------"
  else
    echo "WARNING: $CURRENT_SOLANA_BIN not found or not executable"
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

NEW_SOLANA_BIN="$TARGET/bin/solana"
if [[ ! -x "$NEW_SOLANA_BIN" ]]; then
  echo "ERROR: $NEW_SOLANA_BIN not found or not executable" >&2
  exit 1
fi

echo "=== Candidate version to activate ==="
echo "Target directory: $TARGET"
echo
echo "Checking: $NEW_SOLANA_BIN --version"
echo "--------------------------------------"
if ! NEW_VERSION_OUTPUT="$("$NEW_SOLANA_BIN" --version 2>&1)"; then
  echo "ERROR: solana --version failed for candidate:" >&2
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
read -r -p "Switch active $APP_NAME to $VERSION? [y/N] " REPLY
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

