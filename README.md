# Validator Build Tools

Build, distribution, and deployment system for Solana validator software with both push-based and pull-based distribution mechanisms.

## Overview

This toolkit manages three application types:

| App | Description | Build Method |
|-----|-------------|--------------|
| **agave** | Solana validator (Anza Agave and forks) | Build from source |
| **ha** | Solana Validator HA (high availability) | Download pre-built binary |
| **svf** | Solana Validator Failover | Download pre-built binary |

### Agave Forks

The `agave` application type supports multiple forks, automatically detected from the version tag:

| Fork | Tag Pattern | Repository |
|------|-------------|------------|
| Vanilla Agave | `v3.0.10` | anza-xyz/agave |
| Jito Solana | `v3.0.10-jito` | jito-foundation/jito-solana |
| BAM Client | `v3.0.10-bam*` | jito-labs/bam-client |
| Harmonic | `v3.0.10-harmonic` | meijilabs/proposer |

## Quick Start

### 1. Build an Artifact

```bash
# Build vanilla Agave
./compile-builds agave v3.1.4

# Build Jito variant (auto-detected from tag)
./compile-builds agave v3.0.10-jito

# Build BAM client (auto-detected from tag)
./compile-builds agave v3.0.10-bam_patch1

# Download HA tool
./compile-builds ha v0.1.7

# Download SVF tool
./compile-builds svf v0.1.12

# List all buildable apps
./compile-builds list
```

### 2. Deploy to Clusters (Push Model)

```bash
# List available artifacts
./deploy-builds list

# List versions for an app
./deploy-builds agave list

# Deploy to a cluster
./deploy-builds agave c000 v3.1.4
./deploy-builds ha c001 v0.1.7
./deploy-builds svf t001 v0.1.12
```

### 3. Deploy via Pull (Ansible Model)

```bash
# Enable artifact server (one-time setup on build server)
./enable-artifact-server.sh

# On validator nodes - pull and install
pull-builds agave v3.1.4
pull-builds ha v0.1.7

# Or use Ansible
cd ansible/
ansible-playbook -i inventory.yml pull-and-deploy.yml \
  -e "app=agave version=v3.1.4 auto_activate=true"
```

### 4. Activate on Validator Nodes

```bash
# List installed versions
./activate-builds agave list
./activate-builds ha list

# Show current active version
./activate-builds agave version

# Activate a specific version
./activate-builds agave v3.1.4
./activate-builds ha v0.1.7
./activate-builds svf v0.1.12
```

## Commands Reference

### compile-builds

Build or download application artifacts.

| Command | Description |
|---------|-------------|
| `compile-builds list` | List all buildable applications |
| `compile-builds agave <tag>` | Build Agave or fork (fork auto-detected from tag pattern) |
| `compile-builds ha <tag>` | Download HA binary from GitHub releases |
| `compile-builds svf <tag>` | Download SVF binary from GitHub releases |

