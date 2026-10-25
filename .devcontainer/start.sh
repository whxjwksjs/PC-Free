#!/bin/bash
# PC-Free codespace auto-setup: Windows X-Lite 26H1 (dockurr).
# Runs on codespace create and on every start. Idempotent.
# Log: /tmp/pcfree-start.log
exec >> /tmp/pcfree-start.log 2>&1
set -x
date

# Docker data on the roomy machine disk, not the quota-counted workspace storage
sudo mkdir -p /tmp/docker-data
if ! grep -q "data-root" /etc/docker/daemon.json 2>/dev/null; then
  echo '{"data-root": "/tmp/docker-data"}' | sudo tee /etc/docker/daemon.json
fi

# Repo root (codespaces mount at /workspaces/<repo>)
cd /workspaces/PC-Free 2>/dev/null || cd "$(dirname "$0")/.." || exit 1
pwd

# Wait for the Docker daemon
for i in $(seq 1 30); do
  docker info >/dev/null 2>&1 && break
  sleep 2
done
docker info 2>/dev/null | grep -E "Docker Root Dir|Server Version" || true

# --- Windows X-Lite ISO prep: codespace-side download + extract ---
# (archive.org hosting failed, so the ISO comes from PixelDrain directly.)
XLITE_ISO="./xlite.iso"
XLITE_7Z="./xlite-26h1pro-v2.7z"
XLITE_URL="https://pixeldrain.com/api/file/ZdPxkVmH"
XLITE_7Z_SHA="b10128d189125dfeeef8c20d88dad89c43fd106f4f9c2a389b6f9db1e0005f51"
XLITE_ISO_SIZE=2576439296

need_iso=1
if [ -f "$XLITE_ISO" ]; then
  actual_size=$(stat -c%s "$XLITE_ISO" 2>/dev/null || stat -f%z "$XLITE_ISO" 2>/dev/null)
  if [ "$actual_size" = "$XLITE_ISO_SIZE" ]; then
    echo "xlite.iso already present at expected size, skipping download"
    need_iso=0
  else
    echo "xlite.iso present but wrong size ($actual_size), re-preparing"
    rm -f "$XLITE_ISO"
  fi
fi

if [ "$need_iso" = "1" ]; then
  echo "Downloading X-Lite 7z (resumable)..."
  curl -L -C - -o "$XLITE_7Z" "$XLITE_URL" || exit 1
  echo "Verifying 7z SHA256..."
  actual_sha=$(sha256sum "$XLITE_7Z" | awk '{print $1}')
  if [ "$actual_sha" != "$XLITE_7Z_SHA" ]; then
    echo "SHA256 MISMATCH: got $actual_sha, expected $XLITE_7Z_SHA; deleting download"
    rm -f "$XLITE_7Z"
    exit 1
  fi
  echo "Extracting ISO..."
  rm -rf ./xlite-extract
  mkdir -p ./xlite-extract
  if command -v 7z >/dev/null 2>&1; then
    7z x "$XLITE_7Z" -o./xlite-extract || exit 1
  elif sudo apt-get update && sudo apt-get install -y p7zip-full && command -v 7z >/dev/null 2>&1; then
    7z x "$XLITE_7Z" -o./xlite-extract || exit 1
  else
    python3 -m pip install --user --break-system-externally-managed py7zr 2>/dev/null || python3 -m pip install --user py7zr || exit 1
    python3 -m py7zr x "$XLITE_7Z" -o./xlite-extract || exit 1
  fi
  found_iso=$(find ./xlite-extract -name '*.iso' | head -1)
  if [ -z "$found_iso" ]; then
    echo "No ISO found after extraction"
    exit 1
  fi
  mv "$found_iso" "$XLITE_ISO"
  rm -rf ./xlite-extract
  actual_size=$(stat -c%s "$XLITE_ISO" 2>/dev/null || stat -f%z "$XLITE_ISO" 2>/dev/null)
  if [ "$actual_size" != "$XLITE_ISO_SIZE" ]; then
    echo "Extracted ISO wrong size ($actual_size), aborting"
    rm -f "$XLITE_ISO"
    exit 1
  fi
  echo "xlite.iso ready ($actual_size bytes)"
fi

# Start Windows (first run installs it, ~10-15 min).
# NOTE: windows11.yml binds ./xlite.iso to /custom.iso, so dockurr uses it
# and ignores VERSION. windows10.yml (old Win10 setup) is kept for history
# but is no longer started by this script.
docker compose -f windows11.yml up -d || docker-compose -f windows11.yml up -d || true
docker ps || true
echo "start.sh done"
