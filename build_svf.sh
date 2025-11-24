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

# Check if this version is already built
ARTIFACT_PATH="$ARTIFACT_ROOT/$APP_NAME-$TAG.tar.gz"
if [ -f "$ARTIFACT_PATH" ]; then
  echo "ERROR: Version $TAG already exists at $ARTIFACT_PATH" >&2
  echo "If you want to rebuild, delete the artifact first." >&2
  exit 1
fi

# Strip 'v' prefix if present for download URL construction
VERSION="${TAG#v}"

# Check if the release exists and get available assets
echo ">>> Checking if release $TAG exists..."
RELEASE_INFO=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${TAG}")

if echo "$RELEASE_INFO" | grep -q '"message": "Not Found"'; then
  echo "ERROR: Release $TAG not found in repository $GITHUB_REPO" >&2
  echo "" >&2
  echo "Available releases:" >&2
  curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases" | grep '"tag_name"' | cut -d'"' -f4 | head -10 >&2
  exit 1
fi

echo "✓ Release $TAG exists"

# Construct expected filenames
BINARY_FILENAME="solana-validator-failover-${VERSION}-linux-amd64.gz"
CHECKSUM_FILENAME="solana-validator-failover-${VERSION}-linux-amd64.sha256"

# Verify that the specific linux-amd64 assets exist in this release
echo ">>> Verifying required assets exist..."
ASSETS=$(echo "$RELEASE_INFO" | grep '"name"' | cut -d'"' -f4)

if ! echo "$ASSETS" | grep -q "^${BINARY_FILENAME}$"; then
  echo "ERROR: Binary asset not found: $BINARY_FILENAME" >&2
  echo "" >&2
  echo "Available assets for $TAG:" >&2
  echo "$ASSETS" >&2
  exit 1
fi

if ! echo "$ASSETS" | grep -q "^${CHECKSUM_FILENAME}$"; then
  echo "ERROR: Checksum asset not found: $CHECKSUM_FILENAME" >&2
  echo "" >&2
  echo "Available assets for $TAG:" >&2
  echo "$ASSETS" >&2
  exit 1
fi

echo "✓ Required assets found: $BINARY_FILENAME, $CHECKSUM_FILENAME"

# Construct download URLs
BINARY_URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/${BINARY_FILENAME}"
CHECKSUM_URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/${CHECKSUM_FILENAME}"

echo ">>> Downloading release $TAG for linux-amd64"
echo "    Binary URL:   $BINARY_URL"
echo "    Checksum URL: $CHECKSUM_URL"

cd "$DOWNLOAD_DIR"

# Download binary and checksum
echo ">>> Downloading binary..."
if ! curl -f -L -o "$BINARY_FILENAME" "$BINARY_URL"; then
  echo "ERROR: Failed to download binary from $BINARY_URL" >&2
  exit 1
fi

# Verify the downloaded file is actually gzip
if ! file "$BINARY_FILENAME" | grep -q "gzip compressed"; then
  echo "ERROR: Downloaded file is not in gzip format" >&2
  echo "File type: $(file "$BINARY_FILENAME")" >&2
  echo "First 200 bytes:" >&2
  head -c 200 "$BINARY_FILENAME" >&2
  exit 1
fi

echo ">>> Downloading checksum..."
if ! curl -f -L -o "$CHECKSUM_FILENAME" "$CHECKSUM_URL"; then
  echo "ERROR: Failed to download checksum from $CHECKSUM_URL" >&2
  exit 1
fi

# Extract the binary first
echo ">>> Extracting binary..."
gunzip -f "$BINARY_FILENAME"

EXTRACTED_BINARY="solana-validator-failover-${VERSION}-linux-amd64"

if [[ ! -f "$EXTRACTED_BINARY" ]]; then
  echo "ERROR: Expected binary not found: $EXTRACTED_BINARY" >&2
  exit 1
fi

# Verify checksum (checksum file references the extracted binary)
echo ">>> Verifying checksum..."
EXPECTED_HASH=$(cut -d' ' -f1 "$CHECKSUM_FILENAME")
ACTUAL_HASH=$(sha256sum "$EXTRACTED_BINARY" | cut -d' ' -f1)

if [[ "$EXPECTED_HASH" == "$ACTUAL_HASH" ]]; then
  echo "✓ Checksum verification passed"
  echo "  Expected: $EXPECTED_HASH"
  echo "  Actual:   $ACTUAL_HASH"
else
  echo "ERROR: Checksum verification failed!" >&2
  echo "  Expected: $EXPECTED_HASH" >&2
  echo "  Actual:   $ACTUAL_HASH" >&2
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
