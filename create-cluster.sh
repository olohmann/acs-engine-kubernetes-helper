#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

usage() { echo "Usage: $0 -k <sshPubKeyData> -c <servicePrincipleId> -s <servicePrincipleSecret> -n <dnsPrefix> -i <subscriptionId> -g <resourceGroupName> -l <resourceGroupLocation>" 1>&2; exit 1; }

declare dnsPrefix=""
declare subscriptionId=""
declare resourceGroupName=""
declare deploymentName=""
declare resourceGroupLocation=""
declare sshPubKeyData=""
declare servicePrincipleId=""
declare servicePrincipleSecret=""
declare kubernetesVersion="1.9"
declare networkPolicy="calico"
declare vnetName="kubernetes-vnet"
declare vnetCidr="10.239.0.0/16"
declare subnetName="default"
declare subnetCidr="10.239.0.0/16"
declare firstConsecutiveMasterIP="10.239.255.10"
declare outputDirName="out-$(date +%Y%m%d_%H%M%S)"

while getopts ":k:c:s:n:i:g:l:h:" arg; do
	case "${arg}" in
		k)
			sshPubKeyData=${OPTARG}
			;;
		c)
			servicePrincipleId=${OPTARG}
			;;
		s)
			servicePrincipleSecret=${OPTARG}
			;;
		n)
			dnsPrefix=${OPTARG}
			;;
		i)
			subscriptionId=${OPTARG}
			;;
		g)
			resourceGroupName=${OPTARG}
			;;
		l)
			resourceGroupLocation=${OPTARG}
			;;
		l)
			usage
			;;
		esac
done
shift $((OPTIND-1))

if [ -z "$sshPubKeyData" ] || [ -z "$servicePrincipleId" ] || [ -z "$servicePrincipleSecret" ] || [ -z "$dnsPrefix" ] || [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ] || [ -z "$resourceGroupLocation" ]; then
	echo "Either one of sshPubKeyData, servicePrincipleId, servicePrincipleSecret, dnsPrefix, subscriptionId, resourceGroupName, resourceGroupLocation is empty"
	usage
fi


echo "Using resource group '$resourceGroupName'..."
echo "Running custom VNet deployment: $vnetName $vnetCidr (subnet: $subnetName $subnetCidr)..."
az account set --subscription $subscriptionId > /dev/null 2>&1
az group create -n $resourceGroupName -l $resourceGroupLocation > /dev/null 2>&1
az network vnet create --resource-group $resourceGroupName --name $vnetName --address-prefix $vnetCidr --subnet-name $subnetName --subnet-prefix $subnetCidr > /dev/null 2>&1
declare vnetSubnetId=$(az network vnet create --resource-group $resourceGroupName --name $vnetName --address-prefix $vnetCidr --subnet-name $subnetName --subnet-prefix $subnetCidr --query "newVNet.subnets[0].id" | grep -e "\"[^\"]*\"" | tr -d '"' | tr -d ' ' | tr -d '\n')

echo "Preparing acs-engine model in '$outputDirName'..."
# Escape / (forward slash) in vars for sed replace.
declare sshPubKeyDataEsc=$(echo $sshPubKeyData | sed -e 's/[\/&]/\\&/g')
declare vnetCidrEsc=$(echo $vnetCidr | sed -e 's/[\/&]/\\&/g')
declare vnetSubnetIdEsc=$(echo $vnetSubnetId | sed -e 's/[\/&]/\\&/g')
declare servicePrincipleIdEsc=$(echo $servicePrincipleId | sed -e 's/[\/&]/\\&/g')
declare servicePrincipleSecretEsc=$(echo $servicePrincipleSecret | sed -e 's/[\/&]/\\&/g')

# Replacements
mkdir -p $outputDirName
sed -e "s/\${kubernetesVersion}/$kubernetesVersion/" \
    -e "s/\${networkPolicy}/$networkPolicy/" \
    -e "s/\${dnsPrefix}/$dnsPrefix/" \
    -e "s/\${firstConsecutiveMasterIP}/$firstConsecutiveMasterIP/" \
    -e "s/\${vnetCidr}/$vnetCidrEsc/" \
    -e "s/\${vnetSubnetId}/$vnetSubnetIdEsc/" \
    -e "s/\${sshPubKeyData}/$sshPubKeyDataEsc/" \
    -e "s/\${servicePrincipleId}/$servicePrincipleIdEsc/" \
    -e "s/\${servicePrincipleSecret}/$servicePrincipleSecretEsc/" \
    ./kubernetes_template.json > ./$outputDirName/kubernetes.json

echo "Generating deployment templates from model..."
acs-engine generate --api-model ./$outputDirName/kubernetes.json --output-directory ./$outputDirName/arm-deploy > /dev/null 2>&1

# Clean up acs-engine output
rm -rf ./translations/

echo "Running az arm deployment (this will take several minutes...)"
az group deployment create --resource-group $resourceGroupName --template-file $outputDirName/arm-deploy/azuredeploy.json --parameters $outputDirName/arm-deploy/azuredeploy.parameters.json

# Copy the region-specifc config to the top level in the output directory.
declare resourceGroupLocationLC=$(echo "$resourceGroupLocation" | tr '[:upper:]' '[:lower:]')
cp $outputDirName/arm-deploy/kubeconfig/kubeconfig.$resourceGroupLocationLC.json $outputDirName/config
echo "Done. Your kubeconfig: ./$outputDirName/config"
