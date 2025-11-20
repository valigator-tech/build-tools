#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./build_svf.sh v0.1.10
#

TAG="${1:-}"

if [ -z "$TAG" ]; then
  echo "Usage: $0 <tag>  (e.g. v0.1.10)" >&2
  exit 1
fi

APP_NAME="svf"
GITHUB_REPO="SOL-Strategies/solana-validator-failover"

#BASE_DIR="/opt/valig-builds"
BASE_DIR="/home/sol/git/build-tools/work"

# Where we'll stage versioned releases and artifacts
RELEASE_ROOT="$BASE_DIR/$APP_NAME/releases"
ARTIFACT_ROOT="$BASE_DIR/$APP_NAME/artifacts"
DOWNLOAD_DIR="$BASE_DIR/$APP_NAME/downloads"

mkdir -p "$RELEASE_ROOT" "$ARTIFACT_ROOT" "$DOWNLOAD_DIR"

# Strip 'v' prefix if present for download URL construction
VERSION="${TAG#v}"

# Construct download URLs
BINARY_FILENAME="solana-validator-failover-${VERSION}-linux-amd64.gz"
CHECKSUM_FILENAME="solana-validator-failover-${VERSION}-linux-amd64.sha256"
BINARY_URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/${BINARY_FILENAME}"
CHECKSUM_URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/${CHECKSUM_FILENAME}"

echo ">>> Downloading release $TAG for linux-amd64"
echo "    Binary URL:   $BINARY_URL"
echo "    Checksum URL: $CHECKSUM_URL"

cd "$DOWNLOAD_DIR"

# Download binary and checksum
echo ">>> Downloading binary..."
curl -L -o "$BINARY_FILENAME" "$BINARY_URL"

echo ">>> Downloading checksum..."
curl -L -o "$CHECKSUM_FILENAME" "$CHECKSUM_URL"

# Verify checksum
echo ">>> Verifying checksum..."
if sha256sum -c "$CHECKSUM_FILENAME"; then
  echo "✓ Checksum verification passed"
else
  echo "ERROR: Checksum verification failed!" >&2
  exit 1
fi

# Extract the binary
echo ">>> Extracting binary..."
gunzip -f "$BINARY_FILENAME"

EXTRACTED_BINARY="solana-validator-failover-${VERSION}-linux-amd64"

if [[ ! -f "$EXTRACTED_BINARY" ]]; then
  echo "ERROR: Expected binary not found: $EXTRACTED_BINARY" >&2
  exit 1
fi

# Stage into a versioned directory
echo ">>> Staging release"
STAGE_DIR="$RELEASE_ROOT/$TAG"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/bin"

# Copy and rename the binary
cp "$EXTRACTED_BINARY" "$STAGE_DIR/bin/solana-validator-failover"
chmod +x "$STAGE_DIR/bin/solana-validator-failover"

# Get commit hash from GitHub API (best effort)
CI_COMMIT=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/git/ref/tags/${TAG}" | grep -o '"sha": "[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")

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
