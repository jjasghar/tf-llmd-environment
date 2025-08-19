# Real LLM-D Infrastructure Deployment Configuration
# This file contains Kubernetes resources for deploying actual LLM-D with real AI inference

# Create namespace for LLM-D
resource "kubernetes_namespace" "llm_d_namespace" {
  metadata {
    name = var.llm_d_namespace
    
    labels = {
      "app.kubernetes.io/name"       = "llm-d"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Create service account for LLM-D
resource "kubernetes_service_account" "llm_d_service_account" {
  depends_on = [kubernetes_namespace.llm_d_namespace]
  
  metadata {
    name      = "llm-d-service-account"
    namespace = var.llm_d_namespace
    
    labels = {
      "app.kubernetes.io/name"       = "llm-d"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Create cluster role for LLM-D operations
resource "kubernetes_cluster_role" "llm_d_cluster_role" {
  metadata {
    name = "llm-d-cluster-role"
    
    labels = {
      "app.kubernetes.io/name"       = "llm-d"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps", "secrets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
  
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

# Bind cluster role to service account
resource "kubernetes_cluster_role_binding" "llm_d_cluster_role_binding" {
  depends_on = [kubernetes_service_account.llm_d_service_account, kubernetes_cluster_role.llm_d_cluster_role]
  
  metadata {
    name = "llm-d-cluster-role-binding"
    
    labels = {
      "app.kubernetes.io/name"       = "llm-d"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.llm_d_cluster_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.llm_d_service_account.metadata[0].name
    namespace = var.llm_d_namespace
  }
}

# Note: LLM-D components will be installed separately after infrastructure deployment
# This allows for more reliable installation and better separation of concerns

# Note: Services and deployments will be created by the official LLM-D installer
# The LLM-D infrastructure includes gateway, vLLM, monitoring, and inference components

# Create HuggingFace token secret (required for IBM Granite models)
resource "kubernetes_secret" "huggingface_token" {
  depends_on = [kubernetes_namespace.llm_d_namespace]

  metadata {
    name      = "huggingface-token"
    namespace = var.llm_d_namespace
    
    labels = {
      "app.kubernetes.io/name"       = "llm-d"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    token = var.huggingface_token
  }

  type = "Opaque"
}