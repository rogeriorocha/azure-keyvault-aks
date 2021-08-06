terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.70.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 2.4.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "= 2.2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.11.3"
    }
  }
}


data "azurerm_kubernetes_cluster" "default" {
  #depends_on          = [module.aks-cluster] # refresh cluster state before reading

  #name                = local.cluster_name
  name                = azurerm_kubernetes_cluster.aks.name
  resource_group_name = azurerm_resource_group.rg.name
}


provider "kubectl" {
  host                   = data.azurerm_kubernetes_cluster.default.kube_config.0.host
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.cluster_ca_certificate)
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.client_key)
  #token                  = data.aws_eks_cluster_auth.main.token
  #token                  = data.azurerm_kubernetes_cluster.default.kube_config.0.client_key
  #load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.default.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}



provider "azurerm" {
  features {}
}

provider "azuread" {
  #version = "=1.6.0"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-demo-rpsr-tf-23"
  location = "East US 2"
}

resource "azurerm_user_assigned_identity" "id-aks-kv" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  # RPSR vide in module too 
  name = "id-aks-kv"

}

#data "azuread_service_principal" "sp" {
#  display_name = "AKSClusterServicePrincipal-demo0000999"
#}


## ad
resource "azuread_application" "app" {
  display_name     = "app-sample-tf"
  sign_in_audience = "AzureADMyOrg"
}


resource "azuread_service_principal" "sp-aks" {
  application_id               = azuread_application.app.application_id
  app_role_assignment_required = false
  tags                         = ["example", "tags", "here"]
}

resource "azuread_application_password" "rbac" {
  application_object_id = azuread_application.app.object_id
  display_name          = "rbac"
}


resource "azurerm_key_vault" "kv" {
  #RPSR module have tool!!
  name                = "kv-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  #enabled_for_disk_encryption = true
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  #purge_protection_enabled    = false

  sku_name = "standard"
  /*
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id


    key_permissions = [
      "Get",
      "list"
    ]

    secret_permissions = [
      "set",
      "get",
      "delete",
      "purge",
      "recover",
      "list"
    ]

    storage_permissions = [
      "Get",
      "list"
    ]
  }
  */

}


resource "azurerm_key_vault_access_policy" "kvp-current" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get",
    "list"
  ]

  secret_permissions = [
    "set",
    "get",
    "delete",
    "purge",
    "recover",
    "list"
  ]

  storage_permissions = [
    "Get",
    "list"
  ]

  certificate_permissions = [
      "Get",
      "List",
      "Update",
      "Create",
      "Import",
      "Delete",
      "Recover",
      "Backup",
      "Restore",
      "ManageContacts",
      "ManageIssuers",
      "GetIssuers",
      "ListIssuers",
      "SetIssuers",
      "DeleteIssuers",
  ]   
}


resource "azurerm_key_vault_access_policy" "kvp-id-aks" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.id-aks-kv.principal_id
  secret_permissions = [
    "Get",
  ]
  
  depends_on = [azurerm_key_vault_access_policy.kvp-current]
}

resource "azurerm_key_vault_secret" "kv-secret-1" {
  name         = "DBUsername"
  value        = "sist_rpsr"
  key_vault_id = azurerm_key_vault.kv.id
  
  depends_on = [azurerm_key_vault_access_policy.kvp-current]
}

resource "azurerm_key_vault_secret" "kv-secret-2" {
  name         = "DBPassword"
  value        = "P@ssword&"
  key_vault_id = azurerm_key_vault.kv.id
  
  depends_on = [azurerm_key_vault_access_policy.kvp-current]
}

resource "azurerm_virtual_network" "vn-aks" {
  name                = "vn-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/8"]
  #dns_servers         = ["10.0.0.4", "10.0.0.5"]

  #ddos_protection_plan {
  #  id     = azurerm_network_ddos_protection_plan.example.id
  #  enable = true
  #}
  /*
  subnet {
    name           = "nodesubnet"
    address_prefix = "10.240.0.0/16"
  }
  */

  tags = {
    environment = "Test"
  }
}


resource "azurerm_subnet" "sn-node" {
  name                 = "sn-node"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vn-aks.name
  address_prefixes     = ["10.240.0.0/16"]
}

resource "azurerm_role_assignment" "role-kv-id" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.id-aks-kv.principal_id
}


# az role assignment create --role "" --assignee $aks.servicePrincipalProfile.clientId --scope $identity.id
resource "azurerm_role_assignment" "example" {
  scope                = azurerm_user_assigned_identity.id-aks-kv.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azuread_service_principal.sp-aks.id
}

/* RPSR
resource "azurerm_key_vault_access_policy" "kvp-id-aks" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.id-aks-kv.principal_id

  secret_permissions = [
    "Get",
  ]
}
*/

## AKS
#$aks = az aks create -n $aksName -g $resourceGroupName --service-principal $sp.appId --client-secret $sp.password --kubernetes-version $aksVersion --node-count 2 `
#  --network-plugin azure --vnet-subnet-id $nodesubnet.id --node-vm-size "Standard_DS2_v2" 


#resource "azuread_service_principal_password" "example" {
#  service_principal_id = azuread_service_principal.example.object_id
#}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-tf-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "test"
  kubernetes_version  = "1.19.11"
  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = file(var.ssh_public_key)
    }
  }

  network_profile {
    load_balancer_sku = "Standard"
    network_plugin    = "azure"
  }

  default_node_pool {
    name           = "default"
    node_count     = 2
    vm_size        = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.sn-node.id
  }

  service_principal {
    client_id     = azuread_application.app.application_id
    client_secret = azuread_application_password.rbac.value
  }

  depends_on = [
    azuread_application.app,
    azuread_application_password.rbac
  ]

  tags = {
    Environment = "Dev"
  }
}

