# LLM-D on IBM Cloud - Makefile
# Convenience commands for managing the infrastructure

.PHONY: help init plan apply destroy verify clean check-prereqs show-outputs

# Default target
help: ## Show this help message
	@echo "LLM-D on IBM Cloud Kubernetes - Terraform Infrastructure"
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Prerequisites:"
	@echo "  • IBM Cloud CLI installed and configured"
	@echo "  • Terraform >= 1.0 installed"
	@echo "  • kubectl installed"
	@echo "  • terraform.tfvars file configured"
	@echo ""

check-prereqs: ## Check if all prerequisites are installed
	@echo "🔍 Checking prerequisites..."
	@command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform is not installed"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is not installed"; exit 1; }
	@command -v ibmcloud >/dev/null 2>&1 || { echo "❌ IBM Cloud CLI is not installed"; exit 1; }
	@test -f terraform.tfvars || { echo "❌ terraform.tfvars file not found. Copy terraform.tfvars.example and configure it."; exit 1; }
	@echo "✅ All prerequisites are installed"

init: check-prereqs ## Initialize Terraform
	@echo "🚀 Initializing Terraform..."
	terraform init

plan: check-prereqs ## Show Terraform execution plan
	@echo "📋 Creating Terraform plan..."
	terraform plan

apply: check-prereqs ## Apply Terraform configuration
	@echo "🚀 Applying Terraform configuration..."
	terraform apply

apply-auto: check-prereqs ## Apply Terraform configuration without confirmation
	@echo "🚀 Applying Terraform configuration (auto-approve)..."
	terraform apply -auto-approve

destroy: ## Destroy all infrastructure
	@echo "💥 Destroying infrastructure..."
	@echo "⚠️  This will permanently delete all resources!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ] || exit 1
	terraform destroy

destroy-auto: ## Destroy all infrastructure without confirmation
	@echo "💥 Destroying infrastructure (auto-approve)..."
	terraform destroy -auto-approve

verify: ## Verify LLM-D deployment
	@echo "🔍 Verifying LLM-D deployment..."
	@if ! command -v kubectl >/dev/null 2>&1; then \
		echo "❌ kubectl is not installed"; \
		exit 1; \
	fi
	@./scripts/verify-deployment.sh

show-outputs: ## Show Terraform outputs
	@echo "📊 Terraform outputs:"
	@terraform output

show-cluster-info: ## Show cluster information
	@echo "🏗️  Cluster information:"
	@terraform output cluster_info 2>/dev/null | jq -r . || terraform output cluster_info

show-model-config: ## Show LLM-D model configuration
	@echo "🤖 Model configuration:"
	@terraform output model_configuration 2>/dev/null | jq -r . || terraform output model_configuration

configure-kubectl: ## Configure kubectl for the cluster
	@echo "⚙️  Configuring kubectl..."
	@CLUSTER_ID=$$(terraform output -raw cluster_id 2>/dev/null) && \
	echo "Running: ibmcloud ks cluster config --cluster $$CLUSTER_ID" && \
	ibmcloud ks cluster config --cluster $$CLUSTER_ID

logs: ## Show LLM-D installer logs
	@echo "📋 LLM-D installer logs:"
	@kubectl logs -n llm-d job/llm-d-installer --tail=50 2>/dev/null || echo "❌ Could not get logs. Make sure kubectl is configured and the cluster is running."

status: ## Show cluster and LLM-D status
	@echo "📊 Cluster Status:"
	@kubectl get nodes 2>/dev/null || echo "❌ Could not get nodes. Make sure kubectl is configured."
	@echo ""
	@echo "📊 LLM-D Namespace Status:"
	@kubectl get all -n llm-d 2>/dev/null || echo "❌ Could not get LLM-D resources. Make sure kubectl is configured."
	@echo ""
	@echo "🤖 Model Configuration:"
	@kubectl get configmap llm-d-model-config -n llm-d -o jsonpath='{.data.default_model}' 2>/dev/null && echo "" || echo "❌ Could not get model config."

clean: ## Clean up Terraform state and temporary files
	@echo "🧹 Cleaning up..."
	@rm -rf .terraform/
	@rm -f .terraform.lock.hcl
	@rm -f terraform.tfplan
	@rm -f terraform.tfplan.json
	@rm -f terraform.tfstate.backup
	@echo "✅ Cleanup complete"

validate: ## Validate Terraform configuration
	@echo "✅ Validating Terraform configuration..."
	terraform validate

format: ## Format Terraform files
	@echo "🎨 Formatting Terraform files..."
	terraform fmt -recursive

# Development targets
dev-plan: ## Quick plan for development
	terraform plan -compact-warnings

dev-apply: ## Quick apply for development
	terraform apply -auto-approve -compact-warnings

# Backup targets
backup-state: ## Backup Terraform state
	@echo "💾 Backing up Terraform state..."
	@cp terraform.tfstate terraform.tfstate.backup.$$(date +%Y%m%d_%H%M%S) 2>/dev/null || echo "No state file to backup"

# Documentation
docs: ## Generate documentation
	@echo "📚 Available documentation:"
	@echo "  • README.md - Main documentation"
	@echo "  • terraform.tfvars.example - Configuration template"
	@echo "  • This Makefile - Available commands"

# Quick deployment
quick-deploy: init plan apply configure-kubectl verify ## Complete deployment workflow
	@echo "🎉 Deployment complete!"
	@echo ""
	@$(MAKE) show-cluster-info
	@echo ""
	@$(MAKE) show-model-config

# Example configurations
show-examples: ## Show example configurations
	@echo "📋 Example configurations:"
	@echo ""
	@echo "Small cluster (2 nodes, 8GB each):"
	@echo "  worker_flavor = \"bx2.2x8\""
	@echo "  worker_count_per_zone = 1"
	@echo "  zones = [\"us-south-1\", \"us-south-2\"]"
	@echo ""
	@echo "Large cluster (6 nodes, 32GB each):"
	@echo "  worker_flavor = \"bx2.8x32\""
	@echo "  worker_count_per_zone = 2"
	@echo "  zones = [\"us-south-1\", \"us-south-2\", \"us-south-3\"]"
	@echo ""
	@echo "🤖 Model configurations:"
	@echo ""
	@echo "IBM Granite 8B (Default - Recommended):"
	@echo "  default_model = \"ibm-granite/granite-3.3-8b-instruct\""
	@echo ""
	@echo "IBM Granite 2B (Faster, smaller):"
	@echo "  default_model = \"ibm-granite/granite-3.3-2b-instruct\""
	@echo ""
	@echo "IBM Granite 1B (Fastest, smallest):"
	@echo "  default_model = \"ibm-granite/granite-3.3-1b-instruct\""
	@echo ""
