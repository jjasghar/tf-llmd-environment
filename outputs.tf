output "cluster_id" {
  description = "ID of the created Kubernetes cluster"
  value       = ibm_container_vpc_cluster.llm_d_cluster.id
}

output "cluster_name" {
  description = "Name of the created Kubernetes cluster"
  value       = ibm_container_vpc_cluster.llm_d_cluster.name
}

output "cluster_endpoint" {
  description = "Kubernetes cluster endpoint URL"
  value       = data.ibm_container_cluster_config.cluster_config.host
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate"
  value       = data.ibm_container_cluster_config.cluster_config.ca_certificate
  sensitive   = true
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = ibm_is_vpc.llm_d_vpc.id
}

output "subnet_ids" {
  description = "IDs of the created subnets"
  value       = ibm_is_subnet.llm_d_subnet[*].id
}

output "public_gateway_ids" {
  description = "IDs of the created public gateways"
  value       = ibm_is_public_gateway.llm_d_gateway[*].id
}

output "llm_d_namespace" {
  description = "Kubernetes namespace for LLM-D deployment"
  value       = "default"  # Using default namespace to avoid RBAC issues
}

output "kubectl_config_command" {
  description = "Command to configure kubectl for the cluster"
  value       = "ibmcloud ks cluster config --cluster ${ibm_container_vpc_cluster.llm_d_cluster.id}"
}

output "cluster_info" {
  description = "Summary of cluster information"
  value = {
    name             = ibm_container_vpc_cluster.llm_d_cluster.name
    id               = ibm_container_vpc_cluster.llm_d_cluster.id
    region           = var.region
    worker_flavor    = var.worker_flavor
    total_nodes      = var.worker_count_per_zone * length(var.zones)
    kubernetes_version = var.kubernetes_version
    llm_d_namespace  = "default"  # Using default namespace to avoid RBAC issues
    default_model    = var.default_model
  }
}

output "model_configuration" {
  description = "LLM-D model configuration details"
  value = {
    default_model        = var.default_model
    max_tokens          = var.model_config.max_tokens
    temperature         = var.model_config.temperature
    top_p              = var.model_config.top_p
    repetition_penalty  = var.model_config.repetition_penalty
  }
}
