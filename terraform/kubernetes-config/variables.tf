variable "cluster_name" {
  type = string
}

variable "kubeconfig" {
  type = string
}

variable "resourceGroup" {
  type = string
}
  

variable "subscriptionId" {
  type = string
}

variable "tenantId" {
  type = string
}

variable secretProviderClassName { 
  default = "secret-provider-kv"
}

variable keyVaultName {
  default = "kv-aks"
}

variable secretName {
  default = "secret-kv"
}

variable secret1Name {
  default = "DBUsername"
}

variable secret2Name {
  default = "DBPassword"
}

variable secret1Alias {
  default = "DB_USERNAME"
}

variable secret2Alias {
  default = "DB_PASSWORD"
}


variable  identityName {
  default = "id-aks-kv" 
}

variable  identitySelector {
  default = "azure-kv"
}