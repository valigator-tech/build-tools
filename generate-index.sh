#!/usr/bin/env bash
set -euo pipefail

# Generates index.json file listing all available artifacts
# Output: work/index.json

BASE_DIR="/home/sol/git/build-tools/work"
OUTPUT_FILE="$BASE_DIR/index.json"

# Apps to scan
APPS=("agave" "bam-client" "jito-solana" "harmonic" "ha" "svf")

echo ">>> Generating artifact index..."

# Start JSON structure
echo "{" > "$OUTPUT_FILE"

first_app=true

for app in "${APPS[@]}"; do
  artifact_dir="$BASE_DIR/$app/artifacts"

  if [[ ! -d "$artifact_dir" ]]; then
    continue
  fi

  # Find all tarballs for this app
  versions=()
  while IFS= read -r file; do
    if [[ -f "$file" ]]; then
      basename_file=$(basename "$file")
      # Extract version from filename (e.g., agave-v3.0.10.tar.gz -> v3.0.10)
      version="${basename_file#$app-}"
      version="${version%.tar.gz}"
      versions+=("$version")
    fi
  done < <(find "$artifact_dir" -maxdepth 1 -name "$app-*.tar.gz" -type f 2>/dev/null | sort)

  # Only add to JSON if we found versions
  if [[ ${#versions[@]} -gt 0 ]]; then
    # Add comma before subsequent apps
    if [[ "$first_app" == false ]]; then
      echo "," >> "$OUTPUT_FILE"
    fi
    first_app=false

    # Write app entry
    echo -n "  \"$app\": [" >> "$OUTPUT_FILE"

    first_version=true
    for version in "${versions[@]}"; do
      if [[ "$first_version" == false ]]; then
        echo -n ", " >> "$OUTPUT_FILE"
      fi
      first_version=false
      echo -n "\"$version\"" >> "$OUTPUT_FILE"
    done

    echo -n "]" >> "$OUTPUT_FILE"
  fi
done

# Close JSON structure
echo "" >> "$OUTPUT_FILE"
echo "}" >> "$OUTPUT_FILE"

echo "✓ Index generated: $OUTPUT_FILE"
echo ""
echo "Contents:"
cat "$OUTPUT_FILE"
