# versions.tf
terraform {
  required_version = ">= 1.6.0" # OpenTofu uses Terraform version constraints

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      # Use the latest available version found on the Terraform Registry
      version = "0.0.19"
    }
    # We use a null_resource with local-exec for clusterctl
    # No direct Kubernetes/Helm provider needed initially if using clusterctl init
  }
}