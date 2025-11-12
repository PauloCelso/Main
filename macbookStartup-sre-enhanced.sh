#!/usr/bin/env bash

set -euo pipefail

echo "🔹 Setting up your MacBook SRE/DevOps environment (Enhanced Version)..."

# Security configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/sre-setup-$(date +%Y%m%d-%H%M%S).log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Starting SRE-enhanced setup process..."

# --- Install Homebrew if missing ---
if ! command -v brew &>/dev/null; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

brew update

# --- Essentials ---
log "Installing essentials..."
brew install git wget curl unzip jq htop tree fzf bat

# --- Terminal & Shell ---
log "Installing terminal tools..."
brew install zsh zsh-autosuggestions zsh-syntax-highlighting
brew tap homebrew/cask-fonts
brew install --cask iterm2 font-meslo-lg-nerd-font

# Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Powerlevel10k theme
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
fi

# --- Containers / Docker ---
log "Installing container tools..."
brew install colima docker docker-compose

# --- Kubernetes toolchain ---
log "Installing Kubernetes tools..."
brew install kubectl kind minikube helm k9s kubectx stern

# Advanced Kubernetes tools for SRE
log "Installing advanced Kubernetes tools..."
brew install kubeval kube-score
brew install kube-hunter kube-bench

# --- Infra-as-Code ---
log "Installing Infrastructure as Code tools..."
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew install ansible

# --- Cloud CLIs ---
log "Installing cloud CLIs..."
brew install awscli azure-cli google-cloud-sdk

# --- Python Setup ---
log "Installing Python with pyenv..."
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

# --- SRE Monitoring & Observability ---
log "Installing SRE monitoring tools..."
brew install prometheus grafana
brew install jaeger-tracing
brew install --cask datadog-agent

# Log management
log "Installing log management tools..."
brew install elasticsearch kibana
brew install fluentd

# --- Incident Management ---
log "Installing incident management tools..."
brew install --cask pagerduty-cli
brew install alertmanager

# --- Performance & Load Testing ---
log "Installing performance testing tools..."
brew install k6 artillery
brew install wrk

# --- Chaos Engineering ---
log "Installing chaos engineering tools..."
brew install chaos-mesh
brew install litmus

# --- Network & Security Tools ---
log "Installing network and security tools..."
brew install nmap wireshark
brew install tcpdump netcat
brew install trivy semgrep

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

# Secrets management
log "Installing secrets management tools..."
brew install vault sops

# Messaging
log "Installing messaging tools..."
brew install kafka

# Security / Certificates
log "Installing security/certificate tools..."
brew install step

# --- SRE-Specific Configurations ---
log "Configuring SRE-specific settings..."

# Create SRE workspace
mkdir -p ~/sre-workspace/{monitoring,incidents,chaos,performance}
mkdir -p ~/sre-workspace/{runbooks,playbooks,scripts}

# Set up monitoring configuration
cat > ~/sre-workspace/monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

# Set up Grafana datasource
cat > ~/sre-workspace/monitoring/grafana-datasource.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
EOF

# Create SRE aliases
cat >> ~/.zshrc << 'EOF'

# SRE Aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias kx='kubectl exec -it'

# Monitoring aliases
alias prom='prometheus --config.file=~/sre-workspace/monitoring/prometheus.yml'
alias graf='grafana-server --config=~/sre-workspace/monitoring/grafana.ini'

# Performance testing aliases
alias loadtest='k6 run'
alias artillery-test='artillery run'

# Chaos engineering aliases
alias chaos='chaos-mesh'
alias litmus-test='litmus'

# Security aliases
alias vuln-scan='trivy image'
alias secret-scan='semgrep --config=auto --config=p/secrets'

# Network debugging aliases
alias netstat='netstat -tulpn'
alias ports='lsof -i -P -n | grep LISTEN'
alias trace='traceroute'

# SRE workspace navigation
alias sre='cd ~/sre-workspace'
alias monitoring='cd ~/sre-workspace/monitoring'
alias incidents='cd ~/sre-workspace/incidents'
alias chaos='cd ~/sre-workspace/chaos'
alias performance='cd ~/sre-workspace/performance'
EOF

