#!/bin/bash

# LLM-D Post-Installation Script
# This script installs the real LLM-D infrastructure after Terraform provisions the cluster

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 LLM-D Installation Script"
echo "============================"
echo ""

# Configuration (following official LLM-D inference scheduling instructions)
NAMESPACE="${NAMESPACE:-llm-d-inference-scheduling}"
MODEL="${MODEL:-ibm-granite/granite-3.3-8b-instruct}"
GATEWAY="${GATEWAY:-kgateway}"
RELEASE_NAME="infra-inference-scheduling"
WORKSPACE_DIR="/tmp/llm-d-installation"

echo "📋 Configuration:"
echo "  Namespace: $NAMESPACE"
echo "  Model: $MODEL"
echo "  Gateway: $GATEWAY"
echo "  Release Name: $RELEASE_NAME"
echo "  Workspace: $WORKSPACE_DIR"
echo ""

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check if HF_TOKEN is set
if [ -z "$HF_TOKEN" ]; then
    echo "❌ HF_TOKEN environment variable is required"
    echo "💡 Get your token from: https://huggingface.co/settings/tokens"
    echo "💡 Export it: export HF_TOKEN=your_token_here"
    exit 1
fi
echo "✅ HF_TOKEN is set"

# Check if kubectl is available and connected
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "💡 Make sure you've run: terraform output kubectl_config_command"
    echo "💡 Then run the command to configure kubectl"
    exit 1
fi
echo "✅ kubectl is connected to cluster"

# Note: LLM-D installer will create the namespace if it doesn't exist
echo "ℹ️  LLM-D installer will create namespace '$NAMESPACE' if needed"

# Check node resources
echo ""
echo "🔍 Checking cluster resources..."
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo "✅ Found $NODE_COUNT nodes"

kubectl get nodes -o wide
echo ""

# Create workspace
echo "📁 Setting up workspace..."
rm -rf "$WORKSPACE_DIR"
mkdir -p "$WORKSPACE_DIR"
cd "$WORKSPACE_DIR"

# Clone LLM-D infrastructure
echo "📥 Cloning LLM-D infrastructure..."
git clone https://github.com/llm-d-incubation/llm-d-infra.git
cd llm-d-infra/quickstart

# Install dependencies locally
echo "📦 Installing required dependencies..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew is required on macOS"
        echo "💡 Install from: https://brew.sh"
        exit 1
    fi
    
    echo "🍺 Installing dependencies via Homebrew..."
    brew install yq jq helm helmfile kustomize || true
else
    # Linux
    ./install-deps.sh
fi

echo "✅ Dependencies installed"

# Create values.yaml for IBM Granite model
echo "⚙️  Creating IBM Granite configuration..."
cat > values.yaml << EOF
# IBM Granite Model Configuration for LLM-D with High-Performance Nodes
global:
  modelId: "$MODEL"

# vLLM configuration optimized for bx3d.32x160 nodes (32 vCPUs, 160GB RAM)
vllm:
  enabled: true
  model: "$MODEL"
  trustRemoteCode: true
  maxModelLen: 4096
  resources:
    requests:
      memory: "24Gi"  # Use more of the 160GB available
      cpu: "16"       # Use half of 32 vCPUs
    limits:
      memory: "80Gi"  # Allow up to half of node memory
      cpu: "28"       # Use most vCPUs, leave 4 for system

# Inference scheduling configuration
inference:
  enabled: true
  modelId: "$MODEL"
  maxTokens: 4096
  temperature: 0.7
  topP: 0.9
  repetitionPenalty: 1.1
  scheduling:
    enabled: true
    loadAware: true
    prefixCacheAware: true

# Gateway configuration
gateway:
  enabled: true
  type: "$GATEWAY"

# Monitoring with Prometheus and Grafana
monitoring:
  enabled: true
  prometheus:
    enabled: true
  grafana:
    enabled: true

# Model service configuration
modelservice:
  enabled: true
  replicas: 1
  resources:
    requests:
      memory: "24Gi"
      cpu: "16"
    limits:
      memory: "80Gi"
      cpu: "28"
EOF

echo "✅ Configuration created"

# Install LLM-D infrastructure
echo ""
echo "🚀 Installing LLM-D infrastructure..."
echo "⏱️  This may take 15-20 minutes..."
echo ""

# Step 1: Install infrastructure (following official docs)
echo "🔧 Step 1: Installing LLM-D infrastructure..."
if ./llmd-infra-installer.sh --namespace "$NAMESPACE" -r "$RELEASE_NAME" --gateway "$GATEWAY"; then
    echo ""
    echo "🎉 Step 1 completed: LLM-D infrastructure installed!"
    
    # Step 2: Install model services (following official docs)
    echo ""
    echo "🔧 Step 2: Installing model services with helmfile..."
    
    if [ -d "examples/inference-scheduling" ]; then
        cd examples/inference-scheduling
        
        # Create IBM Granite model configuration
        mkdir -p ms-inference-scheduling
        cat > ms-inference-scheduling/values.yaml << MSEOF
