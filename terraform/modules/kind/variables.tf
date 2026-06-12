variable "cluster_name" {
  description = "Kubernetes cluster name used as the key under node_attestation.k8s_psat.clusters"
  type        = string

  validation {
    condition     = length(trimspace(var.cluster_name)) > 0
    error_message = "cluster_name must be a non-empty string"
  }
}

variable "node_image" {
  description = "The Docker image version of Kubernetes to use"
  type        = string
  default     = "kindest/node:v1.36.1"
}
