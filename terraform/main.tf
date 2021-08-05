terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.70.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {
  #version = "=1.6.0"
}


data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-test-tf"
  location = "East US 2"
}


resource "azurerm_user_assigned_identity" "example" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  name = "search-api"
}

#data "azuread_service_principal" "sp" {
#  display_name = "AKSClusterServicePrincipal-demo0000999"
#}


## ad
resource "azuread_application" "app" {
  display_name                  = "app-sample-tf"
  sign_in_audience              = "AzureADMyOrg"
}

resource "azuread_service_principal" "sp-aks" {
  application_id               = azuread_application.app.application_id
  app_role_assignment_required = false
  tags = ["example", "tags", "here"]
}

resource "azuread_application_password" "rbac" {
  application_object_id = azuread_application.app.object_id
  display_name = "rbac"
}


resource "azurerm_key_vault" "kv" {
  name                        = "kv-aks"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  #enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  #purge_protection_enabled    = false

  sku_name = "standard"
  
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
  
}

resource "azurerm_key_vault_secret" "kv-secret-1" {
  name         = "DBUsername"
  value        = "sist_rpsr"
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "kv-secret-2" {
  name         = "DBPassword"
  value        = "P@ssword&"
  key_vault_id = azurerm_key_vault.kv.id
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

  subnet {
    name           = "nodesubnet"
    address_prefix = "10.240.0.0/16"
  }

  tags = {
    environment = "Test"
  }
}

resource "azurerm_role_assignment" "example" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.example.principal_id
}


/*
az role assignment create --role "" --assignee $aks.servicePrincipalProfile.clientId --scope $identity.id

resource "azurerm_role_assignment" "example" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.example.principal_id
}
*/

resource "azurerm_key_vault_access_policy" "example" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.example.principal_id

  secret_permissions = [
    "Get",
  ]
}