#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# ------------------------------------------------------------------
# Usage
usage() { 
	echo "" 1>&2
	exit 1
}

declare TEMPLATE_FILE="./kubernetes_template.json"

while getopts ":t:h:" arg; do
	case "${arg}" in
		t)
			TEMPLATE_FILE=${OPTARG}
			;;
		h)
			usage
			;;
		esac
done
shift $((OPTIND-1))

# ------------------------------------------------------------------
# Logging

declare -A LOG_LEVELS
LOG_LEVELS=([0]="emerg" [1]="alert" [2]="crit" [3]="err" [4]="warning" [5]="notice" [6]="info" [7]="debug")
function .log () {
  local LEVEL=${1}
  shift
  if [ ${__VERBOSE} -ge ${LEVEL} ]; then
	if [ ${LEVEL} -ge 3 ]; then
		echo "[${LOG_LEVELS[$LEVEL]}]" "$@" 1>&2
    else 
		echo "[${LOG_LEVELS[$LEVEL]}]" "$@"
	fi
  fi
}

function .getShortHash () {
	local STR=${1}
	echo -n ${STR} | sha512sum | awk '{print substr($1,0,13)}'
}

# ------------------------------------------------------------------
# Verify various tools are available PATH
if ! [ -x "$(command -v acs-engine)" ]; then
  .log 3 "acs-engine is required and was not found in PATH." 
  exit 1
fi

if ! [ -x "$(command -v az)" ]; then
  .log 3 "az is required and was not found in PATH." 
  exit 1
fi

if ! [ -x "$(command -v 7z)" ]; then
  .log 3 "7z is required and was not found in PATH. Install via 'sudo apt install p7zip-full' (Ubuntu)." 
  exit 1
fi

if ! [ -x "$(command -v jq)" ]; then
  .log 3 "jq (JSON Command Line Processor) is required and was not found in PATH." 
  exit 1
fi

if ! [ -x "$(command -v openssl)" ]; then
  .log 3 "openssl is required and was not found in PATH." 
  exit 1
fi

# ------------------------------------------------------------------
# Mandatory Parameters 
SUBSCRIPTION_ID=${SUBSCRIPTION_ID:=""}
RESOURCE_GROUP_NAME=${RESOURCE_GROUP_NAME:=""}
RESOURCE_GROUP_LOCATION=${RESOURCE_GROUP_LOCATION:=""}

KUBERNETES_DNS_PREFIX=${KUBERNETES_DNS_PREFIX:=""}

SERVICE_PRINCIPAL_ID=${SERVICE_PRINCIPAL_ID:=""}
SERVICE_PRINCIPAL_SECRET=${SERVICE_PRINCIPAL_SECRET:=""}
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# Optional Parameters
SSH_PUBLIC_KEY_DATA=${SSH_PUBLIC_KEY_DATA:=""}
ADMIN_RESOURCE_GROUP_NAME=${ADMIN_RESOURCE_GROUP_NAME:=""}
ADMIN_KEY_VAULT_NAME=${ADMIN_KEY_VAULT_NAME:=""}
ADMIN_STORAGE_NAME=${ADMIN_STORAGE_NAME:=""}

AADPROFILE_SERVER_APP_ID=${AADPROFILE_SERVER_APP_ID:=""}
AADPROFILE_CLIENT_APP_ID=${AADPROFILE_CLIENT_APP_ID:=""}
AADPROFILE_TENANT_ID=${AADPROFILE_TENANT_ID:=""}
AADPROFILE_ADMIN_ID=${AADPROFILE_ADMIN_ID:=""}
# ------------------------------------------------------------------


# ------------------------------------------------------------------
# Optional Parameters with meaningful defaults
__VERBOSE=${__VERBOSE:=4}
DEPLOYMENT_NAME=${DEPLOYMENT_NAME:="acs-engine-$(date +%Y%m%d_%H%M%S)"}
KUBERNETES_VERSION=${KUBERNETES_VERSION:=1.9}
KUBERNETES_NETWORK_POLICY=${KUBERNETES_NETWORK_POLICY:=calico}

