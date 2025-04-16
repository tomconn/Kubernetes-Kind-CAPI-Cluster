# Kind Cluster for Cluster API (CAPI) bootstrapped using OpenTofu on macOS with Rancher Desktop

This project uses OpenTofu to provision a local Kind Kubernetes cluster. It leverages Rancher Desktop configured with the **`moby` (Docker)** container engine. This first cluster (`capi-management`) acts as a **Cluster API (CAPI) Management Cluster**.

The setup utilizes OpenTofu's `null_resource` with `local-exec` provisioners to execute `kind` CLI commands for reliable cluster creation and `clusterctl init` for CAPI initialization.

Furthermore, this guide demonstrates how to use the provisioned `capi-management` cluster to create a **second, separate CAPI Workload Cluster** (`capi-workload-docker`) using the **Cluster API Provider for Docker (CAPD)**. This workload cluster's nodes will run as Docker containers managed by Rancher Desktop.

## Prerequisites

Ensure the following tools are installed on your macOS system **and accessible in your terminal's `PATH`**:

1.  **Homebrew:** (Recommended package manager for macOS)
    If not installed, run:
    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```
    Ensure your shell environment is configured for Homebrew (run `brew doctor` for guidance).

2.  **OpenTofu:** (Infrastructure as Code Tool)
    ```bash
    brew install opentofu
    tofu --version
    ```

3.  **Rancher Desktop:** (Container Management Application)
    *   Download and install from the [Rancher Desktop website](https://rancherdesktop.io/).
    *   Configure using the **`moby` engine** (see **Rancher Desktop Configuration** section below).

4.  **Kind:** (Kubernetes IN Docker)
    *   The `kind` CLI is **required** as it's called directly by the OpenTofu configuration.
    ```bash
    brew install kind
    kind version
    which kind # Should output a path like /opt/homebrew/bin/kind or /usr/local/bin/kind
    ```

5.  **kubectl:** (Kubernetes Command-Line Tool)
    ```bash
    brew install kubectl
    kubectl version --client
    which kubectl
    ```

6.  **clusterctl:** (Cluster API Command-Line Tool)
    *   `clusterctl` is **required** as it's called directly by the OpenTofu configuration and used for workload cluster management.
    ```bash
    brew install clusterctl
    clusterctl version
    which clusterctl # Should output a path like /opt/homebrew/bin/clusterctl
    ```
    *   **If `which clusterctl` fails after installation, or if `tofu apply` fails with `clusterctl: command not found`, ensure your shell's `PATH` includes the Homebrew bin directory. You might need to update `~/.zshrc` or `~/.bash_profile`. See Homebrew documentation or run `brew doctor`. As a workaround, you can specify the full path to `clusterctl` (found via `which clusterctl`) directly in the `main.tf` `capi_init` provisioner.**

## Rancher Desktop Configuration

This setup requires using the **`moby`** container engine in Rancher Desktop for reliable `kind` operation.

1.  **Open Rancher Desktop Preferences.**
2.  Go to **"Container Engine"**.
3.  **Select `dockerd (moby)`** as the container runtime.
4.  **Apply & Restart:** Apply the changes and let Rancher Desktop restart its backend.

This ensures a standard Docker socket (`/var/run/docker.sock`) is natively available, which `kind` requires.

*(Note: While using `containerd` as the Rancher Desktop engine is possible, it relies on a Docker socket compatibility layer provided by Rancher Desktop that can sometimes be problematic. If you encounter `docker ps ... exit status 1` errors when using `containerd` mode, switching to the `moby` engine is the recommended solution for this guide.)*

**Verify the Docker connection:**
```bash
docker ps                     # Should run without error (list headers or containers)
```

## Part 1: Setup CAPI Management Cluster (with OpenTofu)
1. This section creates the primary Kind cluster that will manage other clusters.
  - Get Files: Clone or download the project files (main.tf, variables.tf, versions.tf, outputs.tf, kind-config.yaml) into a local directory. Ensure these files are present:
  - main.tf: Contains null_resource definitions for Kind and clusterctl.
  - variables.tf: Defines input variables like cluster name, node image.
  - versions.tf: Specifies OpenTofu and provider versions.
  - outputs.tf: Defines outputs like the management cluster kubeconfig path.
  - kind-config.yaml: Defines the Kind cluster structure (1 control-plane, 2 workers).
2. Verify Prerequisites: Double-check that kind, kubectl, and clusterctl are installed and runnable from your terminal.
3. **Initialize OpenTofu:** Download necessary providers.

```bash
tofu init
```

4. **Review Plan:** See what OpenTofu will create (primarily null_resource actions).

```bash
tofu plan
```

5. **Apply Configuration:** This executes the local-exec commands to:
  - Create the Kind cluster (capi-management) using kind create cluster.
  - Generate the kubeconfig file (kubeconfig-capi-management.yaml).
  - Initialize CAPI core components and specified providers (AWS, Azure, GCP by default) using clusterctl init.
  - This will take several minutes.

```bash
tofu apply -auto-approve
```
## Part 2: Verification (Management Cluster)
1. Check Kind Cluster:

```bash
kind get clusters
# Should show 'capi-management' (or your custom name)
```
2. **Set KUBECONFIG for Management Cluster:** Crucially, point kubectl and clusterctl to your new management cluster.

```bash
# Get the exact path from the output
export KUBECONFIG=$(tofu output -raw kubeconfig_path)

