# Validator Build Tools

Comprehensive build, distribution, and deployment system for Solana validator software with both push-based (legacy) and pull-based (Ansible-ready) distribution mechanisms.

## Overview

This toolkit supports building and deploying multiple validator-related applications:

- **agave** - Vanilla Anza Agave validator
- **bam-client** - Jito BAM client variant
- **jito-solana** - Jito Solana variant
- **harmonic** - Harmonic proposer variant
- **ha** - High Availability tool
- **svf** - Solana Validator Failover tool

## Architecture

### Build Server (Push Model - Legacy)

```
┌─────────────────────────────────────────────────────┐
│  Build Server                                       │
│  ├─ build_*.sh       Build and create tarballs     │
│  ├─ deploy_*.sh      Push to remote nodes via SSH  │
│  └─ work/            Local artifact storage         │
└─────────────────────────────────────────────────────┘
                         │ SSH/SCP
                         ▼
┌─────────────────────────────────────────────────────┐
│  Validator Nodes                                    │
│  ├─ /home/sol/releases/<app>/<version>/            │
│  └─ activate_*.sh    Symlink to active version      │
└─────────────────────────────────────────────────────┘
```

### Artifact Server (Pull Model - Ansible)

```
┌─────────────────────────────────────────────────────┐
│  Build/Artifact Server                              │
│  ├─ build_*.sh             Build and create tarballs│
│  ├─ generate-index.sh      Update artifact index    │
│  ├─ enable-artifact-server.sh  Start nginx server   │
│  └─ nginx:8080             Serve artifacts over HTTP│
│      ├─ /index.json                                 │
│      └─ /<app>/artifacts/<app>-<version>.tar.gz    │
└─────────────────────────────────────────────────────┘
                         │ HTTP
                         ▼
┌─────────────────────────────────────────────────────┐
│  Validator Nodes (via Ansible)                      │
│  ├─ pull-builds        Download from artifact server│
│  ├─ /home/sol/releases/<app>/<version>/            │
│  └─ activate_*.sh     Symlink to active version     │
└─────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Build an Artifact

```bash
# Build vanilla Agave
./build_agave.sh v3.1.4

# Build Jito variant
./build_agave.sh v3.0.10-jito

# Build HA tool
./build_ha.sh v0.1.7

# Build SVF tool
./build_svf.sh v0.1.12
```

Artifacts are stored in `/var/www/build-artifacts/<app>/artifacts/<app>-<version>.tar.gz`

### 2A. Deploy via Push (Legacy Method)

```bash
# Deploy to cluster c000
./deploy_agave.sh c000 v3.1.4

# List available packages
./deploy_agave.sh list

# Activate on remote node
ssh validator-01 'cd /home/sol/releases && ./activate_agave.sh v3.1.4'
```

### 2B. Deploy via Pull (Ansible Method)

**On Build Server:**

```bash
# Enable artifact server (one-time setup)
./enable-artifact-server.sh

# Builds automatically update index.json
```

**On Control Machine:**

```bash
cd ansible/

# Deploy to all hosts with defaults
ansible-playbook -i inventory.yml pull-and-deploy.yml

# Deploy specific version
ansible-playbook -i inventory.yml pull-and-deploy.yml \
  -e "app=agave version=v3.1.4"

# Deploy and auto-activate
ansible-playbook -i inventory.yml pull-and-deploy.yml \
  -e "app=agave version=v3.1.4 auto_activate=true"

# Deploy to specific cluster
ansible-playbook -i inventory.yml pull-and-deploy.yml \
  --limit cluster_c000 \
  -e "version=v3.1.4"
```

**Manual Pull (on validator node):**

```bash
# List available apps
pull-builds list

# List versions for an app
pull-builds agave list

# Pull and install specific version
pull-builds agave v3.1.4

