terraform {
  required_version = ">= 1.0"
}

# Call your local module block
module "local_kind_cluster" {
  source = "../../modules/kind"

  cluster_name = var.cluster_name
}

variable "cluster_name" {
  description = "Kind cluster name"
  type        = string
}
output "cluster_name" {
  description = "Kind cluster name"
  value       = module.local_kind_cluster.cluster_name
}

output "endpoint" {
  description = "The Kubernetes API Server endpoint"
  value       = module.local_kind_cluster.endpoint
}

output "kubeconfig_path" {
  description = "The local path where kubeconfig is stored"
  value       = module.local_kind_cluster.kubeconfig_path
}

