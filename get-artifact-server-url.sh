#!/usr/bin/env bash
# Helper script to get the artifact server URL from ~/.env
# Used by Ansible and other tools

if [[ -f "$HOME/.env" ]]; then
  source "$HOME/.env"
fi

echo "${ARTIFACT_SERVER:-http://localhost:8080}"