# Activate
cd /home/sol/releases && ./activate_agave.sh v3.1.4
```

## Components

### Build Scripts

| Script | Purpose |
|--------|---------|
| `build_agave.sh <tag>` | Build Agave and variants (auto-detects from tag) |
| `build_ha.sh <tag>` | Download and package HA tool from GitHub releases |
| `build_svf.sh <tag>` | Download and package SVF tool from GitHub releases |
| `generate-index.sh` | Regenerate artifact index (auto-called by builds) |

### Artifact Server Scripts

| Script | Purpose |
|--------|---------|
| `enable-artifact-server.sh` | Install and start nginx artifact server on port 8080 |
| `disable-artifact-server.sh` | Stop and disable artifact server |
| `nginx-artifact-server.conf` | Nginx configuration for serving artifacts |

### Pull Script

| Command | Description |
|---------|-------------|
| `pull-builds list` | List all available apps |
| `pull-builds <app> list` | List all versions for an app |
| `pull-builds <app> <version>` | Pull and install specific version |

Environment variables:
- `ARTIFACT_SERVER` - Artifact server URL (default: `http://localhost:8080`)

### Legacy Deploy Scripts (Push Model)

| Script | Purpose |
|--------|---------|
| `deploy_agave.sh <cluster> <tag>` | Deploy via SSH to cluster |
| `deploy_agave.sh list` | List available packages |
| `deploy_ha.sh <cluster> <tag>` | Deploy HA tool |
| `deploy_svf.sh <cluster> <tag>` | Deploy SVF tool |

### Activation Scripts (On Validator Nodes)

| Script | Purpose |
|--------|---------|
| `activate_agave.sh <version>` | Switch active Agave version |
| `activate_agave.sh list` | List installed versions |
| `activate_agave.sh version` | Show current active version |
| `activate_agave.sh type` | Show current active app type |

Similar scripts exist for `activate_ha.sh` and `activate_svf.sh`

## Directory Structure

```
build-tools/
├── build_*.sh                    # Build scripts
├── deploy_*.sh                   # Legacy push deployment scripts
├── generate-index.sh             # Index generation for artifact server
├── enable-artifact-server.sh     # Enable nginx artifact server
├── disable-artifact-server.sh    # Disable nginx artifact server
├── nginx-artifact-server.conf    # Nginx configuration
├── get-artifact-server-url.sh    # Helper to read ~/.env (used by Ansible)
├── pull-builds                   # Pull script for validator nodes
├── ansible/                      # Ansible playbooks and inventory
│   ├── pull-and-deploy.yml      # Main deployment playbook
│   ├── inventory.yml            # Sample inventory
│   └── README.md                # Ansible documentation
└── work/                        # Local source code checkouts

/var/www/build-artifacts/        # Artifact storage (served by nginx)
├── index.json                   # Artifact index for pull system
├── agave/
│   ├── artifacts/               # Built tarballs
│   └── releases/                # Staged release directories
├── bam-client/
├── jito-solana/
├── harmonic/
├── ha/
└── svf/
```

## Artifact Server Setup

### Initial Setup (One-Time)

```bash
# 1. Generate initial index
./generate-index.sh

# 2. Enable artifact server
./enable-artifact-server.sh

# 3. Verify server is running
curl http://localhost:8080/index.json

# 4. Test artifact download
curl -I http://localhost:8080/agave/artifacts/agave-v3.1.4.tar.gz
```

### Configuration

**Artifact Server URL** is configured in `~/.env`:

```bash
# Edit ~/.env
vim ~/.env

# Add or update the ARTIFACT_SERVER variable
ARTIFACT_SERVER="http://your-build-server:8080"
```

This configuration is automatically used by:
- `pull-builds` script (sources `~/.env`)
- Ansible playbooks (via `get-artifact-server-url.sh`)
- All other tools

**Priority order:**
1. `ARTIFACT_SERVER` environment variable already set (highest)
2. `~/.env` file
3. Ansible `-e artifact_server=...` override
4. Default: `http://localhost:8080` (lowest)

**Port configuration:** Edit `nginx-artifact-server.conf` line 5:
```nginx
listen 8080;  # Change to desired port
```

### Firewall Configuration

Ensure target validator nodes can access the artifact server:

```bash
# On artifact server
sudo ufw allow 8080/tcp

# Test from validator node
curl http://build-server:8080/index.json
```

