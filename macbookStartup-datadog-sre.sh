#!/usr/bin/env bash

set -euo pipefail

echo "🔹 Setting up your MacBook for Datadog SRE work..."

# Security configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/datadog-sre-setup-$(date +%Y%m%d-%H%M%S).log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Starting Datadog SRE setup process..."

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

# --- Datadog Core Tools ---
log "Installing Datadog core tools..."
brew install --cask datadog-agent
brew install datadog-cli

# Datadog Python SDK
pip install datadog-api-client
pip install datadog

# --- Monitoring & Observability ---
log "Installing monitoring and observability tools..."
brew install prometheus grafana
brew install jaeger-tracing
brew install opentelemetry-collector

# Log management
log "Installing log management tools..."
brew install fluentd
brew install elasticsearch kibana
brew install logstash

# --- Incident Management ---
log "Installing incident management tools..."
brew install --cask pagerduty-cli
brew install alertmanager

# --- Performance & Load Testing ---
log "Installing performance testing tools..."
brew install k6 artillery
brew install wrk

# --- Security Tools ---
log "Installing security tools..."
brew install trivy semgrep
brew install kube-hunter kube-bench
brew install snyk

# --- Network & Debugging Tools ---
log "Installing network and debugging tools..."
brew install nmap wireshark
brew install tcpdump netcat
brew install ngrok

# --- Developer Tools ---
log "Installing developer tools..."
brew install --cask visual-studio-code cursor lens

# --- Database Tools ---
log "Installing database tools..."
brew install postgresql mysql redis
brew install --cask dbeaver-community

# --- Messaging & Communication ---
log "Installing messaging tools..."
brew install kafka
brew install slack-cli

# --- Datadog-Specific Setup ---
log "Setting up Datadog-specific configurations..."

# Create Datadog workspace
mkdir -p ~/datadog-workspace/{dashboards,monitors,alerts,scripts,terraform,ansible}
mkdir -p ~/datadog-workspace/{integrations,automation,testing}

# Set up Datadog environment variables
cat >> ~/.zshrc << 'EOF'

# Datadog environment variables
export DD_API_KEY="${DD_API_KEY:-}"
export DD_APP_KEY="${DD_APP_KEY:-}"
export DD_SITE="${DD_SITE:-datadoghq.com}"
export DD_ENV="${DD_ENV:-development}"

# Datadog aliases
alias dd-cli='datadog-cli'
alias dd-dashboards='datadog-cli dashboards list'
alias dd-monitors='datadog-cli monitors list'
alias dd-logs='datadog-cli logs search'
alias dd-metrics='datadog-cli metrics post'

# Datadog workspace navigation
alias dd-workspace='cd ~/datadog-workspace'
alias dd-dashboards-dir='cd ~/datadog-workspace/dashboards'
alias dd-monitors-dir='cd ~/datadog-workspace/monitors'
alias dd-scripts='cd ~/datadog-workspace/scripts'
EOF

# Create Datadog Terraform configuration
cat > ~/datadog-workspace/terraform/datadog-provider.tf << 'EOF'
terraform {
  required_providers {
    datadog = {
      source = "DataDog/datadog"
      version = "~> 3.0"
    }
  }
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
}

variable "datadog_api_key" {
  description = "Datadog API key"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog application key"
  type        = string
  sensitive   = true
}
EOF

# Create Datadog Ansible playbook
cat > ~/datadog-workspace/ansible/datadog-agent.yml << 'EOF'
---
- name: Install Datadog Agent
  hosts: all
  become: yes
  tasks:
    - name: Install Datadog Agent
      ansible.builtin.apt:
        name: datadog-agent
        state: present
        update_cache: yes
      when: ansible_os_family == "Debian"
    
    - name: Configure Datadog Agent
      ansible.builtin.template:
        src: datadog.yaml.j2
        dest: /etc/datadog-agent/datadog.yaml
        owner: dd-agent
        group: dd-agent
        mode: '0644'
      notify: restart datadog-agent
    
    - name: Start and enable Datadog Agent
      ansible.builtin.systemd:
        name: datadog-agent
        state: started
        enabled: yes
EOF

# Create Datadog dashboard automation script
cat > ~/datadog-workspace/scripts/create-dashboard.sh << 'EOF'
#!/bin/bash
# Script to create Datadog dashboards via API

if [ -z "$DD_API_KEY" ] || [ -z "$DD_APP_KEY" ]; then
    echo "Error: DD_API_KEY and DD_APP_KEY must be set"
    exit 1
fi

DASHBOARD_FILE="${1:-dashboard.json}"
if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "Error: Dashboard file $DASHBOARD_FILE not found"
    exit 1
fi

echo "Creating Datadog dashboard from $DASHBOARD_FILE..."

curl -X POST "https://api.datadoghq.com/api/v1/dashboard" \
  -H "Content-Type: application/json" \
  -H "DD-API-KEY: ${DD_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
  -d @"$DASHBOARD_FILE"

echo "Dashboard creation complete!"
EOF

chmod +x ~/datadog-workspace/scripts/create-dashboard.sh

# Create Datadog monitor automation script
cat > ~/datadog-workspace/scripts/create-monitor.sh << 'EOF'
#!/bin/bash
# Script to create Datadog monitors via API

