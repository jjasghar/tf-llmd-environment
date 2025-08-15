# LLM-D Terraform Troubleshooting Guide

This guide covers common issues and their automated fixes in the LLM-D Terraform deployment.

## 🎯 Issues Automatically Fixed

This Terraform configuration includes fixes for all issues discovered during development and testing:

### ✅ ImagePullBackOff Issue - RESOLVED

**Problem**: Kubernetes pods couldn't pull container images from external registries.

**Root Cause**: IBM Cloud VPC default security group was missing inbound rules for:
- HTTPS (443) - Container registry responses
- HTTP (80) - Fallback registry access  
- DNS (53) - DNS query responses

**Automatic Fix**: Terraform now adds these security group rules:
```hcl
# In main.tf - added automatically
resource "ibm_is_security_group_rule" "allow_inbound_https" {
  group     = data.ibm_is_vpc.llm_d_vpc_data.default_security_group
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 443
    port_max = 443
  }
}
# Plus HTTP (80) and DNS (53) rules
```

### ✅ Resource Group Error - RESOLVED

**Problem**: `Error: Given Resource Group is not found in the account`

**Root Cause**: Default resource group name is "Default" (capital D), not "default"

**Automatic Fix**: Updated default in `terraform.tfvars`:
```hcl
resource_group_name = "Default"  # Capital D
```

### ✅ Kubernetes Version Error - RESOLVED  

**Problem**: `The selected version is unsupported`

**Root Cause**: Kubernetes 1.28 is no longer supported

**Automatic Fix**: Updated to supported version with validation:
```hcl
kubernetes_version = "1.32"  # Latest supported
```

### ✅ Container Registry Connectivity - RESOLVED

**Problem**: External registries (Docker Hub) had connectivity issues from IBM Cloud

**Automatic Fix**: Uses IBM Container Registry by default:
```hcl
container_registry = "icr.io"  # IBM Container Registry
```

## 🔧 Manual Verification (If Needed)

If you encounter issues, verify these fixes are working:

### 1. Check Security Group Rules

```bash
# Get your VPC's default security group ID
terraform output vpc_id
ibmcloud is vpc <vpc-id>

# Check security group rules
ibmcloud is security-group <security-group-id>

# Should show these inbound rules:
# - TCP 443 (HTTPS) 
# - TCP 80 (HTTP)
# - UDP 53 (DNS)
```

### 2. Verify Container Registry

```bash
# Check which registry is configured
grep container_registry terraform.tfvars

# Should show: container_registry = "icr.io"
```

### 3. Test Network Connectivity

```bash
# Test from a cluster pod
kubectl run network-test --image=icr.io/codeengine/hello --rm -it --restart=Never

# Should start successfully (not ImagePullBackOff)
```

## 🐛 Debug Commands

If you still encounter issues:

### Check Pod Status
```bash
kubectl get pods -n llm-d
kubectl describe pod <pod-name> -n llm-d
kubectl logs <pod-name> -n llm-d
```

### Check Events
```bash
kubectl get events -n llm-d --sort-by='.lastTimestamp'
```

### Check Security Groups
```bash
# List security groups
ibmcloud is security-groups

# Check specific group rules
ibmcloud is security-group <sg-id>
```

### Test DNS Resolution
```bash
# From cluster pod
kubectl exec -it <pod-name> -n llm-d -- nslookup registry-1.docker.io
```

## 🚀 Clean Deployment Test

To verify all fixes work:

```bash
# Destroy existing infrastructure
terraform destroy -auto-approve

# Clean apply with all fixes
terraform apply -auto-approve

# Should complete without manual intervention
```

## 📞 Getting Help

If you encounter new issues not covered here:

1. Check Terraform plan: `terraform plan`
2. Check cluster status: `kubectl get nodes`
3. Check pod logs: `kubectl logs -n llm-d <pod-name>`
4. Review security groups: `ibmcloud is security-groups`

All the common issues from our debugging session are now automatically fixed in the Terraform configuration!