## Migration from Push to Pull

To migrate from the legacy push model to the Ansible pull model:

1. **Enable artifact server** on your build machine:
   ```bash
   ./enable-artifact-server.sh
   ```

2. **Deploy pull-builds script** to validator nodes:
   ```bash
   # Copy to nodes (one-time)
   for host in $(cat clusters.sh | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+'); do
     scp pull-builds sol@$host:/usr/local/bin/
   done
   ```

3. **Set up Ansible inventory** in `ansible/inventory.yml`

4. **Test with one node:**
   ```bash
   ansible-playbook -i ansible/inventory.yml ansible/pull-and-deploy.yml \
     --limit validator-01 \
     -e "app=agave version=v3.1.4"
   ```

5. **Roll out to clusters** as needed

The legacy push scripts (`deploy_*.sh`) remain available for manual deployments.

## Workflow Examples

### Full Build and Deploy Workflow (Pull Model)

```bash
# 1. Build new version
./build_agave.sh v3.1.4
# (Automatically updates index.json)

# 2. Deploy to test cluster
ansible-playbook -i ansible/inventory.yml ansible/pull-and-deploy.yml \
  --limit testing \
  -e "version=v3.1.4"

# 3. Verify on test node
ssh validator-t001-01 'cd /home/sol/releases && ./activate_agave.sh list'

# 4. Deploy to production (10 nodes at a time, rolling)
ansible-playbook -i ansible/inventory.yml ansible/pull-and-deploy.yml \
  --limit production \
  -f 10 \
  -e "version=v3.1.4"

# 5. Activate on production (after verification)
ansible-playbook -i ansible/inventory.yml ansible/pull-and-deploy.yml \
  --limit production \
  -e "version=v3.1.4 auto_activate=true"
```

### Emergency Rollback

```bash
# Quick rollback to previous version
ansible-playbook -i ansible/inventory.yml ansible/pull-and-deploy.yml \
  -e "version=v3.1.1 auto_activate=true"
```

### Building Multiple Variants

```bash
# Build all variants of a base version
./build_agave.sh v3.1.4           # Vanilla Agave
./build_agave.sh v3.1.4-jito      # Jito variant
./build_agave.sh v3.1.4-bam_patch1  # BAM variant

# All are now available in index
curl http://localhost:8080/index.json
```

## Troubleshooting

### Artifact Server Issues

```bash
# Check if nginx is running
sudo systemctl status nginx

# Check nginx logs
sudo tail -f /var/log/nginx/artifact-server-*.log

# Test configuration
sudo nginx -t

# Restart server
./disable-artifact-server.sh
./enable-artifact-server.sh
```

### Ansible Issues

```bash
# Test connectivity
ansible -i ansible/inventory.yml all -m ping

# Check inventory
ansible-inventory -i ansible/inventory.yml --list

# Verbose playbook execution
ansible-playbook -i ansible/inventory.yml ansible/pull-and-deploy.yml -vvv
```

### Pull Script Issues

```bash
# Test artifact server connectivity
curl http://build-server:8080/index.json

# Manual pull with verbose curl
ARTIFACT_SERVER=http://build-server:8080 pull-builds agave v3.1.4

# Check downloaded artifact
tar -tzf /tmp/agave-v3.1.4.tar.gz | head
```

## Security Considerations

1. **Artifact Server Access**
   - Configured to only accept GET/HEAD requests
   - Only serves `.tar.gz` files and `index.json`
   - Consider adding authentication for production use

2. **SSH Access**
   - Ansible requires SSH key-based authentication
   - Use `ansible-vault` for sensitive inventory data

3. **Network Segmentation**
   - Keep artifact server on internal network
   - Use firewall rules to restrict access

## Contributing

When adding new tools or modifying the system:

1. Update build scripts to follow the pattern in `build_agave.sh`
2. Ensure `generate-index.sh` includes your new app in the APPS array
3. Test both push and pull deployment methods
4. Update this README with new tools or usage patterns

## License

[Your License Here]