# Create SRE runbook template
cat > ~/sre-workspace/runbooks/incident-response.md << 'EOF'
# Incident Response Runbook

## 1. Initial Response
- [ ] Acknowledge the incident
- [ ] Assess severity (P1-P4)
- [ ] Notify stakeholders
- [ ] Create incident channel

## 2. Investigation
- [ ] Check monitoring dashboards
- [ ] Review logs
- [ ] Check recent deployments
- [ ] Identify root cause

## 3. Resolution
- [ ] Implement fix
- [ ] Verify resolution
- [ ] Monitor for stability
- [ ] Update stakeholders

## 4. Post-Incident
- [ ] Document lessons learned
- [ ] Update runbooks
- [ ] Schedule post-mortem
- [ ] Implement preventive measures
EOF

# Create chaos engineering playbook
cat > ~/sre-workspace/chaos/chaos-playbook.md << 'EOF'
# Chaos Engineering Playbook

## Network Chaos
- Network latency injection
- Network partition simulation
- DNS resolution failures

## Pod Chaos
- Pod failure injection
- Resource exhaustion
- Pod deletion

## Node Chaos
- Node failure simulation
- CPU stress testing
- Memory pressure testing

## Application Chaos
- Service degradation
- Database connection failures
- External service failures
EOF

# Create performance testing scripts
cat > ~/sre-workspace/performance/load-test.js << 'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 200 },
    { duration: '5m', target: 200 },
    { duration: '2m', target: 0 },
  ],
};

export default function () {
  let response = http.get('https://httpbin.org/');
  check(response, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}
EOF

# Create security scanning script
cat > ~/sre-workspace/scripts/security-scan.sh << 'EOF'
#!/bin/bash
echo "🔍 Running comprehensive security scan..."

# Container image scanning
echo "Scanning container images..."
trivy image --severity HIGH,CRITICAL nginx:latest

# Secret scanning
echo "Scanning for secrets..."
semgrep --config=auto --config=p/secrets .

# Kubernetes security scanning
echo "Scanning Kubernetes configurations..."
kube-hunter --remote some.internal.nonexistent

# Network scanning
echo "Scanning network ports..."
nmap -sV -O localhost

echo "Security scan complete!"
EOF

chmod +x ~/sre-workspace/scripts/security-scan.sh

# Create SRE dashboard setup script
cat > ~/sre-workspace/scripts/setup-dashboards.sh << 'EOF'
#!/bin/bash
echo "📊 Setting up SRE dashboards..."

# Start Prometheus
prometheus --config.file=~/sre-workspace/monitoring/prometheus.yml &
PROM_PID=$!

# Start Grafana
grafana-server --config=~/sre-workspace/monitoring/grafana.ini &
GRAF_PID=$!

echo "Prometheus PID: $PROM_PID"
echo "Grafana PID: $GRAF_PID"
echo "Prometheus: http://localhost:9090"
echo "Grafana: http://localhost:3000 (admin/admin)"
EOF

chmod +x ~/sre-workspace/scripts/setup-dashboards.sh

# Create SRE health check script
cat > ~/sre-workspace/scripts/health-check.sh << 'EOF'
#!/bin/bash
echo "🏥 Running SRE health checks..."

# Check Kubernetes cluster health
echo "Kubernetes cluster health:"
kubectl get nodes
kubectl get pods --all-namespaces

# Check system resources
echo "System resources:"
htop -n 1

# Check network connectivity
echo "Network connectivity:"
ping -c 3 google.com

# Check service endpoints
echo "Service endpoints:"
netstat -tulpn | grep LISTEN

echo "Health check complete!"
EOF

chmod +x ~/sre-workspace/scripts/health-check.sh

log "SRE setup complete!"
log "Log file saved at: $LOG_FILE"
log "SRE workspace created at: ~/sre-workspace"
log "Run 'source ~/.zshrc' to load new aliases"

echo "✅ SRE-enhanced setup complete!"
echo "📊 SRE Workspace: ~/sre-workspace"
echo "🔍 Run health check: ~/sre-workspace/scripts/health-check.sh"
echo "📈 Setup dashboards: ~/sre-workspace/scripts/setup-dashboards.sh"
echo "🔒 Security scan: ~/sre-workspace/scripts/security-scan.sh"
