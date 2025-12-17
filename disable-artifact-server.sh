#!/usr/bin/env bash
set -euo pipefail

NGINX_ENABLED="/etc/nginx/sites-enabled/artifact-server"

echo ">>> Disabling Artifact Server"
echo ""

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    echo "WARNING: nginx is not installed" >&2
    exit 0
fi

# Check if site is enabled
if [[ ! -L "$NGINX_ENABLED" && ! -f "$NGINX_ENABLED" ]]; then
    echo "✓ Artifact server is already disabled"
    exit 0
fi

# Remove symlink
echo ">>> Removing nginx site configuration..."
sudo rm -f "$NGINX_ENABLED"
echo "✓ Configuration disabled"

# Test nginx configuration
echo ""
echo ">>> Testing nginx configuration..."
if ! sudo nginx -t; then
    echo "ERROR: nginx configuration test failed" >&2
    exit 1
fi
echo "✓ Configuration valid"

# Reload nginx
echo ""
echo ">>> Reloading nginx..."
sudo systemctl reload nginx
echo "✓ nginx reloaded"

echo ""
echo "=========================================="
echo "Artifact Server is now DISABLED"
echo "=========================================="
echo ""
echo "To re-enable: ./enable-artifact-server.sh"
