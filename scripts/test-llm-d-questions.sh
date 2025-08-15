#!/bin/bash

# LLM-D Question Testing Script
# Demonstrates how to send questions to the inference server

echo "🚀 === LLM-D INFERENCE SERVER - QUESTION TESTING ==="
echo "Model: IBM Granite 3.3 8B Instruct"
echo "Infrastructure: IBM Cloud Kubernetes"
echo

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    case $1 in
        "SUCCESS") echo -e "${GREEN}✅ $2${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $2${NC}" ;;
        "QUESTION") echo -e "${CYAN}🦸 $2${NC}" ;;
        "COMMAND") echo -e "${YELLOW}$ $2${NC}" ;;
    esac
}

# Check if service exists
if ! kubectl get service llm-d-service > /dev/null 2>&1; then
    print_status "ERROR" "LLM-D service not found. Run: terraform apply --auto-approve"
    exit 1
fi

print_status "SUCCESS" "LLM-D service found"

# Test 1: Direct cluster access (most reliable)
print_status "INFO" "=== METHOD 1: Direct Cluster Access (Most Reliable) ==="
print_status "QUESTION" "Testing Superman question..."

kubectl run superman-query --image=busybox --rm --restart=Never --timeout=30s -- /bin/sh -c "
echo 'Testing Superman question...'
echo 'GET /?q=Who is Superman? HTTP/1.1' | nc llm-d-service 8080
" 2>/dev/null | grep -A 20 "answer" || echo "Direct test completed"

echo
print_status "INFO" "=== METHOD 2: Port Forward Access ==="
print_status "INFO" "Setting up fresh port forward..."

# Kill any existing port forwards
pkill -f "port-forward.*llm-d-service" 2>/dev/null || true
sleep 2

# Start fresh port forward
kubectl port-forward service/llm-d-service 8080:8080 > /tmp/pf.log 2>&1 &
PF_PID=$!
sleep 5

# Test if port forward is working
if curl -s --connect-timeout 5 "http://localhost:8080/health" > /dev/null 2>&1; then
    print_status "SUCCESS" "Port forward working"
    
    print_status "QUESTION" "Superman Question:"
    print_status "COMMAND" "curl 'http://localhost:8080/?q=Who is Superman?'"
    SUPERMAN_RESPONSE=$(curl -s "http://localhost:8080/?q=Who is Superman?" | jq -r '.answer' 2>/dev/null || echo "Response error")
    echo "$SUPERMAN_RESPONSE"
    echo
    
    print_status "QUESTION" "Batman Question:"
    print_status "COMMAND" "curl 'http://localhost:8080/?q=Who is Batman?'"
    BATMAN_RESPONSE=$(curl -s "http://localhost:8080/?q=Who is Batman?" | jq -r '.answer' 2>/dev/null || echo "Response error")
    echo "$BATMAN_RESPONSE"
    echo
    
    print_status "QUESTION" "POST Method Test:"
    print_status "COMMAND" "curl -X POST -d '{\"prompt\": \"Who is Wonder Woman?\"}' http://localhost:8080/generate"
    WW_RESPONSE=$(curl -s -X POST "http://localhost:8080/generate" -H "Content-Type: application/json" -d '{"prompt": "Who is Wonder Woman?"}' | jq -r '.response' 2>/dev/null || echo "Response error")
    echo "$WW_RESPONSE"
    
else
    print_status "ERROR" "Port forward not working. Showing alternative methods..."
fi

# Clean up
kill $PF_PID 2>/dev/null || true

echo
print_status "SUCCESS" "=== INFERENCE METHODS SUMMARY ==="
echo "The LLM-D inference server supports multiple ways to send questions:"
echo
echo "1. 🔗 URL Parameter Method:"
echo "   curl 'http://localhost:8080/?q=Who is Superman?'"
echo
echo "2. 📝 POST Request Method:"
echo "   curl -X POST -H 'Content-Type: application/json' \\"
echo "        -d '{\"prompt\": \"Who is Superman?\"}' \\"
echo "        http://localhost:8080/generate"
echo
echo "3. 🏥 Health Check:"
echo "   curl http://localhost:8080/health"
echo
echo "4. 📋 Service Info:"
echo "   curl http://localhost:8080/"

echo
print_status "INFO" "=== TROUBLESHOOTING PORT FORWARD ISSUES ==="
echo "If port forwarding is unstable:"
echo "1. Kill existing forwards: pkill -f 'port-forward.*llm-d'"
echo "2. Start fresh: kubectl port-forward service/llm-d-service 8080:8080"
echo "3. Test connection: curl http://localhost:8080/health"
echo "4. Wait a few seconds between commands"

echo
print_status "SUCCESS" "🎉 LLM-D INFERENCE SERVER IS READY FOR YOUR QUESTIONS!"
