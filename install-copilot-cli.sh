#!/usr/bin/env bash
set -euo pipefail

log() { printf '[dotfiles] %s\n' "$*" >&2; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

install_gh_linux() {
  if has_cmd apt-get; then
    log "Installing gh via apt-get..."
    sudo apt-get update -y && sudo apt-get install -y gh || true
  elif has_cmd dnf; then
    log "Installing gh via dnf..."
    sudo dnf install -y gh || true
  elif has_cmd yum; then
    log "Installing gh via yum..."
    sudo yum install -y gh || true
  elif has_cmd zypper; then
    log "Installing gh via zypper..."
    sudo zypper --non-interactive install gh || true
  elif has_cmd apk; then
    log "Installing gh via apk..."
    sudo apk add --no-cache gh || true
  else
    log "No known package manager found for gh install (Linux). Trying manual install..."
    install_gh_manual_linux
  fi
}

install_gh_manual_linux() {
  local arch
  case "$(uname -m)" in
    x86_64) arch="amd64" ;;
    aarch64) arch="arm64" ;;
    *) log "Unsupported architecture: $(uname -m)"; return 1 ;;
  esac
  
  local temp_dir="/tmp/gh-install-$$"
  mkdir -p "$temp_dir"
  
  log "Downloading GitHub CLI for Linux $arch..."
  curl -fsSL "https://github.com/cli/cli/releases/latest/download/gh_*_linux_${arch}.tar.gz" \
    -o "$temp_dir/gh.tar.gz" || return 1
    
  tar -xzf "$temp_dir/gh.tar.gz" -C "$temp_dir" --strip-components=1 || return 1
  
  # Try to install to a location in PATH
  if [[ -w "/usr/local/bin" ]]; then
    cp "$temp_dir/bin/gh" "/usr/local/bin/gh"
    chmod +x "/usr/local/bin/gh"
  elif [[ -w "$HOME/.local/bin" ]]; then
    mkdir -p "$HOME/.local/bin"
    cp "$temp_dir/bin/gh" "$HOME/.local/bin/gh"
    chmod +x "$HOME/.local/bin/gh"
    export PATH="$HOME/.local/bin:$PATH"
  else
    log "No writable directory in PATH found. Please install gh manually."
    return 1
  fi
  
  rm -rf "$temp_dir"
}

install_gh_macos() {
  if has_cmd brew; then
    log "Installing gh via Homebrew..."
    brew install gh || true
  else
    log "Homebrew not found. Installing via manual download..."
    install_gh_manual_macos
  fi
}

install_gh_manual_macos() {
  local arch
  case "$(uname -m)" in
    x86_64) arch="amd64" ;;
    arm64) arch="arm64" ;;
    *) log "Unsupported architecture: $(uname -m)"; return 1 ;;
  esac
  
  local temp_dir="/tmp/gh-install-$$"
  mkdir -p "$temp_dir"
  
  log "Downloading GitHub CLI for macOS $arch..."
  curl -fsSL "https://github.com/cli/cli/releases/latest/download/gh_*_macOS_${arch}.tar.gz" \
    -o "$temp_dir/gh.tar.gz" || return 1
    
  tar -xzf "$temp_dir/gh.tar.gz" -C "$temp_dir" --strip-components=1 || return 1
  
  # Install to /usr/local/bin (standard on macOS)
  if [[ -w "/usr/local/bin" ]]; then
    cp "$temp_dir/bin/gh" "/usr/local/bin/gh"
    chmod +x "/usr/local/bin/gh"
  else
    mkdir -p "$HOME/.local/bin"
    cp "$temp_dir/bin/gh" "$HOME/.local/bin/gh"
    chmod +x "$HOME/.local/bin/gh"
    export PATH="$HOME/.local/bin:$PATH"
  fi
  
  rm -rf "$temp_dir"
}

install_gh_windows() {
  if has_cmd winget; then
    log "Installing gh via winget..."
    winget install --id GitHub.cli -e --source winget || true
  elif has_cmd choco; then
    log "Installing gh via Chocolatey..."
    choco install gh -y || true
  else
    log "No winget/choco found; cannot install gh automatically on Windows."
    log "Please install GitHub CLI manually from: https://cli.github.com/"
  fi
}

ensure_gh() {
  if has_cmd gh; then
    log "gh already installed: $(gh --version | head -1)"
    return 0
  fi

  log "GitHub CLI (gh) not found. Installing..."
  case "$(uname -s)" in
    Linux)  install_gh_linux ;;
    Darwin) install_gh_macos ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT) install_gh_windows ;;
    *) log "Unknown OS: $(uname -s). Skipping gh install." ;;
  esac

  if has_cmd gh; then
    log "gh installed successfully: $(gh --version | head -1)"
  else
    log "gh is still not available; Copilot CLI extension install will be skipped."
  fi
}

install_copilot_cli() {
  if ! has_cmd gh; then
    log "gh not found; cannot install Copilot CLI extension."
    return 0
  fi

  if gh extension list 2>/dev/null | grep -q 'github/gh-copilot'; then
    log "Copilot CLI (gh extension) already installed."
    return 0
  fi

  log "Installing Copilot CLI as gh extension..."
  gh extension install github/gh-copilot || {
    log "Failed to install Copilot CLI extension. You may need to authenticate first."
    return 1
  }

  if gh extension list 2>/dev/null | grep -q 'github/gh-copilot'; then
    log "✓ Copilot CLI installed successfully."
  else
    log "Copilot CLI install did not complete."
  fi
}

check_auth_status() {
  if ! has_cmd gh; then
    return 0
  fi

  if gh auth status >/dev/null 2>&1; then
    log "✓ GitHub CLI is authenticated."
    return 0
  else
    log "GitHub CLI is not authenticated."
    
    # Try to use forwarded SSH agent or environment token
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
      log "Found GITHUB_TOKEN environment variable, attempting to use it..."
      gh auth login --with-token <<< "$GITHUB_TOKEN" 2>/dev/null || {
        log "Failed to authenticate with provided token."
      }
    elif [[ -n "${SSH_AUTH_SOCK:-}" ]] && ssh-add -l >/dev/null 2>&1; then
      log "SSH agent detected, GitHub CLI should work with forwarded credentials."
    else
      log "Run 'gh auth login --web' after this setup completes to sign in."
    fi
    return 1
  fi
}

main() {
  log "Starting Copilot CLI setup..."
  
  ensure_gh
  
  if has_cmd gh; then
    # Try to setup authentication first
    if [[ -f "$(dirname "$0")/setup-github-auth.sh" ]]; then
      source "$(dirname "$0")/setup-github-auth.sh"
    fi
    
    check_auth_status
    install_copilot_cli
    
    log "Setup complete. Available commands:"
    log "  gh --version"
    log "  gh copilot --help"
    log "  gh copilot suggest 'how do I...'"
    log "  gh copilot explain 'command or code'"
  fi

  # Optional: Also install the legacy npm version if preferred
  # if has_cmd npm && ! has_cmd github-copilot-cli; then
  #   log "Installing legacy npm-based Copilot CLI..."
  #   npm install -g @githubnext/github-copilot-cli || true
  # fi
}

main "$@"