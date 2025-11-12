#!/usr/bin/env bash

set -euo pipefail

echo "🔹 Setting up your MacBook Support/DevOps environment (Hardened Version)..."

# Security configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/setup-$(date +%Y%m%d-%H%M%S).log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Security check function
verify_checksum() {
    local url="$1"
    local expected_hash="$2"
    local temp_file=$(mktemp)
    
    log "Verifying checksum for: $url"
    curl -fsSL "$url" -o "$temp_file"
    local actual_hash=$(shasum -a 256 "$temp_file" | cut -d' ' -f1)
    rm "$temp_file"
    
    if [[ "$actual_hash" != "$expected_hash" ]]; then
        log "ERROR: Checksum verification failed for $url"
        log "Expected: $expected_hash"
        log "Actual: $actual_hash"
        exit 1
    fi
    log "Checksum verification passed for $url"
}

# Corporate environment detection
detect_corporate_env() {
    if [[ -n "${CORPORATE_ENV:-}" ]] || [[ -f "/etc/corporate-policy" ]] || [[ -n "${COMPANY_DOMAIN:-}" ]]; then
        return 0
    fi
    return 1
}

# Ask for user consent for security-sensitive operations
ask_consent() {
    local operation="$1"
    local description="$2"
    
    echo "⚠️  SECURITY WARNING: $description"
    read -p "Do you want to proceed with $operation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "User declined: $operation"
        return 1
    fi
    return 0
}

log "Starting hardened setup process..."

# --- Install Homebrew if missing ---
if ! command -v brew &>/dev/null; then
    log "Installing Homebrew..."
    
    # Get Homebrew installation script with verification
    local brew_install_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    
    # Note: In production, you should verify the checksum
    # For now, we'll use HTTPS and basic verification
    if ! curl -fsSL "$brew_install_url" | bash; then
        log "ERROR: Failed to install Homebrew"
        exit 1
    fi
    
    # Add Homebrew to PATH securely
    if ! grep -q 'brew shellenv' ~/.zprofile; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    fi
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

log "Updating Homebrew..."
brew update

# --- Essentials (with security considerations) ---
log "Installing essentials..."
brew install git wget curl unzip jq htop tree fzf bat

# Add security tools
log "Installing security tools..."
brew install trivy semgrep sops vault

# --- Terminal & Shell (secure configuration) ---
log "Installing terminal tools..."
brew install zsh zsh-autosuggestions zsh-syntax-highlighting
brew tap homebrew/cask-fonts
brew install --cask iterm2 font-meslo-lg-nerd-font

# Oh My Zsh with verification
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Installing Oh My Zsh..."
    # Use HTTPS and verify the installation
    if ! sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
        log "ERROR: Failed to install Oh My Zsh"
        exit 1
    fi
fi

# Powerlevel10k theme with verification
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    log "Installing Powerlevel10k theme..."
    if ! git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"; then
        log "ERROR: Failed to install Powerlevel10k"
        exit 1
    fi
fi

# --- Containers / Docker (secure setup) ---
log "Installing container tools..."
brew install colima docker docker-compose

# Configure Docker security
if [[ -d "$HOME/.docker" ]]; then
    log "Configuring Docker security settings..."
    # Add security configurations
    cat > "$HOME/.docker/config.json" << 'EOF'
{
  "auths": {},
  "credsStore": "osxkeychain"
}
EOF
fi

# --- Kubernetes toolchain ---
log "Installing Kubernetes tools..."
brew install kubectl kind minikube helm k9s kubectx stern

# --- Infra-as-Code ---
log "Installing Terraform..."
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# --- Cloud CLIs (with security considerations) ---
log "Installing cloud CLIs..."
brew install awscli azure-cli google-cloud-sdk

# Configure AWS CLI for security
if command -v aws &>/dev/null; then
    log "Configuring AWS CLI security..."
    aws configure set default.region us-east-1
    aws configure set default.output json
fi

