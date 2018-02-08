# acs-engine-kubernetes-helper

An opinionated helper script for setting up a Kubernetes Cluster with [acs-engine](https://github.com/Azure/acs-engine).

## Background
[Azure AKS](https://docs.microsoft.com/en-us/azure/aks/) offers a great experience for running managed Kubernetes clusters on Azure. If you need to work with the latest features and require more control over your cluster layout though, you want to run an `acs-engine` deployment. 

To reduce the overhead of instantiating an acs-engine cluster I assembled a little helper script that eases the deployment process by:
* Allowing you to put control the deployment via parameters on the shell.
* Creating and configuring a custom VNet for the acs-engine based cluster on the fly. No need to mess around with a JSON file.

In its default configuration the script will create a dev/test cluster with:
* Kubernetes 1.9.1
* 1 master node (VM Size D2\_v2)
* 1 worker node (VM Size D2\_v2)
* Custom VNet (avoids the default 10.0.0.0/8 CIDR)
* RBAC enabled
* [calico](https://docs.projectcalico.org/v2.6/getting-started/) network overlay

However, you can change the layout of the deployment to suit your needs. For example, by configuring an HA master setup with 3 or more nodes or switch to Azure networking (see Tweaking Options below).

## Prerequisites

### az (Azure CLI 2.0)

Install Azure CLI 2.0 as described here: [Microsoft Docs](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)

### acs-engine

Go the the acs-engine repo and download the [latest relase of acs-engine](https://github.com/Azure/acs-engine/releases/latest).
Download, extract and **make sure to put the executable on your PATH.**

## Usage

Clone the repository:
```
git clone https://github.com/olohmann/acs-engine-kubernetes-quickstart.git
cd acs-engine-kubernetes-quickstart
```

Login into your Azure environment with Azure CLI 2.0:
```
az login
```

Configure your deployment:
```
export sshPubKeyData="YOUR_PUBLIC_SSH_KEY ssh-rsa AAAAB3N...."
export servicePrincipleId="YOUR_AZURE_SP_ID"
export servicePrincipleSecret="YOUR_AZURE_SP_SECRET"
export subscriptionId="YOUR_AZURE_SUBSCRIPTION_ID"
export resourceGroupName="YOUR_TARGET_RG"
export resourceGroupLocation="YOUR_TARGET_LOCATION"
export dnsPrefix="YOUR_KUBERNTES_DNS_PREFIX"
```

Create the Kubernetes cluster:
```
./create-cluster.sh -k "$sshPubKeyData" -c "$clientId" -s "$clientSecret" -n "$dnsPrefix" -i "$subscriptionId" -g "$resourceGroupName" -l "$resourceGroupLocation"
```

## Tweaking Options

* You can modify the variables in the `create-cluster.sh` bash script. For example, to use Azure networking or a different VNet CIDR.
* You can change the structure of the `kubernetes_template.json` templatized acs-engine model file. For example, by adding another worker pool.
