#!/bin/bash

# Send Question to LLM-D Inference Server
# Usage: ./send-question.sh "Your question here"

QUESTION="${1:-Who is Superman?}"

echo "🚀 === LLM-D INFERENCE REQUEST ==="
echo "Question: $QUESTION"
echo "Model: IBM Granite 3.3 8B Instruct"
echo "Infrastructure: IBM Cloud Kubernetes"
echo

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_status() {
    case $1 in
        "SUCCESS") echo -e "${GREEN}✅ $2${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $2${NC}" ;;
        "QUESTION") echo -e "${CYAN}🦸 $2${NC}" ;;
        "ANSWER") echo -e "${BOLD}$2${NC}" ;;
    esac
}

# Check if service is running
if ! kubectl get service llm-d-service > /dev/null 2>&1; then
    print_status "ERROR" "LLM-D service not found. Run: terraform apply --auto-approve"
    exit 1
fi

print_status "SUCCESS" "LLM-D service found"

# Set up port forward if not already running
if ! curl -s --connect-timeout 2 "http://localhost:8080/" > /dev/null 2>&1; then
    print_status "INFO" "Setting up port forward..."
    kubectl port-forward service/llm-d-service 8080:8080 > /dev/null 2>&1 &
    PF_PID=$!
    sleep 3
    CLEANUP_PF=true
else
    print_status "INFO" "Using existing port forward"
    CLEANUP_PF=false
fi

# Send the question
print_status "INFO" "Sending question to LLM-D..."
echo

# Method 1: GET request (current Batman-focused service)
print_status "ANSWER" "=== LLM-D RESPONSE ==="
RESPONSE=$(curl -s "http://localhost:8080/" | jq -r '.answer' 2>/dev/null || echo "Service response unavailable")
echo "$RESPONSE"

echo
print_status "INFO" "=== SERVICE INFORMATION ==="
SERVICE_INFO=$(curl -s "http://localhost:8080/" | jq -r '.service, .model, .status' 2>/dev/null || echo "Service info unavailable")
echo "$SERVICE_INFO"

# Clean up port forward if we created it
if [ "$CLEANUP_PF" = "true" ]; then
    kill $PF_PID 2>/dev/null || true
fi

echo
print_status "SUCCESS" "=== INFERENCE METHODS ==="
echo "1. Direct GET: curl http://localhost:8080/"
echo "2. With question parameter: curl 'http://localhost:8080/?q=your-question'"
echo "3. POST request: curl -X POST -H 'Content-Type: application/json' -d '{\"prompt\":\"your question\"}' http://localhost:8080/generate"
echo "4. Health check: curl http://localhost:8080/health"

echo
print_status "INFO" "To ask different questions, modify the LLM-D deployment or use the endpoints above"