KUBERNETES_VNET_NAME=${KUBERNETES_VNET_NAME:=kubernetes-vnet}
KUBERNETES_VNET_CIDR=${KUBERNETES_VNET_CIDR:=10.239.0.0/16}

KUBERNETES_SUBNET_NAME=${KUBERNETES_SUBNET_NAME:=kubernetes-subnet}
KUBERNETES_SUBNET_CIDR=${KUBERNETES_SUBNET_CIDR:=10.239.0.0/16}

KUBERNETES_FIRST_CONSECUTIVE_MASTER_IP=${KUBERNETES_FIRST_CONSECUTIVE_MASTER_IP:=10.239.255.10}

KUBERNETES_MASTER_COUNT=${KUBERNETES_MASTER_COUNT:=1}
KUBERNETES_MASTER_SIZE=${KUBERNETES_MASTER_SIZE:=Standard_D2_v2}

NODE_POOL_1_NAME=${NODE_POOL_1_NAME:="worker"}
NODE_POOL_1_COUNT=${NODE_POOL_1_COUNT:=1}
NODE_POOL_1_SIZE=${NODE_POOL_1_SIZE:=Standard_D2_v2}
NODE_POOL_2_NAME=${NODE_POOL_2_NAME:=""}
NODE_POOL_2_COUNT=${NODE_POOL_2_COUNT:=""}
NODE_POOL_2_SIZE=${NODE_POOL_2_SIZE:=""}
NODE_POOL_3_NAME=${NODE_POOL_3_NAME:=""}
NODE_POOL_3_COUNT=${NODE_POOL_3_COUNT:=""}
NODE_POOL_3_SIZE=${NODE_POOL_3_SIZE:=""}

# ------------------------------------------------------------------

# ------------------------------------------------------------------
# Helper variables
declare outputDirName="deployment-$(date +%Y%m%d_%H%M%S)"
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# Verbose Logging
.log 6 "[==== Mandatory Parameters ====]"
.log 6 "SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
.log 6 "RESOURCE_GROUP_NAME=$RESOURCE_GROUP_NAME"
.log 6 "RESOURCE_GROUP_LOCATION=$RESOURCE_GROUP_LOCATION"
.log 6 "KUBERNETES_DNS_PREFIX=$KUBERNETES_DNS_PREFIX"
.log 6 "SERVICE_PRINCIPAL_ID=$SERVICE_PRINCIPAL_ID"
.log 6 "SERVICE_PRINCIPAL_SECRET=$SERVICE_PRINCIPAL_SECRET"

.log 6 "[==== Optional Overrides ====]"
.log 6 "SSH_PUBLIC_KEY_DATA=$SSH_PUBLIC_KEY_DATA"
.log 6 "DEPLOYMENT_NAME=$DEPLOYMENT_NAME"
.log 6 "KUBERNETES_VERSION=$KUBERNETES_VERSION"
.log 6 "KUBERNETES_NETWORK_POLICY=$KUBERNETES_NETWORK_POLICY"
.log 6 "KUBERNETES_VNET_NAME=$KUBERNETES_VNET_NAME"
.log 6 "KUBERNETES_VNET_CIDR=$KUBERNETES_VNET_CIDR"
.log 6 "KUBERNETES_SUBNET_NAME=$KUBERNETES_SUBNET_NAME"
.log 6 "KUBERNETES_SUBNET_CIDR=$KUBERNETES_SUBNET_CIDR"
.log 6 "KUBERNETES_FIRST_CONSECUTIVE_MASTER_IP=$KUBERNETES_FIRST_CONSECUTIVE_MASTER_IP"

.log 6 "KUBERNETES_MASTER_COUNT=${KUBERNETES_MASTER_COUNT}"
.log 6 "KUBERNETES_MASTER_SIZE=${KUBERNETES_MASTER_SIZE}"