if [ -z "$DD_API_KEY" ] || [ -z "$DD_APP_KEY" ]; then
    echo "Error: DD_API_KEY and DD_APP_KEY must be set"
    exit 1
fi

MONITOR_FILE="${1:-monitor.json}"
if [ ! -f "$MONITOR_FILE" ]; then
    echo "Error: Monitor file $MONITOR_FILE not found"
    exit 1
fi

echo "Creating Datadog monitor from $MONITOR_FILE..."

curl -X POST "https://api.datadoghq.com/api/v1/monitor" \
  -H "Content-Type: application/json" \
  -H "DD-API-KEY: ${DD_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
  -d @"$MONITOR_FILE"

echo "Monitor creation complete!"
EOF

chmod +x ~/datadog-workspace/scripts/create-monitor.sh

# Create Datadog health check script
cat > ~/datadog-workspace/scripts/health-check.sh << 'EOF'
#!/bin/bash
echo "🏥 Running Datadog health checks..."

# Check Datadog API connectivity
echo "Testing Datadog API connectivity..."
if curl -s -f "https://api.datadoghq.com/api/v1/validate" \
  -H "DD-API-KEY: ${DD_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" > /dev/null; then
    echo "✅ Datadog API connectivity: OK"
else
    echo "❌ Datadog API connectivity: FAILED"
fi

# Check Datadog Agent status
echo "Checking Datadog Agent status..."
if systemctl is-active --quiet datadog-agent; then
    echo "✅ Datadog Agent: Running"
else
    echo "❌ Datadog Agent: Not running"
fi

# Check Datadog CLI
echo "Testing Datadog CLI..."
if command -v datadog-cli &> /dev/null; then
    echo "✅ Datadog CLI: Available"
else
    echo "❌ Datadog CLI: Not found"
fi

echo "Datadog health check complete!"
EOF

chmod +x ~/datadog-workspace/scripts/health-check.sh

# Create sample Datadog dashboard
cat > ~/datadog-workspace/dashboards/sample-dashboard.json << 'EOF'
{
  "title": "SRE Dashboard",
  "description": "Sample SRE dashboard for monitoring",
  "widgets": [
    {
      "id": 1,
      "definition": {
        "type": "timeseries",
        "requests": [
          {
            "q": "avg:system.cpu.user{*}"
          }
        ],
        "title": "CPU Usage"
      }
    },
    {
      "id": 2,
      "definition": {
        "type": "timeseries",
        "requests": [
          {
            "q": "avg:system.mem.used{*}"
          }
        ],
        "title": "Memory Usage"
      }
    }
  ],
  "layout_type": "ordered"
}
EOF

# Create sample Datadog monitor
cat > ~/datadog-workspace/monitors/sample-monitor.json << 'EOF'
{
  "name": "High CPU Usage",
  "type": "metric alert",
  "query": "avg(last_5m):avg:system.cpu.user{*} > 80",
  "message": "CPU usage is high on {{host.name}}",
  "tags": ["env:production"],
  "options": {
    "thresholds": {
      "critical": 80,
      "warning": 70
    },
    "notify_audit": false,
    "require_full_window": true,
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
EOF

# Create Datadog integration testing script
cat > ~/datadog-workspace/scripts/test-integrations.sh << 'EOF'
#!/bin/bash
echo "🧪 Testing Datadog integrations..."

# Test Kubernetes integration
echo "Testing Kubernetes integration..."
kubectl get nodes
kubectl get pods --all-namespaces

# Test Docker integration
echo "Testing Docker integration..."
docker ps
docker stats --no-stream

# Test AWS integration
echo "Testing AWS integration..."
aws sts get-caller-identity

# Test Azure integration
echo "Testing Azure integration..."
az account show

# Test GCP integration
echo "Testing GCP integration..."
gcloud auth list

echo "Integration testing complete!"
EOF

chmod +x ~/datadog-workspace/scripts/test-integrations.sh

# Create Datadog performance testing script
cat > ~/datadog-workspace/scripts/performance-test.sh << 'EOF'
#!/bin/bash
echo "🚀 Running Datadog performance tests..."

# Load test with k6
echo "Running load test with k6..."
cat > /tmp/load-test.js << 'JS'
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 0 },
  ],
};

export default function () {
  let response = http.get('https://httpbin.org/');
  check(response, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}
JS

k6 run /tmp/load-test.js

# Artillery test
echo "Running Artillery test..."
artillery quick --count 100 --num 10 https://httpbin.org/

echo "Performance testing complete!"
EOF

chmod +x ~/datadog-workspace/scripts/performance-test.sh

log "Datadog SRE setup complete!"
log "Log file saved at: $LOG_FILE"
log "Datadog workspace created at: ~/datadog-workspace"
log "Run 'source ~/.zshrc' to load new aliases"

echo "✅ Datadog SRE setup complete!"
echo "📊 Datadog Workspace: ~/datadog-workspace"
echo "🔍 Run health check: ~/datadog-workspace/scripts/health-check.sh"
echo "🧪 Test integrations: ~/datadog-workspace/scripts/test-integrations.sh"
echo "🚀 Performance test: ~/datadog-workspace/scripts/performance-test.sh"
echo "📋 See DATADOG_SRE_TOOLKIT.md for detailed documentation"
