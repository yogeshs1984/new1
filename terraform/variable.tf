variable "environment" {} # runtime variable

variable "azure_resource_group" {
    default = "ddet"
}

variable "virtual_networks" {
    default = "10.1.0.0/16"
}

variable "location" {
    default = "westus2"
}

variable "oracledbCount" {
    default = "1"
}

variable "mongodbCount" {
    default = "1"
}


variable "tags" {
  type = map
  default = {
    envronment    = "test"
    provision_by  = "terraform"
  }
}

variable "ssh_public_key" {
    default = ".ssh/kubernetes.pub"
}

variable "client_id" {
    default = "8dcfb4e4-4b5b-42c1-8289-aaa7de69f2b9"
}

variable "client_secret" {
    default = "b.QCUj2P6UE-w-21h6c.Z2jXfB6jVuRBwZ"
}