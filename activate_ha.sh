#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"

BASE_DIR="/home/sol/releases"
APP_NAME="ha"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>" >&2
  echo "  version: e.g. v0.1.0" >&2
  exit 1
fi

if [[ "$VERSION" == "version" ]]; then
  # Print only the active version (or nothing if no active version)
  ACTIVE="$BASE_DIR/solana-validator-ha"
  if [[ -L "$ACTIVE" ]]; then
    CURRENT_TARGET="$(readlink -f "$ACTIVE" || true)"
    # Extract version from path like /home/sol/releases/ha/v0.1.0/bin/solana-validator-ha
    if [[ "$CURRENT_TARGET" =~ /ha/([^/]+)/ ]]; then
      echo "${BASH_REMATCH[1]}"
    fi
  fi
  exit 0
fi

if [[ "$VERSION" == "list" ]]; then
  # Check for current active version
  ACTIVE="$BASE_DIR/solana-validator-ha"
  CURRENT_VERSION=""
  if [[ -L "$ACTIVE" ]]; then
    CURRENT_TARGET="$(readlink -f "$ACTIVE" || true)"
    # Extract version from path like /home/sol/releases/ha/v0.1.0/bin/solana-validator-ha
    if [[ "$CURRENT_TARGET" =~ /ha/([^/]+)/ ]]; then
      CURRENT_VERSION="${BASH_REMATCH[1]}"
    fi
  fi

  echo "Available HA versions for activation:"
  echo "====================================="
  echo

  releases_dir="$BASE_DIR/$APP_NAME"

  if [[ -d "$releases_dir" ]]; then
    # Find all version directories (exclude the 'solana-validator-ha' symlink)
    versions=()
    while IFS= read -r -d '' dir; do
      basename_dir=$(basename "$dir")
      # Skip the symlink
      if [[ "$basename_dir" != "solana-validator-ha" ]]; then
        versions+=("$basename_dir")
      fi
    done < <(find "$releases_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

    # Display versions if any found
    if [[ ${#versions[@]} -gt 0 ]]; then
      echo "[$APP_NAME]"
      for version in "${versions[@]}"; do
        if [[ -n "$CURRENT_VERSION" && "$version" == "$CURRENT_VERSION" ]]; then
          echo "  - $version (active)"
        else
          echo "  - $version"
        fi
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
ACTIVE="$BASE_DIR/solana-validator-ha"
VERSION_DIR="$ROOT/$VERSION"
TARGET_BINARY="$VERSION_DIR/bin/solana-validator-ha"

# ---- Show current active version (if any) ----
echo "=== Current active HA ==="

CURRENT_TARGET=""
CURRENT_VERSION=""
if [[ -L "$ACTIVE" ]]; then
  CURRENT_TARGET="$(readlink -f "$ACTIVE" || true)"

  # Extract version from path like /home/sol/releases/ha/v0.1.0/bin/solana-validator-ha
  if [[ "$CURRENT_TARGET" =~ /ha/([^/]+)/ ]]; then
    CURRENT_VERSION="${BASH_REMATCH[1]}"
    echo "Active version: $CURRENT_VERSION"
  fi

  echo "solana-validator-ha -> ${CURRENT_TARGET:-$ACTIVE}"

  if [[ -x "$ACTIVE" ]]; then
    echo
    echo "Current: $ACTIVE --version"
    echo "--------------------------------------"
    "$ACTIVE" --version || echo "(failed to run current solana-validator-ha --version)"
    echo "--------------------------------------"
  else
    echo "WARNING: $ACTIVE not found or not executable"
  fi
elif [[ -e "$ACTIVE" ]]; then
  echo "WARNING: $ACTIVE exists but is not a symlink"
else
  echo "No active version"
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
  echo "ERROR: solana-validator-ha --version failed for candidate:" >&2
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
read -r -p "Switch active HA to $VERSION? [y/N] " REPLY
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
