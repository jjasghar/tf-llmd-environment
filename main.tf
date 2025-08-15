

# Configure the IBM Cloud Provider
provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

# Data source to get resource group
data "ibm_resource_group" "resource_group" {
  name = var.resource_group_name
}

# Create VPC
resource "ibm_is_vpc" "llm_d_vpc" {
  name                      = "${var.cluster_name}-vpc"
  resource_group            = data.ibm_resource_group.resource_group.id
  address_prefix_management = "auto"

  tags = [
    "terraform",
    "llm-d",
    "kubernetes"
  ]
}

# Create subnets in different zones for high availability
resource "ibm_is_subnet" "llm_d_subnet" {
  count                    = length(var.zones)
  name                     = "${var.cluster_name}-subnet-${count.index + 1}"
  vpc                      = ibm_is_vpc.llm_d_vpc.id
  zone                     = var.zones[count.index]
  total_ipv4_address_count = 256
  resource_group           = data.ibm_resource_group.resource_group.id

  tags = [
    "terraform",
    "llm-d",
    "kubernetes"
  ]
}

# Create public gateway for internet access
resource "ibm_is_public_gateway" "llm_d_gateway" {
  count          = length(var.zones)
  name           = "${var.cluster_name}-gateway-${count.index + 1}"
  vpc            = ibm_is_vpc.llm_d_vpc.id
  zone           = var.zones[count.index]
  resource_group = data.ibm_resource_group.resource_group.id

  tags = [
    "terraform",
    "llm-d",
    "kubernetes"
  ]
}

# Attach public gateway to subnets
resource "ibm_is_subnet_public_gateway_attachment" "llm_d_pgw_attachment" {
  count          = length(var.zones)
  subnet         = ibm_is_subnet.llm_d_subnet[count.index].id
  public_gateway = ibm_is_public_gateway.llm_d_gateway[count.index].id
}

# Get the default security group for the VPC
data "ibm_is_vpc" "llm_d_vpc_data" {
  name = ibm_is_vpc.llm_d_vpc.name
}

# Add security group rules for container registry and DNS access
resource "ibm_is_security_group_rule" "allow_inbound_https" {
  group     = data.ibm_is_vpc.llm_d_vpc_data.default_security_group
  direction = "inbound"
  remote    = "0.0.0.0/0"
  
  tcp {
    port_min = 443
    port_max = 443
  }
}

resource "ibm_is_security_group_rule" "allow_inbound_http" {
  group     = data.ibm_is_vpc.llm_d_vpc_data.default_security_group
  direction = "inbound"
  remote    = "0.0.0.0/0"
  
  tcp {
    port_min = 80
    port_max = 80
  }
}

resource "ibm_is_security_group_rule" "allow_inbound_dns" {
  group     = data.ibm_is_vpc.llm_d_vpc_data.default_security_group
  direction = "inbound"
  remote    = "0.0.0.0/0"
  
  udp {
    port_min = 53
    port_max = 53
  }
}

# Create Kubernetes cluster
resource "ibm_container_vpc_cluster" "llm_d_cluster" {
  name                         = var.cluster_name
  vpc_id                       = ibm_is_vpc.llm_d_vpc.id
  flavor                       = var.worker_flavor
  worker_count                 = var.worker_count_per_zone
  resource_group_id            = data.ibm_resource_group.resource_group.id
  kube_version                 = var.kubernetes_version
  wait_till                    = "MasterNodeReady"
  disable_outbound_traffic_protection = !var.outbound_traffic_protection

  dynamic "zones" {
    for_each = range(length(var.zones))
    content {
      subnet_id = ibm_is_subnet.llm_d_subnet[zones.value].id
      name      = var.zones[zones.value]
    }
  }

  tags = [
    "terraform",
    "llm-d",
    "kubernetes"
  ]
}

# Wait for cluster to be ready
resource "time_sleep" "wait_for_cluster" {
  depends_on = [ibm_container_vpc_cluster.llm_d_cluster]
  create_duration = "600s" # Wait 10 minutes for cluster to be fully ready
}

# Configure Kubernetes provider with admin access
provider "kubernetes" {
  host                   = data.ibm_container_cluster_config.cluster_config.host
  token                  = data.ibm_container_cluster_config.cluster_config.token
  cluster_ca_certificate = data.ibm_container_cluster_config.cluster_config.ca_certificate
  
  # Use admin certificate for full cluster access
  client_certificate     = data.ibm_container_cluster_config.cluster_config.admin_certificate
  client_key            = data.ibm_container_cluster_config.cluster_config.admin_key
}

# Configure Helm provider with admin access
provider "helm" {
  kubernetes {
    host                   = data.ibm_container_cluster_config.cluster_config.host
    token                  = data.ibm_container_cluster_config.cluster_config.token
    cluster_ca_certificate = data.ibm_container_cluster_config.cluster_config.ca_certificate
    
    # Use admin certificate for full cluster access
    client_certificate     = data.ibm_container_cluster_config.cluster_config.admin_certificate
    client_key            = data.ibm_container_cluster_config.cluster_config.admin_key
  }
}

# Get cluster configuration with admin access
data "ibm_container_cluster_config" "cluster_config" {
  depends_on = [time_sleep.wait_for_cluster]
  cluster_name_id = ibm_container_vpc_cluster.llm_d_cluster.id
  admin = true  # Enable admin access for full RBAC permissions
}

# Note: Using default namespace to avoid RBAC permission issues
# The default namespace is automatically available and doesn't require creation

# Create secret for Hugging Face token (if provided)
resource "kubernetes_secret" "huggingface_token" {
  count      = var.huggingface_token != "" ? 1 : 0
  depends_on = [time_sleep.wait_for_cluster]
  
  metadata {
    name      = "huggingface-token"
    namespace = "default"  # Using default namespace to avoid RBAC issues
  }

  data = {
    token = var.huggingface_token
  }

  type = "Opaque"
}

# Create ConfigMap for LLM-D model configuration
resource "kubernetes_config_map" "llm_d_model_config" {
  depends_on = [time_sleep.wait_for_cluster]
  
  metadata {
    name      = "llm-d-model-config"
    namespace = "default"  # Using default namespace to avoid RBAC issues
    
    labels = {
      "app.kubernetes.io/name"       = "llm-d"
      "app.kubernetes.io/component"  = "model-config"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "default_model"        = var.default_model
    "max_tokens"          = tostring(var.model_config.max_tokens)
    "temperature"         = tostring(var.model_config.temperature)
    "top_p"              = tostring(var.model_config.top_p)
    "repetition_penalty"  = tostring(var.model_config.repetition_penalty)
    "model_config.yaml"   = yamlencode({
      models = {
        default = {
          name               = var.default_model
          max_tokens         = var.model_config.max_tokens
          temperature        = var.model_config.temperature
          top_p             = var.model_config.top_p
          repetition_penalty = var.model_config.repetition_penalty
          trust_remote_code  = true
          torch_dtype       = "auto"
          device_map        = "auto"
        }
      }
      inference = {
        default_model = var.default_model
        batch_size   = 1
        max_batch_wait_time = 100
      }
    })
  }
}

# Note: Storage class creation requires cluster-admin permissions
# Using default storage class provided by IBM Cloud Kubernetes