.log 6 "NODE_POOL_1_NAME=${NODE_POOL_1_NAME}"
.log 6 "NODE_POOL_1_COUNT=${NODE_POOL_1_COUNT}"
.log 6 "NODE_POOL_1_SIZE=${NODE_POOL_1_SIZE}"

.log 6 "NODE_POOL_2_NAME=${NODE_POOL_2_NAME}"
.log 6 "NODE_POOL_2_COUNT=${NODE_POOL_2_COUNT}"
.log 6 "NODE_POOL_2_SIZE=${NODE_POOL_2_SIZE}"

.log 6 "NODE_POOL_3_NAME=${NODE_POOL_3_NAME}"
.log 6 "NODE_POOL_3_COUNT=${NODE_POOL_3_COUNT}"
.log 6 "NODE_POOL_3_SIZE=${NODE_POOL_3_SIZE}"

.log 6 "ADMIN_RESOURCE_GROUP_NAME=$ADMIN_RESOURCE_GROUP_NAME"
.log 6 "ADMIN_KEY_VAULT_NAME=$ADMIN_KEY_VAULT_NAME"
.log 6 "ADMIN_STORAGE_NAME=$ADMIN_STORAGE_NAME"

# ------------------------------------------------------------------
param_errs=0

if [ -z "$SUBSCRIPTION_ID" ]; then .log 3 "Required environment variable not defined: SUBSCRIPTION_ID"; param_errs=$((param_errs + 1)); fi
if [ -z "$RESOURCE_GROUP_NAME" ]; then .log 3 "Required environment variable not defined: RESOURCE_GROUP_NAME"; param_errs=$((param_errs + 1)); fi
if [ -z "$RESOURCE_GROUP_LOCATION" ]; then .log 3 "Required environment variable not defined: RESOURCE_GROUP_LOCATION"; param_errs=$((param_errs + 1)); fi
if [ -z "$KUBERNETES_DNS_PREFIX" ]; then .log 3 "Required environment variable not defined: KUBERNETES_DNS_PREFIX"; param_errs=$((param_errs + 1)); fi
if [ -z "$SERVICE_PRINCIPAL_ID" ]; then .log 3 "Required environment variable not defined: SERVICE_PRINCIPAL_ID"; param_errs=$((param_errs + 1)); fi
if [ -z "$SERVICE_PRINCIPAL_SECRET" ]; then .log 3 "Required environment variable not defined: SERVICE_PRINCIPAL_SECRET"; param_errs=$((param_errs + 1)); fi

if [ -z "$DEPLOYMENT_NAME" ]; then .log 3 "Required environment variable not defined: DEPLOYMENT_NAME"; param_errs=$((param_errs + 1)); fi
if [ -z "$KUBERNETES_VERSION" ]; then .log 3 "Required environment variable not defined: KUBERNETES_VERSION"; param_errs=$((param_errs + 1)); fi
if [ -z "$KUBERNETES_NETWORK_POLICY" ]; then .log 3 "Required environment variable not defined: KUBERNETES_NETWORK_POLICY"; param_errs=$((param_errs + 1)); fi
if [ -z "$KUBERNETES_VNET_NAME" ]; then .log 3 "Required environment variable not defined: KUBERNETES_VNET_NAME"; param_errs=$((param_errs + 1)); fi
if [ -z "$KUBERNETES_VNET_CIDR" ]; then .log 3 "Required environment variable not defined: KUBERNETES_VNET_CIDR"; param_errs=$((param_errs + 1)); fi
if [ -z "$KUBERNETES_SUBNET_NAME" ]; then .log 3 "Required environment variable not defined: KUBERNETES_SUBNET_NAME"; param_errs=$((param_errs + 1)); fi
if [ -z "$KUBERNETES_SUBNET_CIDR" ]; then .log 3 "Required environment variable not defined: KUBERNETES_SUBNET_CIDR"; param_errs=$((param_errs + 1)); fi
if [ -z "$KUBERNETES_FIRST_CONSECUTIVE_MASTER_IP" ]; then .log 3 "Required environment variable not defined: KUBERNETES_FIRST_CONSECUTIVE_MASTER_IP"; param_errs=$((param_errs + 1)); fi

