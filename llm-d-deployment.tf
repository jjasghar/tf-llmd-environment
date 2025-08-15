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

# Create real LLM-D deployment with IBM Granite model
resource "kubernetes_deployment" "llm_d_granite" {
  depends_on = [
    kubernetes_config_map.llm_d_model_config,
    kubernetes_service_account.llm_d_service_account,
    kubernetes_cluster_role_binding.llm_d_cluster_role_binding
  ]
  
  metadata {
    name      = "llm-d-granite"
    namespace = var.llm_d_namespace
    
    labels = {
      "app.kubernetes.io/name"       = "llm-d"
      "app.kubernetes.io/component"  = "inference-server"
      "app.kubernetes.io/managed-by" = "terraform"
      "model"                        = "ibm-granite-3.3-8b-instruct"
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
          "model"                       = "ibm-granite-3.3-8b-instruct"
        }
      }
      
      spec {
        service_account_name = kubernetes_service_account.llm_d_service_account.metadata[0].name
        
        container {
          name  = "llm-d-granite"
          image = "python:3.11-slim"
          
          command = ["/bin/bash", "-c"]
          args = [
            <<-EOF
            set -e
            echo "🚀 === REAL IBM GRANITE LLM-D DEPLOYMENT ===" 
            echo "Start time: $(date)"
            echo "Model: ${var.default_model}"
            echo "High-CPU node optimization: bx2.16x64"
            
            # Install system dependencies
            echo "📦 Installing system dependencies..."
            apt-get update && apt-get install -y \
              curl \
              git \
              build-essential \
              libblas3 \
              liblapack3 \
              libopenblas-dev \
              && rm -rf /var/lib/apt/lists/*
            
            # Install Python dependencies
            echo "🐍 Installing Python ML dependencies..."
            pip install --no-cache-dir --upgrade pip
            pip install --no-cache-dir \
              torch --index-url https://download.pytorch.org/whl/cpu
            pip install --no-cache-dir \
              transformers \
              accelerate \
              flask \
              requests \
              numpy \
              sentencepiece \
              psutil \
              safetensors
            
            echo "✅ Dependencies installed successfully"
            
            # Create real IBM Granite inference server
            mkdir -p /app
            cat > /app/granite_server.py << 'PYEOF'
import os
import json
import time
import logging
import gc
import psutil
from datetime import datetime
from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForCausalLM, pipeline
import torch

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Global variables for model and tokenizer
model = None
tokenizer = None
generator = None
model_load_start = None
model_load_end = None

def optimize_cpu_performance():
    """Optimize CPU performance for inference on bx2.16x64 nodes"""
    try:
        cpu_count = psutil.cpu_count(logical=False)
        # Use up to 14 cores (leave 2 for system)
        torch.set_num_threads(min(14, cpu_count))
        torch.set_num_interop_threads(4)
        logger.info(f"🔧 CPU optimization: {cpu_count} physical cores, {torch.get_num_threads()} torch threads")
    except Exception as e:
        logger.warning(f"CPU optimization failed: {e}")

def load_model():
    global model, tokenizer, generator, model_load_start, model_load_end
    
    model_name = os.getenv('MODEL_NAME', '${var.default_model}')
    device = 'cpu'
    
    model_load_start = datetime.now()
    logger.info(f"🔄 Starting IBM Granite model loading: {model_load_start}")
    logger.info(f"📦 Model: {model_name}")
    logger.info(f"🖥️  Device: {device}")
    logger.info(f"💾 Available memory: {psutil.virtual_memory().available / (1024**3):.1f}GB")
    
    # Optimize CPU performance for bx2.16x64
    optimize_cpu_performance()
    
    try:
        # Load tokenizer
        logger.info("📝 Loading tokenizer...")
        tokenizer_start = datetime.now()
        tokenizer = AutoTokenizer.from_pretrained(
            model_name,
            trust_remote_code=True,
            padding_side='left'
        )
        
        if tokenizer.pad_token is None:
            tokenizer.pad_token = tokenizer.eos_token
        
        tokenizer_end = datetime.now()
        logger.info(f"✅ Tokenizer loaded in {(tokenizer_end - tokenizer_start).total_seconds():.2f}s")
        
        # Load IBM Granite model
        logger.info("🧠 Loading IBM Granite model weights...")
        model_weights_start = datetime.now()
        
        model = AutoModelForCausalLM.from_pretrained(
            model_name,
            trust_remote_code=True,
            torch_dtype=torch.float32,
            device_map=None,
            low_cpu_mem_usage=True
        )
        
        model = model.to('cpu')
        model.eval()
        
        # Force garbage collection
        gc.collect()
        
        model_weights_end = datetime.now()
        logger.info(f"✅ IBM Granite model loaded in {(model_weights_end - model_weights_start).total_seconds():.2f}s")
        logger.info(f"💾 Memory usage: {psutil.virtual_memory().percent:.1f}%")
        
        # Create inference pipeline
        logger.info("🔧 Creating IBM Granite inference pipeline...")
        pipeline_start = datetime.now()
        
        generator = pipeline(
            'text-generation',
            model=model,
            tokenizer=tokenizer,
            device=-1,  # CPU
            do_sample=True,
            temperature=float(os.getenv('TEMPERATURE', '${var.model_config.temperature}')),
            top_p=float(os.getenv('TOP_P', '${var.model_config.top_p}')),
            max_new_tokens=int(os.getenv('MAX_TOKENS', '${var.model_config.max_tokens}')),
            pad_token_id=tokenizer.eos_token_id,
            return_full_text=False,
            clean_up_tokenization_spaces=True
        )
        
        pipeline_end = datetime.now()
        model_load_end = datetime.now()
        
        total_load_time = (model_load_end - model_load_start).total_seconds()
        
        logger.info(f"✅ Pipeline created in {(pipeline_end - pipeline_start).total_seconds():.2f}s")
        logger.info(f"🎉 IBM Granite model fully loaded and ready!")
        logger.info(f"⏱️  Total loading time: {total_load_time:.2f}s ({total_load_time/60:.2f} minutes)")
        logger.info(f"🚀 Real IBM Granite LLM-D inference server is ready!")
        
    except Exception as e:
        logger.error(f"❌ Error loading IBM Granite model: {str(e)}")
        raise e

@app.route('/', methods=['GET'])
def home():
    return jsonify({
        "service": "Real LLM-D Inference Server",
        "model": "${var.default_model}",
        "status": "running" if model else "loading",
        "infrastructure": "IBM Cloud Kubernetes + High-CPU Nodes (bx2.16x64)",
        "real_ai_inference": True,
        "message": "Send POST requests to /generate for real AI responses",
        "endpoints": ["/health", "/generate", "/model-info"],
        "node_optimization": "16 vCPUs, 64GB RAM per node"
    })

@app.route('/health', methods=['GET'])
def health_check():
    if model is None or tokenizer is None or generator is None:
        return jsonify({
            'status': 'loading',
            'message': 'IBM Granite model is still loading...',
            'model': '${var.default_model}',
            'memory_usage_percent': psutil.virtual_memory().percent
        }), 503
    
    load_time = None
    if model_load_start and model_load_end:
        load_time = (model_load_end - model_load_start).total_seconds()
    
    return jsonify({
        'status': 'ready',
        'model': '${var.default_model}',
        'device': 'cpu',
        'cpu_threads': torch.get_num_threads(),
        'memory_usage_percent': psutil.virtual_memory().percent,
        'model_load_time_seconds': load_time,
        'real_ai_inference': True,
        'message': 'Real IBM Granite LLM-D inference server is healthy and ready'
    })

@app.route('/generate', methods=['POST'])
def generate_text():
    if model is None or tokenizer is None or generator is None:
        return jsonify({
            'error': 'IBM Granite model not loaded yet. Please wait for initialization.'
        }), 503
    
    try:
        data = request.get_json()
        if not data or 'prompt' not in data:
            return jsonify({'error': 'Missing prompt in request'}), 400
        
        prompt = data['prompt']
        max_tokens = min(int(data.get('max_tokens', os.getenv('MAX_TOKENS', '${var.model_config.max_tokens}'))), 1024)
        
        logger.info(f"🎯 Processing real IBM Granite inference: {prompt[:50]}...")
        
        start_time = time.time()
        memory_before = psutil.virtual_memory().percent
        
        # Generate response using real IBM Granite model
        with torch.no_grad():
            outputs = generator(
                prompt,
                max_new_tokens=max_tokens,
                temperature=float(data.get('temperature', os.getenv('TEMPERATURE', '${var.model_config.temperature}'))),
                top_p=float(data.get('top_p', os.getenv('TOP_P', '${var.model_config.top_p}'))),
                do_sample=True,
                clean_up_tokenization_spaces=True
            )
        
        generated_text = outputs[0]['generated_text'].strip()
        
        # Cleanup
        gc.collect()
        
        inference_time = time.time() - start_time
        memory_after = psutil.virtual_memory().percent
        
        logger.info(f"✅ Real IBM Granite inference completed in {inference_time:.2f}s")
        
        return jsonify({
            'response': generated_text,
            'model': '${var.default_model}',
            'inference_time': round(inference_time, 2),
            'tokens_generated': len(tokenizer.encode(generated_text)),
            'memory_usage_before': memory_before,
            'memory_usage_after': memory_after,
            'real_ai_inference': True,
            'granite_model': True,
            'infrastructure': 'IBM Cloud Kubernetes bx2.16x64'
        })
        
    except Exception as e:
        logger.error(f"❌ IBM Granite inference error: {str(e)}")
        return jsonify({
            'error': f'IBM Granite inference failed: {str(e)}'
        }), 500

@app.route('/model-info', methods=['GET'])
def model_info():
    load_time = None
    if model_load_start and model_load_end:
        load_time = (model_load_end - model_load_start).total_seconds()
    
    return jsonify({
        'model_name': '${var.default_model}',
        'model_type': 'IBM Granite (Real AI)',
        'device': 'cpu',
        'cpu_threads': torch.get_num_threads() if 'torch' in globals() else None,
        'max_tokens': int(os.getenv('MAX_TOKENS', '${var.model_config.max_tokens}')),
        'temperature': float(os.getenv('TEMPERATURE', '${var.model_config.temperature}')),
        'top_p': float(os.getenv('TOP_P', '${var.model_config.top_p}')),
        'model_loaded': model is not None,
        'model_load_time_seconds': load_time,
        'memory_usage_percent': psutil.virtual_memory().percent,
        'infrastructure': 'bx2.16x64 (16 vCPUs, 64GB RAM)',
        'real_ai_inference': True,
        'granite_model': True
    })

if __name__ == '__main__':
    logger.info("🚀 Starting Real IBM Granite LLM-D Inference Server...")
    logger.info("📥 Loading IBM Granite model on high-CPU infrastructure...")
    
    # Load model on startup
    load_model()
    
    # Start Flask server
    logger.info("🌐 Starting Flask server...")
    app.run(host='0.0.0.0', port=8080, debug=False, threaded=True)
PYEOF
            
            echo "🚀 Starting Real IBM Granite LLM-D Inference Server..."
            echo "Server start time: $(date)"
            cd /app && python granite_server.py
            EOF
          ]
          
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
          
          env {
            name  = "TOP_P"
            value = tostring(var.model_config.top_p)
          }
          
          env {
            name  = "REPETITION_PENALTY"
            value = tostring(var.model_config.repetition_penalty)
          }
          
          env {
            name  = "DEVICE"
            value = "cpu"
          }
          
          env {
            name  = "HF_HUB_DISABLE_PROGRESS_BARS"
            value = "1"
          }
          
          env {
            name  = "TRANSFORMERS_CACHE"
            value = "/tmp/transformers_cache"
          }
          
          env {
            name  = "HF_HOME"
            value = "/tmp/huggingface_cache"
          }
          
          resources {
            requests = {
              memory = "12Gi"  # Use significant portion of 64GB
              cpu    = "8"     # Use half of 16 vCPUs
            }
            limits = {
              memory = "32Gi"  # Allow up to half of node memory
              cpu    = "14"    # Use most vCPUs, leave 2 for system
            }
          }
          
          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 1800  # 30 minutes for model loading
            period_seconds        = 60
            timeout_seconds       = 30
            failure_threshold     = 20
          }
          
          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 2400  # 40 minutes for initial setup
            period_seconds        = 300
            timeout_seconds       = 120
            failure_threshold     = 10
          }
          
          volume_mount {
            name       = "model-cache"
            mount_path = "/tmp/transformers_cache"
          }
          
          volume_mount {
            name       = "hf-cache"
            mount_path = "/tmp/huggingface_cache"
          }
        }
        
        volume {
          name = "model-cache"
          empty_dir {
            size_limit = "40Gi"
          }
        }
        
        volume {
          name = "hf-cache"
          empty_dir {
            size_limit = "30Gi"
          }
        }
      }
    }
  }
}

# Create service for real LLM-D
resource "kubernetes_service" "llm_d_service" {
  depends_on = [kubernetes_deployment.llm_d_granite]
  
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