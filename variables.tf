variable "cluster_name" {
  description = "Kind cluster."
  type        = string
  default     = "capi-management"
}

variable "kind_node_image" {
  description = "Kind node image to use (ensure compatibility with CAPI version)."
  type        = string
  default     = "kindest/node:v1.27.3" # Example: Specify a K8s v1.27.x image
}

variable "capi_providers" {
  description = "List of Cluster API infrastructure providers to install (e.g., docker, aws, azure, gcp)."
  type        = list(string)
  default     = ["docker"]
  # Note: Only use default docker for this example
}