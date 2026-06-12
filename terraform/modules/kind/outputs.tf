# outputs.tf

output "cluster_name" {
  description = "Kind cluster name"
  value       = kind_cluster.default.name
}

output "endpoint" {
  description = "The Kubernetes API Server endpoint"
  value       = kind_cluster.this.endpoint
}

output "kubeconfig_path" {
  description = "The local path where kubeconfig is stored"
  value       = kind_cluster.this.kubeconfig_path
}