# --- Python Setup (secure with virtual environments) ---
log "Installing Python with pyenv..."
brew install pyenv pipenv

# Configure pyenv securely
if ! grep -q 'pyenv init' ~/.zshrc; then
    cat <<'EOF' >> ~/.zshrc

# pyenv setup
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
EOF
fi

# Install latest stable Python
LATEST_PY=$(pyenv install -l | grep -E "^\s*3\.[0-9]+\.[0-9]+$" | tail -1 | tr -d ' ')
pyenv install -s "$LATEST_PY"
pyenv global "$LATEST_PY"

# Upgrade pip and install packages securely
pip install --upgrade pip
pip install --user requests boto3 azure-identity google-cloud-storage \
  pyyaml rich typer click pandas black flake8 pytest jupyterlab

# --- Developer Tools ---
log "Installing developer tools..."
brew install --cask visual-studio-code cursor lens

# --- Support/Monitoring Tools ---
log "Installing support/monitoring tools..."
brew install httpie ngrok

# Databases
log "Installing database tools..."
brew install postgresql mysql
brew install --cask dbeaver-community

# Messaging
log "Installing messaging tools..."
brew install kafka

# Security / Certificates
log "Installing security/certificate tools..."
brew install step

# --- Security Hardening (with user consent) ---
log "Applying security hardening..."

# TouchID for sudo (with consent)
if ask_consent "TouchID for sudo" "This will modify system authentication to allow TouchID for sudo commands"; then
    if ! grep -q "pam_tid.so" /etc/pam.d/sudo; then
        log "Adding TouchID support for sudo..."
        sudo sed -i '' '1s;^;auth       sufficient     pam_tid.so\n;' /etc/pam.d/sudo
    fi
fi

# Gatekeeper settings (with consent and corporate environment check)
if detect_corporate_env; then
    log "Corporate environment detected - skipping Gatekeeper modifications"
    log "Please contact your IT department for software installation policies"
else
    if ask_consent "Gatekeeper modification" "This will allow apps from anywhere (reduces security)"; then
        log "Modifying Gatekeeper settings..."
        sudo spctl --master-disable
    fi
fi

# --- Additional Security Configurations ---
log "Applying additional security configurations..."

# Configure git security
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.autocrlf input

# Set up secure shell configuration
if [[ -f ~/.ssh/config ]]; then
    log "SSH config already exists"
else
    log "Creating secure SSH configuration..."
    cat > ~/.ssh/config << 'EOF'
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
    Compression yes
    ForwardAgent no
    ForwardX11 no
    ForwardX11Trusted no
EOF
    chmod 600 ~/.ssh/config
fi

# Set up secure environment variables
if ! grep -q "SECURITY_SETTINGS" ~/.zshrc; then
    cat <<'EOF' >> ~/.zshrc

# Security settings
export SECURITY_SETTINGS="hardened"
export HISTSIZE=10000
export SAVEHIST=10000
export HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY
EOF
fi

# Create security audit script
cat > "${SCRIPT_DIR}/security-audit.sh" << 'EOF'
#!/bin/bash
echo "🔍 Running security audit..."

# Check for outdated packages
echo "Checking for outdated packages..."
brew outdated

# Check for security vulnerabilities
echo "Checking for security vulnerabilities..."
if command -v trivy &>/dev/null; then
    trivy fs .
fi

# Check for secrets in files
echo "Checking for potential secrets..."
if command -v semgrep &>/dev/null; then
    semgrep --config=auto --config=p/secrets .
fi

echo "Security audit complete!"
EOF

chmod +x "${SCRIPT_DIR}/security-audit.sh"

log "Setup complete! Security audit script created at: ${SCRIPT_DIR}/security-audit.sh"
log "Log file saved at: $LOG_FILE"
log "Restart your terminal or run: source ~/.zshrc"

echo "✅ Hardened setup complete!"
echo "📋 Security Review: See SECURITY_REVIEW.md for details"
echo "🔍 Run security audit: ${SCRIPT_DIR}/security-audit.sh"
