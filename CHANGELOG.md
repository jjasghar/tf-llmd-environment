# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-08-19

### 🎉 **Major Release - Real AI Inference System**

This is the first production-ready release featuring **real IBM Granite AI inference** instead of mock responses.

### Added
- **Real AI Inference**: IBM Granite 3.3B-8B Instruct model fully integrated
- **High-Performance Infrastructure**: bx2.16x64 nodes (16 vCPUs, 64GB RAM per node)
- **Production Optimization**: Extended timeouts and proper resource management
- **Dedicated Namespace**: `llm-d` namespace with proper RBAC configuration
- **Service Account**: Dedicated service account with cluster role bindings
- **Extended Caching**: 70Gi total cache storage for large model files
- **CPU Optimization**: Multi-threaded inference optimized for 16-core nodes
- **Real-time Monitoring**: Comprehensive logging and health endpoints
- **Performance Metrics**: Detailed inference timing and resource usage

### Changed
- **BREAKING**: Removed all mock/template response systems
- **BREAKING**: Upgraded default worker flavor from bx2.4x16 to bx2.16x64
- **Infrastructure**: 4x increase in CPU and memory resources per node
- **Model Loading**: Extended timeouts to handle large model downloads (30+ minutes)
- **Cache Management**: Increased cache volumes for IBM Granite model requirements
- **Resource Allocation**: Optimized CPU and memory limits for AI workloads

### Removed
- **Mock Responses**: Eliminated all template/generic response systems
- **Lightweight Deployment**: Removed undersized infrastructure configurations
- **Test Deployments**: Cleaned up temporary and experimental deployments

### Fixed
- **Model Loading Timeouts**: Extended probe delays for large model initialization
- **Cache Volume Issues**: Resolved EmptyDir volume size limitations
- **Package Installation**: Fixed PyTorch and transformers dependency conflicts
- **RBAC Permissions**: Proper cluster roles for LLM-D operations
- **Network Connectivity**: Optimized security groups and VPC configuration

### Performance Improvements
- **4x CPU Performance**: 16 vCPUs vs. 4 vCPUs per node
- **4x Memory Capacity**: 64GB vs. 16GB RAM per node
- **Optimized Inference**: CPU threading and memory management
- **Faster Model Loading**: High-bandwidth nodes for model downloads
- **Efficient Caching**: Proper cache allocation for model persistence

### Technical Details
- **Model**: IBM Granite 3.3B-8B Instruct (`ibm-granite/granite-3.3-8b-instruct`)
- **Loading Time**: ~15 minutes (882 seconds measured)
- **Memory Usage**: ~35GB model weights + inference overhead
- **Inference Time**: ~100 seconds per request (CPU-optimized)
- **Infrastructure**: 48 total vCPUs, 192GB total RAM across 3 zones

### Deployment Metrics
- **Total Deployment Time**: ~35-40 minutes (including model loading)
- **Infrastructure Creation**: ~12 minutes
- **Model Download/Load**: ~15 minutes
- **First Inference Ready**: ~30 minutes from `terraform apply`

### Breaking Changes
- **Node Requirements**: Now requires high-CPU nodes (bx2.16x64 minimum)
- **Memory Requirements**: Minimum 12Gi RAM per pod (up from 2Gi)
- **Storage Requirements**: 70Gi cache storage required
- **Deployment Time**: Extended from ~10 minutes to ~35 minutes (due to real model loading)

### Migration Guide
If upgrading from a previous version:
1. Update `terraform.tfvars` with new default worker_flavor
2. Run `terraform destroy` to remove old infrastructure
3. Run `terraform apply` to deploy v1.0 with real AI

---

## [0.x.x] - Previous Versions

### Historical Context
Previous versions used mock/template response systems for infrastructure testing. 
Version 1.0.0 represents the first production-ready release with real AI inference capabilities.