if [ -z "$KUBERNETES_MASTER_COUNT" ]; then .log 3 "Required environment variable not defined: KUBERNETES_MASTER_COUNT"; param_errs=$((param_errs + 1)); fi
if [ -z "$NODE_POOL_1_NAME" ]; then .log 3 "Required environment variable not defined: NODE_POOL_1_NAME"; param_errs=$((param_errs + 1)); fi
if [ -z "$NODE_POOL_1_COUNT" ]; then .log 3 "Required environment variable not defined: NODE_POOL_1_COUNT"; param_errs=$((param_errs + 1)); fi
if [ -z "$NODE_POOL_1_SIZE" ]; then .log 3 "Required environment variable not defined: NODE_POOL_1_SIZE"; param_errs=$((param_errs + 1)); fi

if ! [ -z "$NODE_POOL_2_NAME" ]; then
	if [ -z "$NODE_POOL_2_COUNT" ]; then .log 3 "Required environment variable not defined: NODE_POOL_2_COUNT"; param_errs=$((param_errs + 1)); fi
	if [ -z "$NODE_POOL_2_SIZE" ]; then .log 3 "Required environment variable not defined: NODE_POOL_2_SIZE"; param_errs=$((param_errs + 1)); fi
fi

if ! [ -z "$NODE_POOL_3_NAME" ]; then
	if [ -z "$NODE_POOL_3_COUNT" ]; then .log 3 "Required environment variable not defined: NODE_POOL_3_COUNT"; param_errs=$((param_errs + 1)); fi
	if [ -z "$NODE_POOL_3_SIZE" ]; then .log 3 "Required environment variable not defined: NODE_POOL_3_SIZE"; param_errs=$((param_errs + 1)); fi
fi

if ! [ -z "$ADMIN_RESOURCE_GROUP_NAME" ]; then	
	if [ -z "$ADMIN_KEY_VAULT_NAME" ]; then .log 3 "Required environment variable not defined: ADMIN_KEY_VAULT_NAME (required in combination with ADMIN_RESOURCE_GROUP_NAME)"; param_errs=$((param_errs + 1)); fi
	if [ -z "$ADMIN_STORAGE_NAME" ]; then .log 3 "Required environment variable not defined: ADMIN_STORAGE_NAME (required in combination with ADMIN_RESOURCE_GROUP_NAME)"; param_errs=$((param_errs + 1)); fi
fi

if ! [ -z "$AADPROFILE_SERVER_APP_ID" ]; then	
	if [ -z "$AADPROFILE_CLIENT_APP_ID" ]; then .log 3 "Required environment variable not defined: AADPROFILE_CLIENT_APP_ID (required in combination with AADPROFILE_SERVER_APP_ID)"; param_errs=$((param_errs + 1)); fi
	if [ -z "$AADPROFILE_TENANT_ID" ]; then .log 3 "Required environment variable not defined: AADPROFILE_TENANT_ID (required in combination with AADPROFILE_SERVER_APP_ID)"; param_errs=$((param_errs + 1)); fi
	if [ -z "$AADPROFILE_ADMIN_ID" ]; then .log 3 "Required environment variable not defined: AADPROFILE_ADMIN_ID (required in combination with AADPROFILE_SERVER_APP_ID)"; param_errs=$((param_errs + 1)); fi
fi

if [ ${param_errs} -gt 0 ]; then 
	.log 3 "Environment configuration invalid. Aborting..."
	exit 1
fi 

.log 6 "Using resource group '$RESOURCE_GROUP_NAME'..."
.log 6 "Running custom VNet deployment: $KUBERNETES_VNET_NAME $KUBERNETES_VNET_CIDR (subnet: $KUBERNETES_SUBNET_NAME $KUBERNETES_SUBNET_CIDR)..."
az account set --subscription $SUBSCRIPTION_ID
az group create -n $RESOURCE_GROUP_NAME -l $RESOURCE_GROUP_LOCATION

