terraform {
  backend "azurerm" {
    resource_group_name  = "ext-rg"
    storage_account_name = "extrastorage26"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
  required_version = ">= 1.0.0"
}