output "secret-provider-class" {
  description = "tasd"
  value = templatefile(
               "${path.module}/secret-provider-class.yaml"
               , 
               { tenantId = "\"${var.tenantId}\"", 
                 resourceGroupName = "\"${var.resourceGroup}\"", 
                 subscriptionId = "\"${var.subscriptionId }\"",
                 secretProviderClassName = var.secretProviderClassName,
                 keyVaultName = var.keyVaultName,
                 secretName = var.secretName,
                 secret1Alias = var.secret1Alias,
                 secret2Alias = var.secret2Alias,
                 secret1Name = var.secret1Name,
                 secret2Name = var.secret2Name
        })
}              