See [Agave Forks](#agave-forks) for tag patterns.

### deploy-builds

Push artifacts to validator clusters via SSH.

| Command | Description |
|---------|-------------|
| `deploy-builds list` | List all apps with available artifacts |
| `deploy-builds <app> list` | List versions for a specific app |
| `deploy-builds <app> <cluster> <tag>` | Deploy to a cluster |

**Available clusters:** c000, c001, c002, c003, t001 (defined in `clusters.sh`)

**Environment variables:**
- `SSH_USER` - Override SSH username (default: current user)

### activate-builds

Manage active versions on validator nodes via symlinks.

| Command | Description |
|---------|-------------|
| `activate-builds list` | List all apps |
| `activate-builds <app> list` | List installed versions |
| `activate-builds <app> version` | Show current active version |
| `activate-builds <app> type` | Show current type (agave variants only) |
| `activate-builds <app> <version>` | Activate a specific version |

**Symlink locations:**
- agave: `/home/sol/releases/active` → version directory
- ha: `/home/sol/releases/solana-validator-ha` → binary
- svf: `/home/sol/releases/solana-validator-failover` → binary

### pull-builds

Pull artifacts from artifact server (for validator nodes).

| Command | Description |
|---------|-------------|
| `pull-builds list` | List all available apps |
| `pull-builds <app> list` | List all versions for an app |
| `pull-builds <app> <version>` | Pull and install specific version |

**Environment variables:**
- `ARTIFACT_SERVER` - Artifact server URL (default: `http://localhost:8080`)

## Architecture

### Push Model (deploy-builds)

```
┌─────────────────────────────────────────────────────┐
│  Build Server                                       │
│  ├─ compile-builds     Build/download artifacts    │
│  ├─ deploy-builds      Push to nodes via SSH       │
│  └─ /var/www/build-artifacts/                      │
└─────────────────────────────────────────────────────┘
                         │ SSH/SCP
                         ▼
┌─────────────────────────────────────────────────────┐
│  Validator Nodes                                    │
│  ├─ /home/sol/releases/<app>/<version>/            │
│  └─ activate-builds    Symlink to active version   │
└─────────────────────────────────────────────────────┘
```

### Pull Model (Ansible)

```
┌─────────────────────────────────────────────────────┐
│  Build/Artifact Server                              │
│  ├─ compile-builds           Build artifacts       │
│  ├─ generate-index.sh        Update artifact index │
│  ├─ enable-artifact-server.sh                      │
│  └─ nginx:8080               Serve over HTTP       │
│      ├─ /index.json                                │
│      └─ /<app>/artifacts/<app>-<version>.tar.gz   │
└─────────────────────────────────────────────────────┘
                         │ HTTP
                         ▼
┌─────────────────────────────────────────────────────┐
│  Validator Nodes                                    │
│  ├─ pull-builds        Download from server        │
│  ├─ /home/sol/releases/<app>/<version>/            │
│  └─ activate-builds    Symlink to active version   │
└─────────────────────────────────────────────────────┘
```

## Directory Structure

```
build-tools/
├── compile-builds                # Unified build script
├── deploy-builds                 # Unified push deployment script
├── activate-builds               # Unified activation script
├── pull-builds                   # Pull script for validator nodes
├── generate-index.sh             # Index generation for artifact server
├── enable-artifact-server.sh     # Enable nginx artifact server
├── disable-artifact-server.sh    # Disable nginx artifact server
├── nginx-artifact-server.conf    # Nginx configuration
├── get-artifact-server-url.sh    # Helper to read ~/.env
├── clusters.sh                   # Cluster host definitions
└── ansible/                      # Ansible playbooks and inventory
    ├── pull-and-deploy.yml       # Main deployment playbook
    ├── inventory.yml             # Sample inventory
    └── README.md                 # Ansible documentation

/var/www/build-artifacts/         # Artifact storage (served by nginx)
├── index.json                    # Artifact index
├── clusters.sh                   # Cluster definitions (deployed copy)
├── src/                          # Source code checkouts
├── agave/
│   ├── artifacts/                # Built tarballs
│   └── releases/                 # Staged release directories
├── bam-client/
├── jito-solana/
├── harmonic/
├── ha/
└── svf/
```

## Artifact Server Setup

### Initial Setup (One-Time)

```bash
# 1. Enable artifact server
./enable-artifact-server.sh

# 2. Verify server is running
curl http://localhost:8080/index.json

# 3. Test artifact download
curl -I http://localhost:8080/agave/artifacts/agave-v3.1.4.tar.gz
```

### Configuration

**Artifact Server URL** is configured in `~/.env`:

```bash
ARTIFACT_SERVER="http://your-build-server:8080"
```

**Priority order:**
1. `ARTIFACT_SERVER` environment variable (highest)
2. `~/.env` file
3. Ansible `-e artifact_server=...` override
4. Default: `http://localhost:8080` (lowest)

## Workflow Examples

### Full Build and Deploy (Pull Model)

```bash
# 1. Build new version
./compile-builds agave v3.1.4

# 2. Deploy to test cluster
ansible-playbook -i ansible/inventory.yml ansible/pull-and-deploy.yml \
  --limit testing \
  -e "version=v3.1.4"

# 3. Verify on test node
ssh validator-t001-01 './activate-builds agave list'

# 4. Deploy to production
ansible-playbook -i ansible/inventory.yml ansible/pull-and-deploy.yml \
  --limit production \
  -e "version=v3.1.4 auto_activate=true"
```

### Emergency Rollback

```bash
ansible-playbook -i ansible/inventory.yml ansible/pull-and-deploy.yml \
  -e "version=v3.1.1 auto_activate=true"
```

### Building Multiple Variants

```bash
./compile-builds agave v3.1.4              # Vanilla Agave
./compile-builds agave v3.1.4-jito         # Jito variant
./compile-builds agave v3.1.4-bam_patch1   # BAM variant

# All now available in index
curl http://localhost:8080/index.json
```

## Troubleshooting

### Artifact Server Issues

```bash
# Check if nginx is running
sudo systemctl status nginx

# Check nginx logs
sudo tail -f /var/log/nginx/artifact-server-*.log

# Restart server
./disable-artifact-server.sh
./enable-artifact-server.sh
```

### Ansible Issues

```bash
# Test connectivity
ansible -i ansible/inventory.yml all -m ping

# Verbose playbook execution
ansible-playbook -i ansible/inventory.yml ansible/pull-and-deploy.yml -vvv
```

### Pull Script Issues

```bash
# Test artifact server connectivity
curl http://build-server:8080/index.json

# Manual pull with debug
ARTIFACT_SERVER=http://build-server:8080 pull-builds agave v3.1.4
```

## Security Considerations

1. **Artifact Server Access**
   - Only accepts GET/HEAD requests
   - Only serves `.tar.gz` files and `index.json`
   - Consider adding authentication for production

2. **SSH Access**
   - Ansible requires SSH key-based authentication
   - Use `ansible-vault` for sensitive inventory data

3. **Network Segmentation**
   - Keep artifact server on internal network
   - Use firewall rules to restrict access
