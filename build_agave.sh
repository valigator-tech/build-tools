#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./build_agave.sh v3.0.10-bam_patch1
#

TAG="${1:-}"

if [ -z "$TAG" ]; then
  echo "Usage: $0 <tag>  (e.g. v3.0.10-bam_patch1)" >&2
  exit 1
fi

if [[ "$TAG" == *"bam"* ]]; then
  echo "Building a BAM client."
  APP_NAME="bam-client"
  REPO_URL="https://github.com/jito-labs/bam-client"

elif [[ "$TAG" == *"jito"* ]]; then
  echo "Building a Agave-Jito client."
  APP_NAME="jito-solana"
  REPO_URL="https://github.com/jito-foundation/jito-solana.git"

elif [[ "$TAG" == *"harmonic"* ]]; then
  echo "Building a Harmonic client."
  APP_NAME="harmonic"
  REPO_URL="git@github.com:meijilabs/proposer.git"

elif [[ $TAG =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Building a vanilla Agave client."
  APP_NAME="agave"
  REPO_URL="https://github.com/anza-xyz/agave.git"


else
  echo "unable to parse supplied tag."
  exit 1
fi

#exit 1

#BASE_DIR="/opt/valig-builds"
BASE_DIR="/var/www/build-artifacts"

# Where we'll stage versioned releases and artifacts
RELEASE_ROOT="$BASE_DIR/$APP_NAME/releases"
ARTIFACT_ROOT="$BASE_DIR/$APP_NAME/artifacts"

# Where the cargo script installs Solana/bam bits
SOLANA_RELEASE_DIR="$HOME/.local/share/solana/install/releases/$TAG"


SRC_BASE="$BASE_DIR/src"
SRC_DIR="$SRC_BASE/$APP_NAME"

mkdir -p "$SRC_BASE" "$RELEASE_ROOT" "$ARTIFACT_ROOT"

# Check if this version is already built
ARTIFACT_PATH="$ARTIFACT_ROOT/$APP_NAME-$TAG.tar.gz"
if [ -f "$ARTIFACT_PATH" ]; then
  echo "ERROR: Version $TAG already exists at $ARTIFACT_PATH" >&2
  echo "If you want to rebuild, delete the artifact first." >&2
  exit 1
fi

echo ">>> Fetching source for tag $TAG"

if [ -d "$SRC_DIR/.git" ]; then
  echo ">>> Repo exists, updating"
  cd "$SRC_DIR"
  # Fix Git ownership issue on shared/mounted directories
  git config --global --add safe.directory "$SRC_DIR"
  git fetch --tags origin
else
  echo ">>> Cloning fresh repo"
  git clone --recurse-submodules "$REPO_URL" "$SRC_DIR"
  cd "$SRC_DIR"
  # Fix Git ownership issue on shared/mounted directories
  git config --global --add safe.directory "$SRC_DIR"
fi

# Clean working tree to avoid cruft
git reset --hard
git clean -fdx

# Checkout the tag you passed in
git checkout "tags/$TAG"
git submodule update --init --recursive

# Build using your existing script
CI_COMMIT=$(git rev-parse HEAD)
echo ">>> Building at commit $CI_COMMIT"

CI_COMMIT="$CI_COMMIT" scripts/cargo-install-all.sh --validator-only "$SOLANA_RELEASE_DIR"

echo ">>> Build complete, staging release"

# Stage into a versioned directory, e.g. /opt/bam/releases/v3.0.10-bam_patch1
STAGE_DIR="$RELEASE_ROOT/$TAG"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/bin"

# Adjust this if the script places binaries somewhere else
cp -a "$SOLANA_RELEASE_DIR"/bin/* "$STAGE_DIR/bin/"

# Optional metadata files
echo "$TAG" > "$STAGE_DIR/TAG"
echo "$CI_COMMIT" > "$STAGE_DIR/COMMIT"
date -u --iso-8601=seconds > "$STAGE_DIR/BUILT_AT"

echo ">>> Creating tarball"

cd "$RELEASE_ROOT"
tar czf "$ARTIFACT_ROOT/$APP_NAME-$TAG.tar.gz" "$TAG"

echo
echo "Done."
echo "Staged directory: $STAGE_DIR"
echo "Artifact:        $ARTIFACT_ROOT/$APP_NAME-$TAG.tar.gz"

# Update artifact index
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPT_DIR/generate-index.sh" ]]; then
  echo ""
  "$SCRIPT_DIR/generate-index.sh"
fi

