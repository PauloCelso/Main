#!/usr/bin/env bash

set -euo pipefail

echo "🔹 Setting up your MacBook Support/DevOps environment..."

# --- Install Homebrew if missing ---
if ! command -v brew &>/dev/null; then
  echo "🍺 Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

brew update

# --- Essentials ---
echo "📦 Installing essentials..."
brew install git wget curl unzip jq htop tree fzf bat

# --- Terminal & Shell ---
echo "💻 Installing iTerm, zsh, and fonts..."
brew install zsh zsh-autosuggestions zsh-syntax-highlighting
brew tap homebrew/cask-fonts
brew install --cask iterm2 font-meslo-lg-nerd-font

# Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "⚡ Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Powerlevel10k theme
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
fi

# --- Containers / Docker ---
echo "🐳 Installing Docker + Colima..."
brew install colima docker docker-compose

# --- Kubernetes toolchain ---
echo "☸️ Installing Kubernetes tools..."
brew install kubectl kind minikube helm k9s kubectx stern

# --- Infra-as-Code ---
echo "🌍 Installing Terraform..."
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# --- Cloud CLIs ---
echo "☁️ Installing cloud CLIs..."
brew install awscli azure-cli google-cloud-sdk

# --- Python Setup ---
echo "🐍 Installing Python with pyenv..."
brew install pyenv pipenv
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

pip install --upgrade pip
pip install requests boto3 azure-identity google-cloud-storage \
  pyyaml rich typer click pandas black flake8 pytest jupyterlab

# --- Developer Tools ---
echo "🛠️ Installing developer tools..."
brew install --cask visual-studio-code cursor lens

# --- Support/Monitoring Tools ---
echo "📊 Installing support/monitoring tools..."
brew install httpie ngrok

# Databases
echo "🗄️ Installing database tools..."
brew install postgresql mysql
brew install --cask dbeaver-community

# Secrets management
echo "🔐 Installing secrets management tools..."
brew install vault sops

# Messaging
echo "📡 Installing messaging tools..."
brew install kafka

# Security / Certificates
echo "🔑 Installing security/certificate tools..."
brew install step

# --- Optional macOS tweaks ---
echo "⚙️ Applying macOS tweaks..."
# Enable TouchID for sudo
if ! grep -q "pam_tid.so" /etc/pam.d/sudo; then
  sudo sed -i '' '1s;^;auth       sufficient     pam_tid.so\n;' /etc/pam.d/sudo
fi

# Allow apps from anywhere (Gatekeeper)
sudo spctl --master-disable

echo "✅ Setup complete! Restart your terminal or run: source ~/.zshrc"