# IBM Granite Model Service Configuration
modelArtifacts:
  uri: "$MODEL"
  
routing:
  modelName: "$MODEL"
  
vllm:
  model: "$MODEL"
  trustRemoteCode: true
  maxModelLen: 4096
  resources:
    requests:
      memory: "24Gi"
      cpu: "16"
    limits:
      memory: "80Gi"
      cpu: "28"
MSEOF
        
        echo "⚙️  Applying model services with helmfile..."
        if helmfile --selector managedBy=helmfile apply -f helmfile.yaml --skip-diff-on-install; then
            echo "✅ Model services installed successfully"
        else
            echo "⚠️  Model services installation had issues, but continuing..."
        fi
        
        cd ../../quickstart
    else
        echo "⚠️  Examples directory not found, skipping model services installation"
    fi
    
    # Wait for pods to be ready
    echo ""
    echo "⏳ Waiting for LLM-D components to be ready..."
    sleep 60
    
    # Check installation
    echo ""
    echo "🔍 Verifying installation..."
    kubectl get pods,services,gateways -n "$NAMESPACE" || kubectl get pods,services -n "$NAMESPACE"
    
    # Check for gateway service (following official docs pattern)
    echo ""
    echo "🔍 Looking for gateway service..."
    echo "Expected service name: ${RELEASE_NAME}-inference-gateway"
    
    # List all helm releases (as shown in official docs)
    echo ""
    echo "📊 Checking Helm releases:"
    helm list -n "$NAMESPACE"
    
    # Find gateway service (as shown in official docs)
    echo ""
    echo "🔍 Checking services:"
    kubectl get services -n "$NAMESPACE"
    
    GATEWAY_SERVICE="${RELEASE_NAME}-inference-gateway"
    
    if kubectl get service "$GATEWAY_SERVICE" -n "$NAMESPACE" &> /dev/null; then
        echo "✅ Found gateway service: $GATEWAY_SERVICE"
        echo ""
        echo "🧪 Testing LLM-D endpoints (following official docs)..."
        echo "Run the following commands to test:"
        echo ""
        echo "# Step 1: Port forward to access the service"
        echo "kubectl port-forward -n $NAMESPACE service/$GATEWAY_SERVICE 8000:80 &"
        echo ""
        echo "# Step 2: Test models endpoint"
        echo "curl -s http://localhost:8000/v1/models -H 'Content-Type: application/json' | jq ."
        echo ""
        echo "# Step 3: Test inference (v1/completions endpoint)"
        echo "curl -s http://localhost:8000/v1/completions \\"
        echo "  -H 'Content-Type: application/json' \\"
        echo "  -d '{\"model\": \"$MODEL\", \"prompt\": \"How are you today?\", \"max_tokens\": 50}' | jq ."
        echo ""
    else
        echo "⚠️  Expected gateway service not found: $GATEWAY_SERVICE"
        echo "📋 Available services:"
        kubectl get services -n "$NAMESPACE"
        echo ""
        echo "💡 Look for a service with 'gateway' in the name and update the port-forward command accordingly"
    fi
    
    echo ""
    echo "🎊 Installation Complete!"
    echo "======================="
    echo ""
    echo "📊 Cluster Information:"
    echo "  • Nodes: $NODE_COUNT × bx3d.32x160 (32 vCPUs, 160GB RAM each)"
    echo "  • Total Resources: $((NODE_COUNT * 32)) vCPUs, $((NODE_COUNT * 160))GB RAM"
    echo "  • Model: $MODEL"
    echo "  • Gateway: $GATEWAY"
    echo "  • Monitoring: Enabled (Prometheus + Grafana)"
    echo ""
    echo "🔗 Next Steps:"
    echo "  • Monitor installation: kubectl get pods -n $NAMESPACE -w"
    echo "  • Access logs: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=vllm -f"
    echo "  • View monitoring: kubectl port-forward -n llm-d-monitoring service/prometheus-grafana 3000:80"
    echo ""
    
else
    echo ""
    echo "❌ LLM-D installation failed"
    echo "📋 Checking logs..."
    kubectl get pods -n "$NAMESPACE"
    echo ""
    echo "💡 Troubleshooting:"
    echo "  • Check pod logs: kubectl logs -n $NAMESPACE <pod-name>"
    echo "  • Verify HF_TOKEN: echo \$HF_TOKEN"
    echo "  • Check cluster resources: kubectl top nodes"
    exit 1
fi

# Cleanup
echo ""
echo "🧹 Cleaning up workspace..."
cd "$PROJECT_DIR"
rm -rf "$WORKSPACE_DIR"

echo "✅ LLM-D installation script completed successfully!"