# Example:
# export KUBECONFIG="./kubeconfig-capi-management.yaml"

echo "Using Kubeconfig: $KUBECONFIG"
kubectl config current-context # Should show 'kind-capi-management'
```

3. **Check Nodes:**

```bash
kubectl get nodes -o wide # Should show 1 control-plane, 2 workers Ready
```

4. **Check CAPI Installation:**

```bash
kubectl get pods -A # Look for pods in capi-*, capa-*, capz-*, capg-* namespaces
```

5. **Check clusterctl Configuration:** Verify clusterctl can read the provider configuration from the management cluster.

```bash
clusterctl version
clusterctl config repositories # Should list core, bootstrap, control-plane, and infra providers
```

## Part 3: Create Docker Workload Cluster (with CAPI)
Now, use the capi-management cluster to create a new workload cluster running in Docker containers.

1. **Prerequisites for this Part:**
  -Management cluster (capi-management) is running.
  -Rancher Desktop (Moby) is running.
  -Your terminal's KUBECONFIG environment variable is pointing to the management cluster (set in the previous verification step).
2. **Verify/Install CAPI Docker Provider (CAPD):**
  - The initial clusterctl init might not have included the Docker provider. Check and install if needed.

```bash
# Check if CAPD controller pods exist (ensure KUBECONFIG is set to management cluster)
kubectl get pods -n capd-system

# If the namespace doesn't exist or pods aren't running, install/update CAPD:
clusterctl init --infrastructure docker

# Wait for 'capd-controller-manager' pod in 'capd-system' to be Running
kubectl get pods -n capd-system --watch
```

3. **Define Workload Cluster Manifest:**
  - Create a new file named workload-cluster-docker.yaml.
  - Copy the content for this file from a reliable CAPI Docker example. See the Cluster API Book Quick Start or use the example structure below as a guide.
  - **Key Components in the Manifest:**
    * Cluster: Top-level object. Defines Pod/Service CIDRs (ensure they don't overlap with host/management cluster). Add labels for ClusterResourceSet if using CNI automation.
    * DockerCluster: Infrastructure-specific cluster object for CAPD.
    * KubeadmControlPlane: Defines the control plane nodes. Specifies K8s version.
    * DockerMachineTemplate (for CP): Template for control plane Docker machines.
    * MachineDeployment: Defines worker node sets.
    * KubeadmConfigTemplate (for Workers): Template for worker node bootstrap configuration.
    * DockerMachineTemplate (for Workers): Template for worker Docker machines.
    (Optional) ClusterResourceSet & ConfigMap: To automatically install a CNI (like Calico). Important: * You need the full CNI manifest (e.g., calico.yaml) inside the ConfigMap - fetch it from the official CNI documentation. Ensure the CIDRs specified in the manifest match the Cluster object.

  - **Review Carefully:** Check resource names, namespaces, infrastructureRef/configRef links, Kubernetes versions, and especially the network CIDRs.

**Example Structure (Fill with details and full CNI manifest):**

[workload-cluster-docker.yaml](workload-cluster-docker.yaml)

4. **Apply the Workload Cluster Manifest:**
Make sure kubectl is still pointing to the capi-management cluster.

```bash
kubectl apply -f workload-cluster-docker.yaml
```

5. **Monitor Workload Cluster Creation:**
Watch the CAPI resources being created within the management cluster:

```bash
# Watch overall status (wait for Phase: Provisioned)
kubectl get cluster capi-workload-docker --watch

# Check control plane and worker machine status
kubectl get kubeadmcontrolplane
kubectl get machinedeployment
kubectl get machines -o wide

# Check underlying Docker resources
kubectl get dockercluster
kubectl get dockermachines

# Check CNI application via ClusterResourceSet (if used)
kubectl get clusterresourceset
```
This will take several minutes.

6. **Get Workload Cluster Kubeconfig:**
Once the control plane is ready (kubectl get kubeadmcontrolplane shows READY=true), retrieve its kubeconfig:

```bash
clusterctl get kubeconfig capi-workload-docker > capi-workload-docker.kubeconfig
```

## Part 4: Verification (Workload Cluster)

1. **Set KUBECONFIG for Workload Cluster:** Point kubectl to the new workload cluster.
```bash
export KUBECONFIG=./capi-workload-docker.kubeconfig
echo "Using Kubeconfig: $KUBECONFIG"
kubectl config current-context # Should show 'capi-workload-docker-admin@capi-workload-docker'
```

2. **Check Workload Nodes:**

```bash
kubectl get nodes -o wide
# Should show 1 control-plane and N worker nodes (based on replicas) in Ready state
```

3. **Check CNI Pods (if using ClusterResourceSet):**

```bash
kubectl get pods -A | grep calico # Or your chosen CNI
# Should show CNI pods running on each node.
```

## Usage
- Your capi-management cluster (running in Kind) is now managing the lifecycle of your capi-workload-docker cluster.
- You can manage the workload cluster by modifying the CAPI manifests (workload-cluster-docker.yaml) and applying them to the management cluster. For example, scale the MachineDeployment replicas.
- Use kubectl with the appropriate KUBECONFIG to interact with either the management or workload cluster.
- Refer to the Cluster API Book for detailed guides on advanced CAPI operations.

## Cleanup
1. **(Optional) Delete Workload Cluster via CAPI:** Before destroying the management cluster, you can gracefully delete the workload cluster using CAPI.

```bash
# Point KUBECONFIG back to the MANAGEMENT cluster
export KUBECONFIG=$(tofu output -raw kubeconfig_path)
kubectl delete -f workload-cluster-docker.yaml
# Monitor deletion using kubectl get cluster, machines, etc. Wait for resources to disappear.
# Also check 'docker ps' to see workload containers being removed.
```

2. **Destroy Management Cluster:** This will execute kind delete cluster for the capi-management cluster via OpenTofu's destroy provisioner.

```bash
# Make sure you are in the directory with the tofu files
tofu destroy --no-approve
```

3. **(Optional) Clean up local files:** Manually remove generated kubeconfig files and OpenTofu working files.

```bash
rm kubeconfig-capi-management.yaml kubeconfig-capi-workload-docker.kubeconfig # Adjust names if changed
rm -rf .terraform tofu.tfstate tofu.tfstate.backup terraform.tfstate.backup terraform.tfstate .terraform.lock.hcl
```

## ToDo
1. Originally tried using containerd but quickly ran into problems. Reverted to Docker, I'll do more research to determine if I can resolve this.
2. Use Ansible for the TF bootstrap provisioners, is this over kill|engineering?
3. Create a couple of clusters across AWS and GCP, try both the managed EKS/GKE and 'k8s the hard way'.
4. Investigate CAPI for Public cloud native resource provisioning. Use TF or AWS controllers etc? Or is Crossplane a solution with less friction? 
