# Dotfiles for VS Code Remote Auto-Setup

This repository contains scripts that VS Code Remote can automatically run when connecting to new remote machines.

## Setup Instructions

1. **Create a GitHub repository** for your dotfiles (e.g., `dotfiles` or `vscode-remote-setup`)

2. **Push this folder's contents** to that repository

3. **Configure VS Code Settings** - Add these to your VS Code user settings (`Ctrl+,` → Open Settings JSON):

```json
{
  // Auto-install Copilot CLI via dotfiles on new remotes
  "dotfiles.repository": "https://github.com/YOUR_USERNAME/dotfiles.git",
  "dotfiles.installCommand": "bash install-copilot-cli.sh",
  
  // Auto-install Copilot extensions on remotes
  "remote.SSH.defaultExtensions": [
    "github.copilot",
    "github.copilot-chat"
  ],
  
  // Optional: Run setup command on every connect (use sparingly)
  // "remote.SSH.remoteCommand": "bash -lc '~/.dotfiles/install-copilot-cli.sh || true'"
}
```

4. **Replace `YOUR_USERNAME`** with your actual GitHub username

## What happens on first remote connect

1. VS Code clones your dotfiles repository to `~/.dotfiles` on the remote
2. Runs `install-copilot-cli.sh` which:
   - Installs GitHub CLI (`gh`) using the system package manager
   - Installs the Copilot CLI as a `gh` extension
   - Provides next steps for authentication
3. Installs Copilot and Copilot Chat extensions in the remote VS Code

## Manual verification after setup

```bash
# Check GitHub CLI
gh --version
gh auth status

# Authenticate if needed
gh auth login --web

# Check Copilot CLI
gh extension list
gh copilot --help
gh copilot suggest "how do I find large files in a directory"
```

## Supported systems

- **Linux**: apt, dnf, yum, zypper, apk package managers + manual fallback
- **macOS**: Homebrew + manual fallback  
- **Windows**: winget, Chocolatey (for WSL/Git Bash scenarios)

The script is idempotent - safe to run multiple times.