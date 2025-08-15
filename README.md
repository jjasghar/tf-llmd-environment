# LLM-D on IBM Cloud Kubernetes - Terraform Infrastructure

This Terraform configuration deploys a production-ready 3-node Kubernetes cluster on IBM Cloud with 16GB RAM per node and automatically installs the [LLM-D infrastructure](https://github.com/llm-d-incubation/llm-d-infra) with **IBM Granite models**.

## 🎯 What's Included

- **✅ Production-Ready Kubernetes**: 3-node cluster optimized for AI workloads
- **✅ IBM Granite Models**: Pre-configured with enterprise-grade LLM models
- **✅ Network Connectivity**: Automatic security group configuration for container registries
- **✅ Service Mesh Ready**: Optional Istio and Kubernetes Gateway API support
- **✅ Reliable Container Registry**: Uses IBM Container Registry (icr.io) for stable image pulls
- **✅ Zero Manual Configuration**: All fixes automated in Terraform

## Architecture

- **Kubernetes Cluster**: 3-node cluster with 16GB RAM per node (bx2.4x16 flavor)
- **High Availability**: Nodes distributed across 3 availability zones
- **Networking**: VPC with public gateways and security group rules for internet access
- **Container Registry**: IBM Container Registry (icr.io) for reliable image delivery
- **LLM-D Installation**: Automated deployment with IBM Granite model configuration
- **Service Mesh**: Optional Istio service mesh and Kubernetes Gateway API

## Prerequisites

1. **IBM Cloud Account**: [Sign up here](https://cloud.ibm.com/)
2. **IBM Cloud CLI**: [Installation guide](https://cloud.ibm.com/docs/cli?topic=cli-getting-started)
3. **Terraform**: Version >= 1.0 [Download here](https://www.terraform.io/downloads.html)
4. **kubectl**: [Installation guide](https://kubernetes.io/docs/tasks/tools/)

## Quick Start

### 1. Clone and Setup

```bash
# Clone this repository
git clone <your-repo-url>
cd tf-llmd-environment

# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars
```

### 2. Configure Variables

Edit `terraform.tfvars` with your settings:

```hcl
# Required: Your IBM Cloud API key
ibmcloud_api_key = "your-ibm-cloud-api-key-here"

# Optional: Hugging Face token for model access
huggingface_token = "your-huggingface-token-here"

# Cluster Configuration
region = "us-south"
cluster_name = "llm-d-cluster"
resource_group_name = "Default"  # Use capital D for default resource group

# Model Configuration (IBM Granite default)
default_model = "ibm-granite/granite-3.3-8b-instruct"

# Service Mesh Configuration
enable_istio = true              # Enable Istio service mesh
enable_kgateway = false         # Enable Kubernetes Gateway API
istio_version = "1.24.1"        # Istio version
container_registry = "icr.io"   # IBM Container Registry (recommended)
```

### 3. Get Your IBM Cloud API Key

1. Go to [IBM Cloud API Keys](https://cloud.ibm.com/iam/apikeys)
2. Click "Create an IBM Cloud API key"
3. Give it a name and description
4. Copy the API key and paste it into `terraform.tfvars`

### 4. Get Hugging Face Token (Optional but Recommended)

1. Go to [Hugging Face Settings](https://huggingface.co/settings/tokens)
2. Create a new token with "Read" permissions
3. Copy the token and paste it into `terraform.tfvars`

### 5. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the planned changes
terraform plan

# Deploy the infrastructure
terraform apply
```

The deployment will take approximately 15-20 minutes to complete.

### 6. Configure kubectl

After deployment, configure kubectl to access your cluster:

```bash
# Get the cluster config command from Terraform output
terraform output kubectl_config_command

# Run the command (example)
ibmcloud ks cluster config --cluster <cluster-id>

# Verify connection
kubectl get nodes
kubectl get pods -n llm-d
```

## Configuration Options

### Service Mesh and Gateway API

Configure service mesh and gateway options:

```hcl
# Istio Service Mesh (Recommended for production)
enable_istio = true          # Enable Istio service mesh  
istio_version = "1.24.1"     # Istio version to install

# Kubernetes Gateway API (Alternative to Istio Ingress)
enable_kgateway = true       # Enable Kubernetes Gateway API

# Container Registry (Fixes image pull issues)
container_registry = "icr.io"      # IBM Container Registry (recommended)
container_registry = "docker.io"   # Docker Hub (may have connectivity issues)
container_registry = "quay.io"     # Red Hat Quay
container_registry = "ghcr.io"     # GitHub Container Registry
```

### Model Configuration

Customize the AI model deployment:

```hcl
# Default Model Selection
default_model = "ibm-granite/granite-3.3-8b-instruct"  # IBM Granite 8B (recommended)

# Model Parameters
model_config = {
  max_tokens         = 4096    # Maximum tokens per response
  temperature        = 0.7     # Creativity level (0.0-2.0)
  top_p             = 0.9      # Nucleus sampling (0.0-1.0)
  repetition_penalty = 1.1     # Repetition penalty (1.0+)
}
```

### Cluster Sizing

The default configuration creates a 3-node cluster with 16GB RAM per node:

- **Worker Flavor**: `bx2.4x16` (4 vCPUs, 16GB RAM)
- **Worker Count**: 1 per zone × 3 zones = 3 total nodes
- **Total Resources**: 12 vCPUs, 48GB RAM

To modify the cluster size, adjust these variables in `terraform.tfvars`:

```hcl
# For more powerful nodes
worker_flavor = "bx2.8x32"  # 8 vCPUs, 32GB RAM

# For more nodes per zone
worker_count_per_zone = 2   # 6 total nodes (2 per zone)
```

### Available Worker Flavors

| Flavor | vCPUs | RAM | Use Case |
|--------|-------|-----|----------|
| bx2.2x8 | 2 | 8GB | Light workloads |
| bx2.4x16 | 4 | 16GB | **Default - Recommended** |
| bx2.8x32 | 8 | 32GB | Heavy AI workloads |
| bx2.16x64 | 16 | 64GB | Very heavy workloads |

### Regions and Zones

Adjust the region and zones based on your location:

```hcl
# US South (Default)
region = "us-south"
zones = ["us-south-1", "us-south-2", "us-south-3"]

# EU Great Britain
region = "eu-gb"
zones = ["eu-gb-1", "eu-gb-2", "eu-gb-3"]

# Japan Tokyo
region = "jp-tok"
zones = ["jp-tok-1", "jp-tok-2", "jp-tok-3"]
```

## LLM-D Components

After deployment, the following LLM-D components will be installed:

- **Inference Gateway**: Routes requests to AI models
- **Model Servers**: Hosts IBM Granite models by default
- **Monitoring**: Observability and metrics collection
- **Storage**: Persistent storage for models and data

### Default Model: IBM Granite

The deployment is configured to use **IBM Granite 3.3 8B Instruct** model by default:
- **Model**: `ibm-granite/granite-3.3-8b-instruct`
- **Capabilities**: Multilingual, coding, reasoning, and tool usage
- **Size**: 8 billion parameters
- **Context**: 4096 tokens
- **Designed for**: Enterprise use cases

### Supported Models

You can configure different models by setting the `default_model` variable:

```hcl
# IBM Granite Models (Recommended)
default_model = "ibm-granite/granite-3.3-8b-instruct"  # Default - 8B parameters
default_model = "ibm-granite/granite-3.3-2b-instruct"  # Smaller - 2B parameters  
default_model = "ibm-granite/granite-3.3-1b-instruct"  # Smallest - 1B parameters

# Legacy IBM Granite Models
default_model = "ibm/granite-13b-instruct-v2"          # Larger - 13B parameters
default_model = "ibm/granite-20b-instruct-v1"          # Largest - 20B parameters

# Alternative Models
default_model = "meta-llama/Llama-2-7b-chat-hf"        # Meta Llama 2 7B
default_model = "meta-llama/Llama-2-13b-chat-hf"       # Meta Llama 2 13B
```

## Monitoring and Management

### Check LLM-D Status

```bash
# Check all LLM-D pods
kubectl get pods -n llm-d

# Check LLM-D services
kubectl get services -n llm-d

# View LLM-D logs
kubectl logs -n llm-d -l app=llm-d --tail=100

# Check model configuration
kubectl get configmap llm-d-model-config -n llm-d -o yaml

# View installer logs to verify Granite model setup
kubectl logs -n llm-d job/llm-d-installer --tail=50
```

### Model Configuration

Check the current model configuration:

```bash
# View model configuration
terraform output model_configuration

# Check deployed model settings
kubectl get configmap llm-d-model-config -n llm-d -o jsonpath='{.data.default_model}'

# View full model config
kubectl get configmap llm-d-model-config -n llm-d -o jsonpath='{.data.model_config\.yaml}' | yq .
```

### Access Services

```bash
# Get service endpoints
kubectl get services -n llm-d

# Port-forward to access services locally
kubectl port-forward -n llm-d service/<service-name> 8080:80
```

## Troubleshooting

### Network Connectivity Issues (Fixed Automatically)

This Terraform configuration **automatically fixes** common IBM Cloud networking issues:

- ✅ **ImagePullBackOff**: Security group rules for HTTPS (443), HTTP (80), and DNS (53) are automatically configured
- ✅ **Container Registry Access**: Uses IBM Container Registry (icr.io) for reliable image pulls  
- ✅ **DNS Resolution**: Inbound UDP 53 rules allow DNS query responses
- ✅ **Registry Connectivity**: Inbound TCP 443/80 rules allow container registry responses

### Common Issues

1. **Resource Group Name Error**
   ```bash
   # Fix: Use "Default" with capital D in terraform.tfvars
   resource_group_name = "Default"  # Not "default"
   
   # Check available resource groups
   ibmcloud resource groups
   ```

2. **Kubernetes Version Error**
   ```bash
   # Fix: Use supported Kubernetes version
   kubernetes_version = "1.32"  # Current supported version
   
   # Check available versions
   ibmcloud ks versions
   ```

3. **API Key Issues**
   ```bash
   # Verify your API key works
   ibmcloud login --apikey your-api-key-here
   ```

4. **Resource Quota Issues**
   ```bash
   # Check your account limits
   ibmcloud ks quota ls
   ```

5. **LLM-D Installation Failed**
   ```bash
   # Check the installer job logs
   kubectl logs -n llm-d job/llm-d-installer
   
   # Check the simple deployment
   kubectl get pods -n llm-d
   kubectl logs -n llm-d deployment/llm-d-simple
   
   # Re-run the installer manually
   kubectl delete job -n llm-d llm-d-installer
   terraform apply -target=kubernetes_job.llm_d_installer
   ```

6. **ImagePullBackOff Issues (Should be automatic fixed)**
   ```bash
   # If you still see ImagePullBackOff, check security groups
   ibmcloud is security-group <security-group-id>
   
   # The following rules should exist (added automatically by Terraform):
   # - Inbound TCP 443 (HTTPS)
   # - Inbound TCP 80 (HTTP) 
   # - Inbound UDP 53 (DNS)
   ```

### Logs and Debugging

```bash
# Terraform logs
export TF_LOG=DEBUG
terraform apply

# Kubernetes events
kubectl get events -n llm-d --sort-by='.lastTimestamp'

# Node status
kubectl describe nodes
```

## Cost Estimation

Estimated monthly costs for the default configuration:

- **Worker Nodes**: 3 × bx2.4x16 ≈ $300-400/month
- **Load Balancers**: ≈ $30/month
- **Storage**: ≈ $20-50/month (depending on usage)
- **Total**: ≈ $350-480/month

> **Note**: Costs vary by region and actual usage. Check IBM Cloud pricing for exact rates.

## Cleanup

To destroy all resources:

```bash
# Destroy the infrastructure
terraform destroy

# Confirm when prompted
```

## Support and Contributing

- **LLM-D Documentation**: [GitHub Repository](https://github.com/llm-d-incubation/llm-d-infra)
- **IBM Cloud Kubernetes**: [Official Documentation](https://cloud.ibm.com/docs/containers)
- **Terraform IBM Provider**: [Documentation](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs)

## What's Fixed Automatically

This Terraform configuration includes all the fixes discovered during debugging:

### ✅ Network Connectivity Issues
- **Security Group Rules**: Automatically adds inbound rules for HTTPS (443), HTTP (80), and DNS (53)
- **Container Registry Access**: Uses IBM Container Registry (icr.io) for reliable image pulls
- **Public Gateway**: Ensures subnets have internet access via public gateways

### ✅ Configuration Issues  
- **Resource Group**: Correctly configured for "Default" resource group name
- **Kubernetes Version**: Uses supported version (1.32) with validation
- **Model Configuration**: IBM Granite model properly configured as default

### ✅ Deployment Reliability
- **Dual Deployment**: Simple deployment + installer job for maximum reliability  
- **Service Mesh Ready**: Optional Istio and Kubernetes Gateway API configuration
- **Container Registry**: Configurable registry selection (icr.io recommended)

### ✅ Enterprise Features
- **Production Ready**: All debugging fixes included in infrastructure code
- **Zero Manual Steps**: No manual intervention required after `terraform apply`
- **Configurable Options**: Service mesh, model selection, and registry options

## Security Considerations

1. **API Key Security**: Store your IBM Cloud API key securely, never commit it to version control
2. **Hugging Face Token**: Keep your HF token private, it provides access to your account  
3. **Network Security**: The cluster is deployed with public gateways and security group rules for internet access
4. **RBAC**: The installer uses broad permissions - review and restrict as needed for production
5. **Container Registry**: Uses IBM Container Registry by default for secure image delivery

## License

This project is licensed under the MIT License - see the LICENSE file for details.
