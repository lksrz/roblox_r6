#!/usr/bin/env bash
set -euo pipefail

# Fetches all referenced Roblox asset IDs into assets/ReplicatedStorage/Assets
# Sources:
# - InsertService:LoadAsset(<id>)
# - *AssetId / *ModelAssetId assignments
#
# Output files:
# - assets/ReplicatedStorage/Assets/<id>.rbxm (skips if exists)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS_DIR="$ROOT_DIR/assets/ReplicatedStorage/Assets"
mkdir -p "$ASSETS_DIR"

TMP_IDS_FILE="$(mktemp)"
trap 'rm -f "$TMP_IDS_FILE"' EXIT

# Collect IDs from code using ripgrep -> extract numbers via awk
collect_ids() {
  rg -n --no-heading -S -e 'InsertService\s*:\s*LoadAsset\(\s*[0-9]+' "$ROOT_DIR" 2>/dev/null | \
    sed -E 's/.*LoadAsset\([[:space:]]*([0-9]+).*/\1/' || true
  rg -n --no-heading -S -e '\bModelAssetId[[:space:]]*=[[:space:]]*[0-9]+' "$ROOT_DIR" 2>/dev/null | \
    sed -E 's/.*ModelAssetId[[:space:]]*=[[:space:]]*([0-9]+).*/\1/' || true
  rg -n --no-heading -S -e '\bAssetId[[:space:]]*=[[:space:]]*[0-9]+' "$ROOT_DIR" 2>/dev/null | \
    sed -E 's/.*AssetId[[:space:]]*=[[:space:]]*([0-9]+).*/\1/' || true
}

collect_ids | sort -u > "$TMP_IDS_FILE"

if [[ ! -s "$TMP_IDS_FILE" ]]; then
  echo "No asset IDs found in repo. Nothing to fetch."
  exit 0
fi

echo "Detected asset IDs:"
cat "$TMP_IDS_FILE" | tr '\n' ' ' && echo

while IFS= read -r ID; do
  [[ -z "$ID" ]] && continue
  # Skip if any matching file/folder already exists (by ID or friendly name -> handled elsewhere)
  if [[ -e "$ASSETS_DIR/$ID.rbxm" || -e "$ASSETS_DIR/$ID.rbxmx" || -d "$ASSETS_DIR/$ID" ]]; then
    echo "- $ID already present, skipping"
    continue
  fi
  URL="https://assetdelivery.roblox.com/v1/asset?id=$ID"
  OUT="$ASSETS_DIR/$ID.rbxm"
  echo "- Fetching $ID -> $OUT"
  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL "$URL" -o "$OUT"; then
      echo "  ! Failed to fetch $ID from Roblox asset delivery" >&2
      rm -f "$OUT" || true
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -qO "$OUT" "$URL"; then
      echo "  ! Failed to fetch $ID from Roblox asset delivery" >&2
      rm -f "$OUT" || true
    fi
  else
    echo "curl or wget required to fetch assets" >&2
    exit 1
  fi
done < "$TMP_IDS_FILE"

echo "Done. Rojo will sync assets from: $ASSETS_DIR"
