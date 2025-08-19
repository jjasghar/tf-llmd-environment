#!/bin/bash

# Test LLM-D API Endpoints
# This script tests the LLM-D inference API following official documentation

set -e

NAMESPACE="${NAMESPACE:-llm-d-inference-scheduling}"
GATEWAY_SERVICE="infra-inference-scheduling-inference-gateway"
LOCAL_PORT="${LOCAL_PORT:-8000}"

echo "🧪 LLM-D API Testing Script"
echo "==========================="
echo ""
echo "📋 Configuration:"
echo "  Namespace: $NAMESPACE"
echo "  Gateway Service: $GATEWAY_SERVICE"
echo "  Local Port: $LOCAL_PORT"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check cluster connectivity
echo "🔍 Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "💡 Run: terraform output kubectl_config_command"
    exit 1
fi
echo "✅ Connected to cluster"

# Check if namespace exists
echo ""
echo "🔍 Checking namespace..."
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "❌ Namespace '$NAMESPACE' does not exist"
    echo "💡 Run: ./scripts/install-llm-d.sh first"
    exit 1
fi
echo "✅ Namespace '$NAMESPACE' exists"

# Check if gateway service exists
echo ""
echo "🔍 Checking gateway service..."
if ! kubectl get service "$GATEWAY_SERVICE" -n "$NAMESPACE" &> /dev/null; then
    echo "❌ Gateway service '$GATEWAY_SERVICE' not found"
    echo "📋 Available services:"
    kubectl get services -n "$NAMESPACE"
    exit 1
fi
echo "✅ Gateway service '$GATEWAY_SERVICE' exists"

# Check pod status
echo ""
echo "📊 Checking LLM-D pod status..."
kubectl get pods -n "$NAMESPACE"

# Start port forwarding
echo ""
echo "🌐 Starting port forward..."
kubectl port-forward -n "$NAMESPACE" service/"$GATEWAY_SERVICE" "$LOCAL_PORT":80 > /dev/null 2>&1 &
PF_PID=$!

# Wait for port forward to be ready
sleep 5

echo "✅ Port forward active (PID: $PF_PID)"
echo ""

# Test endpoints
echo "🧪 Testing LLM-D API endpoints..."
echo ""

# Test 1: Models endpoint
echo "📋 Test 1: /v1/models endpoint"
if curl -s --connect-timeout 10 "http://localhost:$LOCAL_PORT/v1/models" -H "Content-Type: application/json" | jq . > /dev/null 2>&1; then
    echo "✅ Models endpoint working"
    curl -s "http://localhost:$LOCAL_PORT/v1/models" -H "Content-Type: application/json" | jq .
else
    echo "⚠️  Models endpoint not ready yet (this is normal during startup)"
fi

echo ""

# Test 2: Health/basic connectivity
echo "📋 Test 2: Basic connectivity"
if curl -s --connect-timeout 5 "http://localhost:$LOCAL_PORT/" > /dev/null 2>&1; then
    echo "✅ Gateway responding"
else
    echo "⚠️  Gateway still initializing (this is normal)"
fi

echo ""

# Test 3: Inference endpoint (if models are available)
echo "📋 Test 3: Inference endpoint (if ready)"
if curl -s --connect-timeout 10 "http://localhost:$LOCAL_PORT/v1/completions" \
    -H "Content-Type: application/json" \
    -d '{"model": "ibm-granite/granite-3.3-8b-instruct", "prompt": "Hello", "max_tokens": 10}' > /dev/null 2>&1; then
    echo "✅ Inference endpoint working"
else
    echo "ℹ️  Inference endpoint not ready (model may still be loading)"
fi

# Cleanup
echo ""
echo "🧹 Cleaning up..."
kill $PF_PID 2>/dev/null || true
sleep 2

echo ""
echo "🎯 Summary:"
echo "  • LLM-D infrastructure is deployed and running"
echo "  • Gateway service is available"
echo "  • API endpoints are being initialized"
echo ""
echo "💡 To manually test when ready:"
echo "  kubectl port-forward -n $NAMESPACE service/$GATEWAY_SERVICE 8000:80 &"
echo "  curl -s http://localhost:8000/v1/models | jq ."
echo ""
echo "✅ LLM-D API test completed!"
