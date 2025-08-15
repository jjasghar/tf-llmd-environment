#!/bin/bash

# LLM-D Deployment Verification Script
# This script verifies that the LLM-D infrastructure is running correctly

set -e

NAMESPACE="${1:-llm-d}"
TIMEOUT="${2:-300}"

echo "🔍 Verifying LLM-D deployment in namespace: $NAMESPACE"
echo "⏱️  Timeout: ${TIMEOUT}s"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
echo "🔌 Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "💡 Make sure you've run: terraform output kubectl_config_command"
    exit 1
fi
echo "✅ Connected to cluster"

# Check if namespace exists
echo ""
echo "📁 Checking namespace..."
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "❌ Namespace '$NAMESPACE' does not exist"
    exit 1
fi
echo "✅ Namespace '$NAMESPACE' exists"

# Check installer job status
echo ""
echo "🚀 Checking LLM-D installer job..."
JOB_STATUS=$(kubectl get job llm-d-installer -n "$NAMESPACE" -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "NotFound")

if [ "$JOB_STATUS" = "NotFound" ]; then
    echo "❌ LLM-D installer job not found"
    echo "💡 Run: terraform apply to create the installer job"
    exit 1
elif [ "$JOB_STATUS" = "Complete" ]; then
    echo "✅ LLM-D installer job completed successfully"
elif [ "$JOB_STATUS" = "Failed" ]; then
    echo "❌ LLM-D installer job failed"
    echo "📋 Job logs:"
    kubectl logs job/llm-d-installer -n "$NAMESPACE" --tail=20
    exit 1
else
    echo "⏳ LLM-D installer job is still running..."
    echo "⏳ Waiting for completion (timeout: ${TIMEOUT}s)..."
    
    if kubectl wait --for=condition=complete job/llm-d-installer -n "$NAMESPACE" --timeout="${TIMEOUT}s"; then
        echo "✅ LLM-D installer job completed successfully"
    else
        echo "❌ LLM-D installer job did not complete within timeout"
        echo "📋 Job logs:"
        kubectl logs job/llm-d-installer -n "$NAMESPACE" --tail=20
        exit 1
    fi
fi

# Check pods
echo ""
echo "🔍 Checking pods in namespace..."
PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [ "$PODS" -eq 0 ]; then
    echo "⚠️  No pods found in namespace (this might be normal if LLM-D uses different deployment method)"
else
    echo "📊 Found $PODS pods in namespace"
    kubectl get pods -n "$NAMESPACE"
    
    # Check if any pods are not running
    NOT_RUNNING=$(kubectl get pods -n "$NAMESPACE" --no-headers --field-selector=status.phase!=Running 2>/dev/null | wc -l)
    if [ "$NOT_RUNNING" -gt 0 ]; then
        echo ""
        echo "⚠️  Some pods are not in Running state:"
        kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running
    fi
fi

# Check services
echo ""
echo "🌐 Checking services in namespace..."
SERVICES=$(kubectl get services -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [ "$SERVICES" -eq 0 ]; then
    echo "⚠️  No services found in namespace"
else
    echo "📊 Found $SERVICES services in namespace"
    kubectl get services -n "$NAMESPACE"
fi

# Check deployments
echo ""
echo "🚀 Checking deployments in namespace..."
DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [ "$DEPLOYMENTS" -eq 0 ]; then
    echo "⚠️  No deployments found in namespace"
else
    echo "📊 Found $DEPLOYMENTS deployments in namespace"
    kubectl get deployments -n "$NAMESPACE"
fi

# Check configmaps and secrets
echo ""
echo "⚙️  Checking configuration..."
CONFIGMAPS=$(kubectl get configmaps -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
SECRETS=$(kubectl get secrets -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
echo "📊 Found $CONFIGMAPS configmaps and $SECRETS secrets"

# Final status
echo ""
echo "🎉 Verification complete!"
echo ""
echo "📋 Summary:"
echo "  • Namespace: $NAMESPACE ✅"
echo "  • Installer Job: Complete ✅"
echo "  • Pods: $PODS"
echo "  • Services: $SERVICES"
echo "  • Deployments: $DEPLOYMENTS"
echo "  • ConfigMaps: $CONFIGMAPS"
echo "  • Secrets: $SECRETS"
echo ""

if [ "$PODS" -gt 0 ] && [ "$SERVICES" -gt 0 ]; then
    echo "🎊 LLM-D appears to be deployed successfully!"
    echo ""
    echo "🔗 Next steps:"
    echo "  • Check service endpoints: kubectl get services -n $NAMESPACE"
    echo "  • View model configuration: kubectl get configmap llm-d-model-config -n $NAMESPACE -o yaml"
    echo "  • Check deployed model: kubectl get configmap llm-d-model-config -n $NAMESPACE -o jsonpath='{.data.default_model}'"
    echo "  • View logs: kubectl logs -n $NAMESPACE -l app=<app-name>"
    echo "  • Port-forward to access services: kubectl port-forward -n $NAMESPACE service/<service-name> 8080:80"
else
    echo "⚠️  LLM-D deployment may be incomplete or using a different structure"
    echo "💡 Check the installer logs for more details: kubectl logs job/llm-d-installer -n $NAMESPACE"
fi

echo ""
