variable "ibmcloud_api_key" {
  description = "IBM Cloud API key for authentication"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "IBM Cloud region where resources will be created"
  type        = string
  default     = "us-south"
  
  validation {
    condition = contains([
      "us-south", "us-east", "eu-gb", "eu-de", "jp-tok", "au-syd", 
      "jp-osa", "br-sao", "ca-tor", "eu-es", "eu-fr2"
    ], var.region)
    error_message = "Region must be a valid IBM Cloud region."
  }
}

variable "resource_group_name" {
  description = "Name of the IBM Cloud resource group"
  type        = string
  default     = "default"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "llm-d-cluster"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
    error_message = "Cluster name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "zones" {
  description = "List of availability zones for the cluster"
  type        = list(string)
  default     = ["us-south-1", "us-south-2", "us-south-3"]
}

variable "worker_flavor" {
  description = "Flavor (size) of worker nodes. bx3d.32x160 provides 32 vCPUs and 160GB RAM - optimized for AI workloads"
  type        = string
  default     = "bx3d.32x160"
  
  validation {
    condition = contains([
      "bx2.2x8", "bx2.4x16", "bx2.8x32", "bx2.16x64", "bx2.32x128",
      "bx3d.4x20", "bx3d.8x40", "bx3d.16x80", "bx3d.24x120", "bx3d.32x160", "bx3d.48x240", "bx3d.64x320",
      "cx2.2x4", "cx2.4x8", "cx2.8x16", "cx2.16x32", "cx2.32x64",
      "mx2.2x16", "mx2.4x32", "mx2.8x64", "mx2.16x128", "mx2.32x256"
    ], var.worker_flavor)
    error_message = "Worker flavor must be a valid IBM Cloud worker node flavor."
  }
}

variable "worker_count_per_zone" {
  description = "Number of worker nodes per zone (total nodes = worker_count_per_zone * number of zones)"
  type        = number
  default     = 1
  
  validation {
    condition     = var.worker_count_per_zone >= 1 && var.worker_count_per_zone <= 10
    error_message = "Worker count per zone must be between 1 and 10."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster"
  type        = string
  default     = "1.32"
  
  validation {
    condition = contains([
      "1.30", "1.31", "1.32", "1.33"
    ], var.kubernetes_version)
    error_message = "Kubernetes version must be a supported version."
  }
}

variable "llm_d_namespace" {
  description = "Kubernetes namespace for LLM-D deployment"
  type        = string
  default     = "llm-d-inference-scheduling"  # Official LLM-D inference scheduling namespace
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.llm_d_namespace))
    error_message = "Namespace must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "huggingface_token" {
  description = "Hugging Face token for model access (REQUIRED for IBM Granite models)"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.huggingface_token) > 0
    error_message = "HF_TOKEN is required. Get your token from: https://huggingface.co/settings/tokens"
  }
}

variable "enable_logging" {
  description = "Enable cluster logging"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable cluster monitoring"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = list(string)
  default     = []
}

variable "enable_istio" {
  description = "Enable Istio service mesh installation"
  type        = bool
  default     = true
}

variable "enable_kgateway" {
  description = "Enable Kubernetes Gateway API"
  type        = bool
  default     = false
}

variable "istio_version" {
  description = "Istio version to install"
  type        = string
  default     = "1.24.1"
}

variable "container_registry" {
  description = "Container registry to use for pulling images"
  type        = string
  default     = "icr.io"
  
  validation {
    condition = contains([
      "docker.io", "icr.io", "quay.io", "ghcr.io"
    ], var.container_registry)
    error_message = "Container registry must be one of: docker.io, icr.io, quay.io, ghcr.io"
  }
}

variable "default_model" {
  description = "Default model to configure for LLM-D deployment"
  type        = string
  default     = "ibm-granite/granite-3.3-8b-instruct"
  
  validation {
    condition = contains([
      "ibm-granite/granite-3.3-8b-instruct",
      "ibm-granite/granite-3.3-2b-instruct",
      "ibm-granite/granite-3.3-1b-instruct",
      "ibm/granite-13b-instruct-v2",
      "ibm/granite-20b-instruct-v1",
      "meta-llama/Llama-2-7b-chat-hf",
      "meta-llama/Llama-2-13b-chat-hf"
    ], var.default_model)
    error_message = "Model must be a supported model identifier."
  }
}

variable "model_config" {
  description = "Additional model configuration parameters"
  type = object({
    max_tokens    = optional(number, 4096)
    temperature   = optional(number, 0.7)
    top_p        = optional(number, 0.9)
    repetition_penalty = optional(number, 1.1)
  })
  default = {
    max_tokens    = 4096
    temperature   = 0.7
    top_p        = 0.9
    repetition_penalty = 1.1
  }
}

variable "outbound_traffic_protection" {
  description = "Enable outbound traffic protection (blocks internet access from worker nodes)"
  type        = bool
  default     = false  # Disabled to allow container image pulls and LLM-D functionality
}
