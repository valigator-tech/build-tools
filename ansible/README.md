# Ansible Playbooks for Validator Deployment

This directory contains Ansible playbooks for pulling and deploying validator builds using the pull-based artifact system.

## Prerequisites

1. **Ansible installed** on your control machine:
   ```bash
   sudo apt-get update && sudo apt-get install ansible
   ```

2. **SSH access** configured to target hosts (via SSH keys)

3. **Artifact server** running and accessible from target hosts

4. **Artifact server URL** configured in `~/.env`

5. **pull-builds script** and config file (automatically copied to targets)

## Quick Start

### 1. Configure Artifact Server

Edit `~/.env` to set your artifact server URL:

```bash
# Add to ~/.env
ARTIFACT_SERVER="http://your-build-server:8080"
```

### 2. Configure Inventory

Edit `inventory.yml` to define your hosts:

```yaml
all:
  vars:
    ansible_user: sol
  children:
    production:
      hosts:
        validator-01:
          ansible_host: 10.0.0.10
```

### 3. Deploy to All Hosts

Use defaults (agave v3.0.10):
```bash
ansible-playbook -i inventory.yml pull-and-deploy.yml
```

### 4. Deploy Specific Version

```bash
ansible-playbook -i inventory.yml pull-and-deploy.yml \
  -e "app=agave version=v3.1.4"
```

### 5. Deploy and Auto-Activate

```bash
ansible-playbook -i inventory.yml pull-and-deploy.yml \
  -e "app=agave version=v3.1.4 auto_activate=true"
```

## Common Usage Patterns

### Deploy to Specific Host Group

```bash
ansible-playbook -i inventory.yml pull-and-deploy.yml \
  --limit cluster_c000
```

### Deploy to Single Host

```bash
ansible-playbook -i inventory.yml pull-and-deploy.yml \
  --limit validator-c000-01
```

### Deploy Different Apps

```bash
# Deploy HA tool
ansible-playbook -i inventory.yml pull-and-deploy.yml \
  -e "app=ha version=v0.1.7"

# Deploy SVF tool
ansible-playbook -i inventory.yml pull-and-deploy.yml \
  -e "app=svf version=v0.1.12"
```

### Check What Would Change (Dry Run)

```bash
ansible-playbook -i inventory.yml pull-and-deploy.yml \
  --check --diff
```

### Parallel Execution

Deploy to multiple hosts in parallel (10 at a time):
```bash
ansible-playbook -i inventory.yml pull-and-deploy.yml \
  -f 10 \
  -e "app=agave version=v3.1.4"
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `app` | `agave` | Application to deploy (agave, ha, svf, etc.) |
| `version` | `v3.0.10` | Version to deploy |
| `artifact_server` | From `~/.env` | Artifact server URL (can override with `-e`) |
| `auto_activate` | `false` | Automatically activate after pulling |
| `pull_builds_path` | `/tmp/pull-builds` | Path to pull-builds script on target |

## Advanced Configuration

### Using ansible-vault for Sensitive Data

Encrypt sensitive inventory data:
```bash
ansible-vault encrypt inventory.yml
ansible-playbook -i inventory.yml pull-and-deploy.yml --ask-vault-pass
```

### Override Artifact Server

**Globally** (edit `~/.env`):
```bash
# In ~/.env
ARTIFACT_SERVER="http://custom-server:8080"
```

**Per playbook run**:
```bash
ansible-playbook -i inventory.yml pull-and-deploy.yml \
  -e "artifact_server=http://custom-server:8080"
```

**Per host/group** (in `inventory.yml`):
```yaml
validator-special:
  ansible_host: 10.0.0.99
  vars:
    artifact_server: http://custom-server:8080
```

### Rolling Updates

Deploy to hosts one at a time:
```bash
ansible-playbook -i inventory.yml pull-and-deploy.yml \
  --serial 1 \
  -e "app=agave version=v3.1.4"
```

## Troubleshooting

### Check Connectivity

```bash
ansible -i inventory.yml all -m ping
```

### Run Ad-Hoc Commands

```bash
# Check installed versions
ansible -i inventory.yml all -a "cd /home/sol/releases && ./activate_agave.sh list"

# Check disk space
ansible -i inventory.yml all -a "df -h /home/sol/releases"
```

### Verbose Output

```bash
ansible-playbook -i inventory.yml pull-and-deploy.yml -v
ansible-playbook -i inventory.yml pull-and-deploy.yml -vvv  # Very verbose
```

## Integration with Existing Scripts

This playbook works alongside your existing scripts:

- **Build**: Still use `build_agave.sh`, `build_ha.sh`, etc. locally
- **Artifact Server**: Managed by `enable-artifact-server.sh` on build server
- **Pull**: Ansible calls `pull-builds` on target hosts
- **Activate**: Use `auto_activate=true` or manually run `activate_agave.sh`

## See Also

- Main build tools documentation: `../README.md`
- Pull-builds script: `../pull-builds`
- Artifact server setup: `../enable-artifact-server.sh`
