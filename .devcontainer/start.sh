#!/bin/bash
# PC-Free codespace auto-setup (added by Muse).
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

# Start Windows (downloads the Windows image on first run, then installs it)
docker compose -f windows10.yml up -d || docker-compose -f windows10.yml up -d || true
docker ps || true
echo "start.sh done"