.log 6 "Ensure Service Principal has Contributor Rights"
declare EXISTING_AZ_ROLE_ASSIGNMENT=$(az role assignment list --assignee $SERVICE_PRINCIPAL_ID --include-inherited --resource-group $RESOURCE_GROUP_NAME --query '[].properties.principalId' | tr -d '\n')
if [ "$EXISTING_AZ_ROLE_ASSIGNMENT" == "[]" ]; then
	.log 6 "No existing rights found, setting Contributor rights"
	az role assignment create --role Contributor --assignee $SERVICE_PRINCIPAL_ID --resource-group $RESOURCE_GROUP_NAME
else
	.log 6 "Existing role assignment found."
fi

.log 6 "Creating VNet"
az network vnet create --resource-group $RESOURCE_GROUP_NAME --name $KUBERNETES_VNET_NAME --address-prefix $KUBERNETES_VNET_CIDR --subnet-name $KUBERNETES_SUBNET_NAME --subnet-prefix $KUBERNETES_SUBNET_CIDR

declare KUBERNETES_VNET_SUBNET_ID=$(az network vnet create --resource-group $RESOURCE_GROUP_NAME --name $KUBERNETES_VNET_NAME --address-prefix $KUBERNETES_VNET_CIDR --subnet-name $KUBERNETES_SUBNET_NAME --subnet-prefix $KUBERNETES_SUBNET_CIDR --query "newVNet.subnets[0].id" | grep -e "\"[^\"]*\"" | tr -d '"' | tr -d ' ' | tr -d '\n')

.log 6 "Preparing acs-engine model in '$outputDirName'..."
mkdir -p $outputDirName

if [ -z "$SSH_PUBLIC_KEY_DATA" ]; then
	.log 6 "Generating SSH Public Private Key Pair"
	ssh-keygen -f $outputDirName/kubernetes_ssh_key -t rsa -b 4096 -N ''
	SSH_PUBLIC_KEY_DATA=$(cat $outputDirName/kubernetes_ssh_key.pub)
else
	.log 6 "Using provided SSH Public Key"
fi

# Common first
cat ${TEMPLATE_FILE} | \
	jq ".properties.orchestratorProfile.orchestratorRelease = \"${KUBERNETES_VERSION}\"" | \
	jq ".properties.orchestratorProfile.kubernetesConfig.networkPolicy = \"${KUBERNETES_NETWORK_POLICY}\"" | \
	jq ".properties.masterProfile.dnsPrefix = \"${KUBERNETES_DNS_PREFIX}\"" | \
	jq ".properties.masterProfile.count = ${KUBERNETES_MASTER_COUNT}" | \
	jq ".properties.masterProfile.vmSize = \"${KUBERNETES_MASTER_SIZE}\"" | \
	jq ".properties.masterProfile.vnetSubnetId = \"${KUBERNETES_VNET_SUBNET_ID}\"" | \
	jq ".properties.masterProfile.firstConsecutiveStaticIP = \"${KUBERNETES_FIRST_CONSECUTIVE_MASTER_IP}\"" | \
	jq ".properties.masterProfile.vnetCidr = \"${KUBERNETES_VNET_CIDR}\"" | \
	jq ".properties.agentPoolProfiles[0].name = \"${NODE_POOL_1_NAME}\"" | \
	jq ".properties.agentPoolProfiles[0].count = ${NODE_POOL_1_COUNT}" | \
	jq ".properties.agentPoolProfiles[0].vmSize = \"${NODE_POOL_1_SIZE}\"" | \
	jq ".properties.agentPoolProfiles[0].vnetSubnetId = \"${KUBERNETES_VNET_SUBNET_ID}\"" | \
	jq ".properties.linuxProfile.ssh.publicKeys[0].keyData = \"${SSH_PUBLIC_KEY_DATA}\"" | \
	jq ".properties.servicePrincipalProfile.clientId = \"${SERVICE_PRINCIPAL_ID}\"" | \
	jq ".properties.servicePrincipalProfile.secret = \"${SERVICE_PRINCIPAL_SECRET}\"" > ./$outputDirName/kubernetes_tmp_initial.json

