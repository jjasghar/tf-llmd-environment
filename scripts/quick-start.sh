#!/bin/bash

# LLM-D on IBM Cloud - Quick Start Script
# This script guides you through the initial setup and deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 LLM-D on IBM Cloud - Quick Start"
echo "=================================="
echo ""

# Change to project directory
cd "$PROJECT_DIR"

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed"
    echo "💡 Install from: https://www.terraform.io/downloads.html"
    exit 1
fi
echo "✅ Terraform: $(terraform version | head -n1)"

# Check IBM Cloud CLI
if ! command -v ibmcloud &> /dev/null; then
    echo "❌ IBM Cloud CLI is not installed"
    echo "💡 Install from: https://cloud.ibm.com/docs/cli?topic=cli-getting-started"
    exit 1
fi
echo "✅ IBM Cloud CLI: $(ibmcloud version | head -n1)"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    echo "💡 Install from: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi
echo "✅ kubectl: $(kubectl version --client --short 2>/dev/null || echo "installed")"

echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "⚙️  Setting up terraform.tfvars..."
    cp terraform.tfvars.example terraform.tfvars
    echo "✅ Created terraform.tfvars from template"
    echo ""
    echo "🔧 IMPORTANT: Please edit terraform.tfvars with your settings:"
    echo "   • Add your IBM Cloud API key"
    echo "   • Optionally add your Hugging Face token"
    echo "   • Adjust region and cluster settings as needed"
    echo ""
    read -p "Press Enter when you've configured terraform.tfvars..."
else
    echo "✅ terraform.tfvars already exists"
fi

# Validate configuration
echo ""
echo "🔍 Validating configuration..."

# Check if API key is set
if ! grep -q "^ibmcloud_api_key.*=.*[\"'].*[^\"'[:space:]].*[\"']" terraform.tfvars; then
    echo "❌ IBM Cloud API key not configured in terraform.tfvars"
    echo "💡 Get your API key from: https://cloud.ibm.com/iam/apikeys"
    exit 1
fi
echo "✅ IBM Cloud API key configured"

# Test IBM Cloud authentication
echo ""
echo "🔐 Testing IBM Cloud authentication..."
API_KEY=$(grep "^ibmcloud_api_key" terraform.tfvars | cut -d'"' -f2)
if ibmcloud login --apikey "$API_KEY" --quiet; then
    echo "✅ IBM Cloud authentication successful"
else
    echo "❌ IBM Cloud authentication failed"
    echo "💡 Check your API key in terraform.tfvars"
    exit 1
fi

# Show deployment summary
echo ""
echo "📋 Deployment Summary"
echo "===================="

# Extract configuration values
REGION=$(grep "^region" terraform.tfvars | cut -d'"' -f2 || echo "us-south")
CLUSTER_NAME=$(grep "^cluster_name" terraform.tfvars | cut -d'"' -f2 || echo "llm-d-cluster")
WORKER_FLAVOR=$(grep "^worker_flavor" terraform.tfvars | cut -d'"' -f2 || echo "bx2.4x16")
WORKER_COUNT=$(grep "^worker_count_per_zone" terraform.tfvars | cut -d'=' -f2 | tr -d ' ' || echo "1")
DEFAULT_MODEL=$(grep "^default_model" terraform.tfvars | cut -d'"' -f2 || echo "ibm-granite/granite-3.3-8b-instruct")

echo "  Region: $REGION"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Worker Flavor: $WORKER_FLAVOR (4 vCPUs, 16GB RAM)"
echo "  Total Nodes: $((WORKER_COUNT * 3)) (across 3 zones)"
echo "  Default Model: $DEFAULT_MODEL (IBM Granite)"
echo "  Estimated Cost: ~\$350-480/month"
echo ""

# Confirm deployment
echo "⚠️  This will create real IBM Cloud resources that incur costs."
echo ""
read -p "Do you want to proceed with deployment? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 0
fi

# Initialize Terraform
echo ""
echo "🔧 Initializing Terraform..."
terraform init

# Show plan
echo ""
echo "📋 Creating deployment plan..."
if ! terraform plan -out=tfplan; then
    echo "❌ Terraform plan failed"
    exit 1
fi

# Final confirmation
echo ""
echo "🚀 Ready to deploy!"
read -p "Apply the deployment plan? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    rm -f tfplan
    exit 0
fi

# Apply configuration
echo ""
echo "🚀 Deploying infrastructure..."
echo "⏱️  This will take 15-20 minutes..."
echo ""

if terraform apply tfplan; then
    echo ""
    echo "🎉 Infrastructure deployment successful!"
    
    # Configure kubectl
    echo ""
    echo "⚙️  Configuring kubectl..."
    CLUSTER_ID=$(terraform output -raw cluster_id)
    if ibmcloud ks cluster config --cluster "$CLUSTER_ID"; then
        echo "✅ kubectl configured successfully"
        
        # Verify deployment
        echo ""
        echo "🔍 Verifying LLM-D deployment..."
        ./scripts/verify-deployment.sh
        
        echo ""
        echo "🎊 Deployment Complete!"
        echo "====================="
        echo ""
        echo "📊 Cluster Information:"
        terraform output cluster_info | grep -v "<<\|>>" || terraform output cluster_info
        echo ""
        echo "🔗 Next Steps:"
        echo "  • Check cluster status: kubectl get nodes"
        echo "  • View LLM-D pods: kubectl get pods -n llm-d"
        echo "  • View LLM-D services: kubectl get services -n llm-d"
        echo "  • Check model config: kubectl get configmap llm-d-model-config -n llm-d -o yaml"
        echo "  • Monitor installation: kubectl logs -n llm-d job/llm-d-installer -f"
        echo ""
        echo "🤖 IBM Granite Model:"
        echo "  • Default Model: $DEFAULT_MODEL"
        echo "  • View config: make show-model-config"
        echo ""
        echo "📚 Documentation: README.md"
        echo "🛠️  Management: Use 'make help' for common tasks"
        echo ""
    else
        echo "⚠️  kubectl configuration failed, but infrastructure is deployed"
        echo "💡 Run manually: ibmcloud ks cluster config --cluster $CLUSTER_ID"
    fi
else
    echo "❌ Deployment failed"
    rm -f tfplan
    exit 1
fi

# Cleanup
rm -f tfplan

echo "✅ Quick start complete!"
