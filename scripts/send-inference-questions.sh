#!/bin/bash

# LLM-D Inference Question Sender
# Usage: ./send-inference-questions.sh

echo "🚀 === LLM-D INFERENCE SERVER - QUESTION GUIDE ==="
echo "IBM Granite Model on IBM Cloud Kubernetes"
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

# Check if service is running
if ! kubectl get service llm-d-service > /dev/null 2>&1; then
    print_status "ERROR" "LLM-D service not found. Run: terraform apply --auto-approve"
    exit 1
fi

print_status "SUCCESS" "LLM-D service is running"

# Set up port forward
print_status "INFO" "Setting up port forward on localhost:8080..."
kubectl port-forward service/llm-d-service 8080:8080 > /dev/null 2>&1 &
PF_PID=$!
sleep 3

echo
print_status "INFO" "=== HOW TO SEND QUESTIONS TO LLM-D ==="
echo

print_status "QUESTION" "METHOD 1: URL Parameter (GET Request)"
print_status "COMMAND" "curl 'http://localhost:8080/?q=Who is Superman?'"
echo "Response:"
curl -s "http://localhost:8080/?q=Who is Superman?" | jq -r '.answer'
echo

print_status "QUESTION" "METHOD 2: POST Request to /generate endpoint"
print_status "COMMAND" "curl -X POST -H 'Content-Type: application/json' -d '{\"prompt\": \"Who is Batman?\"}' http://localhost:8080/generate"
echo "Response:"
curl -s -X POST "http://localhost:8080/generate" -H "Content-Type: application/json" -d '{"prompt": "Who is Batman?"}' | jq -r '.response'
echo

print_status "QUESTION" "METHOD 3: Wonder Woman Question"
print_status "COMMAND" "curl 'http://localhost:8080/?q=Who is Wonder Woman?'"
echo "Response:"
curl -s "http://localhost:8080/?q=Who is Wonder Woman?" | jq -r '.answer'
echo

print_status "QUESTION" "METHOD 4: Custom Question"
print_status "COMMAND" "curl 'http://localhost:8080/?q=Tell me about superheroes'"
echo "Response:"
curl -s "http://localhost:8080/?q=Tell me about superheroes" | jq -r '.answer'
echo

print_status "QUESTION" "METHOD 5: Health Check"
print_status "COMMAND" "curl http://localhost:8080/health"
echo "Response:"
curl -s "http://localhost:8080/health" | jq '.'
echo

# Clean up
kill $PF_PID 2>/dev/null || true

print_status "SUCCESS" "=== INFERENCE SERVER READY ==="
echo "🎯 To ask your own questions:"
echo "1. kubectl port-forward service/llm-d-service 8080:8080"
echo "2. curl 'http://localhost:8080/?q=YOUR_QUESTION_HERE'"
echo "3. curl -X POST -H 'Content-Type: application/json' -d '{\"prompt\": \"YOUR_QUESTION\"}' http://localhost:8080/generate"

echo
print_status "SUCCESS" "🎉 LLM-D INFERENCE SERVER READY FOR YOUR QUESTIONS! 🚀"
