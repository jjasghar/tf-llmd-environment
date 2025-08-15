# LLM-D Infrastructure Deployment Configuration
# This file contains Kubernetes resources for deploying LLM-D components

# Create a working LLM-D deployment
resource "kubernetes_deployment" "llm_d_simple" {
  depends_on = [kubernetes_namespace.llm_d_namespace, kubernetes_config_map.llm_d_model_config]
  
  metadata {
    name      = "llm-d-simple"
    namespace = var.llm_d_namespace
    
    labels = {
      "app.kubernetes.io/name"       = "llm-d"
      "app.kubernetes.io/component"  = "inference-server"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    replicas = 1
    
    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "llm-d"
        "app.kubernetes.io/component" = "inference-server"
      }
    }
    
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "llm-d"
          "app.kubernetes.io/component" = "inference-server"
        }
      }
      
      spec {
        container {
          name  = "inference-server"
          image = "${var.container_registry}/codeengine/hello"
          
          port {
            container_port = 8080
          }
          
          env {
            name  = "MODEL_NAME"
            value = var.default_model
          }
          
          env {
            name  = "MAX_TOKENS"
            value = tostring(var.model_config.max_tokens)
          }
          
          env {
            name  = "TEMPERATURE"
            value = tostring(var.model_config.temperature)
          }
          
          resources {
            requests = {
              memory = "2Gi"
              cpu    = "1"
            }
            limits = {
              memory = "8Gi"
              cpu    = "4"
            }
          }
        }
      }
    }
  }
}

# Create service for LLM-D
resource "kubernetes_service" "llm_d_service" {
  depends_on = [kubernetes_deployment.llm_d_simple]
  
  metadata {
    name      = "llm-d-service"
    namespace = var.llm_d_namespace
    
    labels = {
      "app.kubernetes.io/name"       = "llm-d"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "llm-d"
      "app.kubernetes.io/component" = "inference-server"
    }
    
    port {
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }
    
    type = "ClusterIP"
  }
}

