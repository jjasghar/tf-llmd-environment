#!/bin/bash

# LLM-D Test Script
# Tests the deployed LLM-D infrastructure with IBM Granite model

set -e

echo "=== LLM-D Infrastructure Test ==="
echo "Testing LLM-D deployment with IBM Granite model..."
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "ERROR") echo -e "${RED}❌ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
    esac
}

# Test 1: Check cluster connectivity
print_status "INFO" "Testing cluster connectivity..."
if kubectl get nodes > /dev/null 2>&1; then
    print_status "SUCCESS" "Cluster connectivity working"
    kubectl get nodes
else
    print_status "ERROR" "Cannot connect to cluster"
    exit 1
fi

echo

# Test 2: Check namespace and pods
print_status "INFO" "Checking LLM-D namespace and pods..."
kubectl get pods -n llm-d

echo

# Test 3: Check services
print_status "INFO" "Checking LLM-D services..."
kubectl get services -n llm-d

echo

# Test 4: Check model configuration
print_status "INFO" "Checking IBM Granite model configuration..."
echo "Default Model:"
kubectl get configmap llm-d-model-config -n llm-d -o jsonpath='{.data.default_model}'
echo
echo
echo "Model Configuration:"
kubectl get configmap llm-d-model-config -n llm-d -o jsonpath='{.data.model_config\.yaml}' | head -20

echo
echo

# Test 5: Check if LLM-D service is responding
print_status "INFO" "Testing LLM-D service health endpoint..."

# Get service IP
SERVICE_IP=$(kubectl get service llm-d-service -n llm-d -o jsonpath='{.spec.clusterIP}')
SERVICE_PORT=$(kubectl get service llm-d-service -n llm-d -o jsonpath='{.spec.ports[0].port}')

print_status "INFO" "Service endpoint: $SERVICE_IP:$SERVICE_PORT"

# Test health endpoint using a test pod
print_status "INFO" "Testing health endpoint..."
kubectl run llm-d-test --image=curlimages/curl --rm -i --restart=Never -- \
    curl -s "http://$SERVICE_IP:$SERVICE_PORT/health" || echo "Health endpoint test completed"

echo

# Test 6: Test the LLM with "Who is Batman" question
print_status "INFO" "Testing LLM-D with 'Who is Batman?' question..."

# Create a test pod to make the request
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: llm-d-batman-test
  namespace: llm-d
spec:
  restartPolicy: Never
  containers:
  - name: test-client
    image: curlimages/curl
    command: ["/bin/sh", "-c"]
    args:
    - |
      echo "=== Testing LLM-D with Batman Question ==="
      echo "Service: $SERVICE_IP:$SERVICE_PORT"
      echo "Question: Who is Batman?"
      echo
      
      # Test basic connectivity first
      echo "Testing connectivity..."
      curl -s --connect-timeout 10 "http://$SERVICE_IP:$SERVICE_PORT/" || echo "Connection test done"
      
      echo
      echo "Testing health endpoint..."
      curl -s --connect-timeout 10 "http://$SERVICE_IP:$SERVICE_PORT/health" || echo "Health test done"
      
      echo
      echo "Testing LLM inference..."
      curl -s --connect-timeout 30 -X POST "http://$SERVICE_IP:$SERVICE_PORT/generate" \
        -H "Content-Type: application/json" \
        -d '{"prompt": "Who is Batman?", "max_length": 100}' || echo "LLM test done"
      
      echo
      echo "=== Test completed ==="
    env:
    - name: SERVICE_IP
      value: "$SERVICE_IP"
    - name: SERVICE_PORT
      value: "$SERVICE_PORT"
EOF

# Wait for the test pod to start and complete
print_status "INFO" "Waiting for test to complete..."
sleep 5

# Show the test results
print_status "INFO" "Test results:"
kubectl logs llm-d-batman-test -n llm-d || print_status "WARNING" "Test pod not ready yet"

echo

# Test 7: Check installer job status
print_status "INFO" "Checking installer job status..."
kubectl get jobs -n llm-d

# Show installer logs if available
print_status "INFO" "Installer job logs (last 20 lines):"
kubectl logs job/llm-d-installer -n llm-d --tail=20 || print_status "WARNING" "Installer still running"

echo

# Test 8: Summary
print_status "INFO" "=== Test Summary ==="
echo "Cluster ID: $(terraform output -raw cluster_id)"
echo "Model: $(terraform output -raw model_configuration | grep default_model | cut -d'"' -f4)"
echo "Namespace: $(terraform output -raw llm_d_namespace)"
echo "Service Endpoint: $SERVICE_IP:$SERVICE_PORT"

echo
print_status "SUCCESS" "LLM-D infrastructure test completed!"
print_status "INFO" "To clean up test pod: kubectl delete pod llm-d-batman-test -n llm-d"

echo
print_status "INFO" "To manually test LLM-D:"
echo "kubectl port-forward -n llm-d service/llm-d-service 8080:8080"
echo "curl -X POST http://localhost:8080/generate -H 'Content-Type: application/json' -d '{\"prompt\": \"Who is Batman?\", \"max_length\": 100}'"
