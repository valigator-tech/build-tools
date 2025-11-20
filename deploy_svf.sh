#!/usr/bin/env bash
set -euo pipefail

CLUSTER="${1:-}"
TAG="${2:-}"

if [[ "$CLUSTER" == "list" ]]; then
  echo "Available SVF packages for deployment:"
  echo "======================================="
  echo

  #BASE_DIR="/opt/valig-builds"
  BASE_DIR="/home/sol/git/build-tools/work"

  APP_NAME="svf"
  artifact_dir="$BASE_DIR/$APP_NAME/artifacts"

  if [[ -d "$artifact_dir" ]]; then
    # Find all .tar.gz files in this artifacts directory
    packages=()
    while IFS= read -r -d '' file; do
      basename_file=$(basename "$file")
      # Extract tag from filename (e.g., svf-v0.1.10.tar.gz -> v0.1.10)
      tag="${basename_file#$APP_NAME-}"
      tag="${tag%.tar.gz}"
      packages+=("$tag")
    done < <(find "$artifact_dir" -maxdepth 1 -name "$APP_NAME-*.tar.gz" -type f -print0 2>/dev/null | sort -z)

    # Display packages if any found
    if [[ ${#packages[@]} -gt 0 ]]; then
      echo "[$APP_NAME]"
      for tag in "${packages[@]}"; do
        echo "  - $tag"
      done
      echo
    else
      echo "No packages found. Run build_svf.sh first to create packages."
    fi
  else
    echo "No packages found. Run build_svf.sh first to create packages."
  fi

  exit 0
fi

if [[ -z "$CLUSTER" || -z "$TAG" ]]; then
  echo "Usage: $0 <cluster> <tag>" >&2
  echo "  cluster: c000 | c001 | c002 | c003 | t001" >&2
  echo "  tag:     e.g. v0.1.10" >&2
  exit 1
fi

APP_NAME="svf"

#BASE_DIR="/opt/valig-builds"
BASE_DIR="/home/sol/git/build-tools/work"

ARTIFACT_ROOT="$BASE_DIR/$APP_NAME/artifacts"
TARBALL="$ARTIFACT_ROOT/$APP_NAME-$TAG.tar.gz"

REMOTE_RELEASE_ROOT="/home/sol/releases/$APP_NAME"
SSH_USER="${SSH_USER:-}"

CLUSTERS_FILE="$BASE_DIR/clusters.sh"

if [[ ! -f "$CLUSTERS_FILE" ]]; then
  echo "ERROR: clusters file not found: $CLUSTERS_FILE" >&2
  exit 1
fi

# shellcheck source=/opt/valig-hosts/clusters.sh
source "$CLUSTERS_FILE"

# Build variable name like CLUSTER_c000, CLUSTER_t001, etc.
VAR_NAME="CLUSTER_${CLUSTER}"

# Ensure the cluster array exists
if ! declare -p "$VAR_NAME" &>/dev/null; then
  echo "ERROR: unknown cluster '$CLUSTER' (no $VAR_NAME in $CLUSTERS_FILE)" >&2
  exit 1
fi

# Name reference: group_arr refers to CLUSTER_c000 / CLUSTER_t001, etc.
declare -n cluster_arr="$VAR_NAME"

HOSTS=("${cluster_arr[@]}")

if [[ ${#HOSTS[@]} -eq 0 ]]; then
  echo "ERROR: cluster '$CLUSTER' has no hosts defined" >&2
  exit 1
fi

if [[ ! -f "$TARBALL" ]]; then
  echo "ERROR: artifact not found: $TARBALL" >&2
  echo "Did you run build_svf.sh for tag '$TAG'?" >&2
  exit 1
fi

echo ">>> Deploying $APP_NAME tag $TAG to cluster $CLUSTER: ${HOSTS[*]}"
echo ">>> Using artifact: $TARBALL"
echo

# Check if version already exists on any host before deploying
echo "Checking if version already exists on remote hosts..."
version_exists=false
for host in "${HOSTS[@]}"; do
  target="$host"
  if [[ -n "$SSH_USER" ]]; then
    target="$SSH_USER@$host"
  fi

  if ssh "$target" "test -d '$REMOTE_RELEASE_ROOT/$TAG'" 2>/dev/null; then
    echo "ERROR: Version $TAG already exists on $target at $REMOTE_RELEASE_ROOT/$TAG" >&2
    version_exists=true
  fi
done

if [[ "$version_exists" == true ]]; then
  echo >&2
  echo "ERROR: Deployment aborted to prevent overwriting existing version" >&2
  echo "       Remove the existing version on all hosts first, or use a different tag" >&2
  exit 1
fi

echo "Version check passed. Proceeding with deployment..."
echo

for host in "${HOSTS[@]}"; do
  target="$host"
  if [[ -n "$SSH_USER" ]]; then
    target="$SSH_USER@$host"
  fi

  echo "==== Host: $target ===="

  ssh "$target" "mkdir -p '$REMOTE_RELEASE_ROOT'"

  scp "$TARBALL" "$target:/tmp/"

  ssh "$target" "cd '$REMOTE_RELEASE_ROOT' && \
                 tar xzf /tmp/$APP_NAME-$TAG.tar.gz && \
                 rm /tmp/$APP_NAME-$TAG.tar.gz"

  echo
done

echo ">>> Done deploying $APP_NAME $TAG to cluster $CLUSTER"
