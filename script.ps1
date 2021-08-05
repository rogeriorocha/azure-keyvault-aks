#   brazilsouth   
#   Standard_DS2_v2
#   Standard_F4s_v2  

az vm list-sizes -l brazilsouth | jq -c '.[] | select(.name | contains("Standard_DS2_"))'



echo "Set variables..." 

$cleanAfter = "false" 

$suffix = "demo-rpsr-002"
$vnetName = "vn-aks"
$spName = "AKSClusterServicePrincipal-"+ $suffix
$subscriptionId = (az account show | ConvertFrom-Json).id
$tenantId = (az account show | ConvertFrom-Json).tenantId
$location = "brazilsouth"
$resourceGroupName = "rg-devops-teste"

$aksName = "aks-" + $suffix
$aksVersion = "1.19.11"
$keyVaultName = "keyvault-" + $suffix

$secret1Name = "DBUsername"
$secret2Name = "DBPassword"

$secret1Alias = "DB_USERNAME"
$secret2Alias = "DB_PASSWORD" 

$identityName = "identity-aks-kv" 
$identitySelector = "azure-kv"
$secretProviderClassName = "secret-provider-kv"

#secrets
$secretName = "secret-kv"
$K8sSecret1 = "usr"
$K8sSecret2 = "psw"

echo "Creating Resource Group $resourceGroupName ..."
$rg = az group create -n $resourceGroupName -l $location | ConvertFrom-Json

echo "Creating an Azure Identity..."
$identity = az identity create -g $resourceGroupName -n $identityName | ConvertFrom-Json
#$identity = az identity show  -g $resourceGroupName -n $identityName | ConvertFrom-Json

echo "Creating Key Vault..."
$keyVault = az keyvault create -n $keyVaultName -g $resourceGroupName -l $location --retention-days 7 | ConvertFrom-Json
#$keyVault = (az keyvault show -n $keyVaultName | ConvertFrom-Json) # retrieve existing KV


echo "creating SP $spName..."
$sp = az ad sp create-for-rbac --skip-assignment --name $spName | ConvertFrom-Json

echo "Create vnet and subnet"
# Create vnet and subnet  
$vnet = az network vnet create -g $resourceGroupName --location $location --name $vnetName --address-prefixes 10.0.0.0/8 | ConvertFrom-Json
$nodesubnet = az network vnet subnet create -g $resourceGroupName --vnet-name $vnetName --name nodesubnet --address-prefixes 10.240.0.0/16 | ConvertFrom-Json
#$podsubnet = az network vnet subnet create -g $resourceGroupName --vnet-name $vnetName --name podsubnet --address-prefixes 10.241.0.0/16 | ConvertFrom-Json
#

echo "Creating AKS cluster..." # doesn't work with AKS with Managed Identity!
#$aks = az aks create -n $aksName -g $resourceGroupName --enable-managed-identity --kubernetes-version $aksVersion --node-count 1 | ConvertFrom-Json
$aks = az aks create -n $aksName -g $resourceGroupName --service-principal $sp.appId --client-secret $sp.password --kubernetes-version $aksVersion --node-count 2 `
  --network-plugin azure --vnet-subnet-id $nodesubnet.id --node-vm-size "Standard_DS2_v2" `
   | ConvertFrom-Json


#   brazilsouth   
#   Standard_DS2_v2
#   Standard_F4s_v2  
#NOT FOUND --pod-subnet-id $podsubnet.id `  
#$aks = (az aks show -n $aksName -g $resourceGroupName | ConvertFrom-Json) # retrieve existing AKS

sleep 10

echo "Connecting/athenticating to AKS..."
az aks get-credentials -n $aksName -g $resourceGroupName --overwrite-existing

sleep 20
kubectl get po -A


echo "Creating Secrets in Key Vault..."
az keyvault secret set --name $secret1Name --value "u_rpsr" --vault-name $keyVaultName
az keyvault secret set --name $secret2Name --value "P@ssword&" --vault-name $keyVaultName

echo "Adding Helm repo for Secret Store CSI..."
helm repo add secrets-store-csi-driver https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/master/charts

echo "Installing Secrets Store CSI Driver using Helm..."
kubectl create ns csi-driver
helm --namespace csi-driver install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver  --set syncSecret.enabled=true

# test Secret Rotation
#helm --namespace csi-driver upgrade --set syncSecret.enabled=true --set enableSecretRotation=true --set rotationPollInterval="10s" csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver
sleep 2
kubectl get pods -n csi-driver

echo "Installing Secrets Store CSI Driver with Azure Key Vault Provider..."
kubectl apply -f https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/deployment/provider-azure-installer.yaml --namespace csi-driver
sleep 2
kubectl get pods -n csi-driver
#helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts
#helm install csi-azure csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --namespace csi-driver

