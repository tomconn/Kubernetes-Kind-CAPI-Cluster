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

output "capi_providers_installed" {
  description = "List of CAPI infrastructure providers attempted to initialize."
  # This still comes directly from the input variable
  value       = var.capi_providers
}