if [ -z "AADPROFILE_SERVER_APP_ID" ]; then
	cat ./$outputDirName/kubernetes_tmp_initial.json | \
		jq 'del(.properties.aadProfile)' > ./$outputDirName/kubernetes_tmp.json
else
	cat ./$outputDirName/kubernetes_tmp_initial.json | \
		jq ".properties.aadProfile.serverAppID = \"${AADPROFILE_SERVER_APP_ID}\"" | \
		jq ".properties.aadProfile.clientAppID = \"${AADPROFILE_CLIENT_APP_ID}\"" | \
		jq ".properties.aadProfile.tenantID = \"${AADPROFILE_TENANT_ID}\"" > ./$outputDirName/kubernetes_tmp.json
fi

if [ -z "$NODE_POOL_2_NAME" ] && [ -z "$NODE_POOL_3_NAME" ]; then
	cat ./$outputDirName/kubernetes_tmp.json | \
	    jq 'del(.properties.agentPoolProfiles[] | select(.name == "${NODE_POOL_2_NAME}"))' | \
		jq 'del(.properties.agentPoolProfiles[] | select(.name == "${NODE_POOL_3_NAME}"))' > ./$outputDirName/kubernetes.json
elif [ -z "$NODE_POOL_3_NAME" ]; then
	cat ./$outputDirName/kubernetes_tmp.json | \
		jq ".properties.agentPoolProfiles[1].name = \"${NODE_POOL_2_NAME}\"" | \
		jq ".properties.agentPoolProfiles[1].count = ${NODE_POOL_2_COUNT}" | \
		jq ".properties.agentPoolProfiles[1].vmSize = \"${NODE_POOL_2_SIZE}\"" | \
		jq ".properties.agentPoolProfiles[1].vnetSubnetId = \"${KUBERNETES_VNET_SUBNET_ID}\"" | \
		jq 'del(.properties.agentPoolProfiles[] | select(.name == "${NODE_POOL_3_NAME}"))' > ./$outputDirName/kubernetes.json
elif [ -z "$NODE_POOL_2_NAME" ]; then
	cat ./$outputDirName/kubernetes_tmp.json | \
		jq ".properties.agentPoolProfiles[2].name = \"${NODE_POOL_3_NAME}\"" | \
		jq ".properties.agentPoolProfiles[2].count = ${NODE_POOL_3_COUNT}" | \
		jq ".properties.agentPoolProfiles[2].vmSize = \"${NODE_POOL_3_SIZE}\"" | \
		jq ".properties.agentPoolProfiles[2].vnetSubnetId = \"${KUBERNETES_VNET_SUBNET_ID}\"" | \
		jq 'del(.properties.agentPoolProfiles[] | select(.name == "${NODE_POOL_2_NAME}"))' > ./$outputDirName/kubernetes.json
else 
	cat ./$outputDirName/kubernetes_tmp.json | \
		jq ".properties.agentPoolProfiles[1].name = \"${NODE_POOL_2_NAME}\"" | \
		jq ".properties.agentPoolProfiles[1].count = ${NODE_POOL_2_COUNT}" | \
		jq ".properties.agentPoolProfiles[1].vmSize = \"${NODE_POOL_2_SIZE}\"" | \
		jq ".properties.agentPoolProfiles[1].vnetSubnetId = \"${KUBERNETES_VNET_SUBNET_ID}\"" | \
		jq ".properties.agentPoolProfiles[2].name = \"${NODE_POOL_3_NAME}\"" | \
		jq ".properties.agentPoolProfiles[2].count = ${NODE_POOL_3_COUNT}" | \
		jq ".properties.agentPoolProfiles[2].vmSize = \"${NODE_POOL_3_SIZE}\"" | \
		jq ".properties.agentPoolProfiles[2].vnetSubnetId = \"${KUBERNETES_VNET_SUBNET_ID}\"" > ./$outputDirName/kubernetes.json
