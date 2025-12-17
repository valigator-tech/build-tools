#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/nginx-artifact-server.conf"
NGINX_AVAILABLE="/etc/nginx/sites-available/artifact-server"
NGINX_ENABLED="/etc/nginx/sites-enabled/artifact-server"

echo ">>> Enabling Artifact Server"
echo ""

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    echo "ERROR: nginx is not installed" >&2
    echo "Install it with: sudo apt-get update && sudo apt-get install nginx" >&2
    exit 1
fi

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

# Generate index.json before enabling
echo ">>> Generating artifact index..."
"$SCRIPT_DIR/generate-index.sh"
echo ""

# Copy config to nginx sites-available (requires sudo)
echo ">>> Installing nginx configuration..."
sudo cp "$CONFIG_FILE" "$NGINX_AVAILABLE"
echo "✓ Config installed to $NGINX_AVAILABLE"

# Create symlink to sites-enabled if it doesn't exist
if [[ -L "$NGINX_ENABLED" || -f "$NGINX_ENABLED" ]]; then
    echo "✓ Config already enabled"
else
    echo ">>> Enabling site..."
    sudo ln -s "$NGINX_AVAILABLE" "$NGINX_ENABLED"
    echo "✓ Config enabled"
fi

# Test nginx configuration
echo ""
echo ">>> Testing nginx configuration..."
if ! sudo nginx -t; then
    echo "ERROR: nginx configuration test failed" >&2
    exit 1
fi
echo "✓ Configuration valid"

# Reload nginx to apply changes
echo ""
echo ">>> Reloading nginx..."
sudo systemctl reload nginx

# Ensure nginx is enabled and started
if ! sudo systemctl is-enabled nginx &> /dev/null; then
    echo ">>> Enabling nginx service..."
    sudo systemctl enable nginx
fi

if ! sudo systemctl is-active nginx &> /dev/null; then
    echo ">>> Starting nginx service..."
    sudo systemctl start nginx
fi

echo "✓ nginx reloaded"
echo ""
echo "=========================================="
echo "Artifact Server is now ENABLED"
echo "=========================================="
echo ""
echo "Server is listening on port 8080"
echo ""
echo "Test URLs:"
echo "  curl http://localhost:8080/index.json"
echo "  curl http://localhost:8080/agave/artifacts/agave-v3.0.10.tar.gz -I"
echo ""
echo "To disable: ./disable-artifact-server.sh"
