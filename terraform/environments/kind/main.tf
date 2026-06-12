terraform {
  required_version = ">= 1.0"
}

# Call your local module block
module "my_kind_cluster" {
  source = "./modules/kind"

  cluster_name = "dev"
}

output "cluster_name" {
  description = "Kind cluster name"
  value       = module.my_kind_cluster.cluster_name
}

output "endpoint" {
  description = "The Kubernetes API Server endpoint"
  value       = module.my_kind_cluster.endpoint
}

output "kubeconfig_path" {
  description = "The local path where kubeconfig is stored"
  value       = module.my_kind_cluster.kubeconfig_path
}