fi

rm $outputDirName/kubernetes_tmp_initial.json
rm $outputDirName/kubernetes_tmp.json

.log 6 "Generating deployment templates from model..."
acs-engine generate --api-model ./$outputDirName/kubernetes.json --output-directory ./$outputDirName/arm-deploy

# Copy just the essential files, remove all other generated data. 
cp $outputDirName/arm-deploy/azuredeploy.json $outputDirName/azuredeploy.json
cp $outputDirName/arm-deploy/azuredeploy.parameters.json $outputDirName/azuredeploy.parameters.json

.log 6 "Prepare scale up template..."
# 1st: Need to remove NSG dependency, see https://github.com/Azure/acs-engine/tree/master/examples/scale-up
cat $outputDirName/azuredeploy.json | jq 'del(.resources[] | .dependsOn[]? | select(. | contains("nsgID")))' | jq 'del(.resources[] | select(.type == "Microsoft.Network/networkSecurityGroups"))' > $outputDirName/azuredeploy_scale_up.json
# 2nd: Set invalid value to count & pool offset, to avoid accidental updates.

if [ -z "$NODE_POOL_2_NAME" ] && [ -z "$NODE_POOL_3_NAME" ]; then
	cat $outputDirName/azuredeploy.parameters.json |  \
		jq ".parameters.${NODE_POOL_1_NAME}Count.value = -1" | \
		jq --argjson n "{\"${NODE_POOL_1_NAME}Offset\": {\"value\": -1}}"  '.parameters + $n' > $outputDirName/azuredeploy_scale_up.parameters.json
elif [ -z "$NODE_POOL_3_NAME" ]; then
	cat $outputDirName/azuredeploy.parameters.json |  \
		jq ".parameters.${NODE_POOL_1_NAME}Count.value = -1" | \
		jq ".parameters.${NODE_POOL_2_NAME}Count.value = -1" | \
		jq --argjson n1 "{\"${NODE_POOL_1_NAME}Offset\": {\"value\": -1}}" --argjson n2 "{\"${NODE_POOL_2_NAME}Offset\": {\"value\": -1}}" '.parameters + $n1 + $n2' > $outputDirName/azuredeploy_scale_up.parameters.json
elif [ -z "$NODE_POOL_2_NAME" ]; then
	cat $outputDirName/azuredeploy.parameters.json |  \
		jq ".parameters.${NODE_POOL_1_NAME}Count.value = -1" | \
		jq ".parameters.${NODE_POOL_3_NAME}Count.value = -1" | \
		jq --argjson n1 "{\"${NODE_POOL_1_NAME}Offset\": {\"value\": -1}}" --argjson n2 "{\"${NODE_POOL_3_NAME}Offset\": {\"value\": -1}}" '.parameters + $n1 + $n2' > $outputDirName/azuredeploy_scale_up.parameters.json
else 
	cat $outputDirName/azuredeploy.parameters.json |  \
		jq ".parameters.${NODE_POOL_1_NAME}Count.value = -1" | \
		jq ".parameters.${NODE_POOL_2_NAME}Count.value = -1" | \
		jq ".parameters.${NODE_POOL_3_NAME}Count.value = -1" | \
		jq --argjson n1 "{\"${NODE_POOL_1_NAME}Offset\": {\"value\": -1}}" --argjson n2 "{\"${NODE_POOL_2_NAME}Offset\": {\"value\": -1}}" --argjson n3 "{\"${NODE_POOL_3_NAME}Offset\": {\"value\": -1}}" '.parameters + $n1 + $n2 + $n3' > $outputDirName/azuredeploy_scale_up.parameters.json
fi

.log 6 "Running az arm deployment (this will take several minutes...)"
az group deployment create --resource-group $RESOURCE_GROUP_NAME --template-file $outputDirName/azuredeploy.json --parameters $outputDirName/azuredeploy.parameters.json