# Create a job to clone and install LLM-D infrastructure (fallback installer)
resource "kubernetes_job" "llm_d_installer" {
  depends_on = [kubernetes_namespace.llm_d_namespace, kubernetes_secret.huggingface_token, kubernetes_config_map.llm_d_model_config]
  
  metadata {
    name      = "llm-d-installer"
    namespace = var.llm_d_namespace
    
    labels = {
      "app.kubernetes.io/name"       = "llm-d-installer"
      "app.kubernetes.io/component"  = "installer"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  wait_for_completion = false

  spec {
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "llm-d-installer"
          "app.kubernetes.io/component" = "installer"
        }
      }
      
      spec {
        restart_policy = "Never"
        
        # Service account for installer
        service_account_name = kubernetes_service_account.llm_d_installer.metadata[0].name
        
        init_container {
          name  = "git-clone"
          image = "${var.container_registry}/codeengine/alpine:latest"
          
          command = [
            "sh", "-c",
            "apk add --no-cache git curl && git clone https://github.com/llm-d-incubation/llm-d-infra.git /workspace && ls -la /workspace"
          ]
          
          volume_mount {
            name       = "workspace"
            mount_path = "/workspace"
          }
        }
        
        container {
          name  = "llm-d-installer"
          image = "${var.container_registry}/codeengine/ubuntu:latest"
          
          command = [
            "sh", "-c", 
            <<-EOF
            # Install required tools
            apt-get update && apt-get install -y curl wget
            
            # Install kubectl
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl && mv kubectl /usr/local/bin/
            
            cd /workspace/quickstart
            
            # Set executable permissions
            chmod +x ./llmd-installer.sh
            
            # Set environment variables
            export HF_TOKEN="$HF_TOKEN_VALUE"
            export DEFAULT_MODEL="$DEFAULT_MODEL_VALUE"
            export MODEL_MAX_TOKENS="$MODEL_MAX_TOKENS_VALUE"
            export MODEL_TEMPERATURE="$MODEL_TEMPERATURE_VALUE"
            export MODEL_TOP_P="$MODEL_TOP_P_VALUE"
            export MODEL_REPETITION_PENALTY="$MODEL_REPETITION_PENALTY_VALUE"
            export ENABLE_ISTIO="$ENABLE_ISTIO_VALUE"
            export ENABLE_KGATEWAY="$ENABLE_KGATEWAY_VALUE"
            export ISTIO_VERSION="$ISTIO_VERSION_VALUE"
            
            echo "Configuring LLM-D with IBM Granite model: $DEFAULT_MODEL"
            echo "Model configuration:"
            echo "  - Model: $DEFAULT_MODEL"
            echo "  - Max Tokens: $MODEL_MAX_TOKENS"
            echo "  - Temperature: $MODEL_TEMPERATURE"
            echo "  - Top P: $MODEL_TOP_P"
            echo "  - Repetition Penalty: $MODEL_REPETITION_PENALTY"
            echo "  - Istio Enabled: $ENABLE_ISTIO"
            echo "  - K-Gateway Enabled: $ENABLE_KGATEWAY"
            
            # Create custom configuration file for Granite model
            cat > model-override.yaml << EOL
apiVersion: v1
kind: ConfigMap
metadata:
  name: model-override-config
  namespace: llm-d
data:
  config.yaml: |
    models:
      - name: "$DEFAULT_MODEL"
        model_id: "$DEFAULT_MODEL"
        max_tokens: $MODEL_MAX_TOKENS
        temperature: $MODEL_TEMPERATURE
        top_p: $MODEL_TOP_P
        repetition_penalty: $MODEL_REPETITION_PENALTY
        trust_remote_code: true
        torch_dtype: "auto"
        device_map: "auto"
    default_model: "$DEFAULT_MODEL"
    istio:
      enabled: $ENABLE_ISTIO
      version: "$ISTIO_VERSION"
    kgateway:
      enabled: $ENABLE_KGATEWAY
EOL
            
            # Apply the model configuration
            kubectl apply -f model-override.yaml || echo "Warning: Could not apply model override config"
            
            # Install Istio if enabled
            if [ "$ENABLE_ISTIO" = "true" ]; then
              echo "Installing Istio service mesh..."
              curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
              export PATH=$PWD/istio-$ISTIO_VERSION/bin:$PATH
              istioctl install --set values.defaultRevision=default -y
              kubectl label namespace default istio-injection=enabled
              kubectl label namespace llm-d istio-injection=enabled
            fi
            
            # Install Kubernetes Gateway API if enabled
            if [ "$ENABLE_KGATEWAY" = "true" ]; then
              echo "Installing Kubernetes Gateway API..."
              kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
            fi
            
            # Run the installer
            echo "Starting LLM-D installation with IBM Granite model..."
            ./llmd-installer.sh
            
            echo "LLM-D installation with IBM Granite model completed successfully"
            EOF
          ]
          
          env {
            name = "HF_TOKEN_VALUE"
            value_from {
              secret_key_ref {
                name     = var.huggingface_token != "" ? "huggingface-token" : "empty-secret"
                key      = "token"
                optional = true
              }
            }
          }
          
          env {
            name = "DEFAULT_MODEL_VALUE"
            value_from {
              config_map_key_ref {
                name = "llm-d-model-config"
                key  = "default_model"
              }
            }
          }
          
          env {
            name = "MODEL_MAX_TOKENS_VALUE"
            value_from {
              config_map_key_ref {
                name = "llm-d-model-config"
                key  = "max_tokens"
              }
            }
          }
          
          env {
            name = "MODEL_TEMPERATURE_VALUE"
            value_from {
              config_map_key_ref {
                name = "llm-d-model-config"
                key  = "temperature"
              }
            }
          }
          
          env {
            name = "MODEL_TOP_P_VALUE"
            value_from {
              config_map_key_ref {
                name = "llm-d-model-config"
                key  = "top_p"
              }
            }
          }
          
          env {
            name = "MODEL_REPETITION_PENALTY_VALUE"
            value_from {
              config_map_key_ref {
                name = "llm-d-model-config"
                key  = "repetition_penalty"
              }
            }
          }
          
          env {
            name  = "ENABLE_ISTIO_VALUE"
            value = tostring(var.enable_istio)
          }
          
          env {
            name  = "ENABLE_KGATEWAY_VALUE"
            value = tostring(var.enable_kgateway)
          }
          
          env {
            name  = "ISTIO_VERSION_VALUE"
            value = var.istio_version
          }
          
          volume_mount {
            name       = "workspace"
            mount_path = "/workspace"
          }
          
          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
        
        volume {
          name = "workspace"
          empty_dir {}
        }
      }
    }
    
    backoff_limit = 3
  }
}

# Service account for the installer
resource "kubernetes_service_account" "llm_d_installer" {
  depends_on = [kubernetes_namespace.llm_d_namespace]
  
  metadata {
    name      = "llm-d-installer"
    namespace = var.llm_d_namespace
    
    labels = {
      "app.kubernetes.io/name"       = "llm-d-installer"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# Cluster role for the installer
resource "kubernetes_cluster_role" "llm_d_installer" {
  metadata {
    name = "llm-d-installer"
    
    labels = {
      "app.kubernetes.io/name"       = "llm-d-installer"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "services", "configmaps", "secrets", "persistentvolumes", "persistentvolumeclaims"]
    verbs      = ["get", "list", "create", "update", "patch", "delete"]
  }
  
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "daemonsets", "statefulsets"]
    verbs      = ["get", "list", "create", "update", "patch", "delete"]
  }
  
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses", "networkpolicies"]
    verbs      = ["get", "list", "create", "update", "patch", "delete"]
  }
  
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    verbs      = ["get", "list", "create", "update", "patch", "delete"]
  }
  
  rule {
    api_groups = ["extensions"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

# Cluster role binding for the installer
resource "kubernetes_cluster_role_binding" "llm_d_installer" {
  metadata {
    name = "llm-d-installer"
    
    labels = {
      "app.kubernetes.io/name"       = "llm-d-installer"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.llm_d_installer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.llm_d_installer.metadata[0].name
    namespace = var.llm_d_namespace
  }
}

# Create an empty secret as fallback when no HuggingFace token is provided
resource "kubernetes_secret" "empty_secret" {
  count      = var.huggingface_token == "" ? 1 : 0
  depends_on = [kubernetes_namespace.llm_d_namespace]

  metadata {
    name      = "empty-secret"
    namespace = var.llm_d_namespace
  }

  data = {
    token = ""
  }

  type = "Opaque"
}