echo "Using the Azure Key Vault Provider..."
$secretProviderKV = @"
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: $($secretProviderClassName)
spec:
  provider: azure
  secretObjects:
  - data:
    - key: username
      objectName: $secret1Alias
    - key: password
      objectName: $secret2Alias
    secretName: $secretName
    type: Opaque
  parameters:
    usePodIdentity: "true"
    useVMManagedIdentity: "false"
    userAssignedIdentityID: ""
    keyvaultName: $keyVaultName
    cloudName: AzurePublicCloud
    objects:  |
      array:
        - |
          objectName: $secret1Name
          objectAlias: $secret1Alias
          objectType: secret
          objectVersion: ""
        - |
          objectName: $secret2Name
          objectAlias: $secret2Alias
          objectType: secret
          objectVersion: ""
    resourceGroup: $resourceGroupName
    subscriptionId: $subscriptionId
    tenantId: $tenantId
"@
$secretProviderKV | kubectl create -f -

echo "Installing AAD Pod Identity into AKS..."
kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
sleep 10 
kubectl get pods

#BUG
#$existingIdentity = $null
#  while($existingIdentity -eq $null) {
#    
#    $existingIdentity = az resource list -g $aks.nodeResourceGroup --query "[?contains(type, 'Microsoft.ManagedIdentity/userAssignedIdentities')]"  | ConvertFrom-Json
#  }
#

echo "Assigning Reader Role to new Identity for Key Vault..."
az role assignment create --role "Reader" --assignee $identity.principalId --scope $keyVault.id

echo "Providing required permissions for MIC..."
az role assignment create --role "Managed Identity Operator" --assignee $aks.servicePrincipalProfile.clientId --scope $identity.id

# az role assignment list --scope $identity.id

echo "Setting policy to access secrets in Key Vault..."
az keyvault set-policy -n $keyVaultName --secret-permissions get --spn $identity.clientId

sleep 10

echo "Adding AzureIdentity and AzureIdentityBinding..."
$aadPodIdentityAndBinding = @"
apiVersion: aadpodidentity.k8s.io/v1
kind: AzureIdentity
metadata:
  name: $($identityName)
spec:
  type: 0
  resourceID: $($identity.id)
  clientID: $($identity.clientId)
---
apiVersion: aadpodidentity.k8s.io/v1
kind: AzureIdentityBinding
metadata:
  name: $($identityName)-binding
spec:
  azureIdentity: $($identityName)
  selector: $($identitySelector)
"@
$aadPodIdentityAndBinding | kubectl apply -f -

echo "Deploying a busybox Pod for testing..."
$busyboxPod = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busybox-deployment
  labels:
    app: busybox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: busybox
  template:
    metadata:
      labels:
        app: busybox
        aadpodidbinding: $($identitySelector)          
    spec:
      terminationGracePeriodSeconds: 0
      containers:
        - name: busybox
          image: k8s.gcr.io/e2e-test-images/busybox:1.29
          command:
            - "/bin/sleep"
            - "10000"
          env:
            - name: SECRET_USERNAME
              valueFrom:
                secretKeyRef:
                  name: $($secretName)
                  key: username
            - name: SECRET_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: $($secretName)
                  key: password
          volumeMounts:
            - name: secrets-store-inline
              mountPath: "/mnt/secrets-store"
              readOnly: true
      volumes:
        - name: secrets-store-inline
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: $($secretProviderClassName)
"@
$busyboxPod | kubectl apply -f - 

sleep 20

echo "Validating the pod has access to the secrets from Key Vault..."
$container = kubectl get pods --selector=app=busybox -o jsonpath='{.items[*].metadata.name}'
echo "container pod busybox = $($container)"

echo "Validating - VOLUME MOUNTS VARS"
kubectl exec -it $container -- ls /mnt/secrets-store/
echo ""
kubectl exec -it $container -- sh -c "echo -n '$secret1Alias = ' > /tmp/t;cat /mnt/secrets-store/$secret1Alias >> /tmp/t; cat /tmp/t"
echo ""
kubectl exec -it $container -- sh -c "echo -n '$secret2Alias = ' > /tmp/t;cat /mnt/secrets-store/$secret2Alias >> /tmp/t; cat /tmp/t"
echo "Validating - ENV VARS"
kubectl exec -it $container -- sh -c "set | grep -e SECRET_USERNAME -e SECRET_PASSWORD"

If ($cleanAfter -eq "true") {
  echo "clean up"
  echo "deleting SP..."
  az ad sp delete --id $sp.appId
  echo "deleting RG  $resourceGroupName ..."
  az group delete -n $resourceGroupName --no-wait -y
} 