# Copy the region-specifc config to the top level in the output directory.
declare RESOURCE_GROUP_LOCATION_LC=$(echo "$RESOURCE_GROUP_LOCATION" | tr '[:upper:]' '[:lower:]')

# Copy the region-specifc config to the top level in the output directory.
cp $outputDirName/arm-deploy/kubeconfig/kubeconfig.$RESOURCE_GROUP_LOCATION_LC.json $outputDirName/config

if ! [ -z "$AADPROFILE_ADMIN_ID" ]; then 
		.log 6 "Configuring cluster-admin role for user $AADPROFILE_ADMIN_ID..."
	if [ -f $outputDirName/kubernetes_ssh_key ]; then
		ssh -o StrictHostKeyChecking=no -i $outputDirName/kubernetes_ssh_key azureuser@$KUBERNETES_DNS_PREFIX.$RESOURCE_GROUP_LOCATION.cloudapp.azure.com << ENDSSH
			kubectl create clusterrolebinding aad-default-cluster-admin-binding \
			--clusterrole=cluster-admin \
			--user "https://sts.windows.net/${AADPROFILE_TENANT_ID}/#${AADPROFILE_ADMIN_ID}"
ENDSSH
	else
		.log 4 "Cannot configure cluster-admin role with custom SSH Key. Please fix manually."
	fi
fi

if ! [ -z "$ADMIN_RESOURCE_GROUP_NAME" ]; then 
	# Copy the region-specifc config to the configured key vault store
	az keyvault secret set --name kubeconfig --vault-name $ADMIN_KEY_VAULT_NAME --file $outputDirName/config --encoding utf-8
	.log 6 "kubeconfig was uploaded to your key vault: $ADMIN_KEY_VAULT_NAME"
	.log 6 "Download via: az keyvault secret download --name kubeconfig --vault-name $ADMIN_KEY_VAULT_NAME --file ~/.kube/config"

	if [ -f $outputDirName/kubernetes_ssh_key ]; then
		az keyvault secret set --name kubernetes-ssh-key --vault-name $ADMIN_KEY_VAULT_NAME --file $outputDirName/kubernetes_ssh_key --encoding utf-8
		.log 6 "kubernetes-ssh-key was uploaded to your key vault: $ADMIN_KEY_VAULT_NAME"
	fi

	declare DEPLOYMENT_CONFIG_PASSWORD=$(openssl rand -base64 24)
	7z a $outputDirName.7z ./$outputDirName/ -p"$DEPLOYMENT_CONFIG_PASSWORD"
	mv $outputDirName.7z ./$outputDirName/
	az keyvault secret set --name deployment-config-password --vault-name $ADMIN_KEY_VAULT_NAME --value "$DEPLOYMENT_CONFIG_PASSWORD"
	.log 6 "$outputDirName.7z password was uploaded to your key vault: $ADMIN_KEY_VAULT_NAME"
	
	declare AZURE_STORAGE_ACCOUNT=$ADMIN_STORAGE_NAME
	declare AZURE_STORAGE_ACCESS_KEY=$(az storage account keys list --account-name $ADMIN_STORAGE_NAME  -g QNOWS_PROD_QA_K8s_ADMIN_RG --query "[0].value" | tr -d '"' | tr -d ' ' | tr -d '\n' )
	az storage container create --name deployment-config --account-name "$AZURE_STORAGE_ACCOUNT" --account-key "$AZURE_STORAGE_ACCESS_KEY"
	az storage blob upload --container-name deployment-config --account-name "$AZURE_STORAGE_ACCOUNT" --account-key "$AZURE_STORAGE_ACCESS_KEY" --file ./$outputDirName/$outputDirName.7z --name $outputDirName.7z
	.log 6 "$outputDirName.7z file was uploaded to your storage account: $ADMIN_STORAGE_NAME"	

	.log 6 "Cleaning up local data..."
	rm -rf ./$outputDirName/
fi

# Clean up
rm -rf ./translations/
