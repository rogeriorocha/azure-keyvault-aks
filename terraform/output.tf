/*
output "secret-provider-class" {
  description = "tasd"
  value = templatefile(
               "${path.root}/secret-provider-class.yaml"
               , 
               { tenantId = "\"${data.azurerm_client_config.current.tenant_id}\"", 
                 resourceGroupName = "\"${azurerm_resource_group.rg.name}\"", 
                 subscriptionId = "\"${data.azurerm_client_config.current.subscription_id}\"",
                 secretProviderClassName = var.secretProviderClassName,
                 keyVaultName = var.keyVaultName,
                 secretName = var.secretName,
                 secret1Alias = var.secret1Alias,
                 secret2Alias = var.secret2Alias,
                 secret1Name = var.secret1Name,
                 secret2Name = var.secret2Name
        })
      
}              

*/