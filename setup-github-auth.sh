#!/usr/bin/env bash
# GitHub Authentication Setup for Remote Machines
# This script helps transfer GitHub authentication to remote machines

log() { printf '[auth-setup] %s\n' "$*" >&2; }

setup_github_token() {
  # Check if GITHUB_TOKEN is already set
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    log "GITHUB_TOKEN already set in environment"
    return 0
  fi

  # Try to get token from various sources
  local token=""
  
  # Method 1: From gh CLI if available locally
  if command -v gh >/dev/null 2>&1; then
    token=$(gh auth token 2>/dev/null || true)
  fi
  
  # Method 2: Check common token storage locations
  if [[ -z "$token" && -f "$HOME/.config/gh/hosts.yml" ]]; then
    # Parse the hosts.yml file for token (basic extraction)
    token=$(grep -A5 "github.com" "$HOME/.config/gh/hosts.yml" | grep "oauth_token" | cut -d'"' -f2 2>/dev/null || true)
  fi
  
  if [[ -n "$token" ]]; then
    log "Found GitHub token, setting up authentication..."
    export GITHUB_TOKEN="$token"
    
    # Persist to shell profile if possible
    for profile in ~/.bashrc ~/.zshrc ~/.profile; do
      if [[ -f "$profile" ]] && ! grep -q "GITHUB_TOKEN" "$profile"; then
        echo "export GITHUB_TOKEN=\"$token\"" >> "$profile"
        log "Added GITHUB_TOKEN to $profile"
        break
      fi
    done
    
    # Try to authenticate gh if installed
    if command -v gh >/dev/null 2>&1; then
      gh auth login --with-token <<< "$token" 2>/dev/null && {
        log "✓ GitHub CLI authenticated successfully"
      }
    fi
  else
    log "No GitHub token found. You'll need to run 'gh auth login --web' manually."
  fi
}

main() {
  log "Setting up GitHub authentication for remote machine..."
  setup_github_token
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi