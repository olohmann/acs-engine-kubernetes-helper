# acs-engine-kubernetes-helper

An opinionated ugly helper script for setting up a Kubernetes Cluster with [acs-engine](https://github.com/Azure/acs-engine).

## Background

[Azure AKS](https://docs.microsoft.com/en-us/azure/aks/) offers a great experience for running managed Kubernetes clusters on Azure. If you need to work with the latest features and require more control over your cluster layout though, you want to run an `acs-engine` deployment.

To reduce the overhead of instantiating an acs-engine cluster I assembled a little helper script that eases the deployment process by:

* Allowing you to control the deployment via environment variables on the shell.
* Creating and configuring a custom VNet for the acs-engine based cluster on the fly. No need to mess around with a JSON file and copy&pasting VNet IDs.

In its default configuration the script will create a dev/test cluster with:

* Kubernetes 1.9.x
* 1 master node (VM Size D2\_v2)
* 1 worker node (VM Size D2\_v2)
* A smaller Custom VNet (avoids the default 10.0.0.0/8 CIDR): 10.239.0.0/16
* RBAC enabled
* [calico](https://docs.projectcalico.org/v2.6/getting-started/) network overlay enabled

However, you can change the layout of the deployment to suit your needs. For example, by configuring an HA master setup with 3 or more nodes or switch to Azure networking (see Tweaking Options below).

## Prerequisites

### az (Azure CLI 2.0)

Install Azure CLI 2.0 as described here: [Microsoft Docs](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

### acs-engine

Go the the acs-engine repo and download the [latest relase of acs-engine](https://github.com/Azure/acs-engine/releases/latest).
Download, extract and **make sure to put the executable on your PATH.**

### 7z

The complete configuration can be automatically uploaded to a storage account with a crypted 7z file.
For Ubuntu: `sudo apt install p7zip-full`

## Usage

Clone the repository:

```sh
git clone https://github.com/olohmann/acs-engine-kubernetes-quickstart.git
cd acs-engine-kubernetes-quickstart
```

Login into your Azure environment with Azure CLI 2.0:

```sh
az login
```

Configure your deployment:

```sh
# Mandatory parameters
export SUBSCRIPTION_ID="..."
export RESOURCE_GROUP_NAME="..."
export RESOURCE_GROUP_LOCATION="..."
export KUBERNETES_DNS_PREFIX="..."
export SERVICE_PRINCIPAL_ID="..."
export SERVICE_PRINCIPAL_SECRET="..."

# Optional overrides
# export __VERBOSE=6
# export AADPROFILE_SERVER_APP_ID="..."
# export AADPROFILE_CLIENT_APP_ID="..."
# export AADPROFILE_TENANT_ID="..."
# export AADPROFILE_ADMIN_ID="..."
# export SSH_PUBLIC_KEY_DATA="..."
# export ADMIN_RESOURCE_GROUP_NAME="..."
# export ADMIN_KEY_VAULT_NAME="..."
# export ADMIN_STORAGE_NAME="..."
# export DEPLOYMENT_NAME="..."
# export KUBERNETES_VERSION="..."
# export KUBERNETES_NETWORK_POLICY="..."
# export KUBERNETES_VNET_NAME="..."
# export KUBERNETES_VNET_CIDR="..."
# export KUBERNETES_SUBNET_NAME="..."
# export KUBERNETES_SUBNET_CIDR="..."
# export KUBERNETES_FIRST_CONSECUTIVE_MASTER_IP="..."
# export KUBERNETES_MASTER_COUNT=1
# export KUBERNETES_MASTER_SIZE="..."
# export NODE_POOL_1_NAME=worker
# export NODE_POOL_1_COUNT=1
# export NODE_POOL_1_SIZE="..."
# export NODE_POOL_2_NAME="..."
# export NODE_POOL_2_COUNT=1
# export NODE_POOL_2_SIZE="..."
# export NODE_POOL_3_NAME="..."
# export NODE_POOL_3_COUNT=1
# export NODE_POOL_3_SIZE="..."
```

Create the Kubernetes cluster:

```sh
# ...define the environment variables...
./create-cluster.sh
```

## Tweaking Options

* You can modify the environment variables that are used by the `create-cluster.sh` bash script.
* You can change the structure of the `kubernetes_template.json` templatized acs-engine model file. If you change it, please 
