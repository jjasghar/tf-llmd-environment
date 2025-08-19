# 🚀 LLM-D on IBM Cloud Kubernetes

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-623CE4?logo=terraform)](https://www.terraform.io/)
[![IBM Cloud](https://img.shields.io/badge/IBM%20Cloud-VPC%20Gen2-1261FE?logo=ibm)](https://www.ibm.com/cloud/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.32+-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![LLM-D](https://img.shields.io/badge/LLM--D-v0.2-FF6B35)](https://llm-d.ai/)
[![vLLM](https://img.shields.io/badge/vLLM-Enabled-00D4AA)](https://github.com/vllm-project/vllm)

This repository provides a **production-ready Terraform configuration** for deploying the official [LLM-D v0.2 infrastructure](https://llm-d.ai/) on IBM Cloud Kubernetes with **high-performance AI workload optimization**. 

## What This Repository Provides

### **Official LLM-D v0.2 Infrastructure**
- **Real LLM-D Deployment**: Official LLM-D v0.2 with vLLM support and inference scheduling
- **Gateway API**: kgateway provider with intelligent routing and load balancing
- **Inference Scheduling**: Load-aware and prefix-cache-aware balancing for optimal performance
- **Monitoring**: Prometheus and Grafana integration for observability
- **Production-Ready**: Follows official LLM-D deployment patterns

### **High-Performance IBM Cloud Infrastructure**
- **Ultra-High-Performance Nodes**: 3 × bx3d.32x160 (32 vCPUs, 160GB RAM each)
- **Total Resources**: 96 vCPUs, 480GB RAM (optimized for large language models)
- **Multi-Zone Deployment**: High availability across 3 availability zones
- **VPC Networking**: Full VPC with subnets, public gateways, and security groups
- **Scalable Design**: Easy to scale up for even higher performance requirements

### **Separated Architecture (Best Practices)**
- **Infrastructure Provisioning**: Terraform handles cluster and networking
- **LLM-D Installation**: Separate script follows official installation process
- **Clean Separation**: Reliable deployment with proper error handling
- **Official Process**: Exactly follows LLM-D documentation patterns

## 🚀 Quick Start - Deploy in 30 Minutes

### **Step 1: Infrastructure Deployment**
```bash
# Clone and configure
git clone https://github.com/jjasghar/tf-llmd-environment.git
cd tf-llmd-environment
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your IBM Cloud API key and HF_TOKEN
# Then deploy infrastructure:
terraform apply --auto-approve
```

### **Step 2: LLM-D Installation**
```bash
# Configure kubectl (use output from terraform)
terraform output kubectl_config_command
# Run the command shown in output

# Install official LLM-D infrastructure
export HF_TOKEN=your_huggingface_token
./scripts/install-llm-d.sh
```

### **Total Deployment Time**: ~35 minutes
- Infrastructure: ~22 minutes
- LLM-D Installation: ~15 minutes

## 📋 Prerequisites

### **Required**
- IBM Cloud account with API key ([Get yours here](https://cloud.ibm.com/iam/apikeys))
- HuggingFace token ([Get yours here](https://huggingface.co/settings/tokens))
- Terraform >= 1.0
- IBM Cloud CLI (`ibmcloud`)

### **Auto-Installed by Scripts**
- kubectl (compatible version)
- yq, jq, helm, helmfile, kustomize

## ⚙️ Configuration

### **Required Variables (terraform.tfvars)**
```hcl
# IBM Cloud authentication
ibmcloud_api_key = "your-ibm-cloud-api-key-here"

# HuggingFace token (REQUIRED for IBM Granite models)
huggingface_token = "your-huggingface-token-here"

# Basic configuration
region = "us-south"
resource_group_name = "Default"
cluster_name = "llm-d-cluster"
```

### **High-Performance Defaults**
```hcl
# Optimized for AI workloads
worker_flavor = "bx3d.32x160"          # 32 vCPUs, 160GB RAM per node
worker_count_per_zone = 1              # 3 total nodes across 3 zones
default_model = "ibm-granite/granite-3.3-8b-instruct"
kubernetes_version = "1.32"

# LLM-D configuration
llm_d_namespace = "llm-d-inference-scheduling"  # Official namespace

# Model configuration
model_config = {
  max_tokens         = 4096
  temperature        = 0.7
  top_p             = 0.9
  repetition_penalty = 1.1
}
```

## 🧪 Testing LLM-D

### **Quick API Test**
```bash
# Test the deployment
./scripts/test-llm-d-api.sh
```

### **Manual Testing**
```bash
# Port forward to access LLM-D
kubectl port-forward -n llm-d-inference-scheduling \
  service/infra-inference-scheduling-inference-gateway 8000:80 &

# Test models endpoint
curl -s http://localhost:8000/v1/models \
  -H "Content-Type: application/json" | jq .

# Test inference endpoint
curl -s http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ibm-granite/granite-3.3-8b-instruct",
    "prompt": "What is artificial intelligence?",
    "max_tokens": 100
  }' | jq .
```

## 📊 Architecture

### **High-Level Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│                    IBM Cloud VPC                           │
│  ┌─────────────────┬─────────────────┬─────────────────┐    │
│  │   us-south-1    │   us-south-2    │   us-south-3    │    │
│  │                 │                 │                 │    │
│  │  ┌───────────┐  │  ┌───────────┐  │  ┌───────────┐  │    │
│  │  │bx3d.32x160│  │  │bx3d.32x160│  │  │bx3d.32x160│  │    │
│  │  │32 vCPUs   │  │  │32 vCPUs   │  │  │32 vCPUs   │  │    │
│  │  │160GB RAM  │  │  │160GB RAM  │  │  │160GB RAM  │  │    │
│  │  └───────────┘  │  └───────────┘  │  └───────────┘  │    │
│  └─────────────────┴─────────────────┴─────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────────────────┐
                    │  LLM-D v0.2 Stack   │
                    │                     │
                    │  ┌───────────────┐  │
                    │  │   Gateway     │  │
                    │  │   (kgateway)  │  │
                    │  └───────────────┘  │
                    │  ┌───────────────┐  │
                    │  │ Inference     │  │
                    │  │ Scheduling    │  │
                    │  └───────────────┘  │
                    │  ┌───────────────┐  │
                    │  │ vLLM Engine   │  │
                    │  │ IBM Granite   │  │
                    │  └───────────────┘  │
                    └─────────────────────┘
```

### **LLM-D Components**
- **Gateway**: Envoy-based gateway with intelligent routing
- **Inference Pool**: Load-aware request distribution
- **Model Service**: vLLM-powered inference engine
- **Monitoring**: Prometheus metrics and Grafana dashboards

## 🛠️ Scripts

### **Essential Scripts**
| Script | Purpose | Usage |
|--------|---------|-------|
| `install-llm-d.sh` | Install official LLM-D infrastructure | `export HF_TOKEN=token && ./scripts/install-llm-d.sh` |
| `test-llm-d-api.sh` | Test LLM-D API endpoints | `./scripts/test-llm-d-api.sh` |
| `quick-start.sh` | Interactive Terraform deployment | `./scripts/quick-start.sh` |
| `verify-deployment.sh` | Verify infrastructure status | `./scripts/verify-deployment.sh` |

## 🎯 API Endpoints

### **Base URL**
```
http://localhost:8000  # via port-forward
```

### **Available Endpoints (vLLM-Compatible)**

#### `GET /v1/models` - List Available Models
```bash
curl -s http://localhost:8000/v1/models \
  -H "Content-Type: application/json" | jq .
```

#### `POST /v1/completions` - Text Completion
```bash
curl -s http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ibm-granite/granite-3.3-8b-instruct",
    "prompt": "Explain quantum computing",
    "max_tokens": 150,
    "temperature": 0.7
  }' | jq .
```

## 📊 Performance Specifications

### **Infrastructure Performance**
- **Cluster**: 3 nodes × bx3d.32x160 (32 vCPUs, 160GB RAM each)
- **Total Resources**: 96 vCPUs, 480GB RAM
- **Network**: Multi-zone VPC with high-bandwidth connectivity
- **Storage**: VPC Block Storage with optimized IOPS

### **LLM-D Performance Features**
- **vLLM Engine**: High-performance inference engine
- **Inference Scheduling**: Load-aware and prefix-cache-aware routing
- **Intelligent Load Balancing**: Reduces tail latency and increases throughput
- **Monitoring**: Real-time metrics and observability

### **Scaling Options**
```hcl
# For even higher performance:
worker_flavor = "bx3d.48x240"  # 48 vCPUs, 240GB RAM
worker_flavor = "bx3d.64x320"  # 64 vCPUs, 320GB RAM

# For production redundancy:
worker_count_per_zone = 2      # 6 total nodes
```

## 🔧 Advanced Configuration

### **Model Selection**
```hcl
# Supported IBM Granite models
default_model = "ibm-granite/granite-3.3-8b-instruct"  # Default (recommended)
default_model = "ibm-granite/granite-3.3-2b-instruct"  # Smaller, faster
default_model = "ibm-granite/granite-3.3-1b-instruct"  # Lightweight
```

### **Performance Tuning**
```hcl
# High-throughput configuration
model_config = {
  max_tokens = 2048           # Faster inference
  temperature = 0.5           # More focused responses
  top_p = 0.8                # Balanced creativity
}
```

## 🚀 Deployment Process

### **What Happens During Deployment:**

**Phase 1: Infrastructure (Terraform)**
1. **VPC Creation** (~2 minutes): Network, subnets, security groups
2. **Cluster Provisioning** (~12 minutes): High-performance Kubernetes cluster
3. **RBAC Setup** (~1 minute): Service accounts and cluster roles
4. **Prerequisites** (~5 minutes): Namespace and secrets

**Phase 2: LLM-D Installation (Script)**
1. **Dependency Installation** (~3 minutes): kubectl, helm, kustomize, etc.
2. **Infrastructure Components** (~5 minutes): Gateway API, kgateway provider
3. **LLM-D Deployment** (~7 minutes): Official charts and inference scheduling
4. **Model Service** (~5 minutes): vLLM engine and model configuration

## 🔍 Monitoring and Observability

### **Health Checks**
```bash
# Check all components
kubectl get pods,services -n llm-d-inference-scheduling

# Check Helm releases
helm list -n llm-d-inference-scheduling

# Test API health
./scripts/test-llm-d-api.sh
```

### **Log Monitoring**
```bash
# Gateway logs
kubectl logs -n llm-d-inference-scheduling deployment/infra-inference-scheduling-inference-gateway -f

# Model service logs
kubectl logs -n llm-d-inference-scheduling deployment/ms-inference-scheduling-llm-d-modelservice-epp -f

# Inference pool logs
kubectl logs -n llm-d-inference-scheduling deployment/gaie-inference-scheduling-epp -f
```

### **Resource Monitoring**
```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -n llm-d-inference-scheduling

# Cluster resource overview
kubectl describe nodes | grep -A 10 "Allocated resources"
```

## 🛠️ Management Commands

### **Deploy Everything**
```bash
terraform apply --auto-approve
export HF_TOKEN=your_token
./scripts/install-llm-d.sh
```

### **Test LLM-D API**
```bash
./scripts/test-llm-d-api.sh
```

### **Scale Infrastructure**
```bash
# Edit terraform.tfvars to change worker_flavor or worker_count_per_zone
terraform apply
```

### **Update LLM-D**
```bash
# Re-run LLM-D installation
export HF_TOKEN=your_token
./scripts/install-llm-d.sh
```

### **Cleanup**
```bash
terraform destroy --auto-approve
```

## 🎯 Use Cases

### **Enterprise AI Applications**
- **Chatbots and Conversational AI**: High-performance inference for customer service
- **Content Generation**: Automated content creation with IBM Granite models
- **Code Generation**: AI-powered development assistance
- **Document Processing**: Intelligent document analysis and summarization

### **Research and Development**
- **Model Evaluation**: Test different prompting strategies and configurations
- **Performance Benchmarking**: Measure inference latency and throughput
- **AI Experimentation**: Prototype new AI-powered features

### **Production Workloads**
- **API Services**: RESTful AI inference endpoints
- **Batch Processing**: Large-scale AI inference jobs
- **Real-time Applications**: Low-latency AI responses
- **Multi-tenant Systems**: Isolated AI services per customer

## 📈 Performance Metrics

### **Infrastructure Performance**
- **Deployment Time**: ~35 minutes total (infrastructure + LLM-D)
- **Node Performance**: 32 vCPUs, 160GB RAM per node
- **Network Bandwidth**: Up to 32Gbps per node
- **High Availability**: Multi-zone deployment with automatic failover

### **LLM-D Performance**
- **API Compatibility**: Full vLLM-compatible API
- **Inference Scheduling**: Intelligent request routing
- **Load Balancing**: Optimized for throughput and latency
- **Monitoring**: Real-time metrics and alerting

## 🔧 Troubleshooting

### **Common Issues**

**Infrastructure Deployment**
- **VPC Name Conflicts**: Terraform uses timestamps to ensure uniqueness
- **Resource Limits**: Ensure sufficient quota for bx3d.32x160 nodes
- **kubectl Version**: Script automatically handles version compatibility

**LLM-D Installation**
- **HF_TOKEN Required**: Must be set as environment variable
- **Dependency Installation**: Script handles all required tools
- **Model Loading**: Large models may take 10-15 minutes to load

**API Testing**
- **Gateway Initialization**: Allow 2-3 minutes for gateway to be ready
- **Model Availability**: Check pod logs for model loading status
- **Port Forwarding**: Ensure no conflicts on local port 8000

### **Verification Commands**
```bash
# Check cluster health
kubectl get nodes

# Check LLM-D status
kubectl get pods -n llm-d-inference-scheduling

# Test API endpoints
./scripts/test-llm-d-api.sh

# Check logs for issues
kubectl logs -n llm-d-inference-scheduling deployment/infra-inference-scheduling-inference-gateway
```

## 📚 Technical Details

### **LLM-D Components Deployed**
- **llm-d-infra** (v1.2.4): Core infrastructure charts
- **inferencepool** (v0.5.1): Gateway API inference extension
- **kgateway** (v2.0.4): Gateway provider for intelligent routing
- **llm-d-modelservice** (v0.2.0): Model service with vLLM integration

### **IBM Granite Model Integration**
- **Model**: `ibm-granite/granite-3.3-8b-instruct`
- **vLLM Backend**: High-performance inference engine
- **Resource Allocation**: 24-80Gi RAM, 16-28 vCPUs per model service
- **Inference Scheduling**: Load-aware routing for optimal performance

### **Network Configuration**
- **Gateway Service**: NodePort with intelligent routing
- **Internal Communication**: ClusterIP services for component communication
- **External Access**: Port forwarding for development and testing
- **Security**: Proper RBAC and network policies
## 📚 Additional Resources

- [LLM-D Official Documentation](https://llm-d.ai/)
- [LLM-D Infrastructure Repository](https://github.com/llm-d-incubation/llm-d-infra)
- [IBM Granite Models](https://huggingface.co/ibm-granite/granite-3.3-8b-instruct)
- [vLLM Documentation](https://docs.vllm.ai/)
- [IBM Cloud Kubernetes Service](https://www.ibm.com/cloud/kubernetes-service)

## 🤝 Contributing

This repository provides production-ready LLM-D infrastructure. For contributions:

1. Fork the repository
2. Create a feature branch
3. Test with real LLM-D deployment
4. Submit a pull request

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details.

## 🎉 Acknowledgments

- **LLM-D Team**: For the excellent v0.2 infrastructure and vLLM integration
- **IBM Granite Team**: For the powerful foundation models
- **vLLM Project**: For high-performance inference capabilities
- **IBM Cloud**: For ultra-high-performance Kubernetes infrastructure

---

**🚀 Ready to deploy production LLM-D? Run `terraform apply --auto-approve` and get official LLM-D v0.2 with IBM Granite in ~35 minutes!**