# outputs.tf

output "cluster_name" {
  description = "Name of the created Kind cluster."
  # Get the name from the manager's triggers map defined in main.tf
  value       = null_resource.kind_cluster_manager.triggers.cluster_name
  depends_on  = [null_resource.kind_cluster_manager] # Ensure manager has run
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file for the Kind cluster."
  # Construct the path based on the manager's triggers map defined in main.tf
  # This must match the path used in the kind_cluster_manager's create provisioner
  value       = "${path.module}/kubeconfig-${null_resource.kind_cluster_manager.triggers.cluster_name}.yaml"
  depends_on  = [null_resource.kind_cluster_manager] # Ensure file exists before output
}

# REMOVE or COMMENT OUT the 'kubeconfig' content output, as we are not using
# the kind_cluster resource which provides this directly.
# Getting the content would require reading the file using a data source
# after the null_resource has run.
# output "kubeconfig" {
#   description = "Kubeconfig content for the Kind cluster (sensitive)."
#   value       = data.local_file.kubeconfig_content.content # Example if using data source
#   sensitive   = true
# }

output "capi_providers_installed" {
  description = "List of CAPI infrastructure providers attempted to initialize."
  # This still comes directly from the input variable
  value       = var.capi_providers
}

# Optional: If you want the kubeconfig content, uncomment the data source
# in the previous thought block and use it here. Requires adding the provider:
# terraform { required_providers { local = { source = "hashicorp/local" } } }
# and running 'tofu init' again.