### PROVIDER AZURE INSTALLER
data "kubectl_file_documents" "manifests-from-provider-azure-installer" {
  content = file("${path.root}/provider-azure-installer.yaml")
}

resource "kubectl_manifest" "provider-azure-installer" {
  count     = length(data.kubectl_file_documents.manifests-from-provider-azure-installer.documents)
  yaml_body = element(data.kubectl_file_documents.manifests-from-provider-azure-installer.documents, count.index)
}

####


module "kubernetes-config" {
  #depends_on   = [module.aks-cluster]
  source = "./kubernetes-config"
  #cluster_name = local.cluster_name
  kubeconfig     = azurerm_kubernetes_cluster.aks.kube_config_raw
  cluster_name   = azurerm_kubernetes_cluster.aks.name
  resourceGroup  = azurerm_resource_group.rg.name
  subscriptionId = data.azurerm_client_config.current.subscription_id
  tenantId       = data.azurerm_client_config.current.tenant_id
}

resource "kubectl_manifest" "secret-provider-class" {
  yaml_body = templatefile(
    "${path.root}/secret-provider-class.yaml"
    ,
    { tenantId                = "\"${data.azurerm_client_config.current.tenant_id}\"",
      resourceGroupName       = "\"${azurerm_resource_group.rg.name}\"",
      subscriptionId          = "\"${data.azurerm_client_config.current.subscription_id}\"",
      secretProviderClassName = var.secretProviderClassName,
      keyVaultName            = var.keyVaultName,
      secretName              = var.secretName,
      secret1Alias            = var.secret1Alias,
      secret2Alias            = var.secret2Alias,
      secret1Name             = var.secret1Name,
      secret2Name             = var.secret2Name
  })
  depends_on = [
    kubectl_manifest.provider-azure-installer,
    module.kubernetes-config
  ]
}


#echo "Installing AAD Pod Identity into AKS..."
#kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
#sleep 10 
#kubectl get pods



data "kubectl_file_documents" "manifests-from-aad-pod-identity" {
  content = file("${path.root}/aad-pod-identity-deployment-rbac.yaml")
}

resource "kubectl_manifest" "aad-pod-identity" {
  count     = length(data.kubectl_file_documents.manifests-from-aad-pod-identity.documents)
  yaml_body = element(data.kubectl_file_documents.manifests-from-aad-pod-identity.documents, count.index)
}


#### azure-identity-and-binding
resource "kubectl_manifest" "azure-identity" {
  yaml_body = templatefile(
    "${path.root}/azure-identity.yaml"
    ,
    {
      identityName      = azurerm_user_assigned_identity.id-aks-kv.name,
      identity_id       = azurerm_user_assigned_identity.id-aks-kv.id,
      identity_clientId = azurerm_user_assigned_identity.id-aks-kv.client_id
    }
  )
  #force_new = true
}

resource "kubectl_manifest" "azure-identity-binding" {
  yaml_body = templatefile(
    "${path.root}/azure-identity-binding.yaml"
    ,
    {
      identityName     = azurerm_user_assigned_identity.id-aks-kv.name,
      identitySelector = var.identitySelector
    }
  )
  #force_new = true  
}

/*
data "kubectl_file_documents" "manifests-from-azure-identity-and-binding" {
  content = templatefile(
    "${path.root}/azure-identity-and-binding.yaml"
    ,
    {
      identityName      = azurerm_user_assigned_identity.id-aks-kv.name,
      identity_id       = azurerm_user_assigned_identity.id-aks-kv.id,
      identity_clientId = azurerm_user_assigned_identity.id-aks-kv.client_id
      identitySelector  = var.identitySelector
    }
  )
  depends_on = [azurerm_user_assigned_identity.id-aks-kv]
}

resource "kubectl_manifest" "manifests-from-azure-identity-and-binding" {
  count     = length(data.kubectl_file_documents.manifests-from-azure-identity-and-binding.documents)
  yaml_body = element(data.kubectl_file_documents.manifests-from-azure-identity-and-binding.documents, count.index)
  #force_new = true
  depends_on = [data.kubectl_file_documents.manifests-from-azure-identity-and-binding]
}
*/

##### SAMPLE BUSYBOX
resource "kubectl_manifest" "busybox-test" {
  yaml_body = templatefile(
    "${path.root}/busybox-test.yaml"
    ,
    {
      identitySelector        = var.identitySelector,
      secretName              = var.secretName,
      secretProviderClassName = var.secretProviderClassName
    }
  )
  depends_on = [azurerm_kubernetes_cluster.aks,
  kubectl_manifest.secret-provider-class]
}

/*
output "current_object_id" {
  description = "current.object_id"
  value = data.azurerm_client_config.current.object_id
}  


output "busybox-test-deploy" {
  description = "busybox-test-deploy"
  value = templatefile(
               "${path.root}/busybox-test.yaml"
               , 
               { 
                 identitySelector         = var.identitySelector,
                 secretName               = var.secretName,
                 secretProviderClassName  = var.secretProviderClassName
               }
            )
}

output "qtde-manifestos" {
  description = "qtde"
  value = length(data.kubectl_file_documents.manifests-from-aad-pod-identity.documents)
}

output "azure-identity-and-binding-out" {
  description = ""
  value = templatefile(
               "${path.root}/azure-identity-and-binding.yaml"
               , 
               { 
                 identityName         = azurerm_user_assigned_identity.id-aks-kv.name,
                 identity_id          = azurerm_user_assigned_identity.id-aks-kv.id,
                 identity_clientId    = azurerm_user_assigned_identity.id-aks-kv.client_id
                 identitySelector     = var.identitySelector 
               }
        )
}              
*/