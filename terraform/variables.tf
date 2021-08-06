#variable "client_id" {}
#variable "client_secret" {}

variable "agent_count" {
  default = 2
}

variable "ssh_public_key" {
  default = "~/.ssh/id_rsa.pub"
}

variable "dns_prefix" {
  default = "k8stest"
}

variable "cluster_name" {
  default = "k8stest"
}

variable "resource_group_name" {
  default = "azure-k8stest"
}

variable "location" {
  default = "Central US"
}


variable "secretProviderClassName" {
  default = "secret-provider-kv"
}

variable "keyVaultName" {
  default = "kv-aks"
}

variable "secretName" {
  default = "secret-kv"
}

variable "secret1Name" {
  default = "DBUsername"
}

variable "secret2Name" {
  default = "DBPassword"
}

variable "secret1Alias" {
  default = "DB_USERNAME"
}

variable "secret2Alias" {
  default = "DB_PASSWORD"
}

variable "identityName" {
  default = "id-aks-kv"
}

variable "identitySelector" {
  default = "azure-kv"
}
